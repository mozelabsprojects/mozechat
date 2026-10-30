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
import 'login_screen.dart';
import 'chat_screen.dart';
import 'room_screen.dart';
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
  bool _isNavigating = false;
  String? _navigatingRoomCode;

  Future<void> _handleRoomTap(String targetCode) async {
    if (_isNavigating) return;
    HapticFeedback.selectionClick();
    _isNavigating = true;

    final chatProvider = context.read<ChatProvider>();
    // Start joining asynchronously in background (zero freeze)
    unawaited(chatProvider.joinRoom(targetCode));

    // Instant, fluid slide-fade transition
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
      final chatProvider = context.read<ChatProvider>();
      final success = await chatProvider.joinRoom(scannedCode);
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.errorMessage ?? "Odaya katılınamadı."),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  void _showQROptions(Color accentColor) {
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
                  'QR KOD TARA',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                subtitle: const Text(
                  'Kamerayı açarak arkadaşınızın QR kodunu okutun',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
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
                  'YENİ ODA QR\'I OLUŞTUR',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                subtitle: const Text(
                  'Arkadaşınızın taraması için yeni bir oda kodu ve QR oluşturun',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final newCode = CryptoService.generateSecureRoomCode();
                  QRDialog.show(
                    context,
                    roomCode: newCode,
                    roomTitle: 'YENİ GÜVENLİ ODA',
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
              // Pin/Unpin
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: accentColor,
                ),
                title: Text(
                  isPinned ? 'Sohbet Sabitlemesini Kaldır' : 'Sohbeti Başa Sabitle',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await PreferencesService.togglePinRoom(targetCode);
                  await _loadLocalSettings();
                },
              ),
              // Set Custom Alias
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: accentColor),
                title: const Text(
                  'Özel İsim / Takma Ad Ver',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  currentAlias.isNotEmpty ? 'Mevcut: $currentAlias' : 'Yalnızca sizin cihazınızda görünür',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetAliasDialog(targetCode, currentAlias, accentColor);
                },
              ),
              // Show QR
              ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: accentColor),
                title: const Text(
                  'Oda QR Kodunu Göster',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  QRDialog.show(
                    context,
                    roomCode: targetCode,
                    roomTitle: currentAlias.isNotEmpty ? currentAlias : 'ODA QR KODU',
                  );
                },
              ),
              // Copy Code
              ListTile(
                leading: Icon(Icons.copy_rounded, color: accentColor),
                title: const Text(
                  'Oda Kodunu Kopyala',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: targetCode));
                  CyberHUD.show(
                    context,
                    message: 'ODA KODU PANOYA KOPYALANDI',
                    icon: Icons.copy_rounded,
                    accentColor: accentColor,
                  );
                },
              ),
              const Divider(color: Colors.white12),
              // Delete Room
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text(
                  'Sohbeti Sil',
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
          'ÖZEL İSİM / ALIAS',
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu isim yalnızca sizin telefonunuzda saklanır, uçtan uca şifrelemeyi etkilemez.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Örn: Ahmet, Zeynep, Ofis Grubu...',
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
            child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
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
            child: const Text('KAYDET', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
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
                'SOHBETLER',
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
                      hintText: 'Sohbet veya kod ara...',
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
          // Panic Camouflage Button (if enabled)
          Consumer<ChatProvider>(
            builder: (context, chatProv, child) {
              if (!chatProv.panicCamouflageEnabled) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.shield_outlined, color: Colors.orangeAccent),
                tooltip: 'Panik / Acil Kamuflaj',
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
          // Search button
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
          // QR Code Button
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: accentColor),
            tooltip: 'QR Kod',
            onPressed: () => _showQROptions(accentColor),
          ),
          // More Menu
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
                    Text('AYARLAR', style: TextStyle(color: accentColor, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Text('ÇIKIŞ YAP', style: TextStyle(color: Colors.red.shade400, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
            ],
          )
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
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 240),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (context, anim, secondaryAnim) => const RoomScreen(),
              transitionsBuilder: (context, anim, secondaryAnim, child) {
                final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.06, 0.0), end: Offset.zero).animate(curved),
                  child: FadeTransition(opacity: curved, child: child),
                );
              },
            ),
          );
        },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'AĞ VERİSİ ALINAMADI',
              style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills(Color accentColor) {
    final filters = [
      {'type': RoomFilterType.all, 'label': 'TÜMÜ', 'icon': null},
      {'type': RoomFilterType.pinned, 'label': 'SABİTLER', 'icon': Icons.push_pin_rounded},
      {'type': RoomFilterType.groups, 'label': 'GRUPLAR', 'icon': Icons.groups_rounded},
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
              isFiltered ? 'EŞLEŞEN SOHBET BULUNAMADI' : '// GÜVENLİ İLETİŞİM AĞI //',
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
              isFiltered
                  ? 'Filtrelemeyi sıfırlamak için arama veya filtre kapsüllerine dokunun'
                  : 'Aktif bir şifreli oda bulunmuyor. Yeni bir düğüm (node) oluşturun veya QR ile bağlanın.',
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
                    'FİLTRELERİ SIFIRLA',
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomScreen()),
                  );
                },
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
                        'YENİ ODA OLUŞTUR',
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

  Widget _buildRoomList(List<QueryDocumentSnapshot> rawDocs, User currentUser, ThemeProvider themeProvider, BuildContext context) {
    final accentColor = themeProvider.accentColor;

    // 1. Map to RoomModel and load aliases asynchronously
    final roomsWithDocs = rawDocs.map((doc) {
      final room = RoomModel.fromMap(doc.data() as Map<String, dynamic>);
      final targetCode = room.roomCode.isNotEmpty ? room.roomCode : room.roomId;
      _loadAliasForRoom(targetCode);
      return {'doc': doc, 'room': room, 'code': targetCode};
    }).toList();

    // 2. Filter by search query and filter pills if active
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

    // 3. Sort: Pinned first, then by lastMessageTime descending
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
      if (msg == null || msg.trim().isEmpty) return 'Sohbet başlatıldı';
      final lower = msg.toLowerCase();
      if (lower.contains('[audio]') || lower.contains('.m4a') || lower.contains('.mp3') || lower.contains('voice_')) {
        return '🎤 Sesli mesaj';
      }
      if (lower.contains('[image]') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp')) {
        return '📷 Fotoğraf';
      }
      if (lower.contains('[video]') || lower.contains('.mp4') || lower.contains('.mov')) {
        return '🎥 Video';
      }
      if (lower.contains('[location]') || lower.contains('signal') || lower.contains('konum')) {
        return '📍 Konum paylaşıldı';
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
          // Right swipe: Pin / Unpin
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
                  isPinned ? 'SABİTİ KALDIR' : 'BAŞA SABİTLE',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          // Left swipe: Delete
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
                  'SOHBETİ SİL',
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
              return false; // Do not dismiss from list, just update pin status
            } else {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.black.withValues(alpha: 0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  title: Text('SOHBETİ SİL?', style: TextStyle(color: accentColor, letterSpacing: 2, fontSize: 16)),
                  content: const Text(
                    'Bu sohbeti aktif sohbetlerinizden kaldırmak istiyor musunuz?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('İPTAL', style: TextStyle(color: accentColor.withValues(alpha: 0.5))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('SİL', style: TextStyle(color: Colors.red.shade400)),
                    ),
                  ],
                ),
              ) ?? false;
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
                          // Minimalist Stealth Room Avatar
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
                                    'SABİT',
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
