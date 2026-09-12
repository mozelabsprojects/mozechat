import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class CallkitService {
  static final CallkitService _instance = CallkitService._internal();
  factory CallkitService() => _instance;
  CallkitService._internal();

  Function(String callId, Map<String, dynamic> offer, String roomId)? onCallAccepted;
  Function(String callId, String roomId)? onCallDeclined;

  Future<void> showCallkitIncoming({
    required String callerName,
    required String roomId,
    required String callId,
    required Map<String, dynamic> offer,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Mozechat',
      avatar: '',
      handle: 'Incoming Call',
      type: 0,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000,
      extra: <String, dynamic>{
        'roomId': roomId,
        'offer': offer,
      },
      headers: <String, dynamic>{'apiKey': '1234'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'assets/mozechat.png',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
        isShowCallID: false,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  void listenToCallEvents() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;
      
      if (event is CallEventActionCallAccept) {
        final extra = event.callKitParams.extra;
        if (onCallAccepted != null && extra != null) {
          var offer = extra['offer'];
          if (offer is String) {
            try {
              offer = jsonDecode(offer);
            } catch (e) {
              debugPrint("Error decoding offer: $e");
            }
          }
          onCallAccepted!(event.callKitParams.id, offer, extra['roomId']);
        }
      } else if (event is CallEventActionCallDecline) {
        final extra = event.callKitParams.extra;
        if (onCallDeclined != null && extra != null) {
          onCallDeclined!(event.callKitParams.id, extra['roomId']);
        }
      }
    });
  }
}
