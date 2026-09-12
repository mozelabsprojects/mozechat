import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/room_screen.dart';
import 'screens/chat_screen.dart';
import 'firebase_options.dart';

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/crypto_service.dart';
import 'services/preferences_service.dart';
import 'services/e2ee_service.dart';
import 'services/notification_service.dart';
import 'repositories/chat_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:screen_protector/screen_protector.dart';
import 'providers/call_provider.dart';
import 'services/callkit_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  if (message.data['type'] == 'NEW_MESSAGE') {
    final roomId = message.data['roomId'];
    final cipherText = message.data['cipherText'];
    final iv = message.data['iv'];

    final history = await PreferencesService.getRoomHistory();
    String? matchedCode;
    for (var code in history) {
      if (CryptoService.deriveRoomId(code) == roomId) {
        matchedCode = code;
        break;
      }
    }

    if (matchedCode != null && cipherText != null && iv != null) {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        await FirebaseAuth.instance.authStateChanges().first;
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
      var key = CryptoService.deriveEncryptionKey(matchedCode);

      if (uid != null) {
        try {
          final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
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
        final text = payload['text'];
        final nickname = payload['nickname'];

        await NotificationService.initialize();

        // Sadece kullanıcı o odada aktif DEĞİLse bildirim göster
        if (NotificationService.currentActiveRoomCode != matchedCode) {
          await NotificationService.showMessageNotification(
            title: 'Yeni Mesaj: $nickname',
            body: text,
            payload: matchedCode,
          );
        }
      } catch (e) {
        // Hata durumunda yoksay
      }
    }
  } else if (message.data['type'] == 'NEW_CALL') {
    final roomId = message.data['roomId'];
    final callerName = message.data['callerName'];
    final callId = message.data['callId'];
    final offerStr = message.data['offer'];

    if (roomId != null && callId != null && offerStr != null) {
      try {
        final offer = jsonDecode(offerStr);
        await CallkitService().showCallkitIncoming(
          callerName: callerName ?? 'Unknown',
          roomId: roomId,
          callId: callId,
          offer: offer,
        );
      } catch (e) {
        debugPrint('Callkit show error: $e');
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

    // Bildirim izni iste (Android 13+ ve iOS için zorunlu)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message dinleyici
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _firebaseMessagingBackgroundHandler(message);
    });

    // FCM token yenilendiğinde tüm odalardaki token'ı güncelle
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token yenilendi: $newToken');
      final repo = ChatRepository();
      await repo.updateFcmTokenForAllRooms(newToken);
    });

    // Uygulama başlangıcında mevcut FCM token'ı tüm odalara kaydet
    try {
      final currentToken = await FirebaseMessaging.instance.getToken();
      if (currentToken != null) {
        debugPrint('📱 FCM Token: $currentToken');
        final repo = ChatRepository();
        await repo.updateFcmTokenForAllRooms(currentToken);
      }
    } catch (e) {
      debugPrint('FCM token alma hatası: $e');
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    debugPrint("🚀 Firebase başarıyla başlatıldı!");

    // Auto-login logic
    final nickname = await PreferencesService.getNickname();
    final lastActiveRoom = await PreferencesService.getLastActiveRoom();
    if (nickname != null && lastActiveRoom != null) {
      initialRoom = lastActiveRoom;
    }
  } catch (e) {
    debugPrint("❌ Firebase başlatma hatası: $e");
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

class _MozechatAppState extends State<MozechatApp> {
  bool _isInitializing = true;
  Widget _homeScreen = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _handleInitialRoute();
    CallkitService().listenToCallEvents();
  }

  Future<void> _handleInitialRoute() async {
    // Uygulama açılışında temel izinleri iste
    await [
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.notification,
    ].request();

    if (!mounted) return;

    // Mevcut anonim oturumu kontrol et
    final currentUser = FirebaseAuth.instance.currentUser;
    final nickname = await PreferencesService.getNickname();

    if (currentUser != null && nickname != null) {
      if (!mounted) return;
      context.read<ChatProvider>().setNickname(nickname);

      // FCM Token update after auth state is confirmed
      try {
        final currentToken = await FirebaseMessaging.instance.getToken();
        if (currentToken != null) {
          final repo = ChatRepository();
          await repo.updateFcmTokenForAllRooms(currentToken);
        }
      } catch (e) {
        debugPrint('FCM update in init route error: $e');
      }

      if (!mounted) return;
      if (widget.initialRoom != null) {
        final chatProvider = context.read<ChatProvider>();
        final success = await chatProvider.joinRoom(widget.initialRoom!);
        if (success && mounted) {
          _homeScreen = const ChatScreen();
        }
      } else {
        _homeScreen = const RoomScreen();
      }
    }
    // Diğer durumda _homeScreen zaten LoginScreen olarak kalır

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
