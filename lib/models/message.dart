class Message {
  final String id;
  final String senderId;
  final String text;
  final String nickname;
  final DateTime timestamp;
  final bool isDeleted;
  final String? replyToMessageId;

  // Fields for media & location
  final String type; // 'text', 'image', 'video', 'location', 'audio', 'deleted'
  final String? mediaUrl; // Legacy or single media fallback
  final String? thumbnailUrl;
  final String? mediaType;
  final List<Map<String, dynamic>>? mediaList; // Format: [{'url': '...', 'thumbnailUrl': '...', 'type': 'image'/'video'}]
  final double? locationLat;
  final double? locationLng;
  final String? locationName;

  // Fields for WhatsApp-like features
  final String status; // 'pending', 'sent', 'delivered', 'read', 'failed'
  final String? localId; // To track local pending messages

  // GOD MODE Features
  final Map<String, dynamic>? metadata;
  final Map<String, bool>? starredBy;
  final Map<String, String>? reactions;
  final bool isEdited;
  final DateTime? lastEdited;
  final Map<String, bool>? visibleTo; // For soft-deletions

  bool get isStarred => starredBy?.values.any((e) => e == true) ?? false;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.nickname,
    required this.timestamp,
    this.isDeleted = false,
    this.replyToMessageId,
    this.type = 'text',
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.mediaList,
    this.locationLat,
    this.locationLng,
    this.locationName,
    this.status = 'sent',
    this.localId,
    this.metadata,
    this.starredBy,
    this.reactions,
    this.isEdited = false,
    this.lastEdited,
    this.visibleTo,
  });
}
