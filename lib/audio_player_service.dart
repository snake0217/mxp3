import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:math';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  Map<String, dynamic>? _currentTrack;
  String? _localAudioPath;
  double _volume = 1.0;

  // === NUEVAS VARIABLES PARA LA COLA DE REPRODUCCIÓN ===
  List<Map<String, dynamic>> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  bool _isRepeat = false;

  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  Map<String, dynamic>? get currentTrack => _currentTrack;
  AudioPlayer get player => _audioPlayer;
  double get volume => _volume;
  
  // Getters para los botones
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;

  AudioPlayerService() {
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _duration = newDuration;
      notifyListeners();
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });

    // === MAGIA: AUTO-AVANZAR AL TERMINAR LA CANCIÓN ===
    _audioPlayer.onPlayerComplete.listen((event) async {
       if (_isRepeat) {
         // Si repetir está activo, volvemos a iniciar la misma canción
         await _audioPlayer.seek(Duration.zero);
         await _audioPlayer.resume();
       } else {
         // Si no, saltamos a la siguiente automáticamente
         await playNext();
       }
    });
  }

  // === NUEVAS FUNCIONES DE ESTADO ===
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  // Cargar una lista entera de canciones
  Future<void> setQueueAndPlay(List<dynamic> tracks, int startIndex, {String? coverUrl, String? artistName}) async {
    // Convertimos la lista cruda en nuestra cola tipada
    _queue = List<Map<String, dynamic>>.from(tracks);
    
    // Nos aseguramos de que todas las canciones en la cola tengan su portada y artista
    for (var track in _queue) {
      track['cover_image_url'] ??= coverUrl;
      track['artist_name'] ??= artistName;
    }
    
    await playFromQueue(startIndex);
  }

  // Reproducir un índice específico de la cola
  Future<void> playFromQueue(int index) async {
    if (_queue.isEmpty || index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await playTrack(_queue[_currentIndex]);
  }

  // Botón Siguiente
  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    
    int nextIndex;
    if (_isShuffle) {
      // Modo Aleatorio: Elegir un índice al azar
      nextIndex = Random().nextInt(_queue.length);
      // Evitar que toque la misma canción seguida si hay más de 1
      if (_queue.length > 1 && nextIndex == _currentIndex) {
        nextIndex = (nextIndex + 1) % _queue.length;
      }
    } else {
      // Modo Normal: Siguiente pista, y si es la última, vuelve a la primera
      nextIndex = (_currentIndex + 1) % _queue.length;
    }
    
    await playFromQueue(nextIndex);
  }

  // Botón Anterior
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    
    // Si la canción lleva más de 3 segundos, "Anterior" simplemente la reinicia
    if (_position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1; // Si está en la primera, salta a la última
    }
    await playFromQueue(prevIndex);
  }

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

  Future<void> pause() async { await _audioPlayer.pause(); }
  Future<void> resume() async { await _audioPlayer.resume(); }
  Future<void> seek(Duration position) async { await _audioPlayer.seek(position); }
}