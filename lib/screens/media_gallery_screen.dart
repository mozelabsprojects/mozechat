import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/audio_bubble.dart';
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
    final strings = context.watch<LocaleProvider>().strings;

    final List<GalleryItem> allMedia = [];
    final List<Message> audioMessages = [];

    for (var msg in chatProvider.messages) {
      if (msg.isDeleted) continue;

      if (msg.type == 'image' && msg.mediaUrl != null) {
        allMedia.add(GalleryItem(messageId: msg.id, type: 'image', url: msg.mediaUrl!));
      } else if (msg.type == 'video' && msg.mediaUrl != null) {
        allMedia.add(
          GalleryItem(
            messageId: msg.id,
            type: 'video',
            url: msg.mediaUrl!,
            thumbnailUrl: msg.thumbnailUrl,
          ),
        );
      } else if (msg.type == 'media_group' && msg.mediaList != null) {
        for (var item in msg.mediaList!) {
          final type = item['type'] ?? 'image';
          final url = item['url'];
          final thumb = item['thumbnailUrl'];
          if (url != null) {
            allMedia.add(
              GalleryItem(
                messageId: msg.id,
                type: type,
                url: url,
                thumbnailUrl: thumb,
              ),
            );
          }
        }
      } else if (msg.type == 'audio' && msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
        audioMessages.add(msg);
      }
    }

    final photos = allMedia.where((m) => m.type == 'image').toList();
    final videos = allMedia.where((m) => m.type == 'video').toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            strings.mediaGalleryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: themeProvider.accentColor,
            labelColor: themeProvider.accentColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '${strings.allTab} (${allMedia.length})'),
              Tab(text: '${strings.photosTab} (${photos.length})'),
              Tab(text: '${strings.videosTab} (${videos.length})'),
              Tab(text: '${strings.audiosTab} (${audioMessages.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGrid(context, allMedia, themeProvider),
            _buildGrid(context, photos, themeProvider),
            _buildGrid(context, videos, themeProvider),
            _buildAudiosList(context, audioMessages, chatProvider, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<GalleryItem> items, ThemeProvider themeProvider) {
    final strings = context.watch<LocaleProvider>().strings;
    if (items.isEmpty) {
      return Center(
        child: Text(
          strings.noMediaFound,
          style: TextStyle(color: themeProvider.accentColor, fontSize: 16),
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

              final mediaList = imageItems
                  .map((m) => {
                        'type': m.type,
                        'url': m.url,
                        'thumbnailUrl': m.thumbnailUrl,
                      })
                  .toList();

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
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, color: Colors.red),
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

  Widget _buildAudiosList(
    BuildContext context,
    List<Message> audioMessages,
    ChatProvider chatProvider,
    ThemeProvider themeProvider,
  ) {
    final strings = context.watch<LocaleProvider>().strings;
    if (audioMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: themeProvider.accentColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              strings.noAudioFound,
              style: TextStyle(color: themeProvider.accentColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: audioMessages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = audioMessages[index];
        final isMe = msg.senderId == chatProvider.currentUserId;
        final timeStr = DateFormat('MMM d, HH:mm').format(msg.timestamp);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161F28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe
                  ? themeProvider.accentColor.withValues(alpha: 0.35)
                  : Colors.white12,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mic_rounded,
                        size: 16,
                        color: themeProvider.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMe ? strings.youSender : msg.nickname,
                        style: TextStyle(
                          color: themeProvider.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AudioBubble(
                audioUrl: msg.mediaUrl!,
                bubbleColor: Colors.transparent,
                textColor: Colors.white,
                isMe: isMe,
              ),
            ],
          ),
        );
      },
    );
  }
}
