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
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
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
      if (onConnectionState != null) onConnectionState!(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      if (onRemoteStreamAdded != null) {
        onRemoteStreamAdded!(stream);
      }
    };

    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
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
      if (onConnectionState != null) onConnectionState!(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      if (onRemoteStreamAdded != null) {
        onRemoteStreamAdded!(stream);
      }
    };

    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(answer);

    await _callRepository.answerCall(_roomId!, _callId!, {
      'sdp': answer.sdp,
      'type': answer.type,
    });

    _listenToIceCandidates();
  }

  Future<void> _initLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  void _listenToAnswerAndIceCandidates() {
    _callRepository.listenToCall(_roomId!, _callId!).listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (data['status'] == 'ended') {
        endCall();
        return;
      }

      if (_peerConnection?.getRemoteDescription() != null) return;
      
      if (data.containsKey('answer')) {
        var answer = data['answer'];
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
    });

    _listenToIceCandidates();
  }

  void _listenToIceCandidates() {
    final remoteRole = _role == 'caller' ? 'callee' : 'caller';
    _callRepository.listenToIceCandidates(_roomId!, _callId!, remoteRole).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  Future<void> endCall() async {
    try {
      if (_roomId != null && _callId != null) {
        await _callRepository.endCall(_roomId!, _callId!);
      }
    } catch (e) {
      debugPrint("Error ending call in DB: $e");
    }
    
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    
    if (onCallEnded != null) onCallEnded!();
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
