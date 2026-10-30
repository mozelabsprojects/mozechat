import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/chat_provider.dart';
import '../utils/color_utils.dart';
import '../screens/media_gallery_screen.dart';
import '../screens/rooms_list_screen.dart';
import '../screens/call_screen.dart';
import '../screens/panic_camouflage_screen.dart';
import '../providers/call_provider.dart';
import '../providers/locale_provider.dart';
import 'qr_dialog.dart';
import 'bouncy_tap.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> selectedMessages;
  final VoidCallback onClearSelection;
  final VoidCallback onShowSettings;
  final VoidCallback onShowCommands;
  final VoidCallback onCopyCode;

  const ChatAppBar({
    super.key,
    required this.selectedMessages,
    required this.onClearSelection,
    required this.onShowSettings,
    required this.onShowCommands,
    required this.onCopyCode,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    if (lastSeen.year == now.year && lastSeen.month == now.month && lastSeen.day == now.day) {
      return DateFormat('HH:mm').format(lastSeen);
    }
    return DateFormat('MMM d, HH:mm').format(lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final appBgColor = Theme.of(context).scaffoldBackgroundColor;
    final topBarTextColor = getContrastColor(appBgColor);

    return AppBar(
      backgroundColor: appBgColor.withValues(alpha: 0.8),
      iconTheme: IconThemeData(color: topBarTextColor),
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: selectedMessages.isNotEmpty
          ? Text(
              '${selectedMessages.length} Selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: topBarTextColor,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF159D87),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF159D87).withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'E2E SECURED: ${chatProvider.roomCode}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: topBarTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  chatProvider.isOtherTyping
                      ? strings.typing
                      : (chatProvider.isOtherOnline
                          ? strings.online
                          : (chatProvider.otherLastSeen != null
                              ? 'Last seen: ${_formatLastSeen(chatProvider.otherLastSeen!)}'
                              : strings.offline)),
                  style: TextStyle(
                    fontSize: 12,
                    color: chatProvider.isOtherTyping
                        ? Colors.amberAccent
                        : (chatProvider.isOtherOnline
                              ? const Color(0xFF159D87)
                              : Colors.grey),
                    fontWeight: FontWeight.bold,
                    fontStyle: chatProvider.isOtherTyping
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
      leading: selectedMessages.isNotEmpty
          ? BouncyTap(
              onTap: onClearSelection,
              child: Icon(Icons.close, color: topBarTextColor),
            )
          : null,
      actions: selectedMessages.isNotEmpty
          ? [
              BouncyTap(
                onTap: () {
                  chatProvider.deleteMessages(selectedMessages);
                  onClearSelection();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(Icons.delete, color: Colors.redAccent),
                ),
              ),
            ]
          : [
              if (chatProvider.panicCamouflageEnabled)
                BouncyTap(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const PanicCamouflageScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.shield_outlined, color: Colors.orangeAccent),
                  ),
                ),
              BouncyTap(
                onTap: () {
                  if (chatProvider.roomCode != null) {
                    QRDialog.show(
                      context,
                      roomCode: chatProvider.roomCode!,
                      roomTitle: 'ODA QR KODU',
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.qr_code_2_rounded, color: topBarTextColor),
                ),
              ),
              BouncyTap(
                onTap: () async {
                  final callProvider = context.read<CallProvider>();
                  try {
                    await callProvider.startCall(chatProvider.roomCode!, chatProvider.currentUserId!, chatProvider.nickname ?? 'Arayan Kişi');
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CallScreen()),
                      );
                    }
                  } catch (e) {
                    debugPrint('Start call failed: $e');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.phone, color: topBarTextColor),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: topBarTextColor),
                color: Theme.of(context).cardColor,
                onSelected: (value) {
                  if (value == 'leave') {
                    chatProvider.leaveRoom();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomsListScreen()),
                      (route) => false,
                    );
                  } else if (value == 'gallery') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MediaGalleryScreen(),
                      ),
                    );
                  } else if (value == 'export') {
                    chatProvider.exportChatHistoryAsText();
                  } else if (value == 'settings') {
                    onShowSettings();
                  } else if (value == 'commands') {
                    onShowCommands();
                  } else if (value == 'copy') {
                    onCopyCode();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'leave',
                    child: ListTile(
                      leading: const Icon(
                        Icons.exit_to_app,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        strings.leaveRoom,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'gallery',
                    child: ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: Text(strings.mediaGallery),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: const Icon(Icons.download),
                      title: Text(strings.exportChat),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: const Icon(Icons.settings),
                      title: Text(strings.settingsTitle),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commands',
                    child: ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Text(strings.commands),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: const Icon(Icons.copy),
                      title: Text(strings.copyRoomCode),
                    ),
                  ),
                ],
              ),
            ],
    );
  }
}
