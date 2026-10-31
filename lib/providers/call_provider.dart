import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../services/callkit_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/crypto_service.dart';
import '../repositories/chat_repository.dart';
import '../repositories/call_repository.dart';
import '../utils/app_strings.dart';
import '../main.dart';
import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import 'chat_provider.dart';

class CallProvider extends ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();
  final CallkitService _callkitService = CallkitService();
  final CallRepository _callRepository = CallRepository();

  bool _isInCall = false;
  bool _isJoiningCall = false;
  bool _isCallConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isCaller = false;
  bool _isCallScreenOpen = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  DateTime? _callStartTime;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  String? _currentRoomCode;
  String? _currentUserNickname;
  String? _peerDisplayName;

  // Real-time room incoming call state for WhatsApp-style in-chat banner
  StreamSubscription<QuerySnapshot>? _roomCallsSubscription;
  String? _watchedRoomCode;
  String? _watchedUserId;
  String? _incomingCallId;
  Map<String, dynamic>? _incomingOffer;
  String? _incomingCallerName;

  CallProvider() {
    _webRTCService.onRemoteStreamAdded = (stream) {
      _remoteStream = stream;
      _isInCall = true;
      _isCallConnected = true;
      _startDurationTimerIfNeeded();
      notifyListeners();
      if (!_isCaller && !_isCallScreenOpen) {
        openCallScreenNow();
      }
    };

    _webRTCService.onCallConnected = () {
      _isInCall = true;
      _isCallConnected = true;
      _startDurationTimerIfNeeded();
      notifyListeners();
      if (!_isCaller && !_isCallScreenOpen) {
        openCallScreenNow();
      }
    };

    _webRTCService.onCallEnded = () {
      _resetCallState();
    };

    _callkitService.onCallAccepted = (callId, roomId, offer, callerName) async {
      final resolvedCode = await _resolveRoomCode(roomId);
      if (resolvedCode.isEmpty) return;

      // Ensure ChatScreen for this room is open underneath CallScreen if user accepted from outside the room
      final ctx = navigatorKey.currentContext;
      if (ctx != null &&
          ctx.mounted &&
          !NotificationService.shouldSuppressNotification(roomCode: resolvedCode)) {
        try {
          final chatProvider = ctx.read<ChatProvider>();
          if (chatProvider.roomCode != resolvedCode) {
            unawaited(chatProvider.joinRoom(resolvedCode));
          }
          if (!NotificationService.isUserInChatScreen) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          }
        } catch (_) {}
      }

      await joinIncomingRoomCall(
        roomCode: resolvedCode,
        callId: callId,
        offer: offer,
        callerName: callerName,
        openCallScreen: true,
      );
    };

    _callkitService.onCallDeclined = (callId, roomId) async {
      // Never decline or kill a call that the user has already answered or is currently joining
      if (_isInCall || _isJoiningCall) return;

      final resolvedCode = await _resolveRoomCode(roomId);
      if (resolvedCode.isNotEmpty && callId.isNotEmpty) {
        await _callRepository.endCall(resolvedCode, callId);
      }
      if (_incomingCallId == callId) {
        _clearIncomingBannerState();
      }
    };

    _callkitService.onCallEndedBySystem = (callId) async {
      // Do not terminate an active or joining Flutter CallScreen session when CallKit notification dismisses
      if (_isJoiningCall || _isInCall) {
        return;
      }
    };
  }

  bool get isInCall => _isInCall;
  bool get isJoiningCall => _isJoiningCall;
  bool get isCallConnected => _isCallConnected || _remoteStream != null;
  bool get isCaller => _isCaller;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  String? get currentRoomCode => _currentRoomCode;
  String? get peerDisplayName => _peerDisplayName;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer get remoteRenderer => _webRTCService.remoteRenderer;
  int get callDurationSeconds => _callDurationSeconds;

  bool get hasIncomingRoomCall =>
      !_isInCall && !_isJoiningCall && _incomingCallId != null && _incomingOffer != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;

  void setCallScreenOpen(bool isOpen) {
    _isCallScreenOpen = isOpen;
  }

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

  Future<String> _resolveDisplayName(String roomCode, {String? preferredName}) async {
    if (preferredName != null &&
        preferredName.trim().isNotEmpty &&
        preferredName != 'Unknown' &&
        preferredName != 'Biri') {
      return preferredName.trim();
    }
    try {
      final alias = await PreferencesService.getRoomAlias(roomCode);
      if (alias != null && alias.trim().isNotEmpty) {
        return alias.trim();
      }
    } catch (_) {}
    if (roomCode.length > 16) {
      return '${roomCode.substring(0, 12)}...';
    }
    return roomCode;
  }

  void openCallScreenNow() {
    if (_isCallScreenOpen) return;

    void tryPush([int attempt = 0]) {
      if (!_isInCall && !_isJoiningCall && !hasIncomingRoomCall) return;
      if (_isCallScreenOpen) return;
      final nav = navigatorKey.currentState;
      if (nav != null) {
        _isCallScreenOpen = true;
        nav.push(MaterialPageRoute(builder: (_) => const CallScreen())).then((_) {
          _isCallScreenOpen = false;
        });
      } else if (attempt < 20) {
        Future.delayed(const Duration(milliseconds: 100), () => tryPush(attempt + 1));
      }
    }

    tryPush();
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
    _isJoiningCall = false;
    _isCallConnected = false;
    _isMuted = false;
    _isSpeaker = false;
    _isCaller = false;
    _localStream = null;
    _remoteStream = null;
    _callStartTime = null;
    _callDurationSeconds = 0;
    _currentRoomCode = null;
    _peerDisplayName = null;
    notifyListeners();
  }

  /// Watch a specific chat room for active incoming calls to power the WhatsApp-style banner
  void watchRoomCalls(String? roomCode, String? currentUserId) {
    final effectiveUid = currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

    if (roomCode == null || roomCode.isEmpty) {
      _roomCallsSubscription?.cancel();
      _roomCallsSubscription = null;
      _watchedRoomCode = null;
      _watchedUserId = null;
      _clearIncomingBannerState();
      return;
    }

    if (_watchedRoomCode == roomCode &&
        _watchedUserId == effectiveUid &&
        _roomCallsSubscription != null) {
      return;
    }

    _roomCallsSubscription?.cancel();
    _watchedRoomCode = roomCode;
    _watchedUserId = effectiveUid;

    _roomCallsSubscription = _callRepository.listenToActiveCalls(roomCode).listen(
      (snapshot) {
        if (_isInCall || _isJoiningCall) {
          if (_incomingCallId != null) {
            _clearIncomingBannerState();
          }
          return;
        }

        final uid = _watchedUserId ?? FirebaseAuth.instance.currentUser?.uid;
        String? foundCallId;
        Map<String, dynamic>? foundOffer;
        String? foundCallerName;

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final status = data['status'] as String?;
          final callerId = data['callerId'] as String?;
          final offer = data['offer'];

          if (status == 'ringing' &&
              callerId != null &&
              callerId != uid &&
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
      },
      onError: (e) {
        debugPrint('watchRoomCalls stream error: $e');
      },
    );
  }

  /// Join an incoming call (from WhatsApp in-chat banner, chat call bubble, or CallKit notification)
  Future<void> joinIncomingRoomCall({
    String? roomCode,
    String? callId,
    Map<String, dynamic>? offer,
    String? callerName,
    bool openCallScreen = true,
  }) async {
    final targetRoom = roomCode ?? _watchedRoomCode ?? _currentRoomCode;
    if (targetRoom == null || targetRoom.isEmpty) return;

    if (_isJoiningCall) {
      if (openCallScreen) openCallScreenNow();
      return;
    }

    if (_isInCall) {
      if (openCallScreen) openCallScreenNow();
      return;
    }

    String? targetCallId = callId ?? _incomingCallId;
    Map<String, dynamic>? targetOffer = offer ?? _incomingOffer;
    String? targetCallerName = callerName ?? _incomingCallerName;

    // Immediately transition state and open CallScreen so tapping feels instant (0ms latency)
    _isJoiningCall = true;
    _isInCall = true;
    _isCallConnected = false;
    _isCaller = false;
    _isMuted = false;
    _isSpeaker = false;
    _callDurationSeconds = 0;
    _callStartTime = DateTime.now();
    _currentRoomCode = targetRoom;
    _incomingCallId = null;
    _incomingOffer = null;
    _incomingCallerName = null;
    notifyListeners();

    if (openCallScreen) {
      openCallScreenNow();
    }

    // Dismiss any ringing system CallKit UI or local notifications for this room
    unawaited(_callkitService.endAllCalls());
    unawaited(NotificationService.clearNotificationsForRoom(targetRoom));

    _peerDisplayName = await _resolveDisplayName(
      targetRoom,
      preferredName: targetCallerName,
    );
    notifyListeners();

    await [Permission.microphone, Permission.bluetoothConnect].request();
    _currentUserNickname = await PreferencesService.getNickname() ?? 'Unknown';

    // If offer or callId wasn't cached (e.g. tapped from CallKit or chat message bubble), fetch from Firestore
    if (targetOffer == null || targetCallId == null || targetCallId.isEmpty) {
      Map<String, dynamic>? callDoc;
      if (targetCallId != null && targetCallId.isNotEmpty) {
        callDoc = await _callRepository.getCall(targetRoom, targetCallId);
      }
      if (callDoc == null || callDoc['status'] != 'ringing') {
        callDoc = await _callRepository.getLatestRingingCall(
          targetRoom,
          excludeCallerId: FirebaseAuth.instance.currentUser?.uid,
        );
      }

      if (callDoc != null && callDoc['offer'] is Map && callDoc['status'] == 'ringing') {
        targetCallId = callDoc['callId']?.toString();
        targetOffer = Map<String, dynamic>.from(callDoc['offer'] as Map);
        final docCaller = callDoc['callerName']?.toString();
        if (docCaller != null && docCaller.isNotEmpty) {
          _peerDisplayName = await _resolveDisplayName(targetRoom, preferredName: docCaller);
          notifyListeners();
        }
      }
    }

    if (targetCallId == null || targetOffer == null) {
      // No active ringing call found in Firestore — end cleanly
      _resetCallState();
      return;
    }

    final ok = await _webRTCService.joinCall(targetRoom, targetCallId, targetOffer);
    if (!ok) {
      _resetCallState();
      return;
    }

    _isJoiningCall = false;
    _isInCall = true;
    _localStream = _webRTCService.localStream;
    _webRTCService.toggleSpeaker(_isSpeaker);
    _startDurationTimerIfNeeded();
    notifyListeners();

    if (openCallScreen && !_isCallScreenOpen) {
      openCallScreenNow();
    }
  }

  /// Decline an incoming call directly from the in-chat WhatsApp banner
  Future<void> declineIncomingRoomCall() async {
    final targetRoom = _watchedRoomCode;
    final targetCallId = _incomingCallId;
    _clearIncomingBannerState();
    await _callkitService.endAllCalls();
    if (targetRoom != null) {
      await NotificationService.clearNotificationsForRoom(targetRoom);
    }
    if (targetRoom != null && targetCallId != null) {
      await _callRepository.endCall(targetRoom, targetCallId);
    }
  }

  /// Start a new outgoing call (or join if the other person just called this room)
  Future<void> startCall(
    String roomCode,
    String callerId,
    String nickname, {
    bool openCallScreen = true,
  }) async {
    if (_isInCall || _isJoiningCall) {
      if (openCallScreen) openCallScreenNow();
      return;
    }

    // If there's already an incoming ringing call in this room, join it instead of colliding!
    if (hasIncomingRoomCall && (_watchedRoomCode == roomCode || _watchedRoomCode == null)) {
      await joinIncomingRoomCall(roomCode: roomCode, openCallScreen: openCallScreen);
      return;
    }

    // Open CallScreen immediately for instant feedback
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

    if (openCallScreen) {
      openCallScreenNow();
    }

    _peerDisplayName = await _resolveDisplayName(roomCode);
    notifyListeners();

    await [Permission.microphone, Permission.bluetoothConnect].request();

    // Check Firestore in case the peer just created a ringing call milliseconds ago
    final existingRinging = await _callRepository.getLatestRingingCall(
      roomCode,
      excludeCallerId: callerId,
    );
    if (existingRinging != null && existingRinging['offer'] is Map) {
      _isCaller = false;
      _isJoiningCall = true;
      _callStartTime = DateTime.now();
      final cId = existingRinging['callId'].toString();
      final cOffer = Map<String, dynamic>.from(existingRinging['offer'] as Map);
      final ok = await _webRTCService.joinCall(roomCode, cId, cOffer);
      _isJoiningCall = false;
      if (!ok) {
        _resetCallState();
        return;
      }
      _isInCall = true;
      _localStream = _webRTCService.localStream;
      _webRTCService.toggleSpeaker(_isSpeaker);
      _startDurationTimerIfNeeded();
      notifyListeners();
      if (openCallScreen && !_isCallScreenOpen) {
        openCallScreenNow();
      }
      return;
    }

    final createdCallId = await _webRTCService.startCall(
      roomCode,
      callerId,
      callerName: nickname,
    );

    if (createdCallId == null) {
      _resetCallState();
      return;
    }

    _isInCall = true;
    _localStream = _webRTCService.localStream;
    _webRTCService.toggleSpeaker(_isSpeaker);
    notifyListeners();

    if (openCallScreen && !_isCallScreenOpen) {
      openCallScreenNow();
    }

    // Send the call started message in the background AFTER the WebRTC call document exists in Firestore!
    unawaited(() async {
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
    }());
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
      final mins = duration.inMinutes.toString().padLeft(2, '0');
      final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
      final timeStr = '$mins:$secs';

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
