import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:screenshot_callback/screenshot_callback.dart';

import '../providers/chat_provider.dart';
import '../providers/call_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/matrix_background.dart';
import '../models/message.dart';
import '../utils/color_utils.dart';
import '../utils/app_strings.dart';
import 'call_screen.dart';

import '../widgets/chat_app_bar.dart';
import '../widgets/chat_message_item.dart';
import '../widgets/chat_bottom_input_bar.dart';
import '../widgets/typing_indicator.dart';
import '../services/notification_service.dart';
import '../widgets/system_status_banner.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/cyber_hud.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ConfettiController _easterEggConfettiController;
  bool _showMatrix = false;
  late ScreenshotCallback _screenshotCallback;

  ChatProvider? _chatProvider;
  CallProvider? _callProvider;

  final Set<String> _selectedMessages = {};
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _easterEggConfettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToBottom) {
        setState(() => _showScrollToBottom = true);
      } else if (_scrollController.offset <= 200 && _showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProvider = context.read<ChatProvider>();
      final callProvider = context.read<CallProvider>();
      chatProvider.setUserInChat(true);
      callProvider.watchRoomCalls(
        chatProvider.roomCode,
        chatProvider.currentUserId,
      );

      if (chatProvider.tapToRevealEnabled) {
        final strings = context.read<LocaleProvider>().strings;
        CyberHUD.show(context, message: strings.tapToRevealHintBubble);
      }
    });

    _screenshotCallback = ScreenshotCallback();
    _screenshotCallback.addListener(() {
      if (mounted) {
        final strings = context.read<LocaleProvider>().strings;
        final nick = context.read<ChatProvider>().nickname ?? strings.unknownUser;
        context.read<ChatProvider>().sendMessage(
          strings.screenshotWarningMsg(nick),
          senderIdOverride: 'system_bot',
          nicknameOverride: strings.systemSender,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= context.read<ChatProvider>();
    _callProvider ??= context.read<CallProvider>();
  }

  @override
  void dispose() {
    _chatProvider?.setUserInChat(false);
    _chatProvider?.updateTyping(false);
    _callProvider?.watchRoomCalls(null, null);
    WidgetsBinding.instance.removeObserver(this);
    _easterEggConfettiController.dispose();
    _scrollController.dispose();
    _screenshotCallback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = _chatProvider;
    if (provider == null) return;

    if (state == AppLifecycleState.resumed) {
      provider.updatePresence(true);
      provider.setUserInChat(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      provider.setUserInChat(false);
      provider.updatePresence(false);
      NotificationService.setActiveChatRoom(null, inChat: false);
    }
  }

  Path _drawHeart(Size size) {
    double width = size.width;
    double height = size.height;
    Path path = Path();
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.2 * width,
      height * 0.1,
      -0.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.cubicTo(
      1.25 * width,
      height * 0.6,
      0.8 * width,
      height * 0.1,
      0.5 * width,
      height * 0.35,
    );
    return path;
  }

  void _triggerEasterEgg() {
    _easterEggConfettiController.play();
  }

  Widget _buildWhatsAppCallBanner(
    BuildContext context,
    CallProvider callProvider,
    AppStrings strings,
  ) {
    // Active Call Banner (WhatsApp-style green bar at top of chat)
    if (callProvider.isInCall) {
      return Material(
        color: const Color(0xFF159D87),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CallScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${strings.ongoingVoiceCallBanner} • ${callProvider.formattedDuration}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        strings.tapToReturnToCall,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    callProvider.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => callProvider.toggleMute(),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => callProvider.endCall(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      strings.endCallBtn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Incoming Call Banner (WhatsApp-style Join / Decline bar at top of chat)
    if (callProvider.hasIncomingRoomCall) {
      final caller = callProvider.incomingCallerName ?? strings.unknownUser;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111922),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF159D87).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF159D87).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ring_volume_rounded,
                color: Color(0xFF159D87),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    strings.incomingVoiceCall,
                    style: const TextStyle(
                      color: Color(0xFF159D87),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => callProvider.declineIncomingRoomCall(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  strings.declineCallBtn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await callProvider.joinIncomingRoomCall(openCallScreen: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF159D87),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  strings.joinCallBtn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showMessageOptions(BuildContext context, dynamic msg, bool isMe) {
    final strings = context.read<LocaleProvider>().strings;

    if (msg.isDeleted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black87,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  strings.deletePermanently,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatProvider>().hardDeleteMessage(msg.id);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (_selectedMessages.isNotEmpty) {
      setState(() {
        if (_selectedMessages.contains(msg.id)) {
          _selectedMessages.remove(msg.id);
        } else {
          _selectedMessages.add(msg.id);
        }
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.check_box_outlined,
                  color: Colors.blueAccent,
                ),
                title: Text(
                  strings.selectMessages,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedMessages.add(msg.id);
                  });
                },
              ),
              ListTile(
                leading: Icon(
                  msg.isStarred ? Icons.star_border : Icons.star,
                  color: Colors.yellow,
                ),
                title: Text(
                  msg.isStarred ? strings.unstar : strings.star,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatProvider>().starMessage(
                    msg.id,
                    !msg.isStarred,
                  );
                },
              ),
              if (isMe && msg.type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blueAccent),
                  title: Text(
                    strings.editMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context, msg);
                  },
                ),
              ListTile(
                title: Wrap(
                  spacing: 12,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.read<ChatProvider>().reactToMessage(msg.id, emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    );
                  }).toList(),
                ),
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    strings.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<ChatProvider>().deleteMessage(msg.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Message msg) {
    final strings = context.read<LocaleProvider>().strings;
    final controller = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(strings.editMessage, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: strings.editMessageHint,
            hintStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && text != msg.text) {
                context.read<ChatProvider>().editMessage(msg.id, text);
              }
              Navigator.pop(ctx);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  void _copyCode() {
    final code = context.read<ChatProvider>().roomCode ?? '';
    final strings = context.read<LocaleProvider>().strings;
    Clipboard.setData(ClipboardData(text: code));
    final accent = context.read<ThemeProvider>().accentColor;
    CyberHUD.show(
      context,
      message: strings.roomCodeCopied,
      icon: Icons.copy_rounded,
      accentColor: accent,
    );
  }

  void _pickColor(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    final strings = context.read<LocaleProvider>().strings;
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.pickColorTitle),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (c) => tempColor = c,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            child: Text(strings.cancel),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(strings.applyBtn),
            onPressed: () {
              onColorChanged(tempColor);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final themeProvider = context.read<ThemeProvider>();
    final strings = context.read<LocaleProvider>().strings;

    final nicknameController = TextEditingController(
      text: chatProvider.nickname,
    );

    List<Color> presetColors = [
      const Color(0xFF159D87),
      const Color(0xFF4A3B5A),
      const Color(0xFF6482AD),
      const Color(0xFF8B263E),
      Colors.black,
      Colors.white,
    ];

    Color currentSenderColor =
        themeProvider.senderBubbleColor ??
        themeProvider.accentColor.withValues(alpha: 0.15);
    Color currentReceiverColor =
        themeProvider.receiverBubbleColor ??
        Theme.of(context).cardColor.withValues(alpha: 0.8);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              strings.settingsTitle.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${strings.changeNickname}:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: strings.enterNewNickname,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${strings.anonymousVoice}:')),
                      Switch(
                        value: chatProvider.isAnonymousVoice,
                        activeThumbColor: themeProvider.accentColor,
                        onChanged: (val) {
                          setDialogState(() {
                            chatProvider.toggleAnonymousVoice(val);
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${strings.tapToReveal}:')),
                      Switch(
                        value: chatProvider.tapToRevealEnabled,
                        activeThumbColor: themeProvider.accentColor,
                        onChanged: (val) {
                          setDialogState(() {
                            chatProvider.toggleTapToReveal(val);
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${strings.panicCamouflage}:')),
                      Switch(
                        value: chatProvider.panicCamouflageEnabled,
                        activeThumbColor: themeProvider.accentColor,
                        onChanged: (val) {
                          setDialogState(() {
                            chatProvider.togglePanicCamouflage(val);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('${strings.myBubbleColor}:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...presetColors.map(
                        (c) => GestureDetector(
                          onTap: () {
                            setDialogState(() => currentSenderColor = c);
                            themeProvider.setSenderBubbleColor(c);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: currentSenderColor == c
                                    ? const Color(0xFF159D87)
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _pickColor(context, currentSenderColor, (c) {
                            setDialogState(() => currentSenderColor = c);
                            themeProvider.setSenderBubbleColor(c);
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: currentSenderColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.color_lens,
                            size: 16,
                            color: getContrastColor(currentSenderColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('${strings.otherBubbleColor}:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...presetColors.map(
                        (c) => GestureDetector(
                          onTap: () {
                            setDialogState(() => currentReceiverColor = c);
                            themeProvider.setReceiverBubbleColor(c);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: currentReceiverColor == c
                                    ? const Color(0xFF159D87)
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _pickColor(context, currentReceiverColor, (c) {
                            setDialogState(() => currentReceiverColor = c);
                            themeProvider.setReceiverBubbleColor(c);
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: currentReceiverColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.color_lens,
                            size: 16,
                            color: getContrastColor(currentReceiverColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strings.closeBtn),
              ),
              ElevatedButton(
                onPressed: () {
                  final newNick = nicknameController.text.trim();
                  if (newNick.isNotEmpty && newNick != chatProvider.nickname) {
                    chatProvider.setNickname(newNick);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(strings.save),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final callProvider = context.watch<CallProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final accent = themeProvider.accentColor;

    if (chatProvider.roomCode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ChatAppBar(
        selectedMessages: _selectedMessages.toList(),
        onClearSelection: () => setState(() => _selectedMessages.clear()),
        onShowSettings: () => _showSettingsMenu(context),
        onCopyCode: _copyCode,
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (_showMatrix)
            Positioned.fill(child: MatrixBackground(color: accent)),
          // Keep audio renderer alive when call is minimized to ChatScreen
          if (callProvider.isInCall && callProvider.remoteStream != null)
            SizedBox(
              width: 0,
              height: 0,
              child: RTCVideoView(callProvider.remoteRenderer),
            ),
          SafeArea(
            child: Column(
              children: [
                const SystemStatusBanner(),
                _buildWhatsAppCallBanner(context, callProvider, strings),
                Expanded(
                  child: chatProvider.isLoading && chatProvider.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                strings.secureChannelConnecting,
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.6),
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            if (!chatProvider.isLoading &&
                                chatProvider.hasMoreMessages &&
                                scrollInfo.metrics.pixels ==
                                    scrollInfo.metrics.maxScrollExtent) {
                              chatProvider.loadMoreMessages();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            reverse: true,
                            itemCount:
                                chatProvider.messages.length +
                                (chatProvider.hasMoreMessages ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == chatProvider.messages.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      strings.fetchingArchive,
                                      style: TextStyle(
                                        color: accent.withValues(alpha: 0.8),
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final msg = chatProvider.messages[index];
                              bool showDateDivider = false;
                              if (index == chatProvider.messages.length - 1) {
                                showDateDivider = true;
                              } else {
                                final nextMsg = chatProvider.messages[index + 1];
                                final currentMsgDate = DateTime(
                                  msg.timestamp.year,
                                  msg.timestamp.month,
                                  msg.timestamp.day,
                                );
                                final nextMsgDate = DateTime(
                                  nextMsg.timestamp.year,
                                  nextMsg.timestamp.month,
                                  nextMsg.timestamp.day,
                                );
                                if (currentMsgDate != nextMsgDate) {
                                  showDateDivider = true;
                                }
                              }

                              return ChatMessageItem(
                                key: ValueKey(msg.id),
                                msg: msg,
                                showDateDivider: showDateDivider,
                                isSelected: _selectedMessages.contains(msg.id),
                                isSelectionMode: _selectedMessages.isNotEmpty,
                                onToggleSelection: () {
                                  setState(() {
                                    if (_selectedMessages.contains(msg.id)) {
                                      _selectedMessages.remove(msg.id);
                                    } else {
                                      _selectedMessages.add(msg.id);
                                    }
                                  });
                                },
                                onLongPress: () => _showMessageOptions(
                                  context,
                                  msg,
                                  msg.nickname == chatProvider.nickname,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  reverseDuration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.4),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: chatProvider.isOtherTyping
                      ? Align(
                          key: const ValueKey('typing_indicator_active'),
                          alignment: Alignment.centerLeft,
                          child: TypingIndicator(
                            textColor: accent,
                            text: strings.typing,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('typing_indicator_empty'),
                        ),
                ),
                ChatBottomInputBar(
                  onEasterEggTriggered: (code) {
                    if (code == 'matrix') {
                      setState(() => _showMatrix = true);
                      Future.delayed(const Duration(seconds: 8), () {
                        if (mounted) setState(() => _showMatrix = false);
                      });
                    } else if (code == 'moze') {
                      _triggerEasterEgg();
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 80,
            child: AnimatedScale(
              scale: _showScrollToBottom ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _showScrollToBottom ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: BouncyTap(
                  onTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _easterEggConfettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            createParticlePath: _drawHeart,
            colors: const [Colors.red, Colors.pink, Colors.pinkAccent],
            numberOfParticles: 30,
            emissionFrequency: 0.05,
            gravity: 0.1,
          ),
        ],
      ),
    );
  }
}
