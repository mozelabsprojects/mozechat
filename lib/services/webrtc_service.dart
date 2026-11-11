import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../repositories/call_repository.dart';
import 'callkit_service.dart';
import 'notification_service.dart';

class WebRTCService {
  final CallRepository _callRepository = CallRepository();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;

  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _iceCandidatesSubscription;
  Timer? _disconnectGraceTimer;
  Timer? _iceRestartTimer;
  Timer? _ringingTimeoutTimer;

  final Map<String, dynamic> _configuration = {
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 8,
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
  };

  Map<String, dynamic> _sdpConstraints({required bool video}) => {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': video,
        },
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      };

  /// Hard cap for the video stream (kbps). 640x480@24fps looks good at ~500kbps,
  /// which keeps mobile data usage low (~3.7 MB/min) while staying smooth.
  static const int _maxVideoBitrateKbps = 550;

  String? _roomId;
  String? _callId;
  String? _role;

  bool _isVideoCall = false;
  bool _isCameraOn = true;
  bool _isFrontCamera = true;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _localRendererInitialized = false;

  bool _hasSetRemoteDescription = false;
  bool _isEndingCall = false;
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];

  Function(MediaStream stream)? onRemoteStreamAdded;
  Function(RTCPeerConnectionState state)? onConnectionState;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(bool isOn)? onRemoteCameraChanged;

  String? get currentCallId => _callId;
  String? get currentRoomId => _roomId;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  RTCVideoRenderer get localRenderer => _localRenderer;
  bool get isVideoCall => _isVideoCall;
  bool get isCameraOn => _isCameraOn;
  bool get isFrontCamera => _isFrontCamera;

  Future<void> _ensureRendererInitialized() async {
    if (!_rendererInitialized) {
      try {
        await _remoteRenderer.initialize();
        _rendererInitialized = true;
      } catch (e) {
        debugPrint('RTCVideoRenderer init warning: $e');
      }
    }
    if (!_localRendererInitialized) {
      try {
        await _localRenderer.initialize();
        _localRendererInitialized = true;
      } catch (e) {
        debugPrint('Local RTCVideoRenderer init warning: $e');
      }
    }
  }

  /// Cap the video m-section bandwidth with `b=AS:` so data usage stays low.
  String _limitVideoBitrate(String sdp) {
    final lines = sdp.split('\r\n');
    final out = <String>[];
    bool inVideo = false;
    bool bitrateInserted = false;
    for (final line in lines) {
      if (line.startsWith('m=')) {
        inVideo = line.startsWith('m=video');
        bitrateInserted = false;
      }
      if (inVideo && line.startsWith('b=AS:')) {
        // Replace any existing limit with ours
        out.add('b=AS:$_maxVideoBitrateKbps');
        bitrateInserted = true;
        continue;
      }
      out.add(line);
      if (inVideo && !bitrateInserted && line.startsWith('c=')) {
        out.add('b=AS:$_maxVideoBitrateKbps');
        bitrateInserted = true;
      }
    }
    return out.join('\r\n');
  }

  /// Optimize Opus (and, for video calls, VP8/H264 bandwidth) SDP parameters
  String _optimizeSdp(String? sdp, {required bool video}) {
    final voiceOptimized = _optimizeSdpForVoice(sdp);
    if (!video || voiceOptimized.isEmpty) return voiceOptimized;
    return _limitVideoBitrate(voiceOptimized);
  }

  /// Optimize Opus SDP parameters to prevent crackling, echo, and packet-loss distortion
  String _optimizeSdpForVoice(String? sdp) {
    if (sdp == null || sdp.isEmpty) return '';
    final lines = sdp.split('\r\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('a=fmtp:111 ')) {
        final paramsToEnsure = <String, String>{
          'minptime': '10',
          'ptime': '20',
          'useinbandfec': '1',
          'usedtx': '1',
          'maxaveragebitrate': '28000',
          'maxplaybackrate': '32000',
          'stereo': '0',
        };
        String line = lines[i];
        paramsToEnsure.forEach((key, value) {
          if (!line.contains('$key=')) {
            line = '$line;$key=$value';
          }
        });
        lines[i] = line;
      }
    }
    return lines.join('\r\n');
  }

  /// Configure hardware communication mode and clean up any leftover session before starting/joining
  Future<void> _prepareSession() async {
    await _cleanupResourcesOnly();
    _hasSetRemoteDescription = false;
    _isEndingCall = false;
    _remoteCandidatesQueue.clear();

    await _ensureRendererInitialized();

    try {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    } catch (e) {
      debugPrint('setAndroidAudioConfiguration warning: $e');
    }
  }

  /// Initiate an outgoing call (voice by default, or video when [video] is true)
  Future<String?> startCall(
    String roomCode,
    String callerId, {
    String? callerName,
    bool video = false,
  }) async {
    try {
      await _prepareSession();

      _roomId = roomCode;
      _callId = const Uuid().v4();
      _role = 'caller';
      _isVideoCall = video;
      _isCameraOn = video;
      _isFrontCamera = true;

      await _initLocalStream(video: video);
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners();
      await _addLocalTracks();

      RTCSessionDescription offer =
          await _peerConnection!.createOffer(_sdpConstraints(video: _isVideoCall));
      RTCSessionDescription localDesc = offer;
      try {
        final optimizedSdp = _optimizeSdp(offer.sdp, video: _isVideoCall);
        final candidateOffer = RTCSessionDescription(optimizedSdp, offer.type);
        await _peerConnection!.setLocalDescription(candidateOffer);
        localDesc = candidateOffer;
      } catch (e) {
        debugPrint('Fallback to standard SDP offer: $e');
        await _peerConnection!.setLocalDescription(offer);
      }

      await _callRepository.createOffer(
        _roomId!,
        _callId!,
        callerId,
        {
          'sdp': localDesc.sdp,
          'type': localDesc.type,
        },
        callerName: callerName,
        isVideo: _isVideoCall,
      );

      // Start 45s ringing timeout in case callee never answers
      _ringingTimeoutTimer?.cancel();
      _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
        debugPrint('WebRTC ringing timeout reached (45s), ending call.');
        endCall();
      });

      _listenToCallDocument();
      _listenToIceCandidates();
      return _callId;
    } catch (e) {
      debugPrint('WebRTC startCall error: $e');
      await endCall();
      return null;
    }
  }

  /// Answer an incoming call. Video is detected from the offer SDP (`m=video`).
  /// When [cameraAllowed] is false the callee still receives the caller's video
  /// but sends audio only.
  Future<bool> joinCall(
    String roomCode,
    String callId,
    Map<String, dynamic> offer, {
    bool cameraAllowed = true,
  }) async {
    try {
      await _prepareSession();

      _roomId = roomCode;
      _callId = callId;
      _role = 'callee';

      final sdp = offer['sdp']?.toString();
      final type = offer['type']?.toString() ?? 'offer';
      if (sdp == null || sdp.isEmpty) {
        throw Exception('Invalid offer SDP');
      }

      _isVideoCall = sdp.contains('m=video');
      _isCameraOn = _isVideoCall && cameraAllowed;
      _isFrontCamera = true;

      await _initLocalStream(video: _isVideoCall && cameraAllowed);
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners();
      await _addLocalTracks();

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _hasSetRemoteDescription = true;

      RTCSessionDescription answer =
          await _peerConnection!.createAnswer(_sdpConstraints(video: _isVideoCall));
      RTCSessionDescription localAnswer = answer;
      try {
        final optimizedSdp = _optimizeSdp(answer.sdp, video: _isVideoCall);
        final candidateAnswer = RTCSessionDescription(optimizedSdp, answer.type);
        await _peerConnection!.setLocalDescription(candidateAnswer);
        localAnswer = candidateAnswer;
      } catch (e) {
        debugPrint('Fallback to standard SDP answer: $e');
        await _peerConnection!.setLocalDescription(answer);
      }

      await _callRepository.answerCall(_roomId!, _callId!, {
        'sdp': localAnswer.sdp,
        'type': localAnswer.type,
      });
      if (_isVideoCall && !_isCameraOn) {
        // Joined a video call without camera permission: tell the caller
        unawaited(_callRepository.setCameraState(_roomId!, _callId!, 'callee', false));
      }

      _processQueuedCandidates();
      // Both caller and callee MUST listen to the call document for remote hang-up!
      _listenToCallDocument();
      _listenToIceCandidates();
      return true;
    } catch (e) {
      debugPrint('WebRTC joinCall error: $e');
      await endCall();
      return false;
    }
  }

  Future<void> _addLocalTracks() async {
    final stream = _localStream;
    if (stream == null || _peerConnection == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = true;
      await _peerConnection!.addTrack(track, stream);
    }
    if (_isVideoCall) {
      for (final track in stream.getVideoTracks()) {
        track.enabled = true;
        await _peerConnection!.addTrack(track, stream);
      }
    }
  }

  void _setupPeerConnectionListeners() {
    if (_peerConnection == null) return;

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_isEndingCall || _roomId == null || _callId == null || _role == null) return;
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      _callRepository.addIceCandidate(_roomId!, _callId!, _role!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRTC ICE State ($_role): $state');
      if (_isEndingCall) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _ringingTimeoutTimer?.cancel();
        _disconnectGraceTimer?.cancel();
        _iceRestartTimer?.cancel();
        if (_callId != null) {
          CallkitService().setCallConnected(_callId!);
        }
        if (onCallConnected != null) onCallConnected!();
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTC Connection State ($_role): $state');
      if (_isEndingCall) return;
      if (onConnectionState != null) onConnectionState!(state);

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _ringingTimeoutTimer?.cancel();
        _disconnectGraceTimer?.cancel();
        _iceRestartTimer?.cancel();
        if (_callId != null) {
          CallkitService().setCallConnected(_callId!);
        }
        if (onCallConnected != null) onCallConnected!();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Transient network hiccup: attempt ICE restart after 4s and allow 25s before dropping
        _iceRestartTimer?.cancel();
        _iceRestartTimer = Timer(const Duration(seconds: 4), () {
          if (!_isEndingCall) {
            debugPrint('Attempting seamless ICE restart after transient disconnect...');
            try {
              _peerConnection?.restartIce();
            } catch (_) {}
          }
        });

        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 25), () {
          debugPrint('WebRTC Disconnect grace period (25s) expired, ending call.');
          endCall();
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Attempt an immediate ICE restart and give 12s to recover before ending
        try {
          _peerConnection?.restartIce();
        } catch (_) {}
        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 12), () {
          debugPrint('WebRTC Failed state did not recover after 12s, ending call.');
          endCall();
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _disconnectGraceTimer?.cancel();
        _iceRestartTimer?.cancel();
        endCall();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (_isEndingCall) return;
      event.track.enabled = true;
      if (event.streams.isNotEmpty) {
        final incoming = event.streams[0];
        for (final track in incoming.getAudioTracks()) {
          track.enabled = true;
        }
        for (final track in incoming.getVideoTracks()) {
          track.enabled = true;
        }
        if (_remoteStream == null ||
            incoming.getVideoTracks().isNotEmpty ||
            _remoteStream!.getVideoTracks().isEmpty) {
          _remoteStream = incoming;
        }
        if (_rendererInitialized) {
          // Force flutter_webrtc to re-bind the native surface when the video track arrives
          // on the same MediaStream instance after the audio track
          if (event.track.kind == 'video' && _remoteRenderer.srcObject == _remoteStream) {
            _remoteRenderer.srcObject = null;
          }
          if (_remoteRenderer.srcObject != _remoteStream) {
            _remoteRenderer.srcObject = _remoteStream;
          }
        }
        if (onRemoteStreamAdded != null) {
          onRemoteStreamAdded!(_remoteStream!);
        }
      }
    };
  }

  Future<void> _initLocalStream({bool video = false}) async {
    // Use both mandatory/optional format (required by Android flutter_webrtc MediaConstraintsUtils)
    // and standard keys for cross-platform compatibility.
    final Map<String, dynamic> audioConstraints = {
      'mandatory': <String, dynamic>{},
      'optional': <Map<String, dynamic>>[
        {'echoCancellation': true},
        {'googEchoCancellation': true},
        {'googEchoCancellation2': true},
        {'googDAEchoCancellation': true},
        {'noiseSuppression': true},
        {'googNoiseSuppression': true},
        {'googNoiseSuppression2': true},
        {'autoGainControl': true},
        {'googAutoGainControl': true},
        {'googAutoGainControl2': true},
        {'googHighpassFilter': true},
        {'googTypingNoiseDetection': true},
        {'googAudioMirroring': false},
      ],
    };

    // Light-weight 480p@24fps capture: great quality on phones, low CPU/battery/data
    final Map<String, dynamic> videoConstraints = {
      'mandatory': <String, dynamic>{
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '24',
      },
      'facingMode': 'user',
      'optional': <Map<String, dynamic>>[],
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': audioConstraints,
        'video': video ? videoConstraints : false,
      });
    } catch (e) {
      debugPrint('Fallback to default media constraints: $e');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video ? {'facingMode': 'user'} : false,
      });
    }

    if (video && _localRendererInitialized) {
      _localRenderer.srcObject = _localStream;
    }
  }

  void _processQueuedCandidates() {
    for (var candidate in _remoteCandidatesQueue) {
      try {
        _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('addCandidate error: $e');
      }
    }
    _remoteCandidatesQueue.clear();
  }

  void _listenToCallDocument() {
    _callSubscription?.cancel();
    if (_roomId == null || _callId == null) return;

    _callSubscription = _callRepository.listenToCall(_roomId!, _callId!).listen((snapshot) async {
      if (_isEndingCall) return;
      if (!snapshot.exists) {
        endCall(fromRemote: true);
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'ended' || status == 'declined') {
        endCall(fromRemote: true);
        return;
      }

      if (status == 'connected') {
        _ringingTimeoutTimer?.cancel();
        if (onCallConnected != null) onCallConnected!();
      }

      // Peer camera on/off state (video calls only)
      if (_isVideoCall && _role != null) {
        final remoteRole = _role == 'caller' ? 'callee' : 'caller';
        final remoteCam = data['cam_$remoteRole'];
        if (remoteCam is bool && onRemoteCameraChanged != null) {
          onRemoteCameraChanged!(remoteCam);
        }
      }

      if (_role == 'caller' && !_hasSetRemoteDescription && data.containsKey('answer')) {
        final answer = data['answer'];
        if (answer is Map && answer['sdp'] != null) {
          _hasSetRemoteDescription = true;
          _ringingTimeoutTimer?.cancel();
          try {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(
                answer['sdp'].toString(),
                (answer['type'] ?? 'answer').toString(),
              ),
            );
            _processQueuedCandidates();
          } catch (e) {
            debugPrint('setRemoteDescription error: $e');
          }
        }
      }
    });
  }

  void _listenToIceCandidates() {
    if (_roomId == null || _callId == null || _role == null) return;
    final remoteRole = _role == 'caller' ? 'callee' : 'caller';
    _iceCandidatesSubscription?.cancel();
    _iceCandidatesSubscription = _callRepository
        .listenToIceCandidates(_roomId!, _callId!, remoteRole)
        .listen((snapshot) {
      if (_isEndingCall) return;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null || data['candidate'] == null) continue;
          final sdpMLineIdxRaw = data['sdpMLineIndex'];
          final int? sdpMLineIdx = sdpMLineIdxRaw is int
              ? sdpMLineIdxRaw
              : int.tryParse(sdpMLineIdxRaw?.toString() ?? '');
          final candidate = RTCIceCandidate(
            data['candidate'].toString(),
            data['sdpMid']?.toString(),
            sdpMLineIdx,
          );

          if (!_hasSetRemoteDescription) {
            _remoteCandidatesQueue.add(candidate);
          } else {
            try {
              _peerConnection?.addCandidate(candidate);
            } catch (e) {
              debugPrint('addCandidate error: $e');
            }
          }
        }
      }
    });
  }

  Future<void> _cleanupResourcesOnly() async {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
    _disconnectGraceTimer?.cancel();
    _disconnectGraceTimer = null;
    _iceRestartTimer?.cancel();
    _iceRestartTimer = null;
    _callSubscription?.cancel();
    _callSubscription = null;
    _iceCandidatesSubscription?.cancel();
    _iceCandidatesSubscription = null;

    try {
      if (_rendererInitialized) {
        _remoteRenderer.srcObject = null;
      }
      if (_localRendererInitialized) {
        _localRenderer.srcObject = null;
      }
    } catch (_) {}

    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _remoteStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      await _remoteStream?.dispose();
    } catch (e) {
      debugPrint('Error disposing streams: $e');
    }

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint('Error disposing peer connection: $e');
    }

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _hasSetRemoteDescription = false;
    _remoteCandidatesQueue.clear();
  }

  Future<void> endCall({bool fromRemote = false}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    final roomToEnd = _roomId;
    final callToEnd = _callId;
    _roomId = null;
    _callId = null;
    _role = null;

    await _cleanupResourcesOnly();

    _isEndingCall = false;
    _isVideoCall = false;
    _isCameraOn = true;
    _isFrontCamera = true;
    if (onCallEnded != null) onCallEnded!();

    // Ensure CallKit system UI / ongoing call notification is immediately cleared
    unawaited(CallkitService().endAllCalls());
    if (roomToEnd != null) {
      unawaited(NotificationService.clearNotificationsForRoom(roomToEnd));
    }

    if (roomToEnd != null && !fromRemote) {
      try {
        if (callToEnd != null) {
          await _callRepository.endCall(roomToEnd, callToEnd);
        }
        await _callRepository.endAllActiveCallsInRoom(roomToEnd);
      } catch (e) {
        debugPrint('Error ending call in DB: $e');
      }
    }
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  /// Turn the local camera on/off without renegotiation (track.enabled) and
  /// tell the peer so it can render a "camera off" placeholder.
  void setCameraEnabled(bool enabled) {
    if (!_isVideoCall) return;
    _isCameraOn = enabled;
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getVideoTracks()) {
        track.enabled = enabled;
      }
    }
    if (_roomId != null && _callId != null && _role != null) {
      unawaited(_callRepository.setCameraState(_roomId!, _callId!, _role!, enabled));
    }
  }

  Future<void> switchCamera() async {
    if (!_isVideoCall) return;
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      _isFrontCamera = !_isFrontCamera;
    } catch (e) {
      debugPrint('switchCamera error: $e');
    }
  }

  void toggleSpeaker(bool isSpeaker) {
    try {
      Helper.setSpeakerphoneOn(isSpeaker);
    } catch (e) {
      debugPrint('toggleSpeaker error: $e');
    }
  }
}
