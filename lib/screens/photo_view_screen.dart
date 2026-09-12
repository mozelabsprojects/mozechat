import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/message.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<Message> imageMessages;
  final int initialIndex;

  const PhotoViewScreen({
    super.key, 
    required this.imageMessages, 
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  bool _isDownloading = false;
  late int currentIndex;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: currentIndex);
  }

  Future<void> _downloadImage() async {
    final currentImageUrl = widget.imageMessages[currentIndex].mediaUrl;
    if (currentImageUrl == null) return;

    setState(() => _isDownloading = true);
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final tempDir = await getTemporaryDirectory();
      var ext = currentImageUrl.split('.').last.split('?').first;
      if (ext.isEmpty || ext.length > 5) ext = 'jpg';
      final path =
          '${tempDir.path}/moze_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(currentImageUrl, path);
      await Gal.putImage(path);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${currentIndex + 1} / ${widget.imageMessages.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
        ),
        centerTitle: true,
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
                  onPressed: _downloadImage,
                  tooltip: 'Save to Gallery',
                ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.imageMessages[index].mediaUrl!),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: widget.imageMessages[index].id),
          );
        },
        itemCount: widget.imageMessages.length,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF159D87)),
        ),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        pageController: pageController,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
