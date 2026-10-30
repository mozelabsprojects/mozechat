import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CyberHUD {
  static OverlayEntry? _currentEntry;

  /// Shows a futuristic stealth HUD capsule toast dropping from the top
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? accentColor,
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    if (_currentEntry != null && _currentEntry!.mounted) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
    }
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    HapticFeedback.lightImpact();
    final effectiveColor = isError
        ? Colors.redAccent
        : (accentColor ?? const Color(0xFF159D87));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CyberHUDWidget(
        message: message,
        icon: icon ?? (isError ? Icons.error_outline_rounded : Icons.shield_outlined),
        accentColor: effectiveColor,
        isError: isError,
        duration: duration,
        onDismissed: () {
          if (_currentEntry == entry) {
            if (entry.mounted) {
              try {
                entry.remove();
              } catch (_) {}
            }
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _CyberHUDWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismissed;

  const _CyberHUDWidget({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.isError,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_CyberHUDWidget> createState() => _CyberHUDWidgetState();
}

class _CyberHUDWidgetState extends State<_CyberHUDWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_animController.isAnimating || _animController.status == AnimationStatus.dismissed) return;
    _animController.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -2) {
                  _dismiss();
                }
              },
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: widget.accentColor, size: 18),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                fontFamily: 'Courier',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

