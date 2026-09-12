import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../utils/color_utils.dart';
import '../screens/media_gallery_screen.dart';
import '../screens/room_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
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
                      ? '[!] Peer is encrypting data...'
                      : (chatProvider.isOtherOnline ? 'Online' : 'Offline'),
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
          ? IconButton(
              icon: Icon(Icons.close, color: topBarTextColor),
              onPressed: onClearSelection,
            )
          : null,
      actions: selectedMessages.isNotEmpty
          ? [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () {
                  chatProvider.deleteMessages(selectedMessages);
                  onClearSelection();
                },
              ),
            ]
          : [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: topBarTextColor),
                color: Theme.of(context).cardColor,
                onSelected: (value) {
                  if (value == 'gallery') {
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
                  } else if (value == 'leave') {
                    chatProvider.leaveRoom();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomScreen()),
                      (route) => false,
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'gallery',
                    child: ListTile(
                      leading: Icon(Icons.photo_library),
                      title: Text('Media Gallery'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Export Chat'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'commands',
                    child: ListTile(
                      leading: Icon(Icons.menu_book),
                      title: Text('Commands'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text('Copy Node Code'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: ListTile(
                      leading: Icon(
                        Icons.exit_to_app,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        'Leave Node',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ],
    );
  }
}
