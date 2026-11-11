import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/proximity_service.dart';
import '../utils/app_strings.dart';

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
  StreamSubscription<bool>? _proximitySub;
  bool _isNear = false;
  bool _pipOnLeft = false;
  bool _pipOnBottom = false;

  @override
  void initState() {
    super.initState();
    // Video calls keep the screen on; only voice calls use the proximity sensor
    final isVideo = context.read<CallProvider>().isVideoCall;
    if (!isVideo) {
      ProximityService.enable();
    } else {
      ProximityService.disable();
      ProximityService.setKeepScreenOn(true);
    }
    _isNear = isVideo ? false : ProximityService.isNear;
    _proximitySub = ProximityService.proximityStream.listen((near) {
      final videoNow = _callProvider?.isVideoCall ?? false;
      final effectiveNear = videoNow ? false : near;
      if (mounted && _isNear != effectiveNear) {
        setState(() => _isNear = effectiveNear);
      }
    });
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

    if (_callProvider!.isVideoCall && _isNear) {
      setState(() => _isNear = false);
    }

    if (!_callProvider!.isInCall && !_callProvider!.isJoiningCall) {
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
    _proximitySub?.cancel();
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

    if (callProvider.isVideoCall) {
      return _buildVideoCallLayout(
        context: context,
        callProvider: callProvider,
        strings: strings,
        accentColor: accentColor,
        displayName: displayName,
        statusText: statusText,
        isConnected: isConnected,
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SafeArea(
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
      if (_isNear)
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black,
            ),
          ),
        ),
    ],
  ),
);
  }

  /// WhatsApp-style full-screen video call: remote video fills the screen,
  /// local camera is a small picture-in-picture, controls float at the bottom.
  Widget _buildVideoCallLayout({
    required BuildContext context,
    required CallProvider callProvider,
    required AppStrings strings,
    required Color accentColor,
    required String displayName,
    required String statusText,
    required bool isConnected,
  }) {
    final remote = callProvider.remoteStream;
    final bool remoteHasVideo =
        remote != null && remote.getVideoTracks().isNotEmpty;
    final bool showRemoteVideo =
        isConnected && remoteHasVideo && callProvider.isRemoteCameraOn;
    // While ringing/connecting show our own camera full-screen, like WhatsApp
    final bool showLocalFull = !isConnected && callProvider.isCameraOn;
    final topInset = MediaQuery.of(context).padding.top;

    Widget background;
    if (showRemoteVideo) {
      background = RTCVideoView(
        callProvider.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else if (showLocalFull) {
      background = Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(
            callProvider.localRenderer,
            mirror: callProvider.isFrontCamera,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
        ],
      );
    } else {
      background = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1014), Color(0xFF151E25)],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.18),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _extractInitials(displayName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isConnected && !callProvider.isRemoteCameraOn) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded,
                      size: 18, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    strings.peerCameraOff,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1014),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => context.read<CallProvider>().switchCamera(),
              child: background,
            ),
          ),

          // Top gradient + header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                      tooltip: strings.tapToReturnToCall,
                      onPressed: _minimizeCallScreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.75)),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Local camera picture-in-picture (draggable to any corner, tap to flip camera)
          if (isConnected)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: _pipOnBottom ? null : topInset + 72,
              bottom: _pipOnBottom
                  ? MediaQuery.of(context).padding.bottom + 128
                  : null,
              left: _pipOnLeft ? 14 : null,
              right: _pipOnLeft ? null : 14,
              child: GestureDetector(
                onTap: () => context.read<CallProvider>().switchCamera(),
                onPanUpdate: (details) {
                  final size = MediaQuery.of(context).size;
                  final newLeft = details.globalPosition.dx < size.width / 2;
                  final newBottom = details.globalPosition.dy > size.height * 0.48;
                  if (newLeft != _pipOnLeft || newBottom != _pipOnBottom) {
                    setState(() {
                      _pipOnLeft = newLeft;
                      _pipOnBottom = newBottom;
                    });
                  }
                },
                child: Container(
                  width: 108,
                  height: 152,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151E25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: callProvider.isCameraOn
                      ? RTCVideoView(
                          callProvider.localRenderer,
                          mirror: callProvider.isFrontCamera,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : const Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white54,
                            size: 28,
                          ),
                        ),
                ),
              ),
            ),

          // Bottom gradient + floating controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                18,
                36,
                18,
                MediaQuery.of(context).padding.bottom + 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF151E25).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlAction(
                      icon: callProvider.isSpeaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: callProvider.isSpeaker
                          ? strings.speakerLabel
                          : strings.earpieceLabel,
                      isActive: callProvider.isSpeaker,
                      activeColor: accentColor,
                      isDark: true,
                      onTap: () => context.read<CallProvider>().toggleSpeaker(),
                    ),
                    _buildControlAction(
                      icon: callProvider.isCameraOn
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      label: callProvider.isCameraOn
                          ? strings.cameraOnLabel
                          : strings.cameraOffLabel,
                      isActive: !callProvider.isCameraOn,
                      activeColor: Colors.orangeAccent,
                      isDark: true,
                      onTap: () => context.read<CallProvider>().toggleCamera(),
                    ),
                    _buildControlAction(
                      icon: Icons.flip_camera_android_rounded,
                      label: strings.flipCameraLabel,
                      isActive: false,
                      activeColor: accentColor,
                      isDark: true,
                      onTap: () => context.read<CallProvider>().switchCamera(),
                    ),
                    _buildControlAction(
                      icon: callProvider.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: callProvider.isMuted
                          ? strings.unmuteLabel
                          : strings.muteLabel,
                      isActive: callProvider.isMuted,
                      activeColor: Colors.orangeAccent,
                      isDark: true,
                      onTap: () => context.read<CallProvider>().toggleMute(),
                    ),
                    _buildControlAction(
                      icon: Icons.call_end_rounded,
                      label: strings.hangupLabel,
                      isActive: true,
                      activeColor: const Color(0xFFE53935),
                      isDark: true,
                      isDestructive: true,
                      onTap: () => context.read<CallProvider>().endCall(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
