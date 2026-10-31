import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:video_player/video_player.dart';
import '../providers/locale_provider.dart';
import '../services/media_service.dart';

class MediaPreviewScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  const MediaPreviewScreen({super.key, required this.assets});

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final MediaService _mediaService = MediaService();
  late List<File?> _files;
  bool _isHD = false;
  bool _isUploading = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _files = List.generate(widget.assets.length, (_) => null);
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    for (int i = 0; i < widget.assets.length; i++) {
      final file = await widget.assets[i].file;
      if (mounted) {
        setState(() {
          _files[i] = file;
        });
      }
    }
  }

  Future<void> _cropCurrent() async {
    final file = _files[_currentIndex];
    if (file == null) return;

    final cropped = await _mediaService.cropImage(file);
    if (cropped != null && mounted) {
      setState(() {
        _files[_currentIndex] = cropped;
      });
    }
  }

  Future<void> _send() async {
    setState(() {
      _isUploading = true;
    });

    List<Map<String, dynamic>> finalData = [];
    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];
      if (file != null) {
        final isVideo = widget.assets[i].type == AssetType.video;
        if (isVideo) {
          final compressedVideo = await _mediaService.compressVideo(file);
          final thumbnail = await _mediaService.getVideoThumbnail(file);
          finalData.add({
            'file': compressedVideo,
            'thumbnail': thumbnail,
            'type': 'video',
          });
        } else {
          final compressed = await _mediaService.compressImage(file, _isHD);
          if (compressed != null) {
            finalData.add({'file': compressed, 'type': 'image'});
          }
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context, finalData);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final currentFile = _files.isNotEmpty ? _files[_currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(strings.editMediaTitle, style: const TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.crop),
            onPressed: _cropCurrent,
            tooltip: strings.cropTooltip,
          ),
        ],
      ),
      body: _isUploading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF159D87)),
            )
          : Column(
              children: [
                Expanded(
                  child: currentFile == null
                      ? const Center(child: CircularProgressIndicator())
                      : widget.assets[_currentIndex].type == AssetType.video
                          ? VideoPreviewWidget(file: currentFile)
                          : Image.file(currentFile, fit: BoxFit.contain),
                ),
                if (_files.length > 1)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _files.length,
                      itemBuilder: (ctx, i) {
                        final file = _files[i];
                        return GestureDetector(
                          onTap: () => setState(() => _currentIndex = i),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _currentIndex == i
                                    ? const Color(0xFF159D87)
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: file == null
                                ? const SizedBox(
                                    width: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        file,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                      if (widget.assets[i].type == AssetType.video)
                                        const Center(
                                          child: Icon(
                                            Icons.play_circle_fill,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                SafeArea(
                  bottom: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black87,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(strings.qualityNormal),
                          Switch(
                            value: _isHD,
                            activeTrackColor: const Color(0xFF159D87).withValues(alpha: 0.5),
                            activeThumbColor: const Color(0xFF159D87),
                            onChanged: (val) => setState(() => _isHD = val),
                          ),
                          const Text(
                            'HD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF159D87),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF159D87),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _send,
                            icon: const Icon(Icons.send),
                            label: Text(strings.encryptAndSendBtn),
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
}

class VideoPreviewWidget extends StatefulWidget {
  final File file;
  const VideoPreviewWidget({super.key, required this.file});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void didUpdateWidget(covariant VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller.dispose();
      _controller = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _controller.play();
            _controller.setLooping(true);
          }
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
