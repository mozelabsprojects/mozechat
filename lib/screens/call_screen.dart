import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  @override
  void initState() {
    super.initState();
    _initRenderers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CallProvider>().addListener(_onCallStateChanged);
      }
    });
  }

  bool _hasPopped = false;

  void _onCallStateChanged() {
    if (!mounted || _hasPopped) return;
    
    final provider = context.read<CallProvider>();
    if (!provider.isInCall) {
      _hasPopped = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    context.read<CallProvider>().removeListener(_onCallStateChanged);
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.greenAccent : Colors.teal;

    if (callProvider.remoteStream != null && _remoteRenderer.srcObject != callProvider.remoteStream) {
      _remoteRenderer.srcObject = callProvider.remoteStream;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: primaryColor.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 60,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              callProvider.remoteStream != null ? 'In Call' : 'Connecting...',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure WebRTC Connection',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
            
            // Audio renderer (hidden, just for playing sound)
            if (callProvider.remoteStream != null)
              SizedBox(
                width: 0,
                height: 0,
                child: RTCVideoView(_remoteRenderer),
              ),
              
            const Spacer(),
            
            // Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  _buildControlButton(
                    icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                    color: callProvider.isMuted ? Colors.redAccent : (isDark ? Colors.white24 : Colors.grey[300]!),
                    iconColor: callProvider.isMuted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      context.read<CallProvider>().toggleMute();
                    },
                  ),
                  
                  // End Call Button
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.redAccent,
                    iconColor: Colors.white,
                    size: 64,
                    onPressed: () {
                      context.read<CallProvider>().endCall();
                      // the listener will pop the route
                    },
                  ),
                  
                  // Speaker Button (Placeholder for now)
                  _buildControlButton(
                    icon: Icons.volume_up,
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                    iconColor: isDark ? Colors.white : Colors.black87,
                    onPressed: () {
                      // Toggle speaker
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
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}
