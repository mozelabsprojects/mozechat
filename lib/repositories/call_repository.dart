import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/crypto_service.dart';

class CallRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Resolves input to the derived roomId. If it's already a 64-char hex hash, reuse it to prevent double-hashing.
  String resolveRoomId(String codeOrId) {
    final trimmed = codeOrId.trim();
    if (trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return CryptoService.deriveRoomId(trimmed);
  }

  /// Ends any previous unfinished ('ringing' or 'connected') calls in the room
  /// so ghost calls never remain stuck in Firestore.
  Future<void> endAllActiveCallsInRoom(String roomCodeOrId, {String? exceptCallId}) async {
    try {
      final roomId = resolveRoomId(roomCodeOrId);
      final callsRef = _firestore.collection('rooms').doc(roomId).collection('calls');
      final activeSnap = await callsRef
          .where('status', whereIn: ['ringing', 'connected'])
          .get();

      if (activeSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      int count = 0;
      for (final doc in activeSnap.docs) {
        if (exceptCallId != null && doc.id == exceptCallId) continue;
        batch.update(doc.reference, {
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('endAllActiveCallsInRoom warning: $e');
    }
  }

  /// Initiate a call offer
  Future<void> createOffer(
    String roomCode,
    String callId,
    String callerId,
    Map<String, dynamic> offer, {
    String? callerName,
  }) async {
    final roomId = resolveRoomId(roomCode);

    // Clean up any stale calls in this room before starting a new one
    await endAllActiveCallsInRoom(roomId, exceptCallId: callId);

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .set({
      'callerId': callerId,
      'callerName': callerName ?? 'Unknown',
      'roomCode': roomCode,
      'offer': offer,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a call with an answer
  Future<void> answerCall(String roomCode, String callId, Map<String, dynamic> answer) async {
    final roomId = resolveRoomId(roomCode);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .update({
      'answer': answer,
      'status': 'connected',
      'connectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// End or reject a call
  Future<void> endCall(String roomCode, String callId) async {
    final roomId = resolveRoomId(roomCode);
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(callId)
          .set({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('endCall doc update warning: $e');
    }
  }

  /// Add an ICE candidate
  Future<void> addIceCandidate(
    String roomCode,
    String callId,
    String role,
    Map<String, dynamic> candidate,
  ) async {
    final roomId = resolveRoomId(roomCode);
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('calls')
          .doc(callId)
          .collection('${role}Candidates')
          .add(candidate);
    } catch (e) {
      debugPrint('addIceCandidate warning: $e');
    }
  }

  /// Listen to a specific call document state
  Stream<DocumentSnapshot> listenToCall(String roomCode, String callId) {
    final roomId = resolveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .snapshots();
  }

  /// Listen to active ('ringing' or 'connected') calls in a room
  Stream<QuerySnapshot> listenToActiveCalls(String roomCode) {
    final roomId = resolveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .where('status', whereIn: ['ringing', 'connected'])
        .snapshots();
  }

  /// Listen to remote ICE candidates
  Stream<QuerySnapshot> listenToIceCandidates(
    String roomCode,
    String callId,
    String remoteRole,
  ) {
    final roomId = resolveRoomId(roomCode);
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('calls')
        .doc(callId)
        .collection('${remoteRole}Candidates')
        .snapshots();
  }
}
