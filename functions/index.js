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

    const payload = {
        data: {
            type: "NEW_CALL",
            roomId: roomId,
            callId: callId,
            callerName: callerName,
            offer: JSON.stringify(callData.offer || {}),
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

    // Recursive delete messages
    const messages = await roomRef.collection("messages").get();
    const batch = db.batch();
    messages.docs.forEach((msg) => {
        batch.delete(msg.ref);
    });
    
    // Active games
    const games = await roomRef.collection("active_games").get();
    games.docs.forEach((game) => {
        batch.delete(game.ref);
    });

    batch.delete(roomRef);
    
    await batch.commit();

    return { success: true };
});
