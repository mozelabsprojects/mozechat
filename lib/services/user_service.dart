import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<int> getCoins(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data()?['coins'] ?? 1000;
    }
    // New user default
    await _firestore.collection('users').doc(userId).set({'coins': 1000}, SetOptions(merge: true));
    return 1000;
  }

  static Future<void> addCoins(String userId, int amount) async {
    final docRef = _firestore.collection('users').doc(userId);
    await docRef.set({'coins': FieldValue.increment(amount)}, SetOptions(merge: true));
  }

  static Future<bool> deductCoins(String userId, int amount) async {
    final docRef = _firestore.collection('users').doc(userId);
    
    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      int current = 1000;
      if (doc.exists) {
        current = doc.data()?['coins'] ?? 1000;
      } else {
        transaction.set(docRef, {'coins': 1000});
      }
      
      if (current >= amount) {
        transaction.set(docRef, {'coins': current - amount}, SetOptions(merge: true));
        return true;
      }
      return false;
    });
  }

  static Future<Map<String, dynamic>> claimDaily(String userId) async {
    final docRef = _firestore.collection('users').doc(userId);
    
    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      DateTime? lastClaim;
      int currentCoins = 1000;
      
      if (doc.exists) {
        final data = doc.data()!;
        currentCoins = data['coins'] ?? 1000;
        if (data['lastDaily'] != null) {
          lastClaim = (data['lastDaily'] as Timestamp).toDate();
        }
      }
      
      final now = DateTime.now();
      if (lastClaim != null) {
        final diff = now.difference(lastClaim);
        if (diff.inHours < 24) {
          return {'success': false, 'hoursLeft': 24 - diff.inHours};
        }
      }
      
      transaction.set(docRef, {
        'coins': currentCoins + 100,
        'lastDaily': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return {'success': true, 'newBalance': currentCoins + 100};
    });
  }
}
