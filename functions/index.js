const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const { setGlobalOptions } = require("firebase-functions/v2");

setGlobalOptions({ region: "europe-west1" });

exports.sendNewMessageNotification = onDocumentCreated("rooms/{roomId}/messages/{messageId}", async (event) => {
    const messageData = event.data.data();
    if (!messageData) return;

    const senderId = messageData.senderId;
    const roomId = event.params.roomId;

    const roomSnap = await admin.firestore().collection("rooms").doc(roomId).get();
    if (!roomSnap.exists) return;

    const roomData = roomSnap.data();
    const fcmTokens = roomData.fcmTokens || {};
    const presence = roomData.presence || {};

    const tokensToNotify = [];

    for (const [uid, token] of Object.entries(fcmTokens)) {
        if (uid !== senderId && token) {
            tokensToNotify.push(token);
        }
    }

    if (tokensToNotify.length === 0) {
        console.log("Bildirim atılacak token bulunamadı.");
        return;
    }

    const payload = {
        data: {
            type: "NEW_MESSAGE",
            roomId: roomId,
            messageId: event.params.messageId,
            senderId: senderId,
            cipherText: messageData.cipherText || "",
            iv: messageData.iv || "",
        }
    };

    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokensToNotify,
            data: payload.data,
            android: { priority: "high" },
            apns: { payload: { aps: { contentAvailable: true } } }
        });
        console.log("Push notifications sent:", response.successCount);
    } catch (error) {
        console.error("Error sending push notifications:", error);
    }
});

exports.sendNewCallNotification = onDocumentCreated("rooms/{roomId}/calls/{callId}", async (event) => {
    const callData = event.data.data();
    if (!callData) return;

    // Sadece yeni başlayan (ringing) aramalar için bildirim at
    if (callData.status !== 'ringing') return;

    const callerId = callData.callerId;
    const roomId = event.params.roomId;
    const callId = event.params.callId;

    const roomSnap = await admin.firestore().collection("rooms").doc(roomId).get();
    if (!roomSnap.exists) return;

    const roomData = roomSnap.data();
    const fcmTokens = roomData.fcmTokens || {};

    const tokensToNotify = [];

    for (const [uid, token] of Object.entries(fcmTokens)) {
        if (uid !== callerId && token) {
            tokensToNotify.push(token);
        }
    }

    if (tokensToNotify.length === 0) {
        console.log("Arama bildirimi atılacak token bulunamadı.");
        return;
    }

    // Kullanıcı adını bulalım
    const callerSnap = await admin.firestore().collection("users").doc(callerId).get();
    const callerName = callerSnap.exists ? (callerSnap.data().nickname || "Biri") : "Biri";

    const offerStr = JSON.stringify(callData.offer || {});
    const payload = {
        data: {
            type: "NEW_CALL",
            roomId: roomId,
            roomCode: callData.roomCode || roomId,
            callId: callId,
            callerName: callerName,
            // FCM data payload is limited to 4KB; if offer is large, client fetches from Firestore
            offer: offerStr.length < 2500 ? offerStr : "",
        }
    };

    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokensToNotify,
            data: payload.data,
            android: { priority: "high" },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: "default"
                    }
                }
            }
        });
        console.log("Call push notifications sent:", response.successCount);
    } catch (error) {
        console.error("Error sending call push notifications:", error);
    }
});

exports.deleteRoomAdmin = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const roomId = request.data.roomId;
    if (!roomId) {
        throw new HttpsError("invalid-argument", "Room ID is required.");
    }

    const db = admin.firestore();
    const roomRef = db.collection("rooms").doc(roomId);
    
    const doc = await roomRef.get();
    if (!doc.exists) {
        throw new HttpsError("not-found", "Room does not exist.");
    }

    const members = doc.data().members || [];
    if (members[0] !== uid) {
        throw new HttpsError("permission-denied", "Only the room creator can delete the room.");
    }

    // Helper to batch-delete a query in chunks <= 400
    const deleteQueryBatch = async (query) => {
        const snapshot = await query.get();
        if (snapshot.empty) return;
        const docs = snapshot.docs;
        for (let i = 0; i < docs.length; i += 400) {
            const batch = db.batch();
            const chunk = docs.slice(i, i + 400);
            chunk.forEach((docSnap) => batch.delete(docSnap.ref));
            await batch.commit();
        }
    };

    // Recursive delete messages
    await deleteQueryBatch(roomRef.collection("messages"));
    
    // Active games
    await deleteQueryBatch(roomRef.collection("active_games"));

    // Calls and candidates
    const callsSnap = await roomRef.collection("calls").get();
    for (const callDoc of callsSnap.docs) {
        await deleteQueryBatch(callDoc.ref.collection("callerCandidates"));
        await deleteQueryBatch(callDoc.ref.collection("calleeCandidates"));
        await callDoc.ref.delete();
    }

    await roomRef.delete();

    return { success: true };
});
