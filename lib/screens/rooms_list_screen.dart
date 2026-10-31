import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../models/room_model.dart';
import '../widgets/system_status_banner.dart';
import '../widgets/cyber_grid.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/cyber_hud.dart';
import '../services/crypto_service.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import '../providers/chat_provider.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'qr_scanner_screen.dart';
import 'panic_camouflage_screen.dart';

enum RoomFilterType { all, pinned, groups }

class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key});

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen> {
  RoomFilterType _filterType = RoomFilterType.all;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _pinnedCodes = {};
  final Map<String, String> _roomAliases = {};
  final Map<String, String> _roomIdToRealCode = {};
  bool _isNavigating = false;
  String? _navigatingRoomCode;

  Future<void> _handleRoomTap(String targetCode) async {
    if (_isNavigating) return;
    HapticFeedback.selectionClick();
    _isNavigating = true;

    final chatProvider = context.read<ChatProvider>();
    unawaited(chatProvider.joinRoom(targetCode));

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, anim, secondaryAnim) => const ChatScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        },
      ),
    );

    _isNavigating = false;
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadLocalSettings();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkUpdateOnStartup(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    final pinned = await PreferencesService.getPinnedRooms();
    final history = await PreferencesService.getRoomHistory();

    for (final code in history) {
      final rId = CryptoService.deriveRoomId(code);
      _roomIdToRealCode[rId] = code;
      _roomIdToRealCode[code] = code;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final userRooms = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('rooms')
            .get();
        for (final doc in userRooms.docs) {
          final code = doc.id;
          final rId = CryptoService.deriveRoomId(code);
          _roomIdToRealCode[rId] = code;
          _roomIdToRealCode[code] = code;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _pinnedCodes = pinned.toSet();
      });
    }
  }

  Future<void> _loadAliasForRoom(String code) async {
    if (_roomAliases.containsKey(code)) return;
    final alias = await PreferencesService.getRoomAlias(code);
    if (alias != null && mounted) {
      setState(() {
        _roomAliases[code] = alias;
      });
    }
  }

  void _openQRScanner() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _handleRoomTap(scannedCode);
    }
  }

  void _showNewRoomModal(Color accentColor) {
    final strings = context.read<LocaleProvider>().strings;
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF101216),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    strings.newRoomModalTitle,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strings.newRoomModalSubtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: TextField(
                  controller: codeCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: strings.roomCodeInputHint,
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.qr_code_scanner, color: accentColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openQRScanner();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: Text(
                        strings.generateSecureCode,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final newCode = CryptoService.generateSecureRoomCode();
                        codeCtrl.text = newCode;
                        CyberHUD.show(context, message: strings.roomCreatedToast);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final code = codeCtrl.text.trim();
                    if (code.isEmpty) {
                      CyberHUD.show(context, message: strings.enterCodeWarning, isError: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _handleRoomTap(code);
                  },
                  child: Text(
                    strings.joinRoom,
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQROptions(Color accentColor) {
    final strings = context.read<LocaleProvider>().strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: accentColor),
                ),
                title: Text(
                  strings.scanQrCodeTitle,
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                subtitle: Text(
                  strings.scanQrCodeSubtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openQRScanner();
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.qr_code_2_rounded, color: accentColor),
                ),
                title: Text(
                  strings.createNewRoomQrTitle,
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                subtitle: Text(
                  strings.createNewRoomQrSubtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final newCode = CryptoService.generateSecureRoomCode();
                  QRDialog.show(
                    context,
                    roomCode: newCode,
                    roomTitle: strings.newSecureRoomTitle,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomContextMenu(RoomModel room, String targetCode, Color accentColor) {
    HapticFeedback.mediumImpact();
    final strings = context.read<LocaleProvider>().strings;
    final isPinned = _pinnedCodes.contains(targetCode);
    final currentAlias = _roomAliases[targetCode] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: accentColor,
                ),
                title: Text(
                  isPinned ? strings.unpinChat : strings.pinChat,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await PreferencesService.togglePinRoom(targetCode);
                  await _loadLocalSettings();
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: accentColor),
                title: Text(
                  strings.setCustomAlias,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  currentAlias.isNotEmpty
                      ? '${strings.currentAliasPrefix}: $currentAlias'
                      : strings.aliasVisibleOnlyToYou,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetAliasDialog(targetCode, currentAlias, accentColor);
                },
              ),
              ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: accentColor),
                title: Text(
                  strings.showRoomQr,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  QRDialog.show(
                    context,
                    roomCode: targetCode,
                    roomTitle: currentAlias.isNotEmpty ? currentAlias : strings.roomQrCodeTitle,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: accentColor),
                title: Text(
                  strings.copyRoomCode,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: targetCode));
                  CyberHUD.show(
                    context,
                    message: strings.roomCodeCopied,
                    icon: Icons.copy_rounded,
                    accentColor: accentColor,
                  );
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text(
                  strings.deleteChat,
                  style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final chatProvider = context.read<ChatProvider>();
                  await chatProvider.removeRoomLocal(targetCode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetAliasDialog(String targetCode, String currentAlias, Color accentColor) {
    final strings = context.read<LocaleProvider>().strings;
    final controller = TextEditingController(text: currentAlias);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        ),
        title: Text(
          strings.customAliasDialogTitle,
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.customAliasDialogSubtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.customAliasHint,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newAlias = controller.text.trim();
              await PreferencesService.saveRoomAlias(targetCode, newAlias);
              if (mounted) {
                setState(() {
                  if (newAlias.isEmpty) {
                    _roomAliases.remove(targetCode);
                  } else {
                    _roomAliases[targetCode] = newAlias;
                  }
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(strings.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;
    final strings = context.watch<LocaleProvider>().strings;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(body: Center(child: Text(strings.notLoggedIn)));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          crossFadeState: _isSearching ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Row(
            children: [
              Icon(Icons.shield_outlined, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Text(
                strings.chats,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 16,
                  color: accentColor,
                ),
              ),
            ],
          ),
          secondChild: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: accentColor.withValues(alpha: 0.7), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: strings.searchPlaceholder,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 16),
                  ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, chatProv, child) {
              if (!chatProv.panicCamouflageEnabled) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.shield_outlined, color: Colors.orangeAccent),
                tooltip: strings.panicTooltip,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const PanicCamouflageScreen(),
                    ),
                  );
                },
              );
            },
          ),
          BouncyTap(
            onTap: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  key: ValueKey(_isSearching),
                  color: accentColor.withValues(alpha: 0.8),
                  size: 22,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: accentColor),
            tooltip: strings.qrCodeTooltip,
            onPressed: () => _showQROptions(accentColor),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: accentColor.withValues(alpha: 0.6)),
            color: Colors.black.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'settings') {
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }
              } else if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: accentColor, size: 18),
                    const SizedBox(width: 10),
                    Text(strings.settingsMenu, style: TextStyle(color: accentColor, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Text(strings.logoutMenu, style: TextStyle(color: Colors.red.shade400, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          CyberGrid(accentColor: accentColor),
          SafeArea(
            child: Column(
              children: [
                const SystemStatusBanner(),
                _buildFilterPills(accentColor),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rooms')
                        .where('members', arrayContains: currentUser.uid)
                        .orderBy('lastMessageTime', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('rooms')
                              .where('members', arrayContains: currentUser.uid)
                              .limit(50)
                              .snapshots(),
                          builder: (context, fallbackSnapshot) {
                            if (fallbackSnapshot.hasError) {
                              return _buildErrorState(fallbackSnapshot.error.toString(), accentColor);
                            }
                            if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                            }
                            final docs = fallbackSnapshot.data?.docs ?? [];
                            if (docs.isEmpty) return _buildEmptyState(accentColor);
                            return _buildRoomList(docs, currentUser, themeProvider, context);
                          },
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return _buildEmptyState(accentColor);
                      return _buildRoomList(docs, currentUser, themeProvider, context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: BouncyTap(
        onTap: () => _showNewRoomModal(accentColor),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: accentColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, Color accentColor) {
    final strings = context.watch<LocaleProvider>().strings;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              strings.networkDataError,
              style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills(Color accentColor) {
    final strings = context.watch<LocaleProvider>().strings;
    final filters = [
      {'type': RoomFilterType.all, 'label': strings.all, 'icon': null},
      {'type': RoomFilterType.pinned, 'label': strings.pinned, 'icon': Icons.push_pin_rounded},
      {'type': RoomFilterType.groups, 'label': strings.groups, 'icon': Icons.groups_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: filters.map((f) {
          final type = f['type'] as RoomFilterType;
          final isSelected = _filterType == type;
          final icon = f['icon'] as IconData?;
          final label = f['label'] as String;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: BouncyTap(
              onTap: () {
                setState(() {
                  _filterType = type;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.8)
                        : accentColor.withValues(alpha: 0.2),
                    width: isSelected ? 1.4 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 13,
                        color: isSelected ? accentColor : Colors.white60,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? accentColor : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(Color accentColor) {
    final strings = context.watch<LocaleProvider>().strings;
    final isFiltered = _filterType != RoomFilterType.all || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isFiltered ? Icons.search_off_rounded : Icons.shield_outlined,
                  size: 36,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered ? strings.noMatchingChats : strings.secureNetworkEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: accentColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered ? strings.noMatchingChatsSub : strings.secureNetworkEmptySub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (isFiltered)
              BouncyTap(
                onTap: () {
                  setState(() {
                    _filterType = RoomFilterType.all;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    strings.resetFilters,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              )
            else
              BouncyTap(
                onTap: () => _showNewRoomModal(accentColor),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        strings.createNewRoomBtn,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomList(
    List<QueryDocumentSnapshot> rawDocs,
    User currentUser,
    ThemeProvider themeProvider,
    BuildContext context,
  ) {
    final accentColor = themeProvider.accentColor;
    final strings = context.watch<LocaleProvider>().strings;

    final roomsWithDocs = rawDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final room = RoomModel.fromMap(data);

      String targetCode = (data['roomCode'] as String?) ?? room.roomCode;
      if (targetCode.isEmpty || targetCode == doc.id) {
        if (_roomIdToRealCode.containsKey(doc.id)) {
          targetCode = _roomIdToRealCode[doc.id]!;
          doc.reference.update({'roomCode': targetCode}).catchError((_) {});
        } else {
          targetCode = room.roomCode.isNotEmpty ? room.roomCode : doc.id;
        }
      } else {
        final rId = CryptoService.deriveRoomId(targetCode);
        _roomIdToRealCode[rId] = targetCode;
        _roomIdToRealCode[doc.id] = targetCode;
      }

      _loadAliasForRoom(targetCode);
      return {'doc': doc, 'room': room, 'code': targetCode};
    }).toList();

    final filtered = roomsWithDocs.where((item) {
      final code = item['code'] as String;
      final room = item['room'] as RoomModel;

      if (_filterType == RoomFilterType.pinned && !_pinnedCodes.contains(code)) {
        return false;
      }
      if (_filterType == RoomFilterType.groups && room.members.length <= 2) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;
      final alias = _roomAliases[code]?.toLowerCase() ?? '';
      final roomName = room.roomName.toLowerCase();
      final lastMsg = (room.lastMessage ?? '').toLowerCase();
      final cLower = code.toLowerCase();

      return cLower.contains(_searchQuery) ||
          alias.contains(_searchQuery) ||
          roomName.contains(_searchQuery) ||
          lastMsg.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final aCode = a['code'] as String;
      final bCode = b['code'] as String;
      final aPinned = _pinnedCodes.contains(aCode);
      final bPinned = _pinnedCodes.contains(bCode);

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aRoom = a['room'] as RoomModel;
      final bRoom = b['room'] as RoomModel;
      final aTime = aRoom.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = bRoom.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (filtered.isEmpty) {
      return _buildEmptyState(accentColor);
    }

    String formatLastMessage(String? msg) {
      if (msg == null || msg.trim().isEmpty) return strings.chatStarted;
      final trimmed = msg.trim();
      final lower = trimmed.toLowerCase();
      if (lower == 'oda oluşturuldu' || lower == 'room created') {
        return strings.roomCreatedPreview;
      }
      if (trimmed.startsWith('📞')) {
        if (lower.contains('sonlandırıldı') || lower.contains('ended')) {
          final dur = RegExp(r'(\d{2}:\d{2})').firstMatch(trimmed)?.group(1);
          if (dur != null) return strings.callEndedMsg(dur);
        }
        return strings.callStartedMsg;
      }
      if (lower.contains('[audio]') || lower.contains('.m4a') || lower.contains('.mp3') || lower.contains('voice_')) {
        return strings.voiceMessagePreview;
      }
      if (lower.contains('[media_group]')) {
        return strings.mediaAlbumPreview;
      }
      if (lower.contains('[image]') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp')) {
        return strings.photoPreview;
      }
      if (lower.contains('[video]') || lower.contains('.mp4') || lower.contains('.mov')) {
        return strings.videoPreview;
      }
      if (lower.contains('[location]') || lower.contains('signal') || lower.contains('konum')) {
        return strings.locationPreview;
      }
      return msg;
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: accentColor,
      backgroundColor: Colors.black87,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          final doc = item['doc'] as QueryDocumentSnapshot;
          final room = item['room'] as RoomModel;
          final targetCode = item['code'] as String;
          final isPinned = _pinnedCodes.contains(targetCode);
          final alias = _roomAliases[targetCode];

          String timeString = '';
          if (room.lastMessageTime != null) {
            final now = DateTime.now();
            final msgDate = room.lastMessageTime!;
            if (now.difference(msgDate).inDays == 0) {
              timeString = DateFormat('HH:mm').format(msgDate);
            } else if (now.difference(msgDate).inDays < 7) {
              timeString = DateFormat('EEE').format(msgDate);
            } else {
              timeString = DateFormat('dd/MM').format(msgDate);
            }
          }

          final displayName = alias != null && alias.isNotEmpty
              ? alias
              : (room.roomName.isNotEmpty
                  ? room.roomName
                  : (targetCode.length > 14 ? '${targetCode.substring(0, 14)}...' : targetCode));

          final String avatarInitial = displayName.isNotEmpty
              ? displayName.trim()[0].toUpperCase()
              : '#';
          final isCurrentNavigating = _isNavigating && _navigatingRoomCode == targetCode;

          return Dismissible(
            key: Key(doc.id),
            direction: DismissDirection.horizontal,
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.8),
                    accentColor.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPinned ? strings.unpinSwipe : strings.pinSwipe,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade800.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    strings.deleteChatSwipe,
                    style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                HapticFeedback.mediumImpact();
                await PreferencesService.togglePinRoom(targetCode);
                await _loadLocalSettings();
                return false;
              } else {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.black.withValues(alpha: 0.95),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                        ),
                        title: Text(strings.deleteChatConfirmTitle, style: TextStyle(color: accentColor, letterSpacing: 2, fontSize: 16)),
                        content: Text(
                          strings.deleteChatConfirmBody,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(strings.cancel, style: TextStyle(color: accentColor.withValues(alpha: 0.5))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(strings.delete, style: TextStyle(color: Colors.red.shade400)),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              }
            },
            onDismissed: (_) async {
              final chatProvider = context.read<ChatProvider>();
              await chatProvider.removeRoomLocal(targetCode);
            },
            child: BouncyTap(
              scaleFactor: 0.98,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: isPinned
                      ? accentColor.withValues(alpha: 0.1)
                      : const Color(0xFF0C0C0C).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPinned
                        ? accentColor.withValues(alpha: 0.5)
                        : accentColor.withValues(alpha: 0.15),
                    width: isPinned ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPinned ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: accentColor.withValues(alpha: 0.15),
                      highlightColor: accentColor.withValues(alpha: 0.08),
                      onTap: () => _handleRoomTap(targetCode),
                      onLongPress: () => _showRoomContextMenu(room, targetCode, accentColor),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: accentColor.withValues(alpha: isPinned ? 0.16 : 0.08),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: isPinned ? 0.6 : 0.25),
                                      width: isPinned ? 1.4 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      avatarInitial,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Courier',
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: Icon(
                                      room.isGroup ? Icons.group_rounded : Icons.lock_outline_rounded,
                                      color: accentColor.withValues(alpha: 0.8),
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isPinned) ...[
                                        Icon(Icons.push_pin_rounded, color: accentColor, size: 14),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isPinned ? Colors.white : accentColor.withValues(alpha: 0.9),
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    formatLastMessage(room.lastMessage),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    color: accentColor.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (isCurrentNavigating)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accentColor,
                                    ),
                                  )
                                else if (isPinned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      strings.pinnedBadge,
                                      style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 12,
                                        color: accentColor.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${room.members.length}',
                                        style: TextStyle(
                                          color: accentColor.withValues(alpha: 0.3),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
            ),
          );
        },
      ),
    );
  }
}
