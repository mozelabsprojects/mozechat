import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../services/crypto_service.dart';

import 'room_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  
  bool _isRestoreMode = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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
  }

  void _loginOrRestore() async {
    final chatProvider = context.read<ChatProvider>();
    
    if (!_isRestoreMode) {
      final nickname = _nicknameController.text.trim();
      if (nickname.isEmpty) return;

      chatProvider.setNickname(nickname);
      
      final seedPhrase = CryptoService.generateSeedPhrase();
      await chatProvider.initializeSession(seedPhrase);

      if (chatProvider.errorMessage == null && mounted) {
        _showSeedPhraseDialog(seedPhrase);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.errorMessage ?? "Initialization failed"),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } else {
      final seedPhrase = _seedController.text.trim();
      if (seedPhrase.isEmpty) return;

      chatProvider.setNickname('Restored_Agent');
      
      await chatProvider.restoreIdentity(seedPhrase);

      if (chatProvider.errorMessage == null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoomScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.errorMessage ?? "Restore failed"),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  void _showSeedPhraseDialog(String seedPhrase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final themeProvider = context.watch<ThemeProvider>();
        final accentColor = themeProvider.accentColor;
        
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400),
              const SizedBox(width: 10),
              Text(
                'CRITICAL BACKUP',
                style: TextStyle(
                  color: Colors.orange.shade400,
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save this 12-word seed phrase securely. If you uninstall the app, this is the ONLY way to restore your identity and messages.',
                style: TextStyle(color: accentColor.withValues(alpha: 0.8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: SelectableText(
                  seedPhrase,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: seedPhrase));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPY TO CLIPBOARD'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RoomScreen()),
                );
              },
              child: Text(
                'I HAVE SAVED IT',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _seedController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      body: Stack(
        children: [
          // Animated background grid
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(accentColor),
            ),
          ),

          // Glowing accent overlay
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
                        accentColor.withValues(alpha: _pulseAnim.value * 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo / Header
                        Center(
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (context, child) {
                              return Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: _pulseAnim.value),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: _pulseAnim.value * 0.4),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.terminal,
                                  color: accentColor,
                                  size: 36,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'MOZECHAT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRestoreMode ? 'IDENTITY RECOVERY SYSTEM' : 'ANONYMOUS ENCRYPTED RELAY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 36),

                        if (!_isRestoreMode) ...[
                          // Nickname label
                          Row(
                            children: [
                              Icon(Icons.chevron_right, color: accentColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'AGENT ALIAS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: accentColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Nickname input
                          TextField(
                            controller: _nicknameController,
                            style: TextStyle(
                              fontSize: 18,
                              color: accentColor,
                              letterSpacing: 1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ghost_rider',
                              hintStyle: TextStyle(
                                color: accentColor.withValues(alpha: 0.25),
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: accentColor.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: accentColor,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: accentColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _loginOrRestore(),
                          ),
                        ] else ...[
                          // Seed phrase label
                          Row(
                            children: [
                              Icon(Icons.vpn_key_outlined, color: accentColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'RECOVERY KEY (12 WORDS)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: accentColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Seed phrase input
                          TextField(
                            controller: _seedController,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 14,
                              color: accentColor,
                              letterSpacing: 1,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'enter your secret twelve word backup phrase here separated by spaces',
                              hintStyle: TextStyle(
                                color: accentColor.withValues(alpha: 0.25),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: accentColor,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: accentColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 28),

                        // Login button
                        context.watch<ChatProvider>().isLoading
                            ? Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: accentColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: _loginOrRestore,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (context, child) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: accentColor.withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: accentColor.withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentColor.withValues(
                                                  alpha: _pulseAnim.value * 0.2),
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _isRestoreMode ? '[ RESTORE IDENTITY ]' : '[ INITIALIZE NEW NODE ]',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                              color: accentColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                        const SizedBox(height: 24),
                        
                        // Toggle mode
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isRestoreMode = !_isRestoreMode;
                              });
                            },
                            child: Text(
                              _isRestoreMode ? 'CANCEL RESTORE' : 'RESTORE EXISTING IDENTITY',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.6),
                                fontSize: 12,
                                letterSpacing: 1.5,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),

                        // Security badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: accentColor.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'E2E ENCRYPTED • ANONYMOUS',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 2,
                                color: accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Cyber grid background painter
class _CyberGridPainter extends CustomPainter {
  final Color accentColor;
  _CyberGridPainter(this.accentColor);

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

    // Random dot accents
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
