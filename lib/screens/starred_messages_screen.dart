import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../providers/locale_provider.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final uid = chatProvider.currentUserId;

    final starredMessages = chatProvider.messages.where((msg) {
      if (uid == null || msg.starredBy == null) return false;
      return msg.starredBy![uid] == true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.starredMessagesTitle),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: starredMessages.isEmpty
          ? Center(
              child: Text(
                strings.noStarredMessages,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: starredMessages.length,
              itemBuilder: (context, index) {
                final msg = starredMessages[index];
                final timeString = DateFormat('MMM d, HH:mm').format(msg.timestamp);

                return Card(
                  color: Colors.black45,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.yellow),
                    title: Text(
                      msg.nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text.isNotEmpty ? msg.text : strings.mediaAttachmentFallback,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeString,
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.star_border, color: Colors.white54),
                      onPressed: () {
                        chatProvider.starMessage(msg.id, false);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
