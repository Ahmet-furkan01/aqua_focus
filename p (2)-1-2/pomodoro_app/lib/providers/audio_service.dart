import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal() {
    _init();
  }

  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isSoundEnabled = false;

  bool get isPlaying => _isPlaying;
  bool get isSoundEnabled => _isSoundEnabled;

  Future<void> _init() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      notifyListeners();
    });

    // Load sound preference
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool('sound_enabled') ?? false;
    notifyListeners();
  }

  Future<void> toggleSound(bool soundEnabled) async {
    if (_isSoundEnabled == soundEnabled) return; // Prevent unnecessary updates

    _isSoundEnabled = soundEnabled;

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', soundEnabled);

    if (soundEnabled && !_isPlaying) {
      await play();
    } else if (!soundEnabled && _isPlaying) {
      await stop();
    }
    notifyListeners();
  }

  Future<void> play() async {
    if (!_isSoundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource('sounds/Ocean.mp3'));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> playSound(String soundPath) async {
    if (!_isSoundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource(soundPath));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing sound: $e');
    }
  }

  Future<void> resume() async {
    if (!_isSoundEnabled) return;

    try {
      await _audioPlayer.resume();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming sound: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
