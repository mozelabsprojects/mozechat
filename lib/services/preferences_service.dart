import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static const String _roomHistoryKey = 'room_history';
  static const String _nicknameKey = 'nickname';
  static const String _backgroundKey = 'background_style';
  static const String _lastActiveRoomKey = 'last_active_room';

  static Future<String?> getLastActiveRoom() async {
    final prefs = await _getPrefs();
    return prefs.getString(_lastActiveRoomKey);
  }

  static Future<void> saveLastActiveRoom(String? roomCode) async {
    final prefs = await _getPrefs();
    if (roomCode == null) {
      await prefs.remove(_lastActiveRoomKey);
    } else {
      await prefs.setString(_lastActiveRoomKey, roomCode);
    }
  }

  static Future<String?> getRoomPassword(String roomCode) async {
    final prefs = await _getPrefs();
    return prefs.getString('lock_$roomCode');
  }

  static Future<void> saveRoomPassword(String roomCode, String? password) async {
    final prefs = await _getPrefs();
    if (password == null) {
      await prefs.remove('lock_$roomCode');
    } else {
      await prefs.setString('lock_$roomCode', password);
    }
  }

  // Geçmiş oda kodlarını getirir.
  static Future<List<String>> getRoomHistory() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_roomHistoryKey) ?? [];
  }

  // Yeni bir odayı geçmişe ekler. En fazla 5 oda saklanır.
  static Future<void> addRoomToHistory(String roomCode) async {
    final prefs = await _getPrefs();
    List<String> history = List<String>.from(prefs.getStringList(_roomHistoryKey) ?? []);

    // Eğer oda zaten listede varsa başa almak için önce sil.
    history.remove(roomCode);

    // En başa ekle.
    history.insert(0, roomCode);

    // Sadece son 5 odayı tut.
    if (history.length > 5) {
      history = history.sublist(0, 5);
    }
    await prefs.setStringList(_roomHistoryKey, history);
  }

  static Future<void> removeRoomFromHistory(String roomCode) async {
    final prefs = await _getPrefs();
    List<String> history = List<String>.from(prefs.getStringList(_roomHistoryKey) ?? []);
    history.remove(roomCode);
    await prefs.setStringList(_roomHistoryKey, history);
  }

  static Future<String?> getNickname() async {
    final prefs = await _getPrefs();
    return prefs.getString(_nicknameKey);
  }

  static Future<void> saveNickname(String? nickname) async {
    final prefs = await _getPrefs();
    if (nickname == null) {
      await prefs.remove(_nicknameKey);
    } else {
      await prefs.setString(_nicknameKey, nickname);
    }
  }

  static Future<String?> getBackgroundStyle() async {
    final prefs = await _getPrefs();
    return prefs.getString(_backgroundKey);
  }

  static Future<void> saveBackgroundStyle(String style) async {
    final prefs = await _getPrefs();
    await prefs.setString(_backgroundKey, style);
  }

  static Future<int?> getThemeIndex() async {
    final prefs = await _getPrefs();
    return prefs.getInt('theme_index');
  }

  static Future<void> saveThemeIndex(int index) async {
    final prefs = await _getPrefs();
    await prefs.setInt('theme_index', index);
  }

  static Future<int?> getSenderBubbleColor() async {
    final prefs = await _getPrefs();
    return prefs.getInt('sender_bubble_color');
  }

  static Future<void> saveSenderBubbleColor(int colorValue) async {
    final prefs = await _getPrefs();
    await prefs.setInt('sender_bubble_color', colorValue);
  }

  static Future<int?> getReceiverBubbleColor() async {
    final prefs = await _getPrefs();
    return prefs.getInt('receiver_bubble_color');
  }

  static Future<void> saveReceiverBubbleColor(int colorValue) async {
    final prefs = await _getPrefs();
    await prefs.setInt('receiver_bubble_color', colorValue);
  }

  static Future<bool> getAnimationsEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool('animations_enabled') ?? true;
  }

  static Future<void> saveAnimationsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool('animations_enabled', enabled);
  }

  static const String _incomingSoundKey = 'incoming_sound_enabled';
  static const String _outgoingSoundKey = 'outgoing_sound_enabled';
  static const String _notificationSoundKey = 'notification_sound_enabled';

  static Future<bool> getIncomingSoundEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_incomingSoundKey) ?? true;
  }

  static Future<void> saveIncomingSoundEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_incomingSoundKey, enabled);
  }

  static Future<bool> getOutgoingSoundEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_outgoingSoundKey) ?? true;
  }

  static Future<void> saveOutgoingSoundEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_outgoingSoundKey, enabled);
  }

  static Future<bool> getNotificationSoundEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_notificationSoundKey) ?? true;
  }

  static Future<void> saveNotificationSoundEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_notificationSoundKey, enabled);
  }

  // --- PINNED ROOMS & ALIASES ---
  static const String _pinnedRoomsKey = 'pinned_rooms';

  static Future<List<String>> getPinnedRooms() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_pinnedRoomsKey) ?? [];
  }

  static Future<bool> togglePinRoom(String roomCode) async {
    final prefs = await _getPrefs();
    final list = List<String>.from(prefs.getStringList(_pinnedRoomsKey) ?? []);
    bool nowPinned;
    if (list.contains(roomCode)) {
      list.remove(roomCode);
      nowPinned = false;
    } else {
      list.insert(0, roomCode);
      nowPinned = true;
    }
    await prefs.setStringList(_pinnedRoomsKey, list);
    return nowPinned;
  }

  static Future<bool> isRoomPinned(String roomCode) async {
    final prefs = await _getPrefs();
    final list = prefs.getStringList(_pinnedRoomsKey) ?? [];
    return list.contains(roomCode);
  }

  static Future<String?> getRoomAlias(String roomCode) async {
    final prefs = await _getPrefs();
    return prefs.getString('alias_$roomCode');
  }

  static Future<void> saveRoomAlias(String roomCode, String? alias) async {
    final prefs = await _getPrefs();
    if (alias == null || alias.trim().isEmpty) {
      await prefs.remove('alias_$roomCode');
    } else {
      await prefs.setString('alias_$roomCode', alias.trim());
    }
  }

  // --- STEALTH & PRIVACY FEATURES ---
  static const String _anonymousVoiceKey = 'anonymous_voice_enabled';
  static const String _tapToRevealKey = 'tap_to_reveal_enabled';
  static const String _panicCamouflageKey = 'panic_camouflage_enabled';

  static Future<bool> getAnonymousVoiceEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_anonymousVoiceKey) ?? false;
  }

  static Future<void> saveAnonymousVoiceEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_anonymousVoiceKey, enabled);
  }

  static Future<bool> getTapToRevealEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_tapToRevealKey) ?? false;
  }

  static Future<void> saveTapToRevealEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_tapToRevealKey, enabled);
  }

  static Future<bool> getPanicCamouflageEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_panicCamouflageKey) ?? false;
  }

  static Future<void> savePanicCamouflageEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_panicCamouflageKey, enabled);
  }
}
