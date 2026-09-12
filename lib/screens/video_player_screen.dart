import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;
  bool _isDownloading = false;

  Future<void> _downloadVideo() async {
    setState(() => _isDownloading = true);
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final tempDir = await getTemporaryDirectory();
      var ext = widget.videoUrl.split('.').last.split('?').first;
      if (ext.isEmpty || ext.length > 5) ext = 'mp4';
      final path =
          '${tempDir.path}/moze_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(widget.videoUrl, path);
      await Gal.putVideo(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved to Gallery!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF159D87),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.videoUrl);
      if (!mounted) return;
      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF159D87),
          handleColor: const Color(0xFF159D87),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white30,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: _downloadVideo,
                  tooltip: 'Save to Gallery',
                ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: _isError
              ? const Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white),
                )
              : _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
              ? Chewie(controller: _chewieController!)
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
