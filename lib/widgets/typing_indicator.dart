import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color textColor;
  final String text;

  const TypingIndicator({
    super.key, 
    required this.textColor,
    this.text = "decrypting stream",
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cursorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _cursorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '>_ ',
            style: TextStyle(
              color: widget.textColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor.withValues(alpha: 0.8),
              fontFamily: 'monospace',
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
          FadeTransition(
            opacity: _cursorAnimation,
            child: Text(
              ' █',
              style: TextStyle(
                color: widget.textColor,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
