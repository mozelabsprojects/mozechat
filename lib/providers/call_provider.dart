import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_service.dart';
import '../services/callkit_service.dart';
import '../services/preferences_service.dart';
import '../services/crypto_service.dart';
import '../repositories/chat_repository.dart';
import '../repositories/call_repository.dart';
import '../utils/app_strings.dart';
import '../main.dart';
import '../screens/call_screen.dart';

class CallProvider extends ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();
  final CallkitService _callkitService = CallkitService();
  final CallRepository _callRepository = CallRepository();

  bool _isInCall = false;
  bool _isCallConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isCaller = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  DateTime? _callStartTime;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  String? _currentRoomCode;
  String? _currentUserNickname;

  // Real-time room incoming call state for WhatsApp-style in-chat banner
  StreamSubscription<QuerySnapshot>? _roomCallsSubscription;
  String? _watchedRoomCode;
  String? _incomingCallId;
  Map<String, dynamic>? _incomingOffer;
  String? _incomingCallerName;

  CallProvider() {
    _webRTCService.onRemoteStreamAdded = (stream) {
      _remoteStream = stream;
      _isCallConnected = true;
      _startDurationTimerIfNeeded();
      notifyListeners();
    };

    _webRTCService.onCallConnected = () {
      _isCallConnected = true;
      _startDurationTimerIfNeeded();
      notifyListeners();
    };

    _webRTCService.onCallEnded = () {
      _resetCallState();
    };

    _callkitService.onCallAccepted = (callId, offer, roomId) async {
      final resolvedCode = await _resolveRoomCode(roomId);
      await joinIncomingRoomCall(
        roomCode: resolvedCode,
        callId: callId,
        offer: offer,
        openCallScreen: true,
      );
    };

    _callkitService.onCallDeclined = (callId, roomId) async {
      final resolvedCode = await _resolveRoomCode(roomId);
      if (resolvedCode.isNotEmpty && callId.isNotEmpty) {
        await _callRepository.endCall(resolvedCode, callId);
      }
      if (_incomingCallId == callId) {
        _clearIncomingBannerState();
      }
      if (_isInCall) {
        await _webRTCService.endCall();
        _resetCallState();
      }
    };

    _callkitService.onCallEndedBySystem = (callId) async {
      if (_isInCall) {
        await endCall();
      }
    };
  }

  bool get isInCall => _isInCall;
  bool get isCallConnected => _isCallConnected || _remoteStream != null;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  String? get currentRoomCode => _currentRoomCode;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer get remoteRenderer => _webRTCService.remoteRenderer;
  int get callDurationSeconds => _callDurationSeconds;

  bool get hasIncomingRoomCall =>
      !_isInCall && _incomingCallId != null && _incomingOffer != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;

  String get formattedDuration {
    final mins = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<String> _resolveRoomCode(String roomIdOrCode) async {
    String resolvedCode = roomIdOrCode.trim();
    if (resolvedCode.length == 64) {
      final history = await PreferencesService.getRoomHistory();
      for (final code in history) {
        if (CryptoService.deriveRoomId(code) == resolvedCode) {
          resolvedCode = code;
          break;
        }
      }
    }
    return resolvedCode;
  }

  void _startDurationTimerIfNeeded() {
    _callStartTime ??= DateTime.now();
    if (_durationTimer != null && _durationTimer!.isActive) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null && _isInCall) {
        _callDurationSeconds = DateTime.now().difference(_callStartTime!).inSeconds;
        notifyListeners();
      }
    });
  }

  void _clearIncomingBannerState() {
    _incomingCallId = null;
    _incomingOffer = null;
    _incomingCallerName = null;
    notifyListeners();
  }

  void _resetCallState() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _isInCall = false;
    _isCallConnected = false;
    _isMuted = false;
    _isSpeaker = false;
    _isCaller = false;
    _localStream = null;
    _remoteStream = null;
    _callStartTime = null;
    _callDurationSeconds = 0;
    _currentRoomCode = null;
    notifyListeners();
  }

  /// Watch a specific chat room for active incoming calls to power the WhatsApp-style banner
  void watchRoomCalls(String? roomCode, String? currentUserId) {
    if (roomCode == null || roomCode.isEmpty) {
      _roomCallsSubscription?.cancel();
      _roomCallsSubscription = null;
      _watchedRoomCode = null;
      _clearIncomingBannerState();
      return;
    }

    if (_watchedRoomCode == roomCode && _roomCallsSubscription != null) {
      return;
    }

    _roomCallsSubscription?.cancel();
    _watchedRoomCode = roomCode;

    _roomCallsSubscription = _callRepository.listenToActiveCalls(roomCode).listen((snapshot) {
      if (_isInCall) {
        if (_incomingCallId != null) {
          _clearIncomingBannerState();
        }
        return;
      }

      String? foundCallId;
      Map<String, dynamic>? foundOffer;
      String? foundCallerName;

      final now = DateTime.now();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final status = data['status'] as String?;
        final callerId = data['callerId'] as String?;
        final offer = data['offer'];
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Ignore calls started more than 60 seconds ago that are still stuck in ringing
        if (createdAt != null && now.difference(createdAt).inSeconds > 60 && status == 'ringing') {
          _callRepository.endCall(roomCode, doc.id);
          continue;
        }

        if (status == 'ringing' &&
            callerId != null &&
            callerId != currentUserId &&
            offer is Map) {
          foundCallId = doc.id;
          foundOffer = Map<String, dynamic>.from(offer);
          foundCallerName = (data['callerName'] as String?) ?? 'Unknown';
          break;
        }
      }

      if (_incomingCallId != foundCallId) {
        _incomingCallId = foundCallId;
        _incomingOffer = foundOffer;
        _incomingCallerName = foundCallerName;
        notifyListeners();
      }
    });
  }

  /// Join an incoming call (either from the in-chat WhatsApp banner or from CallKit)
  Future<void> joinIncomingRoomCall({
    String? roomCode,
    String? callId,
    Map<String, dynamic>? offer,
    bool openCallScreen = false,
  }) async {
    final targetRoom = roomCode ?? _watchedRoomCode;
    final targetCallId = callId ?? _incomingCallId;
    final targetOffer = offer ?? _incomingOffer;

    if (targetRoom == null || targetCallId == null || targetOffer == null) return;
    if (_isInCall) return;

    await [Permission.microphone, Permission.bluetoothConnect].request();

    // Dismiss any ringing system CallKit banner so it doesn't stay stuck
    await _callkitService.endAllCalls();

    _isInCall = true;
    _isCallConnected = false;
    _isCaller = false;
    _isMuted = false;
    _isSpeaker = false;
    _callDurationSeconds = 0;
    _callStartTime = DateTime.now();
    _currentRoomCode = targetRoom;
    _currentUserNickname = await PreferencesService.getNickname() ?? 'Unknown';
    _incomingCallId = null;
    _incomingOffer = null;
    _incomingCallerName = null;
    notifyListeners();

    await _webRTCService.joinCall(targetRoom, targetCallId, targetOffer);
    _localStream = _webRTCService.localStream;
    _webRTCService.toggleSpeaker(_isSpeaker);
    _startDurationTimerIfNeeded();
    notifyListeners();

    if (openCallScreen && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const CallScreen()),
      );
    }
  }

  /// Decline an incoming call directly from the in-chat WhatsApp banner
  Future<void> declineIncomingRoomCall() async {
    final targetRoom = _watchedRoomCode;
    final targetCallId = _incomingCallId;
    _clearIncomingBannerState();
    await _callkitService.endAllCalls();
    if (targetRoom != null && targetCallId != null) {
      await _callRepository.endCall(targetRoom, targetCallId);
    }
  }

  Future<void> startCall(String roomCode, String callerId, String nickname) async {
    if (_isInCall) return;

    await [Permission.microphone, Permission.bluetoothConnect].request();

    _isInCall = true;
    _isCallConnected = false;
    _isCaller = true;
    _isMuted = false;
    _isSpeaker = false;
    _callDurationSeconds = 0;
    _callStartTime = null;
    _currentRoomCode = roomCode;
    _currentUserNickname = nickname;
    _clearIncomingBannerState();
    notifyListeners();

    try {
      final lang = await PreferencesService.getLanguage();
      final strings = AppStrings(lang);
      await ChatRepository().sendMessage(
        roomCode,
        strings.voiceCallStartedMsg,
        nickname,
      );
    } catch (e) {
      debugPrint('Error sending call start message: $e');
    }

    await _webRTCService.startCall(
      roomCode,
      callerId,
      callerName: nickname,
    );
    _localStream = _webRTCService.localStream;
    _webRTCService.toggleSpeaker(_isSpeaker);
    notifyListeners();
  }

  Future<void> endCall() async {
    final wasInCall = _isInCall;
    final wasConnected = _isCallConnected || _remoteStream != null;
    final wasCaller = _isCaller;
    final startTime = _callStartTime;
    final roomCode = _currentRoomCode;
    final nickname = _currentUserNickname;

    _resetCallState();
    await _webRTCService.endCall();

    if (wasInCall && roomCode != null && nickname != null && (wasConnected || wasCaller)) {
      final duration = startTime != null ? DateTime.now().difference(startTime) : Duration.zero;
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      final timeStr = '${mins}m ${secs}s';

      try {
        final lang = await PreferencesService.getLanguage();
        final strings = AppStrings(lang);
        await ChatRepository().sendMessage(
          roomCode,
          strings.voiceCallEndedMsg(timeStr),
          nickname,
        );
      } catch (e) {
        debugPrint('Error sending call end message: $e');
      }
    }
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

  @override
  void dispose() {
    _durationTimer?.cancel();
    _roomCallsSubscription?.cancel();
    super.dispose();
  }
}
