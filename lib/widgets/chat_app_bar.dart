import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/chat_provider.dart';
import '../utils/color_utils.dart';
import '../screens/media_gallery_screen.dart';
import '../screens/rooms_list_screen.dart';
import '../screens/panic_camouflage_screen.dart';
import '../providers/call_provider.dart';
import '../providers/locale_provider.dart';
import 'qr_dialog.dart';
import 'bouncy_tap.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> selectedMessages;
  final VoidCallback onClearSelection;
  final VoidCallback onShowSettings;
  final VoidCallback onCopyCode;

  // Search in chat
  final bool isSearchMode;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onStartSearch;
  final VoidCallback? onCloseSearch;
  final int searchMatchCount;
  final int currentMatchIndex;
  final VoidCallback? onNextMatch;
  final VoidCallback? onPrevMatch;

  const ChatAppBar({
    super.key,
    required this.selectedMessages,
    required this.onClearSelection,
    required this.onShowSettings,
    required this.onCopyCode,
    this.isSearchMode = false,
    this.searchController,
    this.onSearchChanged,
    this.onStartSearch,
    this.onCloseSearch,
    this.searchMatchCount = 0,
    this.currentMatchIndex = 0,
    this.onNextMatch,
    this.onPrevMatch,
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

  Future<void> _handleCallAction(BuildContext context, {bool video = false}) async {
    final chatProvider = context.read<ChatProvider>();
    final callProvider = context.read<CallProvider>();
    final strings = context.read<LocaleProvider>().strings;

    if (chatProvider.roomCode == null || chatProvider.currentUserId == null) {
      return;
    }
    if (callProvider.isInCall) {
      callProvider.openCallScreenNow();
      return;
    }
    if (callProvider.hasIncomingRoomCall) {
      await callProvider.joinIncomingRoomCall(
        roomCode: chatProvider.roomCode,
        openCallScreen: true,
      );
      return;
    }
    try {
      await callProvider.startCall(
        chatProvider.roomCode!,
        chatProvider.currentUserId!,
        chatProvider.nickname ?? strings.unknownUser,
        openCallScreen: true,
        video: video,
      );
    } catch (e) {
      debugPrint('Start call failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final callProvider = context.watch<CallProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final appBgColor = Theme.of(context).scaffoldBackgroundColor;
    final topBarTextColor = getContrastColor(appBgColor);

    Widget titleWidget;

    if (isSearchMode) {
      titleWidget = TextField(
        controller: searchController,
        autofocus: true,
        style: TextStyle(
          color: topBarTextColor,
          fontSize: 16,
        ),
        cursorColor: const Color(0xFF159D87),
        decoration: InputDecoration(
          hintText: strings.searchInChat,
          hintStyle: TextStyle(
            color: topBarTextColor.withValues(alpha: 0.5),
            fontSize: 15,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: onSearchChanged,
      );
    } else if (selectedMessages.isNotEmpty) {
      titleWidget = Text(
        strings.selectedCount(selectedMessages.length),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: topBarTextColor,
        ),
      );
    } else {
      titleWidget = BouncyTap(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MediaGalleryScreen(),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${strings.e2eSecured}: ${chatProvider.roomCode}',
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
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: topBarTextColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              chatProvider.isOtherTyping
                  ? strings.typing
                  : (chatProvider.isOtherOnline
                      ? strings.online
                      : (chatProvider.otherLastSeen != null
                          ? '${strings.lastSeen}: ${_formatLastSeen(chatProvider.otherLastSeen!)}'
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    Widget? leadingWidget;
    if (isSearchMode) {
      leadingWidget = IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: topBarTextColor),
        onPressed: onCloseSearch,
      );
    } else if (selectedMessages.isNotEmpty) {
      leadingWidget = BouncyTap(
        onTap: onClearSelection,
        child: Icon(Icons.close, color: topBarTextColor),
      );
    }

    List<Widget> actionsList;
    if (isSearchMode) {
      actionsList = [
        if (searchMatchCount > 0)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF159D87).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF159D87).withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${currentMatchIndex + 1}/$searchMatchCount',
                style: const TextStyle(
                  color: Color(0xFF159D87),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          )
        else if (searchController != null && searchController!.text.trim().isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Text(
                '0/0',
                style: TextStyle(
                  color: topBarTextColor.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_up_rounded, color: topBarTextColor),
          tooltip: 'Previous',
          visualDensity: VisualDensity.compact,
          onPressed: searchMatchCount > 0 ? onPrevMatch : null,
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: topBarTextColor),
          tooltip: 'Next',
          visualDensity: VisualDensity.compact,
          onPressed: searchMatchCount > 0 ? onNextMatch : null,
        ),
        if (searchController != null && searchController!.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.close_rounded, color: topBarTextColor),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              searchController?.clear();
              if (onSearchChanged != null) onSearchChanged!('');
            },
          ),
      ];
    } else if (selectedMessages.isNotEmpty) {
      actionsList = [
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
      ];
    } else {
      actionsList = [
        if (onStartSearch != null)
          BouncyTap(
            onTap: onStartSearch!,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.search_rounded, color: topBarTextColor),
            ),
          ),
        if (callProvider.isInCall || callProvider.hasIncomingRoomCall)
          BouncyTap(
            onTap: () => _handleCallAction(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFF159D87),
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: topBarTextColor),
          color: Theme.of(context).cardColor,
          onSelected: (value) async {
            if (value == 'call') {
              await _handleCallAction(context);
            } else if (value == 'video_call') {
              await _handleCallAction(context, video: true);
            } else if (value == 'qr') {
              if (chatProvider.roomCode != null) {
                QRDialog.show(
                  context,
                  roomCode: chatProvider.roomCode!,
                  roomTitle: strings.roomQrCodeTitle,
                );
              }
            } else if (value == 'panic') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const PanicCamouflageScreen(),
                ),
              );
            } else if (value == 'gallery') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MediaGalleryScreen(),
                ),
              );
            } else if (value == 'copy') {
              onCopyCode();
            } else if (value == 'export') {
              chatProvider.exportChatHistoryAsText();
            } else if (value == 'settings') {
              onShowSettings();
            } else if (value == 'leave') {
              chatProvider.leaveRoom();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoomsListScreen()),
                (route) => false,
              );
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'call',
              child: ListTile(
                leading: const Icon(Icons.phone, color: Color(0xFF159D87)),
                title: Text(strings.voiceCallTitle),
              ),
            ),
            PopupMenuItem(
              value: 'video_call',
              child: ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Color(0xFF159D87)),
                title: Text(strings.startVideoCall),
              ),
            ),
            PopupMenuItem(
              value: 'qr',
              child: ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: Text(strings.roomQrCodeTitle),
              ),
            ),
            PopupMenuItem(
              value: 'gallery',
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(strings.mediaGallery),
              ),
            ),
            if (chatProvider.panicCamouflageEnabled)
              PopupMenuItem(
                value: 'panic',
                child: ListTile(
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(strings.panicTitle),
                ),
              ),
            PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: const Icon(Icons.copy),
                title: Text(strings.copyRoomCode),
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
          ],
        ),
      ];
    }

    return AppBar(
      backgroundColor: appBgColor.withValues(alpha: 0.8),
      iconTheme: IconThemeData(color: topBarTextColor),
      elevation: 0,
      titleSpacing: NavigationToolbar.kMiddleSpacing / 2,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: titleWidget,
      leading: leadingWidget,
      actions: actionsList,
    );
  }
}
