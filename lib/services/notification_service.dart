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
import '../services/crypto_service.dart';
import '../utils/app_strings.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (notificationResponse.actionId == 'reply_action') {
    final text = notificationResponse.input;
    final roomCode = notificationResponse.payload;
    if (text != null && text.isNotEmpty && roomCode != null && roomCode != 'app_update') {
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
        final plugin = FlutterLocalNotificationsPlugin();
        final notifId = notificationResponse.id ?? roomCode.hashCode.abs();
        await plugin.cancel(id: notifId);
      }
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool isUserInChatScreen = false;
  static String? currentActiveRoomCode;
  static String? currentActiveRoomId;

  /// Updates the active chat screen tracking (WhatsApp logic: suppress push/banner when inside the active chat)
  static void setActiveChatRoom(String? roomCode, {required bool inChat}) {
    if (inChat && roomCode != null && roomCode.trim().isNotEmpty) {
      final cleanCode = roomCode.trim();
      isUserInChatScreen = true;
      currentActiveRoomCode = cleanCode;
      currentActiveRoomId = cleanCode.length == 64
          ? cleanCode
          : CryptoService.deriveRoomId(cleanCode);
      clearNotificationsForRoom(cleanCode);
    } else {
      isUserInChatScreen = false;
      currentActiveRoomCode = null;
      currentActiveRoomId = null;
    }
  }

  /// Returns true if the user is currently viewing the given room on ChatScreen
  static bool shouldSuppressNotification({String? roomCode, String? roomId}) {
    if (!isUserInChatScreen) return false;

    if (roomCode != null && currentActiveRoomCode != null) {
      if (roomCode.trim() == currentActiveRoomCode) return true;
      if (currentActiveRoomId != null &&
          CryptoService.deriveRoomId(roomCode.trim()) == currentActiveRoomId) {
        return true;
      }
    }

    if (roomId != null && currentActiveRoomId != null) {
      if (roomId.trim() == currentActiveRoomId) return true;
    }

    return false;
  }

  static Future<String?> getInitialNotificationPayload() async {
    try {
      final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('Error getting notification launch details: $e');
    }
    return null;
  }

  static Future<void> clearNotificationsForRoom(String roomCode) async {
    try {
      await _notificationsPlugin.cancel(id: roomCode.hashCode.abs());
    } catch (_) {}
  }

  static Future<void> initialize() async {
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

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
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty && payload != 'app_update') {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final chatProvider = context.read<ChatProvider>();
            if (NotificationService.shouldSuppressNotification(roomCode: payload)) {
              return;
            }
            final success = await chatProvider.joinRoom(payload);
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
    // WhatsApp logic: never show a top banner notification if the user is actively inside that chat room
    if (payload != null &&
        payload != 'app_update' &&
        shouldSuppressNotification(roomCode: payload)) {
      return;
    }

    final soundsEnabled = await PreferencesService.getNotificationSoundEnabled();
    final lang = await PreferencesService.getLanguage();
    final strings = AppStrings(lang);

    final isChatPayload = payload != null && payload != 'app_update';

    final androidDetails = AndroidNotificationDetails(
      'mozechat_messages_channel_v7',
      strings.notifChannelName,
      channelDescription: strings.notifChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      ticker: 'ticker',
      fullScreenIntent: false,
      playSound: soundsEnabled,
      actions: isChatPayload
          ? [
              AndroidNotificationAction(
                'reply_action',
                strings.replyAction,
                inputs: [
                  AndroidNotificationActionInput(label: strings.replyHint),
                ],
              ),
            ]
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: soundsEnabled,
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
