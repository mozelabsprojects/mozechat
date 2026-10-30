import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../services/media_service.dart';
import '../services/location_service.dart';
import '../services/audio_cache_service.dart';
import '../models/message.dart';
import '../screens/media_preview_screen.dart';
import 'bouncy_tap.dart';
import 'cyber_hud.dart';

class ChatBottomInputBar extends StatefulWidget {
  final Function(String) onEasterEggTriggered;

  const ChatBottomInputBar({
    super.key,
    required this.onEasterEggTriggered,
  });

  @override
  State<ChatBottomInputBar> createState() => _ChatBottomInputBarState();
}

class _ChatBottomInputBarState extends State<ChatBottomInputBar> {
  final TextEditingController _msgController = TextEditingController();
  final MediaService _mediaService = MediaService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isMenuExpanded = false;
  bool _isBurnMode = false;
  
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _hasText = false;
  bool _isRecording = false;
  Timer? _recordDurationTimer;
  int _recordDuration = 0;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _typingTimer?.cancel();
    _recordDurationTimer?.cancel();
    if (_isTyping && mounted) {
      context.read<ChatProvider>().updateTyping(false);
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    final text = _msgController.text;
    final hasTextNow = text.trim().isNotEmpty;
    final provider = context.read<ChatProvider>();

    if (hasTextNow) {
      if (!_isTyping) {
        _isTyping = true;
        provider.updateTyping(true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(milliseconds: 3000), () {
        _isTyping = false;
        provider.updateTyping(false);
      });
    } else {
      if (_isTyping) {
        _isTyping = false;
        provider.updateTyping(false);
        _typingTimer?.cancel();
      }
    }
    // Only trigger UI rebuild if the send button vs mic button visibility state changes
    if (_hasText != hasTextNow) {
      _hasText = hasTextNow;
      setState(() {});
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 16000,
          sampleRate: 16000,
        ),
        path: path,
      );

      HapticFeedback.mediumImpact();
      _recordDuration = 0;
      _dragOffset = 0.0;
      _recordDurationTimer?.cancel();
      _recordDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDuration++;
          });
        }
      });
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Record error: $e");
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordDurationTimer?.cancel();
    _recordDurationTimer = null;
    final duration = _recordDuration;

    setState(() {
      _isRecording = false;
      _recordDuration = 0;
      _dragOffset = 0.0;
    });

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        if (duration < 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ses kaydı çok kısa, basılı tutarak konuşun.'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        HapticFeedback.lightImpact();
        if (!mounted) return;
        final provider = context.read<ChatProvider>();

        // Create a local pending message
        final localId = const Uuid().v4();
        final tempMsg = Message(
          id: 'temp_$localId',
          senderId: provider.currentUserId ?? 'unknown',
          text: '',
          mediaUrl: path,
          nickname: provider.nickname ?? 'Me',
          timestamp: DateTime.now(),
          type: 'audio',
          status: 'pending',
          localId: localId,
          metadata: {
            if (_isBurnMode) 'burnAfterRead': true,
            if (provider.isAnonymousVoice) 'voiceFilter': 'anonymous',
          },
        );
        provider.addLocalMessage(tempMsg);

        _uploadAudioBackground(path, localId);
      }
    } catch (e) {
      debugPrint("Stop record error: $e");
    }
  }

  Future<void> _uploadAudioBackground(String path, String localId) async {
    try {
      final provider = context.read<ChatProvider>();
      final roomId = provider.roomCode;
      if (roomId == null) return;

      final url = await _mediaService.uploadMedia(File(path), roomId, (progress) {
        // Upload progress callback
      });

      if (url != null) {
        await AudioCacheService.cacheExistingFile(url, File(path));
        await provider.sendMedia(
          url,
          'audio',
          localId: localId,
          metadata: {
            if (_isBurnMode) 'burnAfterRead': true,
            if (provider.isAnonymousVoice) 'voiceFilter': 'anonymous',
          },
        );
      } else {
        provider.updateLocalMessageStatus(localId, 'failed');
      }
    } catch (e) {
      debugPrint("Background upload error: $e");
      if (mounted) {
        context.read<ChatProvider>().updateLocalMessageStatus(localId, 'failed');
      }
    }
    if (mounted) {
      setState(() {
        _isBurnMode = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordDurationTimer?.cancel();
    _recordDurationTimer = null;
    HapticFeedback.heavyImpact();

    setState(() {
      _isRecording = false;
      _recordDuration = 0;
      _dragOffset = 0.0;
    });

    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint("Cancel record error: $e");
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    if (text.toLowerCase() == 'matrix' || text.toLowerCase() == 'moze') {
      widget.onEasterEggTriggered(text.toLowerCase());
      _msgController.clear();
      return;
    }

    context.read<ChatProvider>().sendMessage(
      text,
      metadata: {
        if (_isBurnMode) 'burnAfterRead': true,
      },
    );
    setState(() {
      _isBurnMode = false;
    });
    _msgController.clear();
  }

  Future<void> _handleMediaSelection(List<Map<String, dynamic>> mediaData) async {
    final provider = context.read<ChatProvider>();
    final roomId = provider.roomCode;
    if (roomId == null || mediaData.isEmpty) return;

    setState(() => _isUploading = true);
    
    int totalBytes = 0;
    for (var data in mediaData) {
      final File file = data['file'];
      totalBytes += file.lengthSync();
    }
    
    int uploadedBytes = 0;
    final stopwatch = Stopwatch()..start();
    List<Map<String, dynamic>> mediaList = [];
    final localId = const Uuid().v4();

    for (var data in mediaData) {
      final File file = data['file'];
      final String type = data['type'];
      final File? thumbnail = data['thumbnail'];
      
      final int currentFileSize = file.lengthSync();
      int currentFileUploadedBytes = 0;

      Future<String?> thumbnailUpload = thumbnail != null
          ? _mediaService.uploadMedia(thumbnail, roomId, (_) {})
          : Future.value(null);

      Future<String?> mainUpload = _mediaService.uploadMedia(file, roomId, (progress) {
        int bytesForThisFile = (currentFileSize * progress).round();
        int delta = bytesForThisFile - currentFileUploadedBytes;
        currentFileUploadedBytes = bytesForThisFile;
        uploadedBytes += delta;
        
        double overallProgress = uploadedBytes / totalBytes;
        
        final elapsedSeconds = stopwatch.elapsed.inSeconds;
        String eta = '';
        if (elapsedSeconds > 1 && uploadedBytes > 0) {
          final bytesPerSecond = uploadedBytes / elapsedSeconds;
          final remainingBytes = totalBytes - uploadedBytes;
          final remainingSeconds = (remainingBytes / bytesPerSecond).round();
          eta = '${remainingSeconds}s ETA';
        }
        
        provider.setUploadStatus(true, overallProgress, eta);
        if (mounted) {
          setState(() {
            _uploadProgress = overallProgress;
          });
        }
      });

      final results = await Future.wait([thumbnailUpload, mainUpload]);
      final thumbnailUrl = results[0];
      final url = results[1];

      if (url != null) {
        mediaList.add({
          'url': url,
          'type': type,
          'thumbnailUrl': ?thumbnailUrl,
        });
      }
    }
    
    if (mediaList.isNotEmpty) {
      await provider.sendMediaList(
        mediaList,
        localId: localId,
        metadata: {
          if (_isBurnMode) 'burnAfterRead': true,
        },
      );
    }
    
    provider.setUploadStatus(false, 0, '');
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _pickMedia() async {
    final assets = await _mediaService.pickAssets(context);
    if (assets.isNotEmpty) {
      if (!mounted) return;
      final finalData = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(builder: (_) => MediaPreviewScreen(assets: assets)),
      );
      if (finalData != null) {
        if (!mounted) return;
        await _handleMediaSelection(finalData);
      }
    }
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF159D87)),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await _mediaService.takePhoto();
                if (file != null) {
                  final compressed = await _mediaService.compressImage(file, false);
                  if (compressed != null) {
                    await _handleMediaSelection([{"file": compressed, "type": "image"}]);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF159D87)),
              title: const Text('Record Video', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await _mediaService.recordVideo();
                if (file != null) {
                  final compressed = await _mediaService.compressVideo(file);
                  final thumbnail = await _mediaService.getVideoThumbnail(file);
                  await _handleMediaSelection([{
                    "file": compressed,
                    "type": "video",
                    "thumbnail": thumbnail,
                  }]);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLocation() async {
    setState(() => _isUploading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (!mounted) return;
      if (pos != null) {
        final provider = context.read<ChatProvider>();
        await provider.sendLocation(
          pos.latitude, 
          pos.longitude, 
          'Encrypted Location Signal',
          metadata: {
            if (_isBurnMode) 'burnAfterRead': true,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get location.'), backgroundColor: Colors.red),
        );
      }
    } on LocationDisabledException catch (_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Location Disabled', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Your device location is disabled. Please enable it to send your location.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Geolocator.openLocationSettings();
              },
              child: const Text('SETTINGS', style: TextStyle(color: Color(0xFF159D87))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get location.'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final accent = themeProvider.accentColor;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: accent)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Reply Preview Banner
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: chatProvider.replyToMessage != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "REPLYING TO: ${chatProvider.replyToMessage!.nickname} - ${chatProvider.replyToMessage!.text}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12, 
                                color: accent.withValues(alpha: 0.9),
                                fontFamily: 'Courier',
                              ),
                            ),
                          ),
                          BouncyTap(
                            onTap: () => chatProvider.replyTo(null),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.close, size: 16, color: accent),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Upload Progress Bar
            if (_isUploading || chatProvider.isUploadingMedia)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ENCRYPTING & UPLOADING...',
                          style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                        ),
                        if (chatProvider.uploadEta.isNotEmpty)
                          Text(
                            chatProvider.uploadEta,
                            style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: chatProvider.isUploadingMedia ? chatProvider.uploadProgress : _uploadProgress,
                      backgroundColor: Colors.black,
                      color: accent,
                      minHeight: 2,
                    ),
                  ],
                ),
              ),

            // Main Input Row
            Row(
              children: [
                // Minimalist Recording Bar
                if (_isRecording)
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.redAccent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Pulsing red recording dot
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.3, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, val, child) {
                              return Opacity(
                                opacity: val,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'REC ${_formatDuration(_recordDuration)}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const _LiveAudioWaveform(),
                          const Spacer(),
                          Transform.translate(
                            offset: Offset(_dragOffset.clamp(-50.0, 0.0), 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chevron_left, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
                                Text(
                                  '< SLIDE TO CANCEL',
                                  style: TextStyle(
                                    color: Colors.redAccent.withValues(alpha: 0.7),
                                    fontFamily: 'Courier',
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Minimalist Menu Toggle
                  BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMenuExpanded = !_isMenuExpanded);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          _isMenuExpanded ? Icons.close : Icons.add_circle_outline,
                          key: ValueKey(_isMenuExpanded ? 'close' : 'add'),
                          color: accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // Expanded Tools
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _isMenuExpanded
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BouncyTap(child: IconButton(icon: const Icon(Icons.camera_alt), onPressed: _showCameraOptions, color: accent, tooltip: 'Camera')),
                              BouncyTap(child: IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickMedia, color: accent, tooltip: 'Attach File')),
                              BouncyTap(child: IconButton(icon: const Icon(Icons.location_on), onPressed: _sendLocation, color: accent, tooltip: 'Send Location')),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(width: 4),

                  // Minimalist Terminal-Style Data Input
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutQuad,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _isBurnMode
                              ? Colors.orangeAccent
                              : (_msgController.text.isNotEmpty
                                  ? accent
                                  : accent.withValues(alpha: 0.35)),
                          width: 1.5,
                        ),
                        boxShadow: _msgController.text.isNotEmpty
                            ? [
                                BoxShadow(
                                  color: (_isBurnMode ? Colors.orangeAccent : accent).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              style: TextStyle(
                                fontSize: 14,
                                color: _isBurnMode ? Colors.orangeAccent : accent,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 4,
                              minLines: 1,
                              decoration: InputDecoration(
                                prefixText: '>_ ',
                                prefixStyle: TextStyle(
                                  color: _isBurnMode ? Colors.orangeAccent : accent,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                  fontSize: 14,
                                ),
                                hintText: chatProvider.replyToMessage != null
                                    ? 'REPLYING...'
                                    : (_isBurnMode ? 'BURN MODE ACTIVE...' : 'ENTER DATA...'),
                                hintStyle: TextStyle(
                                  color: (_isBurnMode ? Colors.orangeAccent : accent).withValues(alpha: 0.4),
                                  fontFamily: 'Courier',
                                  letterSpacing: 1,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          BouncyTap(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isBurnMode = !_isBurnMode;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(
                                Icons.local_fire_department,
                                color: _isBurnMode ? Colors.orangeAccent : accent.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 4),

                // Right Button: Fluid Morph between Send & Mic
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: _msgController.text.trim().isNotEmpty
                      ? BouncyTap(
                          key: const ValueKey('send_button'),
                          onTap: _sendMessage,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.send_rounded, color: Colors.black, size: 20),
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('mic_button'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            CyberHUD.show(
                              context,
                              message: '>_ BASILI TUTARAK KAYDEDİN, İPTAL İÇİN SOLA KAYDIRIN',
                              icon: Icons.mic_rounded,
                              accentColor: accent,
                            );
                          },
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecordingAndSend(),
                          onLongPressMoveUpdate: (details) {
                            final dx = details.localOffsetFromOrigin.dx;
                            if (dx < -50) {
                              _cancelRecording();
                            } else if (dx < 0) {
                              setState(() {
                                _dragOffset = dx;
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            width: 42,
                            height: 42,
                            transform: Matrix4.diagonal3Values(_isRecording ? 1.15 : 1.0, _isRecording ? 1.15 : 1.0, 1.0),
                            transformAlignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? Colors.redAccent : accent,
                              boxShadow: _isRecording
                                  ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 3)]
                                  : [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 6)],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.mic_rounded,
                                color: _isRecording ? Colors.white : Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveAudioWaveform extends StatefulWidget {
  const _LiveAudioWaveform();

  @override
  State<_LiveAudioWaveform> createState() => _LiveAudioWaveformState();
}

class _LiveAudioWaveformState extends State<_LiveAudioWaveform> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final val = _waveController.value;
        final heights = [
          6.0 + (val * 8),
          14.0 - (val * 8),
          5.0 + (val * 13),
          15.0 - (val * 9),
          8.0 + (val * 7),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: heights.map((h) {
            return Container(
              width: 2.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
