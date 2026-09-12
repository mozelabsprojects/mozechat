import 'package:audioplayers/audioplayers.dart';
import 'preferences_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioService._internal();

  Future<void> playSound(String path) async {
    bool soundsEnabled = true;
    if (path.contains('messagesent')) {
      soundsEnabled = await PreferencesService.getOutgoingSoundEnabled();
    } else if (path.contains('messagerecieved')) {
      soundsEnabled = await PreferencesService.getIncomingSoundEnabled();
    }
    if (!soundsEnabled) return;
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
