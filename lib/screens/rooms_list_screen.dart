import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../models/room_model.dart';
import '../widgets/system_status_banner.dart';
import '../widgets/cyber_grid.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'room_screen.dart';
import 'settings_screen.dart';
import '../providers/chat_provider.dart';

class RoomsListScreen extends StatelessWidget {
  const RoomsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.dns_outlined, color: accentColor, size: 20),
            const SizedBox(width: 10),
            Text(
              'ACTIVE RELAYS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 16,
                color: accentColor,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: accentColor.withValues(alpha: 0.6)),
            color: Colors.black.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'settings') {
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }
              } else if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: accentColor, size: 18),
                    const SizedBox(width: 10),
                    Text('SYSTEM CONFIG', style: TextStyle(color: accentColor, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Text('DISCONNECT', style: TextStyle(color: Colors.red.shade400, letterSpacing: 1.5, fontSize: 12)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: Stack(
        children: [
          CyberGrid(accentColor: accentColor),
          SafeArea(
            child: Column(
              children: [
                const SystemStatusBanner(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rooms')
                        .where('members', arrayContains: currentUser.uid)
                        .orderBy('lastMessageTime', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('rooms')
                              .where('members', arrayContains: currentUser.uid)
                              .snapshots(),
                          builder: (context, fallbackSnapshot) {
                            if (fallbackSnapshot.hasError) {
                              return _buildErrorState(fallbackSnapshot.error.toString(), accentColor);
                            }
                            if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                            }
                            final docs = fallbackSnapshot.data?.docs ?? [];
                            if (docs.isEmpty) return _buildEmptyState(accentColor);
                            return _buildRoomList(docs, currentUser, themeProvider, context);
                          },
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return _buildEmptyState(accentColor);
                      return _buildRoomList(docs, currentUser, themeProvider, context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor.withValues(alpha: 0.15),
        foregroundColor: accentColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
        ),
        elevation: 10,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoomScreen()),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error, Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'CONNECTION ERROR',
              style: TextStyle(fontSize: 14, color: Colors.red.shade400, letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error, style: TextStyle(fontSize: 11, color: Colors.red.shade400.withValues(alpha: 0.6)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 72, color: accentColor.withValues(alpha: 0.15)),
          const SizedBox(height: 20),
          Text(
            'NO SECURE NODES DETECTED',
            style: TextStyle(
              fontSize: 14,
              color: accentColor.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Initialize a new relay to start encrypted comms',
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.2),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<QueryDocumentSnapshot> docs, User currentUser, ThemeProvider themeProvider, BuildContext context) {
    final accentColor = themeProvider.accentColor;
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80), // bottom padding for FAB
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final room = RoomModel.fromMap(docs[index].data() as Map<String, dynamic>);

        String timeString = '';
        if (room.lastMessageTime != null) {
          final now = DateTime.now();
          final msgDate = room.lastMessageTime!;
          if (now.difference(msgDate).inDays == 0) {
            timeString = DateFormat('HH:mm').format(msgDate);
          } else if (now.difference(msgDate).inDays < 7) {
            timeString = DateFormat('EEE').format(msgDate);
          } else {
            timeString = DateFormat('dd/MM').format(msgDate);
          }
        }

        final roomName = room.roomName.isNotEmpty 
            ? room.roomName 
            : room.roomId.length > 12 
                ? '${room.roomId.substring(0, 12)}...' 
                : room.roomId;

        return Dismissible(
          key: Key(docs[index].id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade800.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.delete_outline, color: Colors.red.shade400),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.black.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                title: Text('TERMINATE LINK?', style: TextStyle(color: accentColor, letterSpacing: 2, fontSize: 16)),
                content: Text(
                  'Remove this node from your active relays?',
                  style: TextStyle(color: accentColor.withValues(alpha: 0.6)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('CANCEL', style: TextStyle(color: accentColor.withValues(alpha: 0.5))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('TERMINATE', style: TextStyle(color: Colors.red.shade400)),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) async {
            final chatProvider = context.read<ChatProvider>();
            await chatProvider.removeRoomLocal(room.roomId);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: accentColor.withValues(alpha: 0.2),
                    highlightColor: accentColor.withValues(alpha: 0.1),
                    onTap: () async {
                      final chatProvider = context.read<ChatProvider>();
                      await chatProvider.joinRoom(room.roomId);
                      
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: accentColor.withValues(alpha: 0.08),
                              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                            ),
                            child: Icon(
                              room.isGroup ? Icons.group : Icons.lock_outline,
                              color: accentColor.withValues(alpha: 0.5),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roomName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: accentColor.withValues(alpha: 0.9),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  room.lastMessage ?? 'Node initialized',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accentColor.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.3),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 12,
                                    color: accentColor.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${room.members.length}',
                                    style: TextStyle(
                                      color: accentColor.withValues(alpha: 0.3),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
