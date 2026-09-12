import 'dart:math';
import 'package:flutter/material.dart';

class MatrixBackground extends StatefulWidget {
  final Color color;
  const MatrixBackground({super.key, this.color = const Color(0xFF159D87)});

  @override
  State<MatrixBackground> createState() => _MatrixBackgroundState();
}

class _MatrixBackgroundState extends State<MatrixBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<_MatrixDrop> _drops;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final int columnCount = (size.width / 20).floor();
    _drops = List.generate(
      columnCount,
      (index) => _MatrixDrop(
        x: index * 20.0,
        y: _random.nextDouble() * size.height,
        speed: 2 + _random.nextDouble() * 5,
        initialMaxLength: 10 + _random.nextInt(15),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _MatrixPainter(
            _drops,
            widget.color,
            MediaQuery.of(context).size.height,
          ),
        );
      },
    );
  }
}

class _MatrixDrop {
  final double x;
  double y;
  final double speed;
  int maxLength;
  List<String> characters;
  final bool isWord;

  _MatrixDrop({
    required this.x,
    required this.y,
    required this.speed,
    required int initialMaxLength,
  }) : isWord = Random().nextDouble() > 0.8,
       maxLength = initialMaxLength,
       characters = [] {
    if (isWord) {
      final words = ["ZEYNEP", "SENİ", "SEVİYORUM"];
      final word = words[Random().nextInt(words.length)];
      maxLength = word.length;
      characters = word.split('');
    } else {
      characters = List.generate(
        maxLength,
        (_) => String.fromCharCode(0x30A0 + Random().nextInt(96)),
      );
    }
  }
}

class _MatrixPainter extends CustomPainter {
  final List<_MatrixDrop> drops;
  final Color color;
  final double screenHeight;
  final Random random = Random();

  _MatrixPainter(this.drops, this.color, this.screenHeight);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    for (var drop in drops) {
      drop.y += drop.speed;
      if (drop.y > screenHeight) {
        drop.y = 0;
      }

      for (int i = 0; i < drop.maxLength; i++) {
        final double currentY = drop.y - (i * 20);
        if (currentY < 0 || currentY > screenHeight) continue;

        if (random.nextDouble() > 0.95 && !drop.isWord) {
          drop.characters[i] = String.fromCharCode(0x30A0 + random.nextInt(96));
        }

        final double opacity = 1.0 - (i / drop.maxLength);
        final TextStyle textStyle = TextStyle(
          color: i == 0 ? Colors.white : color.withValues(alpha: opacity),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        );

        final TextSpan span = TextSpan(
          text: drop.characters[i],
          style: textStyle,
        );
        final TextPainter tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(drop.x, currentY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter oldDelegate) => true;
}
