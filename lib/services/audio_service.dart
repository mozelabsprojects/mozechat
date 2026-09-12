import 'package:audioplayers/audioplayers.dart';
import 'preferences_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Cached sound settings to avoid async SharedPreferences on every play
  bool _outgoingSoundEnabled = true;
  bool _incomingSoundEnabled = true;
  bool _initialized = false;

  AudioService._internal();

  /// Call once at startup or lazily to load cached settings
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _outgoingSoundEnabled = await PreferencesService.getOutgoingSoundEnabled();
    _incomingSoundEnabled = await PreferencesService.getIncomingSoundEnabled();
    _initialized = true;
  }

  /// Call this when user changes sound settings to update cache
  void updateCachedSettings({bool? outgoing, bool? incoming}) {
    if (outgoing != null) _outgoingSoundEnabled = outgoing;
    if (incoming != null) _incomingSoundEnabled = incoming;
  }

  Future<void> playSound(String path) async {
    await _ensureInitialized();
    
    // Check against actual file names used in the app
    if (path.contains('sentlnx')) {
      if (!_outgoingSoundEnabled) return;
    } else if (path.contains('gtanotification')) {
      if (!_incomingSoundEnabled) return;
    }
    
    try {
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      // Ignore if file is missing
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
