import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/color_utils.dart';
import 'message_bubble.dart';
import 'date_divider.dart';
import 'swipe_to_reply.dart';

class ChatMessageItem extends StatelessWidget {
  final Message msg;
  final bool showDateDivider;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelection;
  final VoidCallback onLongPress;

  const ChatMessageItem({
    super.key,
    required this.msg,
    required this.showDateDivider,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onLongPress,
  });

  String? _getReplyText(BuildContext context, String replyId) {
    final messages = context.read<ChatProvider>().messages;
    final strings = context.read<LocaleProvider>().strings;
    try {
      final replyMsg = messages.firstWhere((m) => m.id == replyId);
      return '${replyMsg.nickname}: ${replyMsg.text}';
    } catch (_) {
      return strings.deletedOrUnavailableMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final isBot = msg.senderId == 'system_bot';
    final isMe = !isBot && msg.senderId == chatProvider.currentUserId;

    final accent = themeProvider.accentColor;
    final appBgColor = Theme.of(context).scaffoldBackgroundColor;

    Color senderBg = themeProvider.senderBubbleColor ?? accent.withValues(alpha: 0.2);
    Color receiverBg = themeProvider.receiverBubbleColor ?? Theme.of(context).cardColor.withValues(alpha: 0.8);
    Color senderBorder = themeProvider.senderBubbleColor?.withValues(alpha: 0.8) ?? accent.withValues(alpha: 0.8);
    Color receiverBorder = themeProvider.receiverBubbleColor?.withValues(alpha: 0.8) ?? accent.withValues(alpha: 0.3);

    if (isBot) {
      receiverBg = Colors.black.withValues(alpha: 0.6);
      receiverBorder = Colors.redAccent.withValues(alpha: 0.8);
    }

    final currentBg = isMe ? senderBg : receiverBg;
    final textColor = getContrastColor(currentBg);

    Widget bubble = MessageBubble(
      msg: msg,
      isMe: isMe,
      isBot: isBot,
      currentBg: currentBg,
      textColor: textColor,
      borderColor: isMe ? senderBorder : receiverBorder,
      appBgColor: appBgColor,
      replyText: msg.replyToMessageId != null ? _getReplyText(context, msg.replyToMessageId!) : null,
      onRetry: msg.status == 'failed' && msg.localId != null
          ? () {
              chatProvider.retryMessage(msg);
            }
          : null,
    );

    if (isSelectionMode) {
      bubble = GestureDetector(
        onTap: onToggleSelection,
        child: Container(
          color: isSelected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: accent,
                onChanged: (_) => onToggleSelection(),
              ),
              Expanded(child: bubble),
            ],
          ),
        ),
      );
    } else {
      bubble = GestureDetector(
        onLongPress: chatProvider.tapToRevealEnabled ? null : onLongPress,
        onDoubleTap: () {
          HapticFeedback.mediumImpact();
          chatProvider.reactToMessage(msg.id, '🛡️');
        },
        child: bubble,
      );
    }

    final wrappedBubble = SwipeToReply(
      enabled: !isSelectionMode && !msg.isDeleted,
      accentColor: accent,
      onReply: () => chatProvider.replyTo(msg),
      child: bubble,
    );

    if (showDateDivider) {
      return Column(
        children: [
          DateDivider(date: msg.timestamp),
          wrappedBubble,
        ],
      );
    }

    return wrappedBubble;
  }
}
