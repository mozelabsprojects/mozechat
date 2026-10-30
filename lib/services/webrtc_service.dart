import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/call_repository.dart';
import 'package:uuid/uuid.dart';

class WebRTCService {
  final CallRepository _callRepository = CallRepository();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _iceCandidatesSubscription;
  Timer? _disconnectGraceTimer;
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      }
    ]
  };

  final Map<String, dynamic> _offerSdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  String? _roomId;
  String? _callId;
  String? _role;

  Function(MediaStream stream)? onRemoteStreamAdded;
  Function(RTCPeerConnectionState state)? onConnectionState;
  Function()? onCallEnded;

  /// Initiate an outgoing call
  Future<String?> startCall(String roomCode, String callerId) async {
    _roomId = roomCode;
    _callId = const Uuid().v4();
    _role = 'caller';

    await _initLocalStream();
    _peerConnection = await createPeerConnection(_configuration, _offerSdpConstraints);
    
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _callRepository.addIceCandidate(_roomId!, _callId!, _role!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint("WebRTC Connection State: $state");
      if (onConnectionState != null) onConnectionState!(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _disconnectGraceTimer?.cancel();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Tolerans süresi: Mobil ağ / WiFi geçişlerinde çağrının hemen kopmasını önler
        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 8), () {
          debugPrint("WebRTC Disconnect tolerans süresi doldu, çağrı sonlandırılıyor");
          endCall();
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _disconnectGraceTimer?.cancel();
        endCall();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        if (onRemoteStreamAdded != null) {
          onRemoteStreamAdded!(_remoteStream!);
        }
      }
    };

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }
    }

    RTCSessionDescription offer = await _peerConnection!.createOffer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(offer);

    await _callRepository.createOffer(_roomId!, _callId!, callerId, {
      'sdp': offer.sdp,
      'type': offer.type,
    });

    _listenToAnswerAndIceCandidates();
    return _callId;
  }

  /// Answer an incoming call
  Future<void> joinCall(String roomCode, String callId, Map<String, dynamic> offer) async {
    _roomId = roomCode;
    _callId = callId;
    _role = 'callee';

    await _initLocalStream();
    _peerConnection = await createPeerConnection(_configuration, _offerSdpConstraints);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _callRepository.addIceCandidate(_roomId!, _callId!, _role!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint("WebRTC Connection State (Answer): $state");
      if (onConnectionState != null) onConnectionState!(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _disconnectGraceTimer?.cancel();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Tolerans süresi: Mobil ağ / WiFi geçişlerinde çağrının hemen kopmasını önler
        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 8), () {
          debugPrint("WebRTC Disconnect tolerans süresi doldu (Answer), çağrı sonlandırılıyor");
          endCall();
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _disconnectGraceTimer?.cancel();
        endCall();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        if (onRemoteStreamAdded != null) {
          onRemoteStreamAdded!(_remoteStream!);
        }
      }
    };

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    _hasSetRemoteDescription = true;

    RTCSessionDescription answer = await _peerConnection!.createAnswer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(answer);

    await _callRepository.answerCall(_roomId!, _callId!, {
      'sdp': answer.sdp,
      'type': answer.type,
    });

    _processQueuedCandidates();
    _listenToIceCandidates();
  }

  Future<void> _initLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  bool _hasSetRemoteDescription = false;
  bool _isEndingCall = false;
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];

  void _processQueuedCandidates() {
    for (var candidate in _remoteCandidatesQueue) {
      try {
        _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint("addCandidate error: $e");
      }
    }
    _remoteCandidatesQueue.clear();
  }

  void _listenToAnswerAndIceCandidates() {
    _callSubscription?.cancel();
    _callSubscription = _callRepository.listenToCall(_roomId!, _callId!).listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (data['status'] == 'ended') {
        endCall();
        return;
      }

      if (_hasSetRemoteDescription) return;
      
      if (data.containsKey('answer')) {
        _hasSetRemoteDescription = true;
        var answer = data['answer'];
        try {
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(answer['sdp'], answer['type']),
          );
          _processQueuedCandidates();
        } catch (e) {
          debugPrint("setRemoteDescription error: $e");
        }
      }
    });

    _listenToIceCandidates();
  }

  void _listenToIceCandidates() {
    final remoteRole = _role == 'caller' ? 'callee' : 'caller';
    _iceCandidatesSubscription?.cancel();
    _iceCandidatesSubscription = _callRepository.listenToIceCandidates(_roomId!, _callId!, remoteRole).listen((snapshot) {
      if (_isEndingCall) return;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          var candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          if (!_hasSetRemoteDescription) {
            _remoteCandidatesQueue.add(candidate);
          } else {
            try {
              _peerConnection?.addCandidate(candidate);
            } catch (e) {
              debugPrint("addCandidate error: $e");
            }
          }
        }
      }
    });
  }

  Future<void> endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    _disconnectGraceTimer?.cancel();
    _disconnectGraceTimer = null;
    _callSubscription?.cancel();
    _callSubscription = null;
    _iceCandidatesSubscription?.cancel();
    _iceCandidatesSubscription = null;

    try {
      if (_roomId != null && _callId != null) {
        await _callRepository.endCall(_roomId!, _callId!);
      }
    } catch (e) {
      debugPrint("Error ending call in DB: $e");
    }
    
    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _remoteStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      await _remoteStream?.dispose();
    } catch (e) {
      debugPrint("Error disposing streams: $e");
    }

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint("Error disposing peer connection: $e");
    }
    
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _hasSetRemoteDescription = false;
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
    Helper.setSpeakerphoneOn(isSpeaker);
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
