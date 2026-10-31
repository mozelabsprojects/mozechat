import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';
import '../providers/locale_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallProvider? _callProvider;
  bool _hasPopped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_callProvider == null) {
      _callProvider = context.read<CallProvider>();
      _callProvider!.addListener(_onCallStateChanged);
    }
  }

  void _onCallStateChanged() {
    if (!mounted || _hasPopped || _callProvider == null) return;

    if (!_callProvider!.isInCall) {
      _hasPopped = true;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _callProvider?.removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF159D87);
    final isConnected = callProvider.isCallConnected;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E12) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with minimize button (returns to chat while keeping call active)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 32,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    onPressed: () {
                      if (!_hasPopped && Navigator.of(context).canPop()) {
                        _hasPopped = true;
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.secureWebrtcConnection,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            // Avatar with subtle pulse ring
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: primaryColor.withValues(alpha: isConnected ? 0.35 : 0.15),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 56,
                backgroundColor: primaryColor.withValues(alpha: 0.18),
                child: Icon(
                  isConnected ? Icons.graphic_eq_rounded : Icons.person_rounded,
                  size: 54,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              callProvider.currentRoomCode ?? strings.voiceCallTitle,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isConnected
                    ? primaryColor.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isConnected
                    ? '${strings.inCallTitle} • ${callProvider.formattedDuration}'
                    : strings.callConnecting,
                style: TextStyle(
                  color: isConnected
                      ? primaryColor
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Hidden WebRTC audio renderer
            if (callProvider.remoteStream != null)
              SizedBox(
                width: 0,
                height: 0,
                child: RTCVideoView(callProvider.remoteRenderer),
              ),

            const Spacer(),

            // Bottom Controls Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131920) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  _buildControlButton(
                    icon: callProvider.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: callProvider.isMuted ? strings.unmuteMic : strings.muteMic,
                    color: callProvider.isMuted
                        ? Colors.orangeAccent
                        : (isDark ? Colors.white12 : Colors.grey[200]!),
                    iconColor: callProvider.isMuted
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    textColor: isDark ? Colors.white70 : Colors.black87,
                    onPressed: () {
                      context.read<CallProvider>().toggleMute();
                    },
                  ),

                  // End Call Button
                  _buildControlButton(
                    icon: Icons.call_end_rounded,
                    label: strings.endCallLabel,
                    color: Colors.redAccent,
                    iconColor: Colors.white,
                    textColor: Colors.redAccent,
                    size: 64,
                    onPressed: () {
                      context.read<CallProvider>().endCall();
                    },
                  ),

                  // Speaker Button
                  _buildControlButton(
                    icon: callProvider.isSpeaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: strings.speakerphone,
                    color: callProvider.isSpeaker
                        ? primaryColor
                        : (isDark ? Colors.white12 : Colors.grey[200]!),
                    iconColor: callProvider.isSpeaker
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    textColor: isDark ? Colors.white70 : Colors.black87,
                    onPressed: () {
                      context.read<CallProvider>().toggleSpeaker();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.48,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
