import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';
import '../services/e2ee_service.dart';
import '../services/preferences_service.dart';
import '../services/notification_service.dart';
import '../services/bot_service.dart';
import '../services/audio_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  String? _nickname;
  String? _roomCode;
  String? _currentAesKeyBase64;
  DateTime? _roomJoinTime;
  String? _errorMessage;
  bool _isLoading = false;

  // For multi-media ETA
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  String _uploadEta = '';
  
  bool get isUploadingMedia => _isUploadingMedia;
  double get uploadProgress => _uploadProgress;
  String get uploadEta => _uploadEta;

  List<Message> _firestoreMessages = [];
  List<Message> _localMessages = [];
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;

  int _memberCount = 1;
  bool _isOtherOnline = false;
  bool _isOtherTyping = false;
  DateTime? _otherLastSeen;
  String? _lastMessageId; // Yeni mesajları takip etmek için
  Message? _replyToMessage; // Yanıtlanan mesaj
  bool _isUserInChatScreen = false; // Kullanıcı sohbet ekranında mı?
  String _backgroundStyle = 'solid'; // matrix, solid, gradient
  
  BotService? _botService;
  final Set<String> _processedCommandIds = {};

  Future<void> _playSound(String path) async {
    await AudioService().playSound(path);
  }


  // God Mode Features
  List<String> _notes = [];

  // Cached messages list (dirty flag pattern)
  List<Message>? _cachedMessages;

  List<String> get notes => _notes;

  String? get nickname => _nickname;
  String? get roomCode => _roomCode;
  String? get currentUserId => _repository.currentUserId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  List<Message> get messages {
    if (_cachedMessages != null) return _cachedMessages!;
    final all = [..._firestoreMessages, ..._localMessages];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _cachedMessages = all;
    return all;
  }

  void _invalidateMessagesCache() {
    _cachedMessages = null;
  }

  int get memberCount => _memberCount;
  bool get isOtherOnline => _isOtherOnline;
  bool get isOtherTyping => _isOtherTyping;
  DateTime? get otherLastSeen => _otherLastSeen;
  Message? get replyToMessage => _replyToMessage;
  String get backgroundStyle => _backgroundStyle;

  int _messageLimit = 50;
  bool _isAnonymousVoice = false;
  bool get isAnonymousVoice => _isAnonymousVoice;
  
  void toggleAnonymousVoice(bool val) {
    _isAnonymousVoice = val;
    notifyListeners();
  }
  
  bool get hasMoreMessages => _firestoreMessages.length >= _messageLimit;

  void loadMoreMessages() {
    _messageLimit += 50;
    _listenToMessages();
    notifyListeners();
  }

  Future<void> initializeState() async {
    _nickname = await PreferencesService.getNickname();
    _backgroundStyle =
        await PreferencesService.getBackgroundStyle() ?? 'matrix';
    
    _botService = BotService(
      sendBotMessage: (msg) {
        sendBotMessage(msg);
      },
      clearMessages: (n) {
        if (_roomCode != null) _repository.deleteLastNMessages(_roomCode!, n, aesKeyBase64: _currentAesKeyBase64);
      },
      addNote: (note) {
        if (_roomCode != null) _repository.addNoteToRoom(_roomCode!, note);
      },
      getNotes: () => notes,
      scheduleReminder: (msg, secs) {
        Future.delayed(Duration(seconds: secs), () {
          sendBotMessage("⏰ Hatırlatma: $msg");
          NotificationService.showMessageNotification(
            title: "Moze bot alarm",
            body: msg,
            payload: _roomCode ?? 'unknown',
          );
        });
      },
    );
    notifyListeners();
  }

  void setNickname(String name) {
    _nickname = name;
    PreferencesService.saveNickname(name);
    notifyListeners();
  }

  void setBackgroundStyle(String style) {
    _backgroundStyle = style;
    PreferencesService.saveBackgroundStyle(style);
    notifyListeners();
  }

  void replyTo(Message? msg) {
    _replyToMessage = msg;
    notifyListeners();
  }

  Future<void> sendMedia(
    String mediaUrl,
    String mediaType, {
    String? localId,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (_roomCode == null || _nickname == null) return;
    try {
      final replyId = _replyToMessage?.id;
      _replyToMessage = null;
      notifyListeners();
      const initialStatus = 'sent';
      await _repository.sendMessage(
        _roomCode!,
        '[Media Attachment]',
        _nickname!,
        replyToMessageId: replyId,
        type: mediaType,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        mediaType: mediaType,
        localId: localId,
        status: initialStatus,
        metadata: metadata,
        aesKeyBase64: _currentAesKeyBase64,
      );
      _playSound('sounds/sentlnx.mp3');
    } catch (e) {
      if (localId != null) {
        updateLocalMessageStatus(localId, 'failed');
      }
      _setError(e.toString());
    }
  }

  Future<void> sendMediaList(
    List<Map<String, dynamic>> mediaList, {
    String? localId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_roomCode == null || _nickname == null) return;
    try {
      final replyId = _replyToMessage?.id;
      _replyToMessage = null;
      notifyListeners();
      const initialStatus = 'sent';
      
      final enhancedMetadata = metadata ?? {};
      enhancedMetadata['mediaList'] = mediaList;

      await _repository.sendMessage(
        _roomCode!,
        '[Media Album]',
        _nickname!,
        replyToMessageId: replyId,
        type: 'media_group',
        localId: localId,
        status: initialStatus,
        metadata: enhancedMetadata,
        aesKeyBase64: _currentAesKeyBase64,
      );
      _playSound('sounds/sentlnx.mp3');
    } catch (e) {
      if (localId != null) {
        updateLocalMessageStatus(localId, 'failed');
      }
      _setError(e.toString());
    }
  }

  void setUploadStatus(bool isUploading, double progress, String eta) {
    _isUploadingMedia = isUploading;
    _uploadProgress = progress;
    _uploadEta = eta;
    notifyListeners();
  }

  Future<void> sendLocation(double lat, double lng, String locationName, {Map<String, dynamic>? metadata}) async {
    if (_roomCode == null || _nickname == null) return;
    try {
      final replyId = _replyToMessage?.id;
      _replyToMessage = null;
      notifyListeners();
      const initialStatus = 'sent';
      await _repository.sendMessage(
        _roomCode!,
        '[Location]',
        _nickname!,
        replyToMessageId: replyId,
        type: 'location',
        locationLat: lat,
        locationLng: lng,
        locationName: locationName,
        status: initialStatus,
        metadata: metadata,
        aesKeyBase64: _currentAesKeyBase64,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> exportChatHistoryAsText() async {
    if (_roomCode == null) return;
    try {
      _setLoading(true);
      final textData = await _repository.fetchAllMessagesAsText(_roomCode!, aesKeyBase64: _currentAesKeyBase64);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mozechat_history_$_roomCode.txt');
      await file.writeAsString(textData);
      _setLoading(false);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'MozeChat History Export');
    } catch (e) {
      _setLoading(false);
      _setError('Export failed: $e');
    }
  }

  Future<void> initializeSession(String seedPhrase) async {
    try {
      _setLoading(true);
      await _repository.initializeSession(seedPhrase);
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
    }
  }

  Future<void> restoreIdentity(String seedPhrase) async {
    try {
      _setLoading(true);
      await _repository.restoreIdentity(seedPhrase);
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
    }
  }

  Future<bool> joinRoom(String code) async {
    try {
      _setLoading(true);
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);
      
      if (!isOffline) {
        await _repository.joinOrCreateRoom(code);
        
        final doc = await _repository.getRoomMetadata(code);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final notesData = data['notes'] as List<dynamic>? ?? [];
          _notes = notesData.cast<String>();
        }
      }
      _roomCode = code;
      _roomJoinTime = DateTime.now();

      // Geçmişe ekle
      await PreferencesService.addRoomToHistory(code);
      await PreferencesService.saveLastActiveRoom(code);

      NotificationService.currentActiveRoomCode = code;
      NotificationService.clearNotificationsForRoom(code);

      _listenToRoom();
      _listenToMessages();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> joinExplicitRoom(String pseudoRoomCode) async {
    try {
      _setLoading(true);
      
      _roomCode = pseudoRoomCode; // This acts as the secure room code
      _roomJoinTime = DateTime.now();

      // Fetch Room to get encryptedKeys
      try {
        final roomDoc = await _repository.getRoomMetadata(pseudoRoomCode);
        if (roomDoc.exists) {
          final data = roomDoc.data() as Map<String, dynamic>? ?? {};
          final encryptedKeys = data['encryptedKeys'] as Map<String, dynamic>?;
          final uid = currentUserId;
          if (encryptedKeys != null && uid != null) {
            final myEncKey = encryptedKeys[uid];
            if (myEncKey != null) {
              _currentAesKeyBase64 = await E2EEService().decryptRoomKey(myEncKey, uid);
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting room E2EE key: $e');
      }

      NotificationService.currentActiveRoomCode = pseudoRoomCode;
      NotificationService.clearNotificationsForRoom(pseudoRoomCode);

      _listenToRoom();
      _listenToMessages();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }


  Future<void> sendMessage(String text, {
    String? senderIdOverride,
    String? nicknameOverride,
    Map<String, dynamic>? metadata,
  }) async {
    if (_roomCode == null || text.trim().isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.contains(ConnectivityResult.none);

    final replyId = _replyToMessage?.id;
    _replyToMessage = null;
    notifyListeners();

    if (isOffline) {
      final localId = const Uuid().v4();
      addLocalMessage(
        Message(
          id: 'temp_$localId',
          senderId: senderIdOverride ?? currentUserId ?? '',
          text: text.trim(),
          nickname: nicknameOverride ?? _nickname ?? 'Unknown',
          timestamp: DateTime.now(),
          type: 'text',
          status: 'failed',
          localId: localId,
          replyToMessageId: replyId,
          metadata: metadata,
        ),
      );
      return;
    }

    try {
      const initialStatus = 'sent';
      await _repository.sendMessage(
        _roomCode!,
        text.trim(),
        nicknameOverride ?? _nickname ?? 'Unknown',
        senderIdOverride: senderIdOverride,
        replyToMessageId: replyId,
        status: initialStatus,
        metadata: metadata,
        aesKeyBase64: _currentAesKeyBase64,
      );
      _playSound('sounds/sentlnx.mp3');
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> retryMessage(Message msg) async {
    if (msg.localId == null) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _setError("Internet is still disconnected.");
      return;
    }

    // Yükleniyor durumuna al
    updateLocalMessageStatus(msg.localId!, 'pending');

    if (msg.type == 'text') {
      try {
        const initialStatus = 'sent';
        await _repository.sendMessage(
          _roomCode!,
          msg.text,
          msg.nickname,
          replyToMessageId: msg.replyToMessageId,
          localId: msg.localId,
          status: initialStatus,
          aesKeyBase64: _currentAesKeyBase64,
        );
      } catch (e) {
        updateLocalMessageStatus(msg.localId!, 'failed');
      }
    } else {
      // Medya (Resim/Video/Ses) retry için path yoksa geç
      updateLocalMessageStatus(msg.localId!, 'failed');
    }
  }

  Future<void> sendBotMessage(
    String text, {
    String botName = "Moze bot",
  }) async {
    if (_roomCode == null) return;
    try {
      await _repository.sendMessage(
        _roomCode!,
        text,
        botName,
        senderIdOverride: 'system_bot',
        aesKeyBase64: _currentAesKeyBase64,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_roomCode != null) {
      await _repository.deleteMessage(_roomCode!, messageId, aesKeyBase64: _currentAesKeyBase64);
    }
  }

  Future<void> deleteMessages(List<String> messageIds) async {
    if (_roomCode != null && messageIds.isNotEmpty) {
      await _repository.deleteMessages(_roomCode!, messageIds, aesKeyBase64: _currentAesKeyBase64);
    }
  }

  Future<void> hardDeleteMessage(String messageId) async {
    if (_roomCode != null) {
      await _repository.hardDeleteMessage(_roomCode!, messageId);
    }
  }

  Future<void> starMessage(String messageId, bool isStarred) async {
    if (_roomCode != null) {
      await _repository.toggleStarMessage(_roomCode!, messageId, isStarred);
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    if (_roomCode != null) {
      await _repository.reactToMessage(_roomCode!, messageId, emoji);
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    if (_roomCode != null) {
      await _repository.editMessage(_roomCode!, messageId, newText, aesKeyBase64: _currentAesKeyBase64);
    }
  }

  void _listenToRoom() {
    _roomSubscription?.cancel();
    if (_roomCode != null) {
      _roomSubscription = _repository.listenToRoom(_roomCode!).listen((
        snapshot,
      ) {
        if (!snapshot.exists) {
          _setError("This node has been destroyed.");
          leaveRoom();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          final members = data['members'] as List<dynamic>? ?? [];
          final currentUid = _repository.currentUserId;

          if (!members.contains(currentUid)) {
            _setError("You have been kicked from this node.");
            leaveRoom();
            return;
          }

          _memberCount = members.length;

          final presence = data['presence'] as Map<String, dynamic>? ?? {};
          final typing = data['typing'] as Map<String, dynamic>? ?? {};
          final lastSeenMap = data['lastSeen'] as Map<String, dynamic>? ?? {};

          // Merge notes from room metadata (eliminates duplicate listener)
          final notesData = data['notes'] as List<dynamic>? ?? [];
          _notes = notesData.cast<String>();

          _isOtherOnline = false;
          _isOtherTyping = false;
          _otherLastSeen = null;

          presence.forEach((key, value) {
            if (key != currentUid) {
              if (value == true) {
                _isOtherOnline = true;
              } else {
                final ls = lastSeenMap[key];
                if (ls is Timestamp) {
                  final seenDate = ls.toDate();
                  // Pick the most recent lastSeen among offline users
                  if (_otherLastSeen == null || seenDate.isAfter(_otherLastSeen!)) {
                    _otherLastSeen = seenDate;
                  }
                }
              }
            }
          });

          typing.forEach((key, value) {
            if (key != currentUid && value == true) {
              _isOtherTyping = true;
            }
          });

          notifyListeners();
        }
      });
    }
  }

  void _listenToMessages() {
    _messagesSubscription?.cancel();
    if (_roomCode != null) {
      _messagesSubscription = _repository
          .listenToMessages(_roomCode!, limit: _messageLimit, aesKeyBase64: _currentAesKeyBase64)
          .listen(
            (msgs) {
              bool isInitialLoad = _firestoreMessages.isEmpty;
              _firestoreMessages = msgs;

              // Local mesajları temizle (Eğer firestore'a ulaşmışlarsa)
              final incomingLocalIds = msgs.map((m) => m.localId).whereType<String>().toSet();
              if (incomingLocalIds.isNotEmpty) {
                _localMessages.removeWhere(
                  (localMsg) => incomingLocalIds.contains(localMsg.localId),
                );
              }

              if (msgs.isNotEmpty) {
                final latestMsg = msgs.first;
                final currentUid = _repository.currentUserId;

                if (latestMsg.senderId != currentUid &&
                    latestMsg.id != _lastMessageId) {
                  _lastMessageId = latestMsg.id;
                  
                  if (!isInitialLoad) {
                    _playSound('sounds/gtanotification.mp3');
                  }
                }

                // Status update logic:
                // 1. If user is IN the chat screen -> mark as 'read'
                // 2. If user is in the app but NOT in chat screen -> mark as 'delivered'
                List<String> toRead = [];
                List<String> toDeliver = [];
                for (var msg in msgs) {
                  if (msg.senderId == currentUid) continue;
                  if (_isUserInChatScreen && msg.status != 'read') {
                    toRead.add(msg.id);
                  } else if (!_isUserInChatScreen && msg.status == 'sent') {
                    toDeliver.add(msg.id);
                  }
                }
                if (toRead.isNotEmpty) {
                  _repository.updateMessagesStatusBatch(
                    _roomCode!,
                    toRead,
                    'read',
                  );
                }
                if (toDeliver.isNotEmpty) {
                  _repository.updateMessagesStatusBatch(
                    _roomCode!,
                    toDeliver,
                    'delivered',
                  );
                }
                // Removed Ghost Mode
                // Bot command processing
                for (var msg in msgs) {
                  if (_processedCommandIds.contains(msg.id)) break; // Stop checking older messages
                  
                  // Ignore commands from before the user joined the room
                  if (_roomJoinTime != null && msg.timestamp.isBefore(_roomJoinTime!)) {
                    _processedCommandIds.add(msg.id);
                    continue;
                  }

                  _processedCommandIds.add(msg.id);
                  if (msg.text.startsWith('!') && msg.senderId != 'system_bot') {
                    if (currentUid == msg.senderId) {
                      _botService?.komutCalistir(msg.text, msg.senderId, msg.nickname);
                    } else {
                      // Karşı taraftan gelen broadcast komutlar (!hatırlat vb.) lokal olarak çalıştırılır
                      final args = msg.text.trim().split(' ');
                      if (args[0].toLowerCase() == '!hatırlat' && args.length >= 3) {
                        int? secs = int.tryParse(args.last);
                        if (secs != null) {
                          final reminderMsg = args.sublist(1, args.length - 1).join(" ");
                          Future.delayed(Duration(seconds: secs), () {
                            NotificationService.showMessageNotification(
                              title: "Moze bot alarm",
                              body: reminderMsg,
                              payload: _roomCode ?? 'unknown',
                            );
                          });
                        }
                      }
                    }
                  }
                }
              }

              _invalidateMessagesCache();
              notifyListeners();
            },
            onError: (e) {
              _setError("Mesajlar alınamadı: $e");
            },
          );
    }
  }

  Future<void> updatePresence(bool isOnline) async {
    if (_roomCode != null) {
      await _repository.updatePresence(_roomCode!, isOnline);
    }
  }

  Future<void> updateTyping(bool isTyping) async {
    if (_roomCode != null) {
      await _repository.updateTypingStatus(_roomCode!, isTyping);
    }
  }

  void setUserInChat(bool value) {
    _isUserInChatScreen = value;
    // When user enters chat screen, immediately mark delivered messages as read
    if (value && _roomCode != null) {
      final currentUid = _repository.currentUserId;
      final toRead = <String>[];
      for (var msg in _firestoreMessages) {
        if (msg.senderId != currentUid && msg.status != 'read') {
          toRead.add(msg.id);
        }
      }
      if (toRead.isNotEmpty) {
        _repository.updateMessagesStatusBatch(_roomCode!, toRead, 'read');
      }
    }
    notifyListeners();
  }

  void leaveRoom() {
    _isUserInChatScreen = false;
    updatePresence(false);
    NotificationService.currentActiveRoomCode = null;
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    // Oda geçmişten SİLİNMEZ, sadece abonelik biter.
    _roomCode = null;
    _firestoreMessages = [];
    _localMessages = [];
    _invalidateMessagesCache();
    _lastMessageId = null;
    _roomJoinTime = null;
    _processedCommandIds.clear();
    PreferencesService.saveLastActiveRoom(null);
    notifyListeners();
  }

  // Local message handling
  void addLocalMessage(Message msg) {
    _localMessages.add(msg);
    _invalidateMessagesCache();
    notifyListeners();
  }

  void updateLocalMessageStatus(String localId, String status) {
    final index = _localMessages.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      final old = _localMessages[index];
      _localMessages[index] = Message(
        id: old.id,
        senderId: old.senderId,
        text: old.text,
        nickname: old.nickname,
        timestamp: old.timestamp,
        type: old.type,
        mediaUrl: old.mediaUrl,
        mediaType: old.mediaType,
        status: status,
        localId: old.localId,
      );
      _invalidateMessagesCache();
      notifyListeners();
    }
  }

  void removeLocalMessage(String localId) {
    _localMessages.removeWhere((m) => m.localId == localId);
    _invalidateMessagesCache();
    notifyListeners();
  }

  Future<bool> isCreator(String roomCode) async {
    return await _repository.isCreator(roomCode);
  }

  Future<void> destroyRoom(String roomCode) async {
    await _repository.destroyRoom(roomCode);
    await PreferencesService.removeRoomFromHistory(roomCode);
    final lastActive = await PreferencesService.getLastActiveRoom();
    if (lastActive == roomCode) {
      await PreferencesService.saveLastActiveRoom(null);
    }
    notifyListeners();
  }

  Future<void> kickMembers(String roomCode) async {
    await _repository.kickMembers(roomCode);
    notifyListeners();
  }

  Future<void> removeRoomLocal(String roomCode) async {
    await _repository.leaveRoom(roomCode);
    await PreferencesService.removeRoomFromHistory(roomCode);
    final lastActive = await PreferencesService.getLastActiveRoom();
    if (lastActive == roomCode) {
      await PreferencesService.saveLastActiveRoom(null);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    updatePresence(false);
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }
}
