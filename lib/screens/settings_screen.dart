import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/locale_provider.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import '../services/audio_service.dart';
import '../services/cache_service.dart';
import '../widgets/cyber_grid.dart';
import '../widgets/cyber_hud.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingUpdate = false;
  bool _isClearingCache = false;
  String _cacheSize = 'Hesaplanıyor...';
  bool _outgoingSound = true;
  bool _incomingSound = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await CacheService.getFormattedCacheSize();
    if (mounted) {
      setState(() => _cacheSize = size);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await CacheService.clearAllCache();
    await _refreshCacheSize();
    if (mounted) {
      setState(() => _isClearingCache = false);
      final accent = context.read<ThemeProvider>().accentColor;
      CyberHUD.show(
        context,
        message: '[OK] MEDYA ÖNBELLEĞİ TEMİZLENDİ',
        icon: Icons.cleaning_services_outlined,
        accentColor: accent,
      );
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    await UpdateService().checkForUpdate(showToastIfUpToDate: true, context: context);
    if (mounted) setState(() => _isCheckingUpdate = false);
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final prefNick = await PreferencesService.getNickname();
      if (prefNick != null && prefNick.isNotEmpty) {
        _nameController.text = prefNick;
      } else {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['nickname'] ?? data['displayName'] ?? '';
        }
      }
      final outS = await PreferencesService.getOutgoingSoundEnabled();
      final inS = await PreferencesService.getIncomingSoundEnabled();
      if (mounted) {
        setState(() {
          _outgoingSound = outS;
          _incomingSound = inS;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newAlias = _nameController.text.trim();
    if (newAlias.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await PreferencesService.saveNickname(newAlias);
      if (mounted) {
        context.read<ChatProvider>().setNickname(newAlias);
      }
      await _firestore.collection('users').doc(user.uid).set({
        'nickname': newAlias,
        'displayName': newAlias,
      }, SetOptions(merge: true));

      if (!mounted) return;
      final accent = context.read<ThemeProvider>().accentColor;
      CyberHUD.show(
        context,
        message: '[OK] ALIAS GÜNCELLENDİ',
        icon: Icons.check_circle_outline,
        accentColor: accent,
      );
    } catch (e) {
      if (!mounted) return;
      CyberHUD.show(
        context,
        message: '[HATA] $e',
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;
    final localeProvider = context.watch<LocaleProvider>();
    final strings = localeProvider.strings;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.settings_outlined, color: accentColor, size: 20),
            const SizedBox(width: 10),
            Text(
              strings.settingsTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 16,
                color: accentColor,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          CyberGrid(accentColor: accentColor),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display name section
                        Row(
                          children: [
                            Icon(Icons.chevron_right, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'AGENT ALIAS',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: TextField(
                              controller: _nameController,
                              style: TextStyle(
                                fontSize: 16, 
                                color: accentColor,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.terminal, color: accentColor.withValues(alpha: 0.4)),
                                hintText: 'Enter alias...',
                                hintStyle: TextStyle(color: accentColor.withValues(alpha: 0.2)),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: accentColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // UID display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'UID: ${_auth.currentUser?.uid ?? "—"}',
                            style: TextStyle(
                              fontSize: 10,
                              color: accentColor.withValues(alpha: 0.3),
                              letterSpacing: 1,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Privacy & Stealth Section
                        Row(
                          children: [
                            Icon(Icons.security, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'PRIVACY & STEALTH CONFIG',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Consumer<ChatProvider>(
                                builder: (context, chatProvider, _) {
                                  return Column(
                                    children: [
                                      // Robotic Anonymous Voice
                                      SwitchListTile(
                                        title: Text(
                                          strings.anonymousVoiceTitle,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          strings.anonymousVoiceSubtitle,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                        value: chatProvider.isAnonymousVoice,
                                        activeThumbColor: accentColor,
                                        inactiveTrackColor: Colors.black45,
                                        onChanged: (value) {
                                          chatProvider.toggleAnonymousVoice(value);
                                        },
                                      ),
                                      Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
                                      // Tap to reveal
                                      SwitchListTile(
                                        title: Text(
                                          strings.tapToRevealTitle,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          strings.tapToRevealSubtitle,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                        value: chatProvider.tapToRevealEnabled,
                                        activeThumbColor: accentColor,
                                        inactiveTrackColor: Colors.black45,
                                        onChanged: (value) {
                                          chatProvider.toggleTapToReveal(value);
                                          if (value && mounted) {
                                            CyberHUD.show(
                                              context,
                                              message: strings.tapToRevealActiveToast,
                                            );
                                          }
                                        },
                                      ),
                                      Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
                                      // Panic camouflage
                                      SwitchListTile(
                                        title: Text(
                                          strings.panicTitle,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          strings.panicSubtitle,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                        value: chatProvider.panicCamouflageEnabled,
                                        activeThumbColor: accentColor,
                                        inactiveTrackColor: Colors.black45,
                                        onChanged: (value) {
                                          chatProvider.togglePanicCamouflage(value);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Language Section
                        Row(
                          children: [
                            Icon(Icons.language_rounded, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              strings.languageSection,
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localeProvider.isTurkish ? 'Mevcut Dil: Türkçe 🇹🇷' : 'Current Language: English 🇺🇸',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => localeProvider.setLanguage('tr'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: localeProvider.isTurkish ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'TR 🇹🇷',
                                          style: TextStyle(
                                            color: localeProvider.isTurkish ? accentColor : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => localeProvider.setLanguage('en'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !localeProvider.isTurkish ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'EN 🇺🇸',
                                          style: TextStyle(
                                            color: !localeProvider.isTurkish ? accentColor : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Eco Mode section
                        Row(
                          children: [
                            Icon(Icons.battery_charging_full, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'PERFORMANCE & BATTERY',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: SwitchListTile(
                                title: Text(
                                  'ECO MODE',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Disables animations and physics engine to save battery.',
                                  style: TextStyle(
                                    color: accentColor.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                                value: !themeProvider.animationsEnabled,
                                activeThumbColor: accentColor,
                                inactiveTrackColor: Colors.black45,
                                onChanged: (value) {
                                  themeProvider.setAnimationsEnabled(!value);
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Audio & Sound FX
                        Row(
                          children: [
                            Icon(Icons.volume_up_outlined, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'AUDIO & SOUND FX',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: Text(
                                      'GİDEN MESAJ SESİ',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Mesaj gönderildiğinde bildirim sesi çalar.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    value: _outgoingSound,
                                    activeThumbColor: accentColor,
                                    inactiveTrackColor: Colors.black45,
                                    onChanged: (value) async {
                                      setState(() => _outgoingSound = value);
                                      await PreferencesService.saveOutgoingSoundEnabled(value);
                                      AudioService().updateCachedSettings(outgoing: value);
                                    },
                                  ),
                                  Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
                                  SwitchListTile(
                                    title: Text(
                                      'GELEN MESAJ SESİ',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Yeni mesaj alındığında bildirim sesi çalar.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    value: _incomingSound,
                                    activeThumbColor: accentColor,
                                    inactiveTrackColor: Colors.black45,
                                    onChanged: (value) async {
                                      setState(() => _incomingSound = value);
                                      await PreferencesService.saveIncomingSoundEnabled(value);
                                      AudioService().updateCachedSettings(incoming: value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Theme section
                        Row(
                          children: [
                            Icon(Icons.chevron_right, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'INTERFACE THEME',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AppThemeMode.values.map((mode) {
                            final isActive = themeProvider.currentMode == mode;
                            return GestureDetector(
                              onTap: () => themeProvider.setTheme(mode),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isActive
                                      ? accentColor.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.5),
                                  border: Border.all(
                                    color: isActive
                                        ? accentColor.withValues(alpha: 0.8)
                                        : accentColor.withValues(alpha: 0.2),
                                    width: isActive ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isActive ? [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ] : [],
                                ),
                                child: Text(
                                  mode.name.toUpperCase(),
                                  style: TextStyle(
                                    color: isActive
                                        ? accentColor
                                        : accentColor.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 32),

                        // System Update Section
                        Text(
                          'SYSTEM OTA UPDATES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_sync_outlined, color: accentColor, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GitHub In-App OTA',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Otomatik APK & Sürüm Denetimi',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isCheckingUpdate
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor,
                                      ),
                                    )
                                  : OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: accentColor,
                                        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _checkUpdate,
                                      child: const Text(
                                        'DENETLE',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Media Cache & Storage Section
                        Text(
                          'DATA & STORAGE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cleaning_services_outlined, color: accentColor, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Medya & Geçici Önbellek',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ses, resim ve video kalıntıları: $_cacheSize',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isClearingCache
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor,
                                      ),
                                    )
                                  : OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade400,
                                        side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _clearCache,
                                      child: const Text(
                                        'TEMİZLE',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Save button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _updateProfile,
                                splashColor: accentColor.withValues(alpha: 0.3),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.5),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '[ SAVE CONFIGURATION ]',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Version & mozelabs.com branding
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'MOZECHAT v0.1.0',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: accentColor.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Developed with precision by mozelabs.com',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
