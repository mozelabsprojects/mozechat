import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../main.dart';
import '../screens/chat_screen.dart';
import '../providers/chat_provider.dart';
import '../repositories/chat_repository.dart';
import '../services/preferences_service.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (notificationResponse.actionId == 'reply_action') {
    final text = notificationResponse.input;
    final roomCode = notificationResponse.payload;
    if (text != null && text.isNotEmpty && roomCode != null) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        final nickname = await PreferencesService.getNickname() ?? 'Me';
        final repo = ChatRepository();
        
        if (repo.currentUserId == null) {
          await FirebaseAuth.instance.authStateChanges().first;
        }
        
        if (repo.currentUserId == null) {
          return;
        }
        
        await repo.sendMessage(roomCode, text, nickname);
      } catch (e) {
        // Ignored in background
      } finally {
        // Dismiss notification to stop the spinner
        final plugin = FlutterLocalNotificationsPlugin();
        final notifId = notificationResponse.id ?? roomCode.hashCode;
        await plugin.cancel(id: notifId);
      }
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static String? currentActiveRoomCode;

  static Future<void> clearNotificationsForRoom(String roomCode) async {
    await _notificationsPlugin.cancel(id: roomCode.hashCode);
  }

  static Future<void> initialize() async {
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    // iOS için bildirim izinlerini istemek üzere konfigürasyon (isteğe bağlı ama önerilir)
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload != null) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final chatProvider = context.read<ChatProvider>();
            final success = await chatProvider.joinRoom(details.payload!);
            if (success && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            }
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final soundsEnabled = await PreferencesService.getNotificationSoundEnabled();
    
    final androidDetails = AndroidNotificationDetails(
      'mozechat_messages_channel_v3',
      'Mesaj Bildirimleri',
      channelDescription: 'Yeni mesaj geldiğinde bildirim gönderir.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundsEnabled,
      sound: const RawResourceAndroidNotificationSound('gtanotification'),
      actions: const [
        AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: soundsEnabled,
      sound: 'gtanotification.mp3',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: payload != null ? payload.hashCode.abs() : DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
