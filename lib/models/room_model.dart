import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String roomId;
  final String roomCode;
  final String roomName;
  final bool isGroup;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String createdBy;
  final List<String> members;
  final String encryptionKey; // Deprecated but kept for fallback
  final Map<String, String>? encryptedKeys; // For E2EE mapping

  RoomModel({
    required this.roomId,
    required this.roomCode,
    required this.roomName,
    required this.isGroup,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    required this.createdBy,
    required this.members,
    required this.encryptionKey,
    this.encryptedKeys,
  });

  factory RoomModel.fromMap(Map<String, dynamic> data) {
    return RoomModel(
      roomId: data['roomId'] ?? '',
      roomCode: data['roomCode'] ?? data['roomId'] ?? '',
      roomName: data['roomName'] ?? data['roomCode'] ?? '',
      isGroup: data['isGroup'] ?? false,
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      encryptionKey: data['encryptionKey'] ?? '',
      encryptedKeys: data['encryptedKeys'] != null
          ? Map<String, String>.from(data['encryptedKeys'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomCode': roomCode,
      'roomName': roomName,
      'isGroup': isGroup,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'createdBy': createdBy,
      'members': members,
      'encryptionKey': encryptionKey,
      'encryptedKeys': encryptedKeys,
    };
  }
}
