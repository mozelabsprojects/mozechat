import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../services/crypto_service.dart';

import 'rooms_list_screen.dart';

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
    final strings = context.read<LocaleProvider>().strings;

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
            content: Text(chatProvider.errorMessage ?? strings.initFailed),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } else {
      final seedPhrase = _seedController.text.trim();
      if (seedPhrase.isEmpty) return;

      final nickname = _nicknameController.text.trim();
      if (nickname.isEmpty) return;

      chatProvider.setNickname(nickname);

      await chatProvider.restoreIdentity(seedPhrase);

      if (chatProvider.errorMessage == null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoomsListScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.errorMessage ?? strings.restoreFailed),
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
        final strings = context.watch<LocaleProvider>().strings;
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
              Expanded(
                child: Text(
                  strings.criticalBackup,
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontSize: 15,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.criticalBackupDesc,
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
                    SnackBar(content: Text(strings.copiedToClipboard)),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(strings.copyToClipboard),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RoomsListScreen()),
                );
              },
              child: Text(
                strings.iHaveSavedIt,
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
    final strings = context.watch<LocaleProvider>().strings;
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(accentColor),
            ),
          ),
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
                        Consumer<LocaleProvider>(
                          builder: (context, localeProv, _) {
                            return Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                onTap: () {
                                  localeProv.setLanguage(localeProv.isTurkish ? 'en' : 'tr');
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language, color: accentColor, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        localeProv.isTurkish ? 'TR 🇹🇷' : 'EN 🇺🇸',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
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
                          _isRestoreMode ? strings.identityRecoverySystem : strings.anonymousEncryptedRelay,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Icon(Icons.chevron_right, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              strings.agentAlias,
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
                        if (_isRestoreMode) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.vpn_key_outlined, color: accentColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                strings.recoveryKeyLabel,
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
                              hintText: strings.recoveryKeyHint,
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
                                            _isRestoreMode ? strings.restoreIdentityBtn : strings.initNewNode,
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
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isRestoreMode = !_isRestoreMode;
                              });
                            },
                            child: Text(
                              _isRestoreMode ? strings.cancelRestore : strings.restoreExistingIdentity,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: accentColor.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              strings.e2eBadge,
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
