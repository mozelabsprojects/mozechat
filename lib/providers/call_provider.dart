import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_service.dart';
import '../services/callkit_service.dart';

class CallProvider extends ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();
  final CallkitService _callkitService = CallkitService();
  
  bool _isInCall = false;
  bool _isMuted = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallProvider() {
    _webRTCService.onRemoteStreamAdded = (stream) {
      _remoteStream = stream;
      notifyListeners();
    };

    _webRTCService.onCallEnded = () {
      _isInCall = false;
      _localStream = null;
      _remoteStream = null;
      notifyListeners();
    };

    _callkitService.onCallAccepted = (callId, offer, roomId) async {
      _isInCall = true;
      _isInCall = true;
      notifyListeners();
      await _webRTCService.joinCall(roomId, callId, offer);
      _localStream = _webRTCService.localStream;
      notifyListeners();
    };

    _callkitService.onCallDeclined = (callId, roomId) {
      // Logic handled via DB endCall if needed
    };
  }

  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> startCall(String roomCode, String callerId) async {
    await [Permission.camera, Permission.microphone].request();
    
    _isInCall = true;
    notifyListeners();

    await _webRTCService.startCall(roomCode, callerId);
    _localStream = _webRTCService.localStream;
    notifyListeners();
  }

  Future<void> endCall() async {
    await _webRTCService.endCall();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _webRTCService.toggleMute(_isMuted);
    notifyListeners();
  }
}
