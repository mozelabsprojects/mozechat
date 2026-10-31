import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'preferences_service.dart';
import '../utils/app_strings.dart';

class CallkitService {
  static final CallkitService _instance = CallkitService._internal();
  factory CallkitService() => _instance;
  CallkitService._internal();

  StreamSubscription<CallEvent?>? _eventSubscription;
  String? _lastKnownRoomId;
  String? _lastKnownCallId;
  String? _lastKnownCallerName;

  /// Tracks callIds that have already triggered CallKit so duplicate FCM messages never show multiple notifications
  static final Set<String> _shownCallIds = <String>{};

  /// Prevents programmatic endAllCalls() (used to dismiss ringing UI on accept) from triggering CallEventActionCallEnded
  bool _ignoringProgrammaticEnd = false;
  Timer? _ignoreEndTimer;

  Function(String callId, String roomId, Map<String, dynamic>? offer, String? callerName)? onCallAccepted;
  Function(String callId, String roomId)? onCallDeclined;
  Function(String callId)? onCallEndedBySystem;

  bool hasShownCall(String callId) => _shownCallIds.contains(callId);

  Future<void> showCallkitIncoming({
    required String callerName,
    required String roomId,
    required String callId,
    Map<String, dynamic>? offer,
  }) async {
    if (callId.isNotEmpty && _shownCallIds.contains(callId)) {
      return;
    }
    if (callId.isNotEmpty) {
      _shownCallIds.add(callId);
    }

    _lastKnownRoomId = roomId;
    _lastKnownCallId = callId;
    _lastKnownCallerName = callerName;

    final lang = await PreferencesService.getLanguage();
    final strings = AppStrings(lang);

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Mozechat',
      avatar: '',
      handle: strings.voiceCallTitle,
      type: 0, // Audio call
      missedCallNotification: const NotificationParams(
        showNotification: false,
        isShowCallback: false,
      ),
      callingNotification: const NotificationParams(
        showNotification: false,
        isShowCallback: false,
      ),
      duration: 45000,
      extra: <String, dynamic>{
        'roomId': roomId,
        'callId': callId,
        'callerName': callerName,
      },
      headers: <String, dynamic>{'apiKey': '1234'},
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B1014',
        backgroundUrl: 'assets/mozechat.png',
        actionColor: '#159D87',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: strings.incomingVoiceCall,
        missedCallNotificationChannelName: strings.missedCallTitle,
        isShowCallID: false,
        isShowFullLockedScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 48000.0,
        audioSessionPreferredIOBufferDuration: 0.02,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('showCallkitIncoming error: $e');
    }
  }

  Future<void> setCallConnected(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      debugPrint('setCallConnected warning: $e');
    }
  }

  /// Dismisses any CallKit notifications without triggering onCallEndedBySystem
  Future<void> endAllCalls() async {
    _ignoringProgrammaticEnd = true;
    _ignoreEndTimer?.cancel();
    _ignoreEndTimer = Timer(const Duration(milliseconds: 2500), () {
      _ignoringProgrammaticEnd = false;
    });
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('endAllCalls warning: $e');
    }
  }

  /// Checks if there is an accepted/active CallKit call when the app starts or resumes from background
  Future<void> checkActiveCallsAndJoinIfNeeded() async {
    try {
      final List<CallKitParams> active = await FlutterCallkitIncoming.activeCalls();
      if (active.isNotEmpty) {
        final CallKitParams first = active.first;
        final callId = first.id.isNotEmpty ? first.id : (_lastKnownCallId ?? '');
        final extra = first.extra;
        String roomId = _lastKnownRoomId ?? '';
        String? callerName = first.nameCaller ?? _lastKnownCallerName;
        Map<String, dynamic>? offerMap;

        if (extra != null) {
          roomId = (extra['roomId']?.toString()) ?? roomId;
          callerName = (extra['callerName']?.toString()) ?? callerName;
          final rawOffer = extra['offer'];
          if (rawOffer is Map) {
            offerMap = Map<String, dynamic>.from(rawOffer);
          } else if (rawOffer is String && rawOffer.isNotEmpty) {
            try {
              offerMap = Map<String, dynamic>.from(jsonDecode(rawOffer));
            } catch (_) {}
          }
        }

        if (callId.isNotEmpty && roomId.isNotEmpty && onCallAccepted != null) {
          onCallAccepted!(callId, roomId, offerMap, callerName);
        }
      }
    } catch (e) {
      debugPrint('checkActiveCallsAndJoinIfNeeded warning: $e');
    }
  }

  void listenToCallEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      if (event is CallEventActionCallAccept) {
        final extra = event.callKitParams.extra;
        final callId = event.callKitParams.id.isNotEmpty
            ? event.callKitParams.id
            : (_lastKnownCallId ?? '');
        final roomId = (extra?['roomId']?.toString()) ?? _lastKnownRoomId ?? '';
        final callerName = (extra?['callerName']?.toString()) ??
            event.callKitParams.nameCaller ??
            _lastKnownCallerName;

        Map<String, dynamic>? offerMap;
        final rawOffer = extra?['offer'];
        if (rawOffer is Map) {
          offerMap = Map<String, dynamic>.from(rawOffer);
        } else if (rawOffer is String && rawOffer.isNotEmpty) {
          try {
            offerMap = Map<String, dynamic>.from(jsonDecode(rawOffer));
          } catch (_) {}
        }

        if (onCallAccepted != null && (callId.isNotEmpty || roomId.isNotEmpty)) {
          onCallAccepted!(callId, roomId, offerMap, callerName);
        }
      } else if (event is CallEventActionCallDecline) {
        final extra = event.callKitParams.extra;
        final roomId = (extra?['roomId']?.toString()) ?? _lastKnownRoomId ?? '';
        final callId = event.callKitParams.id.isNotEmpty
            ? event.callKitParams.id
            : (_lastKnownCallId ?? '');
        await endAllCalls();
        if (onCallDeclined != null && roomId.isNotEmpty && callId.isNotEmpty) {
          onCallDeclined!(callId, roomId);
        }
      } else if (event is CallEventActionCallEnded) {
        // Ignore programmatic endAllCalls() triggered when transitioning from CallKit notification to CallScreen
        if (_ignoringProgrammaticEnd) {
          return;
        }
        final callId = event.callKitParams.id;
        if (onCallEndedBySystem != null) {
          onCallEndedBySystem!(callId);
        }
      } else if (event is CallEventActionCallTimeout) {
        final callId = event.id;
        final roomId = _lastKnownRoomId ?? '';
        await endAllCalls();
        if (onCallDeclined != null && roomId.isNotEmpty) {
          onCallDeclined!(callId, roomId);
        }
      }
    });
  }
}
