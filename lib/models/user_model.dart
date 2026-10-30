import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String nickname;
  final String? publicKey;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.nickname,
    this.publicKey,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final nick = data['nickname'] ?? data['displayName'] ?? '';
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: nick,
      nickname: nick,
      publicKey: data['publicKey'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'nickname': nickname,
      'publicKey': publicKey,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
