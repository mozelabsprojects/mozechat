import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final Color accentColor;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    required this.accentColor,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _slideAnim;
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;

  static const double _triggerThreshold = 45.0;
  static const double _maxDragOffset = 70.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnim = Tween<double>(begin: 0.0, end: 0.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    // Only allow swiping right
    if (details.delta.dx > 0 || _dragOffset > 0) {
      final newOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDragOffset);
      if (newOffset != _dragOffset) {
        setState(() {
          _dragOffset = newOffset;
        });

        if (_dragOffset >= _triggerThreshold && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          HapticFeedback.lightImpact();
        } else if (_dragOffset < _triggerThreshold && _hasTriggeredHaptic) {
          _hasTriggeredHaptic = false;
        }
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    if (_dragOffset >= _triggerThreshold) {
      widget.onReply();
    }
    _resetOffset();
  }

  void _onHorizontalDragCancel() {
    _resetOffset();
  }

  void _resetOffset() {
    if (_dragOffset == 0.0) return;
    _slideAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _dragOffset = _slideAnim.value;
          });
        }
      });
    _animController.forward(from: 0.0);
    _hasTriggeredHaptic = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final progress = (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);
    final iconScale = progress;
    final iconOpacity = progress;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // Sleek reply indicator behind the bubble on the left
          Positioned(
            left: 12,
            child: Opacity(
              opacity: iconOpacity,
              child: Transform.scale(
                scale: iconScale,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasTriggeredHaptic
                        ? widget.accentColor.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _hasTriggeredHaptic
                          ? widget.accentColor
                          : Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: _hasTriggeredHaptic
                        ? [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: _hasTriggeredHaptic ? widget.accentColor : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Translated message bubble
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

