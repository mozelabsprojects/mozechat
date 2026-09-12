import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class Particle {
  double x, y;
  double vx, vy;
  double? targetX, targetY;
  
  Particle({required this.x, required this.y, required this.vx, required this.vy});
}

class CyberGrid extends StatefulWidget {
  final Color accentColor;
  const CyberGrid({super.key, required this.accentColor});

  @override
  State<CyberGrid> createState() => _CyberGridState();
}

class _CyberGridState extends State<CyberGrid> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late Ticker _ticker;
  
  final List<Particle> _particles = [];
  bool _particlesInitialized = false;
  double _elapsedTime = 0.0;
  bool _isForming = false;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ticker = createTicker(_tick);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = context.watch<ThemeProvider>();
    if (themeProvider.animationsEnabled) {
      if (!_ticker.isActive) _ticker.start();
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      if (_ticker.isActive) _ticker.stop();
      if (_pulseController.isAnimating) _pulseController.stop();
    }
  }

  void _initParticles(Size size) {
    _particles.clear();
    final rng = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(Particle(
        x: rng.nextDouble() * size.width,
        y: rng.nextDouble() * size.height,
        vx: (rng.nextDouble() - 0.5) * 40,
        vy: (rng.nextDouble() - 0.5) * 40,
      ));
    }
    _particlesInitialized = true;
    _lastSize = size;
  }

  void _computeTargets(Size size) {
    final marginX = size.width * 0.25;
    final marginY = size.height * 0.35;
    final w = size.width - marginX * 2;
    final h = size.height - marginY * 2;
    
    final p1 = Offset(marginX, marginY + h);
    final p2 = Offset(marginX, marginY);
    final p3 = Offset(size.width / 2, marginY + h * 0.5);
    final p4 = Offset(marginX + w, marginY);
    final p5 = Offset(marginX + w, marginY + h);

    int index = 0;
    for (int i = 0; i < 10; i++) {
      double t = i / 9;
      _particles[index].targetX = p1.dx + (p2.dx - p1.dx) * t;
      _particles[index].targetY = p1.dy + (p2.dy - p1.dy) * t;
      index++;
    }
    for (int i = 0; i < 10; i++) {
      double t = i / 9;
      _particles[index].targetX = p2.dx + (p3.dx - p2.dx) * t;
      _particles[index].targetY = p2.dy + (p3.dy - p2.dy) * t;
      index++;
    }
    for (int i = 0; i < 10; i++) {
      double t = i / 9;
      _particles[index].targetX = p3.dx + (p4.dx - p3.dx) * t;
      _particles[index].targetY = p3.dy + (p4.dy - p3.dy) * t;
      index++;
    }
    for (int i = 0; i < 10; i++) {
      double t = i / 9;
      _particles[index].targetX = p4.dx + (p5.dx - p4.dx) * t;
      _particles[index].targetY = p4.dy + (p5.dy - p4.dy) * t;
      index++;
    }
  }

  void _clearTargets() {
    for (var p in _particles) {
      p.targetX = null;
      p.targetY = null;
    }
  }

  void _tick(Duration elapsed) {
    if (!_particlesInitialized || _lastSize.width == 0) return;
    
    final dt = 0.016; 
    _elapsedTime += dt;

    if (_elapsedTime % 15.0 < 10.0) {
      if (_isForming) {
        _isForming = false;
        _clearTargets();
      }
    } else {
      if (!_isForming) {
        _isForming = true;
        _computeTargets(_lastSize);
      }
    }

    setState(() {
      for (var p in _particles) {
        if (_isForming && p.targetX != null && p.targetY != null) {
          final dx = p.targetX! - p.x;
          final dy = p.targetY! - p.y;
          p.vx = p.vx * 0.9 + dx * 0.5;
          p.vy = p.vy * 0.9 + dy * 0.5;
        } else {
          final rng = Random();
          p.vx += (rng.nextDouble() - 0.5) * 5;
          p.vy += (rng.nextDouble() - 0.5) * 5;
          
          final speed = sqrt(p.vx * p.vx + p.vy * p.vy);
          if (speed > 40) {
            p.vx = (p.vx / speed) * 40;
            p.vy = (p.vy / speed) * 40;
          }
        }

        p.x += p.vx * dt;
        p.y += p.vy * dt;

        if (!_isForming) {
          if (p.x < 0) { p.x = 0; p.vx *= -1; }
          if (p.x > _lastSize.width) { p.x = _lastSize.width; p.vx *= -1; }
          if (p.y < 0) { p.y = 0; p.vy *= -1; }
          if (p.y > _lastSize.height) { p.y = _lastSize.height; p.vy *= -1; }
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEco = !context.watch<ThemeProvider>().animationsEnabled;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (!_particlesInitialized && size.width > 0) {
                _initParticles(size);
              } else if (_particlesInitialized && _lastSize != size) {
                _lastSize = size;
                if (_isForming) _computeTargets(size);
              }
              return CustomPaint(
                painter: _CyberGridPainter(
                  widget.accentColor, 
                  isEco ? null : _particles,
                  isEco,
                ),
              );
            },
          ),
        ),
        if (!isEco)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        widget.accentColor.withValues(alpha: _pulseAnim.value * 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final Color accentColor;
  final List<Particle>? particles;
  final bool isEcoMode;

  _CyberGridPainter(this.accentColor, this.particles, this.isEcoMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dotPaint = Paint()..color = accentColor.withValues(alpha: 0.2);
    
    if (isEcoMode || particles == null) {
      final rng = Random(42);
      for (int i = 0; i < 40; i++) {
        final x = rng.nextDouble() * size.width;
        final y = rng.nextDouble() * size.height;
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    } else {
      for (var p in particles!) {
        canvas.drawCircle(Offset(p.x, p.y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    if (isEcoMode && oldDelegate.isEcoMode) return false;
    return true;
  }
}
