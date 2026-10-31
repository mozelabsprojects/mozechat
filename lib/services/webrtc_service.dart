import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../repositories/call_repository.dart';
import 'callkit_service.dart';

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

  final Map<String, dynamic> _offerSdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  String? _roomId;
  String? _callId;
  String? _role;

  bool _hasSetRemoteDescription = false;
  bool _isEndingCall = false;
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];

  Function(MediaStream stream)? onRemoteStreamAdded;
  Function(RTCPeerConnectionState state)? onConnectionState;
  Function()? onCallConnected;
  Function()? onCallEnded;

  String? get currentCallId => _callId;
  String? get currentRoomId => _roomId;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  Future<void> _ensureRendererInitialized() async {
    if (!_rendererInitialized) {
      try {
        await _remoteRenderer.initialize();
        _rendererInitialized = true;
      } catch (e) {
        debugPrint('RTCVideoRenderer init warning: $e');
      }
    }
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
          'maxaveragebitrate': '48000',
          'maxplaybackrate': '48000',
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

  /// Initiate an outgoing call
  Future<String?> startCall(
    String roomCode,
    String callerId, {
    String? callerName,
  }) async {
    try {
      await _prepareSession();

      _roomId = roomCode;
      _callId = const Uuid().v4();
      _role = 'caller';

      await _initLocalStream();
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners();

      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = true;
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      RTCSessionDescription offer = await _peerConnection!.createOffer(_offerSdpConstraints);
      RTCSessionDescription localDesc = offer;
      try {
        final optimizedSdp = _optimizeSdpForVoice(offer.sdp);
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

  /// Answer an incoming call
  Future<bool> joinCall(
    String roomCode,
    String callId,
    Map<String, dynamic> offer,
  ) async {
    try {
      await _prepareSession();

      _roomId = roomCode;
      _callId = callId;
      _role = 'callee';

      await _initLocalStream();
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners();

      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = true;
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      final sdp = offer['sdp']?.toString();
      final type = offer['type']?.toString() ?? 'offer';
      if (sdp == null || sdp.isEmpty) {
        throw Exception('Invalid offer SDP');
      }

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _hasSetRemoteDescription = true;

      RTCSessionDescription answer = await _peerConnection!.createAnswer(_offerSdpConstraints);
      RTCSessionDescription localAnswer = answer;
      try {
        final optimizedSdp = _optimizeSdpForVoice(answer.sdp);
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
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        for (var track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
        }
        if (_rendererInitialized && _remoteRenderer.srcObject != _remoteStream) {
          _remoteRenderer.srcObject = _remoteStream;
        }
        if (onRemoteStreamAdded != null) {
          onRemoteStreamAdded!(_remoteStream!);
        }
      }
    };
  }

  Future<void> _initLocalStream() async {
    // Use both mandatory/optional format (required by Android flutter_webrtc MediaConstraintsUtils)
    // and standard keys for cross-platform compatibility.
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
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
      },
      'video': false,
    };
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      debugPrint('Fallback to default audio constraints: $e');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
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

    // Ensure CallKit system UI / ongoing call notification is immediately cleared
    await CallkitService().endAllCalls();

    if (!fromRemote && roomToEnd != null) {
      try {
        if (callToEnd != null) {
          await _callRepository.endCall(roomToEnd, callToEnd);
        }
        await _callRepository.endAllActiveCallsInRoom(roomToEnd);
      } catch (e) {
        debugPrint('Error ending call in DB: $e');
      }
    }

    _isEndingCall = false;
    if (onCallEnded != null) onCallEnded!();
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
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
