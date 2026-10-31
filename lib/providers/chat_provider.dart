import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';
import '../services/e2ee_service.dart';
import '../services/crypto_service.dart';
import '../services/preferences_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../utils/app_strings.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  String? _nickname;
  String? _roomCode;
  String? _currentAesKeyBase64;
  String? _errorMessage;
  bool _isLoading = false;

  // For multi-media ETA
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  String _uploadEta = '';
  DateTime _lastUploadNotify = DateTime(0);

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
  String? _lastMessageId;
  Message? _replyToMessage;
  bool _isUserInChatScreen = false;
  String _backgroundStyle = 'solid';

  Future<void> _playSound(String path) async {
    await AudioService().playSound(path);
  }

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

  bool _tapToRevealEnabled = false;
  bool get tapToRevealEnabled => _tapToRevealEnabled;

  bool _panicCamouflageEnabled = false;
  bool get panicCamouflageEnabled => _panicCamouflageEnabled;

  void toggleAnonymousVoice(bool val) {
    _isAnonymousVoice = val;
    PreferencesService.saveAnonymousVoiceEnabled(val);
    notifyListeners();
  }

  void toggleTapToReveal(bool val) {
    _tapToRevealEnabled = val;
    PreferencesService.saveTapToRevealEnabled(val);
    notifyListeners();
  }

  void togglePanicCamouflage(bool val) {
    _panicCamouflageEnabled = val;
    PreferencesService.savePanicCamouflageEnabled(val);
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
    _isAnonymousVoice = await PreferencesService.getAnonymousVoiceEnabled();
    _tapToRevealEnabled = await PreferencesService.getTapToRevealEnabled();
    _panicCamouflageEnabled = await PreferencesService.getPanicCamouflageEnabled();
    notifyListeners();
  }

  void setNickname(String name) {
    _nickname = name;
    PreferencesService.saveNickname(name);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nickname': name,
      }, SetOptions(merge: true));
    }
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

    final now = DateTime.now();
    if (!isUploading ||
        progress == 0.0 ||
        progress >= 1.0 ||
        now.difference(_lastUploadNotify).inMilliseconds >= 100) {
      _lastUploadNotify = now;
      notifyListeners();
    }
  }

  Future<void> sendLocation(
    double lat,
    double lng,
    String locationName, {
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
    final strings = AppStrings(await PreferencesService.getLanguage());
    try {
      _setLoading(true);
      final textData = await _repository.fetchAllMessagesAsText(
        _roomCode!,
        aesKeyBase64: _currentAesKeyBase64,
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mozechat_history_$_roomCode.txt');
      await file.writeAsString(textData);
      _setLoading(false);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: strings.exportHistorySubject);
    } catch (e) {
      _setLoading(false);
      _setError('${strings.exportFailedPrefix}: $e');
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
      String resolvedCode = code.trim();
      if (resolvedCode.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(resolvedCode)) {
        final history = await PreferencesService.getRoomHistory();
        for (final hCode in history) {
          if (CryptoService.deriveRoomId(hCode) == resolvedCode) {
            resolvedCode = hCode;
            break;
          }
        }
      }

      _roomCode = resolvedCode;
      _firestoreMessages = [];
      _localMessages = [];
      _cachedMessages = null;
      _setLoading(true);
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);

      if (!isOffline) {
        await _repository.joinOrCreateRoom(resolvedCode);

        final doc = await _repository.getRoomMetadata(resolvedCode);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final notesData = data['notes'] as List<dynamic>? ?? [];
          _notes = notesData.cast<String>();
        }
      }

      await PreferencesService.addRoomToHistory(resolvedCode);
      await PreferencesService.saveLastActiveRoom(resolvedCode);

      NotificationService.clearNotificationsForRoom(resolvedCode);
      if (_isUserInChatScreen) {
        NotificationService.setActiveChatRoom(resolvedCode, inChat: true);
      }

      _listenToRoom();
      _listenToMessages();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> joinExplicitRoom(String pseudoRoomCode) async {
    try {
      _setLoading(true);

      _roomCode = pseudoRoomCode;

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

      NotificationService.clearNotificationsForRoom(pseudoRoomCode);
      if (_isUserInChatScreen) {
        NotificationService.setActiveChatRoom(pseudoRoomCode, inChat: true);
      }

      _listenToRoom();
      _listenToMessages();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<void> sendMessage(
    String text, {
    String? senderIdOverride,
    String? nicknameOverride,
    Map<String, dynamic>? metadata,
  }) async {
    if (_roomCode == null || text.trim().isEmpty) return;

    final replyId = _replyToMessage?.id;
    _replyToMessage = null;
    notifyListeners();

    final localId = const Uuid().v4();
    try {
      const initialStatus = 'sent';
      await _repository.sendMessage(
        _roomCode!,
        text.trim(),
        nicknameOverride ?? _nickname ?? 'Unknown',
        senderIdOverride: senderIdOverride,
        replyToMessageId: replyId,
        localId: localId,
        status: initialStatus,
        metadata: metadata,
        aesKeyBase64: _currentAesKeyBase64,
      );
      _playSound('sounds/sentlnx.mp3');
    } catch (e) {
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
      _setError(e.toString());
    }
  }

  Future<void> retryMessage(Message msg) async {
    if (msg.localId == null) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      final strings = AppStrings(await PreferencesService.getLanguage());
      _setError(strings.internetDisconnectedError);
      return;
    }

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
      updateLocalMessageStatus(msg.localId!, 'failed');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_roomCode != null) {
      await _repository.deleteMessage(
        _roomCode!,
        messageId,
        aesKeyBase64: _currentAesKeyBase64,
      );
    }
  }

  Future<void> deleteMessages(List<String> messageIds) async {
    if (_roomCode != null && messageIds.isNotEmpty) {
      await _repository.deleteMessages(
        _roomCode!,
        messageIds,
        aesKeyBase64: _currentAesKeyBase64,
      );
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

  Future<void> editMessage(
    String messageId,
    String newText, {
    bool isGameMove = false,
  }) async {
    if (_roomCode != null) {
      await _repository.editMessage(
        _roomCode!,
        messageId,
        newText,
        aesKeyBase64: _currentAesKeyBase64,
        isGameMove: isGameMove,
      );
    }
  }

  void _listenToRoom() {
    _roomSubscription?.cancel();
    if (_roomCode != null) {
      _roomSubscription = _repository.listenToRoom(_roomCode!).listen((
        snapshot,
      ) async {
        if (!snapshot.exists) {
          final strings = AppStrings(await PreferencesService.getLanguage());
          _setError(strings.nodeDestroyedError);
          leaveRoom();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          final members = data['members'] as List<dynamic>? ?? [];
          final currentUid = _repository.currentUserId;

          if (!members.contains(currentUid)) {
            final strings = AppStrings(await PreferencesService.getLanguage());
            _setError(strings.kickedFromNodeError);
            leaveRoom();
            return;
          }

          _memberCount = members.length;

          final presence = data['presence'] as Map<String, dynamic>? ?? {};
          final typing = data['typing'] as Map<String, dynamic>? ?? {};
          final lastSeenMap = data['lastSeen'] as Map<String, dynamic>? ?? {};

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
                  if (_otherLastSeen == null || seenDate.isAfter(_otherLastSeen!)) {
                    _otherLastSeen = seenDate;
                  }
                }
              }
            }
          });

          final oldTyping = _isOtherTyping;
          bool newTyping = false;
          typing.forEach((key, value) {
            if (key != currentUid && value == true) {
              newTyping = true;
            }
          });
          _isOtherTyping = newTyping;

          if (oldTyping != newTyping) {
            notifyListeners();
          }
        }
      });
    }
  }

  void _listenToMessages() {
    _messagesSubscription?.cancel();
    if (_roomCode != null) {
      _messagesSubscription = _repository
          .listenToMessages(
            _roomCode!,
            limit: _messageLimit,
            aesKeyBase64: _currentAesKeyBase64,
          )
          .listen(
            (msgs) {
              bool isInitialLoad = _firestoreMessages.isEmpty;
              _firestoreMessages = msgs;

              final incomingLocalIds = msgs
                  .map((m) => m.localId)
                  .whereType<String>()
                  .toSet();
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
              }

              _invalidateMessagesCache();
              notifyListeners();
            },
            onError: (e) {
              _setError('$e');
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
    NotificationService.setActiveChatRoom(_roomCode, inChat: value);

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
    updateTyping(false);
    NotificationService.setActiveChatRoom(null, inChat: false);
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    _roomCode = null;
    _firestoreMessages = [];
    _localMessages = [];
    _invalidateMessagesCache();
    _lastMessageId = null;
    PreferencesService.saveLastActiveRoom(null);
    notifyListeners();
  }

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
    updateTyping(false);
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
