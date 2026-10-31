import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  CallProvider? _callProvider;
  bool _hasPopped = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_callProvider == null) {
      _callProvider = context.read<CallProvider>();
      _callProvider!.setCallScreenOpen(true);
      _callProvider!.addListener(_onCallStateChanged);
    }
  }

  void _onCallStateChanged() {
    if (!mounted || _hasPopped || _callProvider == null) return;

    if (!_callProvider!.isInCall) {
      _hasPopped = true;
      _callProvider!.setCallScreenOpen(false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _minimizeCallScreen() {
    if (!_hasPopped && Navigator.of(context).canPop()) {
      _hasPopped = true;
      _callProvider?.setCallScreenOpen(false);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callProvider?.setCallScreenOpen(false);
    _callProvider?.removeListener(_onCallStateChanged);
    super.dispose();
  }

  String _extractInitials(String title) {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return 'M';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // WhatsApp-inspired emerald/cyber accent tailored to user's selected theme
    final rawAccent = themeProvider.accentColor;
    final accentColor = rawAccent == const Color(0xFF000000)
        ? const Color(0xFF159D87)
        : rawAccent;

    final isConnected = callProvider.isCallConnected;
    final displayName =
        callProvider.peerDisplayName ??
        callProvider.currentRoomCode ??
        strings.voiceCallTitle;

    final statusText = isConnected
        ? callProvider.formattedDuration
        : (callProvider.isCaller
              ? strings.callingStatus
              : strings.connectingCall);

    final bgColor = isDark ? const Color(0xFF0B1014) : const Color(0xFFF2F5F8);
    final cardColor = isDark ? const Color(0xFF151E25) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111B21);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF54656F);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. WhatsApp-style Top Bar (Minimize button + E2E Encryption Pill)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        color: primaryTextColor,
                      ),
                      tooltip: strings.tapToReturnToCall,
                      onPressed: _minimizeCallScreen,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                strings.secureWebrtcConnection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : const Color(0xFF111B21),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. WhatsApp-style Peer Name & Call Status / Timer at the Top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF25D366).withValues(alpha: 0.14)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected
                                ? const Color(0xFF25D366)
                                : accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: isConnected
                                ? const Color(0xFF25D366)
                                : secondaryTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 3. Lightweight Animated Avatar Ring (Center)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = themeProvider.animationsEnabled
                    ? _pulseController.value
                    : 0.5;
                final outerScale = 1.0 + (pulse * 0.12);
                final middleScale = 1.0 + (pulse * 0.06);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: outerScale,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(
                            alpha: isConnected ? 0.07 : 0.04,
                          ),
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isConnected ? 0.22 : 0.12,
                            ),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: middleScale,
                      child: Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(
                            alpha: isConnected ? 0.12 : 0.08,
                          ),
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isConnected ? 0.35 : 0.20,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    child!,
                  ],
                );
              },
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.30),
                      accentColor.withValues(alpha: 0.14),
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.65),
                    width: 2.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _extractInitials(displayName),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 4),
                      Icon(
                        callProvider.isMuted
                            ? Icons.mic_off_rounded
                            : Icons.graphic_eq_rounded,
                        size: 20,
                        color: callProvider.isMuted
                            ? Colors.orangeAccent
                            : const Color(0xFF25D366),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Hidden WebRTC audio renderer to ensure audio playback across platforms
            if (callProvider.remoteStream != null)
              SizedBox(
                width: 0,
                height: 0,
                child: RTCVideoView(callProvider.remoteRenderer),
              ),

            const Spacer(),

            // 4. WhatsApp-style Floating Pill Control Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Speaker Button
                    _buildControlAction(
                      icon: callProvider.isSpeaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: callProvider.isSpeaker
                          ? strings.speakerLabel
                          : strings.earpieceLabel,
                      isActive: callProvider.isSpeaker,
                      activeColor: accentColor,
                      isDark: isDark,
                      onTap: () => context.read<CallProvider>().toggleSpeaker(),
                    ),

                    // Return to Chat Button
                    _buildControlAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: strings.chats,
                      isActive: false,
                      activeColor: accentColor,
                      isDark: isDark,
                      onTap: _minimizeCallScreen,
                    ),

                    // Mute Mic Button
                    _buildControlAction(
                      icon: callProvider.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: callProvider.isMuted
                          ? strings.unmuteLabel
                          : strings.muteLabel,
                      isActive: callProvider.isMuted,
                      activeColor: Colors.orangeAccent,
                      isDark: isDark,
                      onTap: () => context.read<CallProvider>().toggleMute(),
                    ),

                    // End Call (Hangup) Button
                    _buildControlAction(
                      icon: Icons.call_end_rounded,
                      label: strings.hangupLabel,
                      isActive: true,
                      activeColor: const Color(0xFFE53935),
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () => context.read<CallProvider>().endCall(),
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

  Widget _buildControlAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final bg = isDestructive
        ? const Color(0xFFE53935)
        : (isActive
              ? activeColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.06)));

    final fg = (isDestructive || isActive)
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF111B21));

    final labelColor = isDestructive
        ? const Color(0xFFE53935)
        : (isDark
              ? Colors.white.withValues(alpha: 0.78)
              : const Color(0xFF54656F));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
