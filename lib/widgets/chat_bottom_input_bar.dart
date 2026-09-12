import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
import '../models/message.dart';
import '../screens/media_preview_screen.dart';

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
  bool _isRecording = false;

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
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    final text = _msgController.text;
    final provider = context.read<ChatProvider>();

    if (text.isNotEmpty) {
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
    // Also trigger UI update so the send button vs mic button animates correctly
    setState(() {});
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
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
        setState(() => _isRecording = true);
      } else {
        await Permission.microphone.request();
      }
    } catch (e) {
      debugPrint("Record error: $e");
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        if (!mounted) return;
        final provider = context.read<ChatProvider>();

        // Create a local pending message
        final localId = const Uuid().v4();
        final tempMsg = Message(
          id: 'temp_$localId',
          senderId: provider.currentUserId ?? 'unknown',
          text: '',
          nickname: provider.nickname ?? 'Me',
          timestamp: DateTime.now(),
          type: 'audio',
          status: 'pending',
          localId: localId,
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
    setState(() => _isRecording = false);
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint("Cancel record error: $e");
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

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
        border: Border(top: BorderSide(color: accent)),
      ),
      child: Column(
        children: [
          if (chatProvider.replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.5)),
                color: accent.withValues(alpha: 0.1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: ${chatProvider.replyToMessage!.nickname} - ${chatProvider.replyToMessage!.text}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => chatProvider.replyTo(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (_isUploading || chatProvider.isUploadingMedia)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Encrypting & Uploading Media...',
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      if (chatProvider.uploadEta.isNotEmpty)
                        Text(
                          chatProvider.uploadEta,
                          style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: chatProvider.isUploadingMedia ? chatProvider.uploadProgress : _uploadProgress,
                    backgroundColor: Colors.black,
                    color: accent,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: child.key == const ValueKey('close')
                        ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                        : Tween<double>(begin: 0.75, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    _isMenuExpanded ? Icons.close : Icons.add_circle_outline,
                    key: ValueKey(_isMenuExpanded ? 'close' : 'add'),
                    color: accent,
                  ),
                ),
                onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isMenuExpanded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _showCameraOptions, color: accent),
                          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickMedia, color: accent),
                          IconButton(icon: const Icon(Icons.location_on), onPressed: _sendLocation, color: accent),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isBurnMode ? Colors.orangeAccent : accent.withValues(alpha: 0.5), 
                      width: 1.5
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: TextStyle(
                            fontSize: 14, 
                            color: _isBurnMode ? Colors.orangeAccent : const Color(0xFF159D87),
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            prefixText: '>_ ',
                            prefixStyle: TextStyle(
                              color: _isBurnMode ? Colors.orangeAccent : const Color(0xFF159D87),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              fontSize: 14,
                            ),
                            hintText: chatProvider.replyToMessage != null
                              ? 'REPLYING...'
                              : (_isBurnMode ? 'BURN MODE ACTIVE...' : 'ENTER DATA...'),
                            hintStyle: TextStyle(
                              color: (_isBurnMode ? Colors.orangeAccent : const Color(0xFF159D87)).withValues(alpha: 0.4),
                              fontFamily: 'Courier',
                              letterSpacing: 1,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.local_fire_department,
                          color: _isBurnMode ? Colors.orangeAccent : accent.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isBurnMode = !_isBurnMode;
                          });
                        },
                        tooltip: 'Burn After Reading',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _msgController.text.isNotEmpty
                  ? Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                      child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: _sendMessage),
                    )
                  : GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecordingAndSend(),
                      onLongPressMoveUpdate: (details) {
                        if (details.localOffsetFromOrigin.dx < -50 || details.localOffsetFromOrigin.dy < -50) {
                          _cancelRecording();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        transform: Matrix4.diagonal3Values(_isRecording ? 1.2 : 1.0, _isRecording ? 1.2 : 1.0, 1.0),
                        transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.redAccent : accent,
                          boxShadow: _isRecording ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 5)] : [],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.mic, color: _isRecording ? Colors.white : Colors.black),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
