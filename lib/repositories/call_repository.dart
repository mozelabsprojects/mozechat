import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/crypto_service.dart';

class CallRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initiate a call offer
  Future<void> createOffer(String roomCode, String callId, String callerId, Map<String, dynamic> offer) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .set({
      'callerId': callerId,
      'offer': offer,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a call with an answer
  Future<void> answerCall(String roomCode, String callId, Map<String, dynamic> answer) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .update({
      'answer': answer,
      'status': 'connected',
    });
  }

  /// End or reject a call
  Future<void> endCall(String roomCode, String callId) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add an ICE candidate
  Future<void> addIceCandidate(
      String roomCode, String callId, String role, Map<String, dynamic> candidate) async {
    final roomId = CryptoService.deriveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .collection('${role}Candidates') // 'callerCandidates' or 'calleeCandidates'
        .add(candidate);
  }

  /// Listen to call state
  Stream<DocumentSnapshot> listenToCall(String roomCode, String callId) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .snapshots();
  }

  /// Listen to new incoming calls for a specific room (optional, handled via FCM in background)
  Stream<QuerySnapshot> listenToIncomingCalls(String roomCode) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Listen to remote ICE candidates
  Stream<QuerySnapshot> listenToIceCandidates(String roomCode, String callId, String remoteRole) {
    final roomId = CryptoService.deriveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .collection('${remoteRole}Candidates')
        .snapshots();
  }
}
