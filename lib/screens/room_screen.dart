import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../services/crypto_service.dart';
import '../services/preferences_service.dart';
import '../widgets/cyber_grid.dart';

import 'chat_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/qr_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  List<String> _history = [];
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await PreferencesService.getRoomHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  void _createRoom() {
    final code = CryptoService.generateSecureRoomCode();
    _codeController.text = code;
    QRDialog.show(context, roomCode: code, roomTitle: 'YENİ GÜVENLİ ODA');
  }

  void _scanQR() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _codeController.text = scannedCode;
      _joinRoom(scannedCode);
    }
  }

  void _joinRoom(String code) async {
    if (code.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final success = await chatProvider.joinRoom(code);

    if (success && mounted) {
      chatProvider.clearError();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
      _loadHistory();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatProvider.errorMessage ?? "Failed to connect to node",
          ),
          backgroundColor: Colors.red.shade900,
        ),
      );
      chatProvider.clearError();
    }
  }

  void _showRoomOptions(String hCode) async {
    final chatProvider = context.read<ChatProvider>();
    final isCreator = await chatProvider.isCreator(hCode);
    if (!mounted) return;

    final themeProvider = context.read<ThemeProvider>();
    final accentColor = themeProvider.accentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 1),
                left: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 0.5),
                right: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.hub, color: accentColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hCode,
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'CREATOR',
                            style: TextStyle(color: accentColor, fontSize: 9, letterSpacing: 1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildOptionTile(
                  icon: Icons.login,
                  label: 'CONNECT TO NODE',
                  color: accentColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _joinRoom(hCode);
                  },
                ),
                if (isCreator)
                  _buildOptionTile(
                    icon: Icons.group_remove,
                    label: 'KICK ALL MEMBERS',
                    color: Colors.orange,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await chatProvider.kickMembers(hCode);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('All members kicked'),
                            backgroundColor: Colors.orange.shade900,
                          ),
                        );
                      }
                    },
                  ),
                _buildOptionTile(
                  icon: isCreator ? Icons.delete_forever : Icons.exit_to_app,
                  label: isCreator ? 'DESTROY NODE' : 'DISCONNECT NODE',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (isCreator) {
                      await chatProvider.destroyRoom(hCode);
                    } else {
                      await chatProvider.removeRoomLocal(hCode);
                    }
                    _loadHistory();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: accentColor),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          children: [
            Icon(Icons.hub, color: accentColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NODE ACCESS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    '> ${chatProvider.nickname ?? "UNKNOWN"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor.withValues(alpha: 0.5),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: accentColor.withValues(alpha: 0.6)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: accentColor.withValues(alpha: 0.6)),
            onPressed: () async {
              context.read<ChatProvider>().leaveRoom();
              await FirebaseAuth.instance.signOut();
              await PreferencesService.saveNickname(null);
              await PreferencesService.saveLastActiveRoom(null);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cyber Background
          CyberGrid(accentColor: accentColor),

          SafeArea(
            child: Column(
              children: [
                Divider(color: accentColor.withValues(alpha: 0.15), height: 1),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Create room button
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (context, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    splashColor: accentColor.withValues(alpha: 0.3),
                                    highlightColor: accentColor.withValues(alpha: 0.1),
                                    onTap: _createRoom,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: Colors.black.withValues(alpha: 0.5),
                                        border: Border.all(
                                          color: accentColor.withValues(alpha: _glowAnim.value),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withValues(alpha: _glowAnim.value * 0.15),
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_circle_outline, color: accentColor, size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            'INITIALIZE SECURE NODE',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                              color: accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: accentColor.withValues(alpha: 0.15))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'MANUAL OVERRIDE',
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.3),
                                  fontSize: 11,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: accentColor.withValues(alpha: 0.15))),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Join room input
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: TextField(
                                    controller: _codeController,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      letterSpacing: 2,
                                      color: accentColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'NODE ACCESS CODE',
                                      hintStyle: TextStyle(
                                        color: accentColor.withValues(alpha: 0.2),
                                        letterSpacing: 2,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(alpha: 0.6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: accentColor.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: accentColor),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.qr_code_scanner_rounded, color: accentColor),
                                        tooltip: 'QR Kod Tara',
                                        onPressed: _scanQR,
                                      ),
                                    ),
                                    onSubmitted: (val) => _joinRoom(val.trim().toUpperCase()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            chatProvider.isLoading
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: accentColor,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _joinRoom(
                                            _codeController.text.trim().toUpperCase(),
                                          ),
                                          splashColor: accentColor.withValues(alpha: 0.3),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: Colors.black.withValues(alpha: 0.5),
                                              border: Border.all(
                                                color: accentColor.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward,
                                              color: accentColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),

                        // Room History
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 36),
                          Row(
                            children: [
                              Icon(Icons.history, color: accentColor.withValues(alpha: 0.4), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'RECENT CONNECTIONS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  fontSize: 12,
                                  color: accentColor.withValues(alpha: 0.5),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_history.length}',
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_history.length, (index) {
                            final hCode = _history[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _codeController.text = hCode;
                                        _joinRoom(hCode);
                                      },
                                      onLongPress: () => _showRoomOptions(hCode),
                                      splashColor: accentColor.withValues(alpha: 0.2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.black.withValues(alpha: 0.5),
                                          border: Border.all(
                                            color: accentColor.withValues(alpha: 0.12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.dns_outlined,
                                              color: accentColor.withValues(alpha: 0.5),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                hCode,
                                                style: TextStyle(
                                                  color: accentColor.withValues(alpha: 0.8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  letterSpacing: 1,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: accentColor.withValues(alpha: 0.3),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Long-press for node override options',
                              style: TextStyle(
                                fontSize: 10,
                                color: accentColor.withValues(alpha: 0.2),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
