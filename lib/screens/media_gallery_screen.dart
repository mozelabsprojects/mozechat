import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import 'photo_view_gallery_screen.dart';
import 'video_player_screen.dart';

class GalleryItem {
  final String messageId;
  final String type;
  final String url;
  final String? thumbnailUrl;

  GalleryItem({
    required this.messageId,
    required this.type,
    required this.url,
    this.thumbnailUrl,
  });
}

class MediaGalleryScreen extends StatelessWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final List<GalleryItem> allMedia = [];

    for (var msg in chatProvider.messages) {
      if (msg.isDeleted) continue;

      if (msg.type == 'image' && msg.mediaUrl != null) {
        allMedia.add(GalleryItem(messageId: msg.id, type: 'image', url: msg.mediaUrl!));
      } else if (msg.type == 'video' && msg.mediaUrl != null) {
        allMedia.add(GalleryItem(messageId: msg.id, type: 'video', url: msg.mediaUrl!, thumbnailUrl: msg.thumbnailUrl));
      } else if (msg.type == 'media_group' && msg.mediaList != null) {
        for (var item in msg.mediaList!) {
          final type = item['type'] ?? 'image';
          final url = item['url'];
          final thumb = item['thumbnailUrl'];
          if (url != null) {
            allMedia.add(GalleryItem(messageId: msg.id, type: type, url: url, thumbnailUrl: thumb));
          }
        }
      }
    }

    final photos = allMedia.where((m) => m.type == 'image').toList();
    final videos = allMedia.where((m) => m.type == 'video').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text(
            'MEDIA GALLERY',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: themeProvider.accentColor,
            labelColor: themeProvider.accentColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'TÜMÜ'),
              Tab(text: 'FOTOĞRAFLAR'),
              Tab(text: 'VİDEOLAR'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGrid(context, allMedia, themeProvider),
            _buildGrid(context, photos, themeProvider),
            _buildGrid(context, videos, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<GalleryItem> items, ThemeProvider themeProvider) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          '> NO_MEDIA_FOUND',
          style: TextStyle(color: themeProvider.accentColor, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final displayUrl = item.type == 'video' ? (item.thumbnailUrl ?? '') : item.url;

        return GestureDetector(
          onTap: () {
            if (item.type == 'video') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(videoUrl: item.url),
                ),
              );
            } else {
              final imageItems = items.where((m) => m.type == 'image').toList();
              final initialIndex = imageItems.indexOf(item);
              
              final mediaList = imageItems.map((m) => {
                'type': m.type,
                'url': m.url,
                'thumbnailUrl': m.thumbnailUrl
              }).toList();
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewGalleryScreen(
                    mediaList: mediaList,
                    initialIndex: initialIndex >= 0 ? initialIndex : 0,
                  ),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: themeProvider.accentColor.withValues(alpha: 0.5),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: displayUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: themeProvider.accentColor),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.red),
                ),
                if (item.type == 'video')
                  const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
