import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/message.dart';
import '../services/crypto_service.dart';
import '../services/media_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../services/e2ee_service.dart';
import '../services/preferences_service.dart';

class ChatRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  Future<User?> initializeSession(String seedPhrase) async {
    final email = CryptoService.getAuthEmailFromSeed(seedPhrase);
    final password = CryptoService.getAuthPasswordFromSeed(seedPhrase);

    UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final uid = userCredential.user!.uid;

    final publicKey = await E2EEService().initializeKeypair(uid);
    final privateKeyStr = await E2EEService().exportPrivateKey(uid);
    
    if (privateKeyStr != null) {
      final key = CryptoService.deriveKeyFromSeed(seedPhrase);
      final encryptedMsg = CryptoService.encryptMessage(privateKeyStr, key);
      
      await _firestore.collection('users').doc(uid).set({
        'identity_cipherText': encryptedMsg.cipherText,
        'identity_iv': encryptedMsg.ivBase64,
        'publicKey': publicKey,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return userCredential.user;
  }

  Future<User?> restoreIdentity(String seedPhrase) async {
    final email = CryptoService.getAuthEmailFromSeed(seedPhrase);
    final password = CryptoService.getAuthPasswordFromSeed(seedPhrase);

    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final cipherText = data['identity_cipherText'];
      final iv = data['identity_iv'];

      if (cipherText != null && iv != null) {
        final key = CryptoService.deriveKeyFromSeed(seedPhrase);
        final decryptedPrivateStr = CryptoService.decryptMessage(cipherText, iv, key);
        
        if (decryptedPrivateStr.isNotEmpty && !decryptedPrivateStr.contains('[Şifre Çözülemedi]')) {
          await E2EEService().importPrivateKey(uid, decryptedPrivateStr);
        }
      }
    }

    await _restoreRooms(uid);

    return userCredential.user;
  }

  Future<void> _restoreRooms(String uid) async {
    final roomsQuery = await _firestore.collection('users').doc(uid).collection('rooms').get();
    
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    for (var doc in roomsQuery.docs) {
      final roomCode = doc.id;
      final roomId = CryptoService.deriveRoomId(roomCode);
      
      await PreferencesService.addRoomToHistory(roomCode);

      if (token != null) {
        await _firestore.collection('rooms').doc(roomId).update({
          'fcmTokens.$uid': token,
        }).catchError((_) {});
      }
    }
  }


  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> updateFcmTokenForAllRooms(String token) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomsQuery = await _firestore.collection('users').doc(uid).collection('rooms').get();
    for (var doc in roomsQuery.docs) {
      final roomCode = doc.id;
      final roomId = CryptoService.deriveRoomId(roomCode);
      await _firestore.collection('rooms').doc(roomId).update({
        'fcmTokens.$uid': token,
      }).catchError((_) {});
    }
  }


  Future<bool> isCreator(String roomCode) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final doc = await roomRef.get();
    if (doc.exists) {
      final members = doc.data()?['members'] as List<dynamic>? ?? [];
      return members.isNotEmpty && members[0] == uid;
    }
    return false;
  }

  Future<void> destroyRoom(String roomCode) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);

    final doc = await roomRef.get();
    if (doc.exists) {
      final members = doc.data()?['members'] as List<dynamic>? ?? [];
      if (members.isNotEmpty && members[0] == uid) {
        final messages = await roomRef.collection('messages').get();
        for (var i = 0; i < messages.docs.length; i += 500) {
          final batch = _firestore.batch();
          final end = (i + 500 < messages.docs.length) ? i + 500 : messages.docs.length;
          for (var j = i; j < end; j++) {
            batch.delete(messages.docs[j].reference);
          }
          await batch.commit();
        }
        await roomRef.delete();
      }
    }
  }

  Future<void> kickMembers(String roomCode) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    final doc = await roomRef.get();
    if (!doc.exists) return;
    
    final members = List<String>.from(doc.data()?['members'] ?? []);
    if (members.isEmpty || members.first != uid) return;
    
    // Yalnızca odayı kuran kişi (ilk üye) kalır
    final updates = <String, dynamic>{
      'members': [uid],
    };
    
    // Diğer üyelerin fcm token'larını temizle
    final fcmTokens = doc.data()?['fcmTokens'] as Map<String, dynamic>? ?? {};
    for (var key in fcmTokens.keys) {
      if (key != uid) {
        updates['fcmTokens.$key'] = FieldValue.delete();
      }
    }
    
    await roomRef.update(updates);
  }

  Future<void> leaveRoom(String roomCode) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await roomRef.update({
      'members': FieldValue.arrayRemove([uid]),
      'fcmTokens.$uid': FieldValue.delete(),
    });

    // Kendi listesinden de sil
    await _firestore.collection('users').doc(uid).collection('rooms').doc(roomCode).delete();
  }

  Future<void> updateTypingStatus(String roomCode, bool isTyping) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await roomRef.update({'typing.$uid': isTyping}).catchError((_) {});
  }

  Future<void> joinOrCreateRoom(String roomCode) async {
    final uid = currentUserId;
    if (uid == null) throw Exception("Kullanıcı giriş yapmamış.");

    final roomId = CryptoService.deriveRoomId(roomCode);
    final roomRef = _firestore.collection('rooms').doc(roomId);

    final snapshot = await roomRef.get();

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    if (!snapshot.exists) {
      final data = <String, dynamic>{
        'members': [uid],
        'presence': {uid: true},
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': 'Oda oluşturuldu',
      };
      if (token != null) data['fcmTokens'] = {uid: token};
      await roomRef.set(data);
    } else {
      final List<dynamic> members = snapshot.data()?['members'] ?? [];
      if (!members.contains(uid)) {
        if (members.length >= 2) {
          throw Exception("Oda kapasitesi dolu (Maks 2 kişi).");
        }
      }

      final updates = <String, dynamic>{
        'members': FieldValue.arrayUnion([uid]),
        'presence.$uid': true,
      };
      if (token != null) updates['fcmTokens.$uid'] = token;

      await roomRef.update(updates);
    }

    // Kendi koleksiyonuna odayı kaydet
    await _firestore.collection('users').doc(uid).collection('rooms').doc(roomCode).set({
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMessage(
    String roomCode,
    String text,
    String nickname, {
    String? replyToMessageId,
    String? senderIdOverride,
    String type = 'text',
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaType,
    double? locationLat,
    double? locationLng,
    String? locationName,
    String? localId,
    String status = 'sent',
    Map<String, dynamic>? metadata,
    String? aesKeyBase64,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);

    final payloadMap = <String, dynamic>{
      'text': text,
      'nickname': nickname,
      'type': type,
    };
    if (mediaUrl != null) payloadMap['mediaUrl'] = mediaUrl;
    if (thumbnailUrl != null) payloadMap['thumbnailUrl'] = thumbnailUrl;
    if (mediaType != null) payloadMap['mediaType'] = mediaType;
    if (metadata != null && metadata.containsKey('mediaList')) {
      payloadMap['mediaList'] = metadata['mediaList'];
    }
    if (locationLat != null) payloadMap['locationLat'] = locationLat;
    if (locationLng != null) payloadMap['locationLng'] = locationLng;
    if (locationName != null) payloadMap['locationName'] = locationName;

    final payload = jsonEncode(payloadMap);

    final encryptedMsg = await CryptoService.encryptMessageAsync(payload, key);

    final data = <String, dynamic>{
      'senderId': senderIdOverride ?? uid,
      'cipherText': encryptedMsg.cipherText,
      'iv': encryptedMsg.ivBase64,
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'status': status,
    };

    if (metadata != null) {
      data['metadata'] = metadata;
    }

    if (localId != null) {
      data['localId'] = localId;
    }

    if (replyToMessageId != null) {
      data['replyToMessageId'] = replyToMessageId;
    }

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add(data);

    // Update room's lastMessageTime and lastMessage for rooms list query
    await _firestore.collection('rooms').doc(roomId).update({
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessage': type == 'text' ? text : '[$type]',
    }).catchError((_) {});
  }

  Stream<List<Message>> listenToMessages(String roomCode, {int limit = 50, String? aesKeyBase64}) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);

    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final cipherList = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'cipherText': data['cipherText'] as String?,
              'ivBase64': data['iv'] as String?,
            };
          }).toList();

          final decryptedPayloads = await CryptoService.decryptMessageBatchAsync(cipherList, key);

          final messages = <Message>[];
          for (int i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            final data = doc.data();

            final senderId = data['senderId'] as String? ?? '';
            final timestamp =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            final isDeleted = data['isDeleted'] ?? false;
            final replyToMessageId = data['replyToMessageId'] as String?;
            
            final metadata = data['metadata'] as Map<String, dynamic>?;
            final starredBy = (data['starredBy'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool));
            final reactions = (data['reactions'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String));
            final isEdited = data['isEdited'] ?? false;
            final lastEdited = (data['lastEdited'] as Timestamp?)?.toDate();
            final visibleTo = (data['visibleTo'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool));

            String text = "[Encrypted Message]";
            String nickname = "Unknown";
            String type = 'text';
            String? mediaUrl;
            String? thumbnailUrl;
            String? mediaType;
            List<Map<String, dynamic>>? mediaList;
            double? locationLat;
            double? locationLng;
            String? locationName;

            final decryptedPayload = decryptedPayloads[i];
            if (decryptedPayload != null && decryptedPayload != "[Şifre Çözülemedi]") {
              try {
                final Map<String, dynamic> payloadMap = jsonDecode(decryptedPayload);
                text = payloadMap['text'] ?? '';
                nickname = payloadMap['nickname'] ?? 'Unknown';
                type = payloadMap['type'] ?? 'text';
                mediaUrl = payloadMap['mediaUrl'];
                thumbnailUrl = payloadMap['thumbnailUrl'];
                mediaType = payloadMap['mediaType'];
                if (payloadMap['mediaList'] != null) {
                  mediaList = List<Map<String, dynamic>>.from(payloadMap['mediaList']);
                }
                locationLat = payloadMap['locationLat']?.toDouble();
                locationLng = payloadMap['locationLng']?.toDouble();
                locationName = payloadMap['locationName'];
              } catch (e) {
                text = decryptedPayload; 
              }
            } else if (decryptedPayload == "[Şifre Çözülemedi]") {
              text = decryptedPayload!;
            }

            if (isDeleted) {
              text = "🚫 This message was deleted.";
              type = 'text';
              mediaUrl = null;
              mediaList = null;
              locationLat = null;
            }

            String status = data['status'] as String? ?? 'sent';
            final uid = currentUserId;
            if (doc.metadata.hasPendingWrites && uid != null && senderId == uid) {
              status = 'pending';
            }
            final localId = data['localId'] as String?;

            messages.add(Message(
              id: doc.id,
              senderId: senderId,
              text: text,
              nickname: nickname,
              timestamp: timestamp,
              isDeleted: isDeleted,
              replyToMessageId: replyToMessageId,
              type: type,
              mediaUrl: mediaUrl,
              thumbnailUrl: thumbnailUrl,
              mediaType: mediaType,
              mediaList: mediaList,
              locationLat: locationLat,
              locationLng: locationLng,
              locationName: locationName,
              status: status,
              localId: localId,
              metadata: metadata,
              starredBy: starredBy,
              reactions: reactions,
              isEdited: isEdited,
              lastEdited: lastEdited,
              visibleTo: visibleTo,
            ));
          }
          
          return messages.where((msg) {
            // Soft delete logic: if visibleTo is explicitly false for this user, hide it
            final uid = currentUserId;
            if (uid != null && msg.visibleTo != null) {
              if (msg.visibleTo![uid] == false) return false;
            }
            return true;
          }).toList();
        });
  }

  Future<String> fetchAllMessagesAsText(String roomCode, {String? aesKeyBase64}) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);

    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    final cipherList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'cipherText': data['cipherText'] as String?,
        'ivBase64': data['iv'] as String?,
      };
    }).toList();

    final decryptedPayloads = await CryptoService.decryptMessageBatchAsync(cipherList, key);

    final buffer = StringBuffer();
    buffer.writeln("=== MOZECHAT HISTORY EXPORT ===");
    buffer.writeln("Room Code: $roomCode");
    buffer.writeln("Export Date: ${DateTime.now().toString().split('.')[0]}");
    buffer.writeln("================================\n");

    for (int i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      final data = doc.data();
      final isDeleted = data['isDeleted'] ?? false;
      
      if (isDeleted) continue;

      final visibleTo = (data['visibleTo'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool));
      final uid = currentUserId;
      if (uid != null && visibleTo != null) {
        if (visibleTo[uid] == false) continue;
      }

      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final dateStr = "${timestamp.day.toString().padLeft(2, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

      String text = "[Encrypted Message]";
      String nickname = "Unknown";
      String type = 'text';

      final decryptedPayload = decryptedPayloads[i];
      if (decryptedPayload != null && decryptedPayload != "[Şifre Çözülemedi]") {
        try {
          final Map<String, dynamic> payloadMap = jsonDecode(decryptedPayload);
          text = payloadMap['text'] ?? '';
          nickname = payloadMap['nickname'] ?? 'Unknown';
          type = payloadMap['type'] ?? 'text';
          
          if (type == 'image') text = '[Resim Gönderildi]';
          if (type == 'video') text = '[Video Gönderildi]';
          if (type == 'audio') text = '[Sesli Mesaj]';
          if (type == 'media_group') text = '[Çoklu Medya Gönderildi]';
          if (type == 'location') text = '[Konum Gönderildi: ${payloadMap['locationName']}]';
        } catch (e) {
          text = decryptedPayload;
        }
      } else if (decryptedPayload == "[Şifre Çözülemedi]") {
        text = decryptedPayload!;
      }

      buffer.writeln("[$dateStr] $nickname: $text");
    }

    return buffer.toString();
  }

  Future<void> deleteMessage(String roomCode, String messageId, {String? aesKeyBase64}) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);
    final docRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final cipherText = data['cipherText'] as String?;
    final iv = data['iv'] as String?;

    String nickname = 'Unknown';
    if (cipherText != null && iv != null && cipherText.isNotEmpty) {
      final decrypted = CryptoService.decryptMessage(cipherText, iv, key);
      try {
        final payloadMap = jsonDecode(decrypted);
        nickname = payloadMap['nickname'] ?? 'Unknown';
      } catch (_) {}
    }

    final newPayloadMap = {
      'text': 'Bu mesaj silindi',
      'nickname': nickname,
      'type': 'deleted',
    };

    final encryptedMsg = await CryptoService.encryptMessageAsync(
      jsonEncode(newPayloadMap),
      key,
    );

    final uid = currentUserId;
    if (uid == null) return;

    // Check if anyone has starred this message
    final starredBy = data['starredBy'] as Map<String, dynamic>? ?? {};
    bool hasStars = starredBy.values.any((v) => v == true);

    if (hasStars) {
      // Mutation Lock: Just hide it for the deleter
      await docRef.update({
        'visibleTo.$uid': false,
      });
    } else {
      // Normal soft delete
      await docRef.update({
        'isDeleted': true,
        'cipherText': encryptedMsg.cipherText,
        'iv': encryptedMsg.ivBase64,
      });
    }
  }

  Future<void> deleteMessages(String roomCode, List<String> messageIds, {String? aesKeyBase64}) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);

    // Process in chunks of 500 to respect Firestore batch limit
    for (var i = 0; i < messageIds.length; i += 500) {
      final batch = _firestore.batch();
      final end = (i + 500 < messageIds.length) ? i + 500 : messageIds.length;
      final chunk = messageIds.sublist(i, end);

      for (final messageId in chunk) {
        final docRef = _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc(messageId);
        final snapshot = await docRef.get();
        if (!snapshot.exists) continue;

        final data = snapshot.data()!;
        final cipherText = data['cipherText'] as String?;
        final iv = data['iv'] as String?;

        String nickname = 'Unknown';
        if (cipherText != null && iv != null && cipherText.isNotEmpty) {
          final decrypted = CryptoService.decryptMessage(cipherText, iv, key);
          try {
            final payloadMap = jsonDecode(decrypted);
            nickname = payloadMap['nickname'] ?? 'Unknown';
            final mediaUrl = payloadMap['mediaUrl'] as String?;
            if (mediaUrl != null) {
              MediaService().deleteMediaFile(mediaUrl); // Fire and forget
            }
            final mediaList = payloadMap['mediaList'] as List<dynamic>?;
            if (mediaList != null) {
              for (var m in mediaList) {
                final mUrl = m['url'] as String?;
                if (mUrl != null) MediaService().deleteMediaFile(mUrl);
              }
            }
          } catch (_) {}
        }

        final newPayloadMap = {
          'text': 'Bu mesaj silindi',
          'nickname': nickname,
          'type': 'deleted',
        };

        final encryptedMsg = CryptoService.encryptMessage(
          jsonEncode(newPayloadMap),
          key,
        );

        batch.update(docRef, {
          'isDeleted': true,
          'cipherText': encryptedMsg.cipherText,
          'iv': encryptedMsg.ivBase64,
        });
      }

      await batch.commit();
    }
  }

  Future<void> hardDeleteMessage(String roomCode, String messageId) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    final docRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
        
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final cipherText = data['cipherText'] as String?;
      final iv = data['iv'] as String?;
      if (cipherText != null && iv != null && cipherText.isNotEmpty) {
        final key = CryptoService.deriveEncryptionKey(roomCode);
        final decrypted = CryptoService.decryptMessage(cipherText, iv, key);
        try {
          final payload = jsonDecode(decrypted);
          final mediaUrl = payload['mediaUrl'] as String?;
          if (mediaUrl != null) {
            MediaService().deleteMediaFile(mediaUrl);
          }
          final mediaList = payload['mediaList'] as List<dynamic>?;
          if (mediaList != null) {
            for (var m in mediaList) {
              final mUrl = m['url'] as String?;
              if (mUrl != null) MediaService().deleteMediaFile(mUrl);
            }
          }
        } catch (_) {}
      }
      await docRef.delete();
    }
  }

  Stream<DocumentSnapshot> listenToRoomMetadata(String roomCode) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  Future<DocumentSnapshot> getRoomMetadata(String roomCode) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore.collection('rooms').doc(roomId).get();
  }

  Future<void> updateRoomLock(String roomCode, bool isLocked, String? password) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore.collection('rooms').doc(roomId).update({
      'isLocked': isLocked,
      'lockPassword': password,
    });
  }

  Future<void> addNoteToRoom(String roomCode, String note) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore.collection('rooms').doc(roomId).update({
      'notes': FieldValue.arrayUnion([note])
    });
  }

  Future<void> deleteLastNMessages(String roomCode, int n, {String? aesKeyBase64}) async {
    final uid = currentUserId;
    if (uid == null) return;
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);
    
    final query = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(n)
        .get();

    final batch = _firestore.batch();
    for (var doc in query.docs) {
      final data = doc.data();
      final cipherText = data['cipherText'] as String?;
      final iv = data['iv'] as String?;
      if (cipherText != null && iv != null && cipherText.isNotEmpty) {
        final decrypted = CryptoService.decryptMessage(cipherText, iv, key);
        try {
          final payload = jsonDecode(decrypted);
          final mediaUrl = payload['mediaUrl'] as String?;
          if (mediaUrl != null) {
            MediaService().deleteMediaFile(mediaUrl);
          }
        } catch (_) {}
      }

      final newPayloadMap = {
        'text': 'Bu mesaj silindi',
        'nickname': 'System',
        'type': 'deleted',
      };
      final encryptedMsg = CryptoService.encryptMessage(
        jsonEncode(newPayloadMap),
        key,
      );
      batch.update(doc.reference, {
        'isDeleted': true,
        'cipherText': encryptedMsg.cipherText,
        'iv': encryptedMsg.ivBase64,
      });
    }
    await batch.commit();
  }

  Future<void> toggleStarMessage(
    String roomCode,
    String messageId,
    bool isStarred,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'starredBy.$uid': isStarred});
  }

  Future<void> reactToMessage(String roomCode, String messageId, String emoji) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  Future<void> editMessage(String roomCode, String messageId, String newText, {String? aesKeyBase64}) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    final roomId = CryptoService.deriveRoomId(roomCode);
    final key = aesKeyBase64 != null 
        ? encrypt.Key.fromBase64(aesKeyBase64)
        : CryptoService.deriveEncryptionKey(roomCode);
    
    final docRef = _firestore.collection('rooms').doc(roomId).collection('messages').doc(messageId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    if (data['senderId'] != uid) return; // Only sender can edit

    final cipherText = data['cipherText'] as String?;
    final iv = data['iv'] as String?;

    Map<String, dynamic> payloadMap = {};
    if (cipherText != null && iv != null && cipherText.isNotEmpty) {
      final decrypted = CryptoService.decryptMessage(cipherText, iv, key);
      try {
        payloadMap = jsonDecode(decrypted);
      } catch (_) {}
    }

    payloadMap['text'] = newText;

    final encryptedMsg = CryptoService.encryptMessage(jsonEncode(payloadMap), key);

    await docRef.update({
      'isEdited': true,
      'lastEdited': FieldValue.serverTimestamp(),
      'cipherText': encryptedMsg.cipherText,
      'iv': encryptedMsg.ivBase64,
    });
  }

  Future<void> updatePresence(String roomCode, bool isOnline) async {
    final uid = currentUserId;
    if (uid == null) return;

    final roomId = CryptoService.deriveRoomId(roomCode);
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'presence.$uid': isOnline,
        if (!isOnline) 'lastSeen.$uid': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Document might not exist if they leave before creating properly, ignore.
    }
  }

  Stream<DocumentSnapshot> listenToRoom(String roomCode) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  Future<void> updateMessagesStatusBatch(
    String roomCode,
    List<String> messageIds,
    String status,
  ) async {
    final uid = currentUserId;
    if (uid == null || messageIds.isEmpty) return;
    final roomId = CryptoService.deriveRoomId(roomCode);

    final batch = _firestore.batch();
    for (final id in messageIds) {
      final ref = _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(id);
      batch.update(ref, {'status': status});
    }

    await batch.commit().catchError((_) {});
  }
}
