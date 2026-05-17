import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Map<String, dynamic>? _currentTrack;
  String? _localAudioPath;
  double _volume = 1.0;
  // Expose getters so other widgets can read the state
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;

  Map<String, dynamic>? get currentTrack => _currentTrack;
  AudioPlayer get player => _audioPlayer;
  double get volume => _volume;

  AudioPlayerService() {
    _setupAudioPlayer();
  }


  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners(); // Tell widgets to update when state changes
    });
    
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _duration = newDuration;
      notifyListeners();
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((event) async {
       // Simple complete logic for now
       await _audioPlayer.seek(Duration.zero);
       await _audioPlayer.pause();
       _isPlaying = false;
       _position = Duration.zero;
       notifyListeners();
    });
  }

  // Simplified play track function
  Future<void> playTrack(Map<String, dynamic> track) async {
      _currentTrack = track;
      notifyListeners();
      
      String audioUrl = track['audio_file_url'];
      var file = await DefaultCacheManager().getSingleFile(audioUrl);
      _localAudioPath = file.path; 

      await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
  }

  Future<void> setVolume(double value) async {
    _volume = value;
    await _audioPlayer.setVolume(_volume);
    notifyListeners(); 
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }
}