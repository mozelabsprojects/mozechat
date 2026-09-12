import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_service.dart';
import '../services/callkit_service.dart';
import '../services/preferences_service.dart';
import '../repositories/chat_repository.dart';
import '../main.dart';
import '../screens/call_screen.dart';

class CallProvider extends ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();
  final CallkitService _callkitService = CallkitService();
  
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  DateTime? _callStartTime;
  String? _currentRoomCode;
  String? _currentUserNickname;

  CallProvider() {
    _webRTCService.onRemoteStreamAdded = (stream) {
      _remoteStream = stream;
      notifyListeners();
    };

    _webRTCService.onCallEnded = () {
      _isInCall = false;
      _localStream = null;
      _remoteStream = null;
      _callStartTime = null;
      notifyListeners();
    };

    _callkitService.onCallAccepted = (callId, offer, roomId) async {
      await [Permission.microphone].request();
      _isInCall = true;
      _callStartTime = DateTime.now();
      _currentRoomCode = roomId;
      _currentUserNickname = await PreferencesService.getNickname() ?? 'Unknown';
      notifyListeners();
      await _webRTCService.joinCall(roomId, callId, offer);
      _localStream = _webRTCService.localStream;
      _isSpeaker = false;
      _webRTCService.toggleSpeaker(_isSpeaker);
      notifyListeners();

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const CallScreen()),
        );
      }
    };

    _callkitService.onCallDeclined = (callId, roomId) {
      // Logic handled via DB endCall if needed
    };
  }

  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> startCall(String roomCode, String callerId, String nickname) async {
    await [Permission.microphone, Permission.bluetoothConnect].request();
    
    _isInCall = true;
    _callStartTime = DateTime.now();
    _currentRoomCode = roomCode;
    _currentUserNickname = nickname;
    notifyListeners();

    try {
      await ChatRepository().sendMessage(
        roomCode,
        "📞 Sesli arama başlattı.",
        nickname,
      );
    } catch (e) {
      debugPrint("Error sending call start message: $e");
    }

    await _webRTCService.startCall(roomCode, callerId);
    _localStream = _webRTCService.localStream;
    _isSpeaker = false;
    _webRTCService.toggleSpeaker(_isSpeaker);
    notifyListeners();
  }

  Future<void> endCall() async {
    if (_isInCall && _callStartTime != null && _currentRoomCode != null && _currentUserNickname != null) {
      final duration = DateTime.now().difference(_callStartTime!);
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      final timeStr = "${mins}m ${secs}s";
      
      try {
        await ChatRepository().sendMessage(
          _currentRoomCode!,
          "📞 Sesli arama sonlandırıldı. Süre: $timeStr",
          _currentUserNickname!,
        );
      } catch (e) {
        debugPrint("Error sending call end message: $e");
      }
    }

    _callStartTime = null;
    await _webRTCService.endCall();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _webRTCService.toggleMute(_isMuted);
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    _webRTCService.toggleSpeaker(_isSpeaker);
    notifyListeners();
  }
}
