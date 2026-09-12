import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;

  final String? publicKey;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.displayName,

    this.publicKey,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? '',

      publicKey: data['publicKey'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,

      'publicKey': publicKey,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
