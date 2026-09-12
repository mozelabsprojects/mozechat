import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class PhotoViewGalleryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> mediaList;
  final int initialIndex;

  const PhotoViewGalleryScreen({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewGalleryScreen> createState() => _PhotoViewGalleryScreenState();
}

class _PhotoViewGalleryScreenState extends State<PhotoViewGalleryScreen> {
  late int currentIndex;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${currentIndex + 1} / ${widget.mediaList.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          final item = widget.mediaList[index];
          final url = item['url'] as String;
          final type = item['type'] as String;

          if (type == 'video') {
            // For now just show the thumbnail for videos in gallery
            final thumbnailUrl = item['thumbnailUrl'] as String?;
            return PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(thumbnailUrl ?? ''),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes: PhotoViewHeroAttributes(tag: url),
            );
          }

          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(url),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: url),
          );
        },
        itemCount: widget.mediaList.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            color: accentColor,
            value: event == null
                ? 0
                : event.expectedTotalBytes != null
                    ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                    : null,
          ),
        ),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        pageController: pageController,
        onPageChanged: (int index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
