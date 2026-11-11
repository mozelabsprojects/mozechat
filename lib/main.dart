import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/login_screen.dart';
import 'screens/rooms_list_screen.dart';
import 'screens/chat_screen.dart';
import 'firebase_options.dart';

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/crypto_service.dart';
import 'services/preferences_service.dart';
import 'services/e2ee_service.dart';
import 'services/notification_service.dart';
import 'repositories/chat_repository.dart';
import 'repositories/call_repository.dart';
import 'utils/app_strings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:screen_protector/screen_protector.dart';
import 'providers/call_provider.dart';
import 'services/callkit_service.dart';
import 'services/proximity_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final lang = await PreferencesService.getLanguage();
  final strings = AppStrings(lang);

  if (message.data['type'] == 'NEW_MESSAGE') {
    final roomId = message.data['roomId'] as String?;
    final messageId = message.data['messageId'] as String?;
    final senderId = message.data['senderId'] as String?;
    final cipherText = message.data['cipherText'] as String?;
    final iv = message.data['iv'] as String?;

    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      try {
        await FirebaseAuth.instance.authStateChanges().first;
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (uid != null && senderId != null && senderId == uid) {
      return;
    }

    // Acknowledge delivery to Firestore immediately upon receiving message on recipient device
    if (messageId != null && roomId != null && (senderId == null || senderId != uid)) {
      try {
        final msgRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc(messageId);
        unawaited(msgRef.get().then((docSnap) {
          if (docSnap.exists) {
            final currentStatus = docSnap.data()?['status'] as String?;
            if (currentStatus == 'sent') {
              return msgRef.update({
                'status': 'delivered',
                'deliveredAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }).catchError((_) {}));
      } catch (_) {}
    }

    // Suppress immediately if user is currently viewing this room in ChatScreen
    if (NotificationService.shouldSuppressNotification(roomId: roomId)) {
      return;
    }

    final history = await PreferencesService.getRoomHistory();
    String? matchedCode;
    for (var code in history) {
      if (CryptoService.deriveRoomId(code) == roomId) {
        matchedCode = code;
        break;
      }
    }

    if (matchedCode != null &&
        NotificationService.shouldSuppressNotification(
          roomCode: matchedCode,
          roomId: roomId,
        )) {
      return;
    }

    if (matchedCode != null && cipherText != null && iv != null) {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        try {
          await FirebaseAuth.instance.authStateChanges().first;
          uid = FirebaseAuth.instance.currentUser?.uid;
        } catch (_) {}
      }
      var key = CryptoService.deriveEncryptionKey(matchedCode);

      if (uid != null && roomId != null) {
        try {
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .get();
          if (roomDoc.exists) {
            final data = roomDoc.data()!;
            final encryptedKeys = data['encryptedKeys'] as Map<String, dynamic>?;
            if (encryptedKeys != null) {
              final myEncKey = encryptedKeys[uid];
              if (myEncKey != null) {
                final aesKeyBase64 = await E2EEService().decryptRoomKey(myEncKey, uid);
                if (aesKeyBase64 != null) {
                  key = encrypt.Key.fromBase64(aesKeyBase64);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Background E2EE decrypt failed: $e');
        }
      }

      final decryptedStr = CryptoService.decryptMessage(cipherText, iv, key);
      try {
        final payload = jsonDecode(decryptedStr);
        final senderId = payload['senderId'] as String?;
        if (uid != null && senderId != null && senderId == uid) {
          return;
        }

        final text = (payload['text'] as String?) ?? '';
        final nickname = (payload['nickname'] as String?) ?? strings.unknownUser;
        final lowerText = text.toLowerCase();
        final isCallLogMsg = text.startsWith('📞');
        final isCallStartMsg = isCallLogMsg &&
            !lowerText.contains('sonlandırıldı') &&
            !lowerText.contains('ended');

        // WhatsApp-style call notification handling:
        // Never spam a text message notification for '📞' call log entries!
        if (isCallLogMsg) {
          if (isCallStartMsg) {
            // Only show CallKit incoming UI if user is outside this chat room (deduplicated by callId)
            if (!NotificationService.shouldSuppressNotification(
              roomCode: matchedCode,
              roomId: roomId,
            )) {
              try {
                final ringingDoc = await CallRepository().getLatestRingingCall(
                  matchedCode,
                  excludeCallerId: uid,
                );
                if (ringingDoc != null && ringingDoc['callId'] != null) {
                  final bool isVideo = ringingDoc['isVideo'] == true ||
                      lowerText.contains('görüntülü') ||
                      lowerText.contains('video');
                  final Map<String, dynamic>? offerMap = ringingDoc['offer'] is Map
                      ? Map<String, dynamic>.from(ringingDoc['offer'] as Map)
                      : null;
                  await CallkitService().showCallkitIncoming(
                    callerName: nickname,
                    roomId: matchedCode,
                    callId: ringingDoc['callId'].toString(),
                    offer: offerMap,
                    isVideo: isVideo,
                  );
                }
              } catch (_) {}
            }
          } else {
            // Call ended log message: dismiss any leftover ringing CallKit UI
            await CallkitService().endAllCalls();
            await NotificationService.clearNotificationsForRoom(matchedCode);
          }
          return;
        }

        await NotificationService.initialize();

        if (!NotificationService.shouldSuppressNotification(
          roomCode: matchedCode,
          roomId: roomId,
        )) {
          await NotificationService.showMessageNotification(
            title: strings.newMessageFrom(nickname),
            body: text,
            payload: matchedCode,
          );
        }
      } catch (e) {
        debugPrint('Background decryption failed: $e');
        await NotificationService.initialize();
        if (!NotificationService.shouldSuppressNotification(
          roomCode: matchedCode,
          roomId: roomId,
        )) {
          await NotificationService.showMessageNotification(
            title: strings.newMessageTitle,
            body: strings.newEncryptedMessageBody,
            payload: matchedCode,
          );
        }
      }
    }
  } else if (message.data['type'] == 'NEW_CALL') {
    final roomId = (message.data['roomCode'] ?? message.data['roomId']) as String?;
    final callerName = message.data['callerName'] as String?;
    final callerId = message.data['callerId'] as String?;
    final callId = message.data['callId'] as String?;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && callerId != null && callerId == currentUid) {
      return;
    }

    if (roomId != null && callId != null) {
      try {
        final resolvedId = CallRepository().resolveRoomId(roomId);

        // WhatsApp logic: if user is actively viewing this chat screen, the in-chat top banner handles it
        if (NotificationService.shouldSuppressNotification(
          roomCode: roomId,
          roomId: resolvedId,
        )) {
          return;
        }

        final effectiveCallerName = callerName ?? strings.unknownUser;
        final isVideoCall = message.data['isVideo']?.toString() == 'true';
        Map<String, dynamic>? offerMap;
        final rawOffer = message.data['offer'];
        if (rawOffer is String && rawOffer.isNotEmpty) {
          try {
            offerMap = Map<String, dynamic>.from(jsonDecode(rawOffer));
          } catch (_) {}
        }

        await CallkitService().showCallkitIncoming(
          callerName: effectiveCallerName,
          roomId: roomId,
          callId: callId,
          offer: offerMap,
          isVideo: isVideoCall,
        );

        await NotificationService.showMessageNotification(
          title: isVideoCall ? strings.incomingVideoCall : strings.incomingVoiceCall,
          body: effectiveCallerName,
          payload: 'call:$roomId',
          isCallNotification: true,
        );
      } catch (e) {
        debugPrint('Callkit show error: $e');
      }
    }
  } else if (message.data['type'] == 'END_CALL') {
    final roomId = (message.data['roomCode'] ?? message.data['roomId']) as String?;
    final callId = message.data['callId'] as String?;
    await CallkitService().endAllCalls();
    if (roomId != null) {
      await NotificationService.clearNotificationsForRoom(roomId);
    }
    if (callId != null && callId.isNotEmpty) {
      CallkitService.removeShownCall(callId);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ProximityService.init();

  try {
    await ScreenProtector.preventScreenshotOn();
  } catch (e) {
    debugPrint('ScreenProtector Error: $e');
  }

  await NotificationService.initialize();

  String? initialRoom;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Disable automatic OS foreground banner so NotificationService can enforce WhatsApp-style active-room suppression
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _firebaseMessagingBackgroundHandler(message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      final repo = ChatRepository();
      await repo.updateFcmTokenForAllRooms(newToken);
    });

    try {
      final currentToken = await FirebaseMessaging.instance.getToken();
      if (currentToken != null) {
        final repo = ChatRepository();
        await repo.updateFcmTokenForAllRooms(currentToken);
      }
    } catch (e) {
      debugPrint('FCM token fetch warning: $e');
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Note: Always start at RoomsListScreen on normal app launch as requested.
    // initialRoom is only set if launched directly from a notification tap.
    final launchPayload = await NotificationService.getInitialNotificationPayload();
    if (launchPayload != null &&
        launchPayload.isNotEmpty &&
        launchPayload != 'app_update') {
      initialRoom = launchPayload;
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..initializeState(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider()..initializeState(),
        ),
        ChangeNotifierProvider(
          create: (_) => CallProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: MozechatApp(initialRoom: initialRoom),
    ),
  );
}

class MozechatApp extends StatefulWidget {
  final String? initialRoom;
  const MozechatApp({super.key, this.initialRoom});

  @override
  State<MozechatApp> createState() => _MozechatAppState();
}

class _MozechatAppState extends State<MozechatApp> with WidgetsBindingObserver {
  bool _isInitializing = true;
  Widget _homeScreen = const LoginScreen();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleInitialRoute();
    CallkitService().listenToCallEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CallkitService().checkActiveCallsAndJoinIfNeeded();
      unawaited(ChatRepository().markPendingMessagesAsDelivered());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          context.read<ChatProvider>().updatePresence(false);
        } catch (_) {}
      }
    }
  }

  Future<void> _handleInitialRoute() async {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.notification,
    ].request();

    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final nickname = await PreferencesService.getNickname();

    if (currentUser != null && nickname != null) {
      if (!mounted) return;
      context.read<ChatProvider>().setNickname(nickname);

      try {
        final currentToken = await FirebaseMessaging.instance.getToken();
        if (currentToken != null) {
          final repo = ChatRepository();
          await repo.updateFcmTokenForAllRooms(currentToken);
        }
      } catch (e) {
        debugPrint('FCM update in init route error: $e');
      }

      unawaited(ChatRepository().markPendingMessagesAsDelivered());

      if (!mounted) return;
      if (widget.initialRoom != null) {
        final isCallLaunch = widget.initialRoom!.startsWith('call:');
        final targetRoom = isCallLaunch
            ? widget.initialRoom!.substring(5)
            : widget.initialRoom!;

        final chatProvider = context.read<ChatProvider>();
        final callProvider = context.read<CallProvider>();
        final success = await chatProvider.joinRoom(targetRoom);
        if (success && mounted) {
          _homeScreen = const RoomsListScreen();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (navigatorKey.currentState != null && !NotificationService.isUserInChatScreen) {
              navigatorKey.currentState!.push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
              if (isCallLaunch) {
                await callProvider.joinIncomingRoomCall(
                  roomCode: targetRoom,
                  openCallScreen: true,
                );
              } else {
                await CallkitService().checkActiveCallsAndJoinIfNeeded();
              }
            }
          });
        } else {
          _homeScreen = const RoomsListScreen();
        }
      } else {
        _homeScreen = const RoomsListScreen();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          CallkitService().checkActiveCallsAndJoinIfNeeded();
        });
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mozechat',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: _isInitializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _homeScreen,
    );
  }
}
