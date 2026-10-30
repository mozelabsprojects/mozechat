import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:screenshot_callback/screenshot_callback.dart';

import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/matrix_background.dart';
import '../models/message.dart';
import '../utils/color_utils.dart';

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

    // Mark user as actively viewing chat screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().setUserInChat(true);
      }
    });

    _screenshotCallback = ScreenshotCallback();
    _screenshotCallback.addListener(() {
      if (mounted) {
        final nick = context.read<ChatProvider>().nickname ?? 'Kullanıcı';
        context.read<ChatProvider>().sendMessage(
          "⚠️ [SİSTEM UYARISI] $nick ekran görüntüsü aldı!",
          senderIdOverride: 'system_bot',
          nicknameOverride: 'SİSTEM',
        );
      }
    });
  }

  @override
  void dispose() {
    // Mark user as no longer viewing chat screen & stop typing indicator
    context.read<ChatProvider>().setUserInChat(false);
    context.read<ChatProvider>().updateTyping(false);
    WidgetsBinding.instance.removeObserver(this);
    _easterEggConfettiController.dispose();
    _scrollController.dispose();
    _screenshotCallback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<ChatProvider>();
    if (state == AppLifecycleState.resumed) {
      provider.updatePresence(true);
      provider.setUserInChat(true);
      NotificationService.currentActiveRoomCode = provider.roomCode;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      provider.setUserInChat(false);
      provider.updatePresence(false);
      NotificationService.currentActiveRoomCode = null;
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

  void _showMessageOptions(BuildContext context, dynamic msg, bool isMe) {
    if (msg.isDeleted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black87,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Permanently',
                  style: TextStyle(color: Colors.red),
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
                title: const Text(
                  'Select Messages',
                  style: TextStyle(color: Colors.white),
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
                  msg.isStarred ? 'Remove Star' : 'Star Message',
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
                  title: const Text(
                    'Edit Message',
                    style: TextStyle(color: Colors.white),
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
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
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
    final controller = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'New text...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && text != msg.text) {
                context.read<ChatProvider>().editMessage(msg.id, text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _copyCode() {
    final code = context.read<ChatProvider>().roomCode ?? "";
    Clipboard.setData(ClipboardData(text: code));
    final accent = context.read<ThemeProvider>().accentColor;
    CyberHUD.show(
      context,
      message: 'ODA KODU PANOYA KOPYALANDI',
      icon: Icons.copy_rounded,
      accentColor: accent,
    );
  }

  void _pickColor(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (c) => tempColor = c,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('APPLY'),
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
            title: const Text(
              'SETTINGS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Change Nickname:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter new nickname',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Anonymous Voice:'),
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
                      const Text('Tap-to-Reveal:'),
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
                      const Text('Panic Camouflage:'),
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
                  const Text('My Bubble Color:'),
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
                  const Text('Other Bubble Color:'),
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
                child: const Text('CLOSE'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newNick = nicknameController.text.trim();
                  if (newNick.isNotEmpty && newNick != chatProvider.nickname) {
                    chatProvider.setNickname(newNick);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCommandsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Sistem Komutları', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚙️ Terminal Komutları', style: TextStyle(color: Color(0xFF159D87), fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 8),
              Text(
                '!help : Yardım menüsünü gösterir\n'
                '!clear [sayı] : Son mesajları temizler\n'
                '!wipe : Ekrandaki akışı anında temizler\n'
                '!note [yazı] : Şifreli ortak not ekler\n'
                '!notes : Kayıtlı notları listeler\n'
                '!remind [yazı] [sn] : Hatırlatıcı alarm kurar',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('KAPAT', style: TextStyle(color: Color(0xFF159D87))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();
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

    // Lock removed

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ChatAppBar(
        selectedMessages: _selectedMessages.toList(),
        onClearSelection: () => setState(() => _selectedMessages.clear()),
        onShowSettings: () => _showSettingsMenu(context),
        onShowCommands: () => _showCommandsDialog(context),
        onCopyCode: _copyCode,
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (_showMatrix)
            Positioned.fill(child: MatrixBackground(color: accent)),
          SafeArea(
            child: Column(
              children: [
                const SystemStatusBanner(),
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
                                '[ SECURE CHANNEL CONNECTING... ]',
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
                                scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                              chatProvider.loadMoreMessages();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            reverse: true,
                            itemCount: chatProvider.messages.length + (chatProvider.hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatProvider.messages.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                '[FETCHING ARCHIVE...]',
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
                          final currentMsgDate = DateTime(msg.timestamp.year, msg.timestamp.month, msg.timestamp.day);
                          final nextMsgDate = DateTime(nextMsg.timestamp.year, nextMsg.timestamp.month, nextMsg.timestamp.day);
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
                          onLongPress: () => _showMessageOptions(context, msg, msg.nickname == chatProvider.nickname),
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
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: chatProvider.isOtherTyping
                      ? Align(
                          key: const ValueKey('typing_indicator_active'),
                          alignment: Alignment.centerLeft,
                          child: TypingIndicator(
                            textColor: accent,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('typing_indicator_empty')),
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
                      context.read<ChatProvider>().sendBotMessage(
                        "Seni seviyorum Zeynep, Allah seni yanımdan ayırmasın ve yolumuzu kolaylaştırsın. İyi ki varsın.",
                      );
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
                    child: const Icon(Icons.arrow_downward_rounded, color: Colors.black, size: 22),
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
