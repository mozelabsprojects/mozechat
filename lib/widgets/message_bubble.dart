import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../services/location_service.dart';
import '../screens/photo_view_screen.dart';
import '../screens/video_player_screen.dart';
import '../screens/photo_view_gallery_screen.dart';
import 'audio_bubble.dart';

class MessageBubble extends StatefulWidget {
  final Message msg;
  final bool isMe;
  final bool isBot;
  final Color currentBg;
  final Color textColor;
  final Color borderColor;
  final Color appBgColor;
  final String? replyText;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.isBot,
    required this.currentBg,
    required this.textColor,
    required this.borderColor,
    required this.appBgColor,
    this.replyText,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  Timer? _burnTimer;
  int _timeLeft = 10;
  late AnimationController _burnAnimController;
  late Animation<double> _burnScale;
  late Animation<double> _burnOpacity;

  @override
  void initState() {
    super.initState();
    _burnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _burnScale = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _burnAnimController, curve: Curves.easeIn));
    _burnOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _burnAnimController, curve: Curves.easeOut));
    _checkBurn();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.msg.status == 'read' && oldWidget.msg.status != 'read') {
      _checkBurn();
    }
  }

  @override
  void dispose() {
    _burnTimer?.cancel();
    _burnAnimController.dispose();
    super.dispose();
  }

  void _checkBurn() {
    if (widget.msg.metadata?['burnAfterRead'] == true && widget.msg.status == 'read' && !widget.msg.isDeleted) {
      _burnTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _timeLeft--;
        });
        if (_timeLeft <= 0) {
          timer.cancel();
          _burnAnimController.forward().then((_) {
            if (mounted) context.read<ChatProvider>().deleteMessage(widget.msg.id);
          });
        }
      });
    }
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();

    Widget statusWidget;

    switch (widget.msg.status) {
      case 'pending':
        statusWidget = Text('...', style: TextStyle(color: widget.textColor.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold));
        break;
      case 'failed':
        statusWidget = Text('[ERR]', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold));
        break;
      case 'sent':
        statusWidget = Text('•', style: TextStyle(color: widget.textColor.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.bold));
        break;
      case 'delivered':
        statusWidget = Text('••', style: TextStyle(color: const Color(0xFF159D87), fontSize: 14, fontWeight: FontWeight.bold));
        break;
      case 'read':
        statusWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.msg.metadata?['burnAfterRead'] == true)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Text('🔥$_timeLeft', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            Text(
              '••', 
              style: const TextStyle(
                color: Colors.cyanAccent, 
                fontSize: 14, 
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)]
              )
            ),
          ],
        );
        break;
      default:
        statusWidget = Text('•', style: TextStyle(color: widget.textColor.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.bold));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: statusWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.msg.isDeleted && widget.msg.metadata?['burnAfterRead'] == true) {
      return const SizedBox.shrink();
    }
    
    final timeString = DateFormat('HH:mm').format(widget.msg.timestamp);
    final isBurn = widget.msg.metadata?['burnAfterRead'] == true && !widget.msg.isDeleted;
    final bgColor = isBurn ? Colors.orangeAccent.withValues(alpha: 0.1) : widget.currentBg;
    final bdrColor = isBurn ? Colors.orangeAccent : widget.borderColor;
    final shadowColor = isBurn ? Colors.orangeAccent.withValues(alpha: 0.4) : widget.borderColor.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: widget.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: AnimatedBuilder(
              animation: _burnAnimController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _burnScale.value,
                  child: Opacity(
                    opacity: _burnOpacity.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(2),
                    topRight: const Radius.circular(12),
                    bottomLeft: widget.isMe ? const Radius.circular(12) : Radius.zero,
                    bottomRight: widget.isMe ? Radius.zero : const Radius.circular(12),
                  ),
                  border: Border.all(color: bdrColor, width: 1.5),
                  color: bgColor,
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: isBurn ? 20 : 10,
                      spreadRadius: isBurn ? 2 : 1,
                    ),
                  ],
                ),
              child: Stack(
                children: [
                  if (!widget.msg.isDeleted)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(2),
                          topRight: const Radius.circular(12),
                          bottomLeft: widget.isMe ? const Radius.circular(12) : Radius.zero,
                          bottomRight: widget.isMe ? Radius.zero : const Radius.circular(12),
                        ),
                        child: widget.isBot
                            ? Container()
                            : Opacity(
                                opacity: 0.05,
                                child: CustomPaint(
                                  painter: _CyberGridPainter(color: widget.textColor),
                                ),
                              ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.isMe && !widget.isBot)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              widget.msg.nickname,
                              style: TextStyle(
                                color: widget.isBot
                                    ? Colors.white
                                    : widget.textColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                                fontFamily: 'Courier',
                              ),
                            ),
                          ),
                        if (widget.replyText != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: widget.textColor, width: 2),
                              ),
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.replyText!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                              child: _buildContent(context),
                            ),
                            if (widget.msg.reactions != null && widget.msg.reactions!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                                child: Wrap(
                                  spacing: 4,
                                  children: widget.msg.reactions!.entries.map((entry) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Text(entry.value, style: const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.msg.isStarred)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4.0),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.yellow,
                                      size: 14,
                                    ),
                                  ),
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.textColor.withValues(alpha: 0.6),
                                  ),
                                ),
                                if (widget.msg.isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      "(edited)",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic,
                                        color: widget.textColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                _buildStatusIcon(),
                              ],
                            ),
                          ],
                        ),
                        if (widget.msg.status == 'failed' && widget.onRetry != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Center(
                              child: GestureDetector(
                                onTap: widget.onRetry,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh,
                                        size: 16,
                                        color: Colors.redAccent,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tap to retry',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.msg.type == 'media_group' && widget.msg.mediaList != null && widget.msg.mediaList!.isNotEmpty) {
      return _buildMediaGrid(context, widget.msg.mediaList!);
    } else if (widget.msg.type == 'image' && widget.msg.mediaUrl != null) {
      return GestureDetector(
        onTap: () {
          final chatProvider = context.read<ChatProvider>();
          final allImageMsgs = chatProvider.messages
              .where((m) => m.type == 'image' && m.mediaUrl != null)
              .toList()
              .reversed
              .toList(); // Chronological order
          
          final initialIndex = allImageMsgs.indexWhere((m) => m.id == widget.msg.id);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoViewScreen(
                imageMessages: allImageMsgs.isNotEmpty ? allImageMsgs : [widget.msg],
                initialIndex: initialIndex >= 0 ? initialIndex : 0,
              ),
            ),
          );
        },
        child: Hero(
          tag: widget.msg.id,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: CachedNetworkImage(
              imageUrl: widget.msg.mediaUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      );
    } else if (widget.msg.type == 'video' && widget.msg.mediaUrl != null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoUrl: widget.msg.mediaUrl!),
          ),
        ),
        child: Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.msg.thumbnailUrl != null)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: CachedNetworkImage(
                    imageUrl: widget.msg.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.msg.type == 'location' && widget.msg.locationLat != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  '[ LOCATION SIGNAL ENCRYPTED ]',
                  style: TextStyle(color: widget.textColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LAT: ${widget.msg.locationLat}\nLNG: ${widget.msg.locationLng}',
            style: TextStyle(fontFamily: 'monospace', color: widget.textColor),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.textColor,
              foregroundColor: widget.currentBg,
            ),
            onPressed: () => LocationService.openInGoogleMaps(
              widget.msg.locationLat!,
              widget.msg.locationLng!,
            ),
            child: const Text('OPEN MAP'),
          ),
        ],
      );
    } else if (widget.msg.type == 'audio') {
      if (widget.msg.status == 'pending') {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: Colors.grey),
            const SizedBox(width: 8),
            Text("Ses yükleniyor...", style: TextStyle(color: widget.textColor)),
          ],
        );
      } else if (widget.msg.status == 'failed') {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              "Ses gönderilemedi.",
              style: TextStyle(color: Colors.redAccent),
            ),
          ],
        );
      }
      return AudioBubble(
        audioUrl: widget.msg.mediaUrl ?? '',
        bubbleColor: widget.currentBg,
        textColor: widget.textColor,
        isMe: widget.isMe,
        isAnonymous: widget.msg.metadata?['voiceFilter'] == 'anonymous',
      );
    } else {
      Widget textWidget = Text(
        widget.msg.text,
        style: TextStyle(
          fontSize: 16,
          fontStyle: widget.msg.isDeleted ? FontStyle.italic : FontStyle.normal,
          color: widget.msg.isDeleted ? widget.textColor.withValues(alpha: 0.6) : widget.textColor,
        ),
      );

      return textWidget;
    }
  }

  Widget _buildMediaGrid(BuildContext context, List<Map<String, dynamic>> mediaList) {
    int displayCount = mediaList.length > 4 ? 4 : mediaList.length;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewGalleryScreen(mediaList: mediaList),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        child: GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: displayCount == 1 ? 1 : 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final item = mediaList[index];
            final type = item['type'];
            final url = type == 'video' ? (item['thumbnailUrl'] ?? '') : item['url'];
            
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  ),
                ),
                if (type == 'video')
                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30)),
                if (index == 3 && mediaList.length > 4)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '+${mediaList.length - 4}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final Color color;

  _CyberGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    const double spacing = 20.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
