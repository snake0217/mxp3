import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator/palette_generator.dart'; 
import 'package:provider/provider.dart'; // <-- IMPORTAMOS PROVIDER
import 'dart:convert';
import 'dart:ui';

import '../constants.dart';
import '../audio_player_service.dart'; // <-- IMPORTAMOS EL SERVICIO

class PlayerScreen extends StatefulWidget {
  final String albumId;
  final String albumTitle;
  final String artistName;
  final String coverUrl;
  final String? initialTrackId;

  const PlayerScreen({
    Key? key,
    required this.albumId,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
    this.initialTrackId,
  }) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  final Color mxp3AccentColor = const Color(0xFFE6007E);
  
  Color _color1 = const Color(0xFF121212);
  Color _color2 = const Color(0xFF1C1C1C);
  Color _color3 = const Color(0xFF2A2A2A);
  Color _color4 = const Color(0xFF000000);

  bool _isLoading = true;
  bool _isDragging = false; 
  double _dragValue = 0.0;  


  bool _isFavorite = false;

  late AnimationController _fastRotationController;
  late AnimationController _movementController;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _moveAnimation1;
  late Animation<Offset> _moveAnimation2;

  @override
  void initState() {
    super.initState();
    // === YA NO INICIAMOS UN REPRODUCTOR LOCAL AQUÍ ===
    _fetchAndPlayTrack();
    _updatePalette(); 

    _fastRotationController = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(); 
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(_fastRotationController);

    _movementController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true); 
    _moveAnimation1 = Tween<Offset>(begin: const Offset(-0.2, -0.2), end: const Offset(0.2, 0.1)).animate(CurvedAnimation(parent: _movementController, curve: Curves.easeInOut));
    _moveAnimation2 = Tween<Offset>(begin: const Offset(0.1, 0.2), end: const Offset(-0.1, -0.2)).animate(CurvedAnimation(parent: _movementController, curve: Curves.easeInOut));
  }

  Future<void> _updatePalette() async {
    final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(NetworkImage(widget.coverUrl), size: const Size(100, 100));
    setState(() {
      _color1 = paletteGenerator.vibrantColor?.color ?? paletteGenerator.dominantColor?.color ?? const Color(0xFF121212);
      _color2 = paletteGenerator.lightVibrantColor?.color ?? paletteGenerator.mutedColor?.color ?? const Color(0xFF1C1C1C);
      _color3 = paletteGenerator.darkVibrantColor?.color ?? paletteGenerator.darkMutedColor?.color ?? const Color(0xFF2A2A2A);
      _color4 = paletteGenerator.lightMutedColor?.color ?? Colors.black;
    });
  }

  Future<void> _fetchAndPlayTrack() async {
    try {
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'auth_token');
      final url = Uri.parse('${ApiConstants.baseUrl}/albums/${widget.albumId}/tracks');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks'] as List;
        
        if (tracks.isNotEmpty) {
          // Buscamos el índice de la canción que tocamos
          int startIndex = 0;
          if (widget.initialTrackId != null) {
            startIndex = tracks.indexWhere((t) => t['track_id'] == widget.initialTrackId);
            if (startIndex == -1) startIndex = 0;
          }

          // Si es un álbum nuevo, cargamos toda la cola y empezamos en el índice seleccionado
          if (audioService.currentTrack?['album_id'] != widget.albumId) {
            await audioService.setQueueAndPlay(
              tracks, 
              startIndex, // Ya no es siempre 0
              coverUrl: widget.coverUrl, 
              artistName: widget.artistName
            );
          } else if (widget.initialTrackId != null && audioService.currentTrack?['track_id'] != widget.initialTrackId) {
             // Si el álbum ya estaba sonando, pero tocaste otra canción de esa lista
             await audioService.playFromQueue(startIndex);
          }
          
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false); // Evita carga infinita si hay error 404
      }
    } catch (e) { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  @override
  void dispose() {
    // IMPORTANTE: Ya NO destruimos el _audioPlayer aquí, porque es global. Solo las animaciones.
    _fastRotationController.dispose();
    _movementController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Leemos el estado global del reproductor en tiempo real
    final audioService = Provider.of<AudioPlayerService>(context);
    final double imageSize = MediaQuery.of(context).size.width > 450 ? 350 : MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          Positioned.fill(child: _buildIntenseLavaLamp()),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),

          Scaffold(
            backgroundColor: Colors.transparent, 
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                // Al minimizar, la canción sigue sonando en el servicio global
                onPressed: () => Navigator.pop(context), 
              ),
              title: Text(widget.albumTitle, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              centerTitle: true,
            ),
            body: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildPlayerContent(imageSize, audioService),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntenseLavaLamp() {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.mirror),
      child: Stack(
        children: [
          Positioned(top: -120, left: -120, child: RotationTransition(turns: _rotationAnimation, child: Container(width: 450, height: 450, decoration: BoxDecoration(shape: BoxShape.circle, color: _color1.withOpacity(0.8))))),
          Positioned(bottom: -80, right: -80, child: RotationTransition(turns: ReverseAnimation(_rotationAnimation), child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: _color2.withOpacity(0.7))))),
          Positioned(top: MediaQuery.of(context).size.height * 0.3, left: MediaQuery.of(context).size.width * 0.1, child: SlideTransition(position: _moveAnimation1, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: _color3.withOpacity(0.6))))),
          Positioned(bottom: MediaQuery.of(context).size.height * 0.2, right: MediaQuery.of(context).size.width * 0.1, child: SlideTransition(position: _moveAnimation2, child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: _color4.withOpacity(0.5))))),
        ],
      ),
    );
  }

  Widget _buildPlayerContent(double imageSize, AudioPlayerService audioService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(widget.coverUrl, width: imageSize, height: imageSize, fit: BoxFit.cover),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioService.currentTrack?['title'] ?? 'Cargando...', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.artistName, style: const TextStyle(color: Colors.white70, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: FaIcon(_isFavorite ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, color: _isFavorite ? mxp3AccentColor : Colors.white, size: 26),
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildPlayerControls(audioService),
      ],
    );
  }

  Widget _buildPlayerControls(AudioPlayerService audioService) {
    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }
    
    // Lógica para el ícono de volumen dinámico
    Widget volumeIcon = const FaIcon(FontAwesomeIcons.volumeHigh, color: Colors.white70, size: 18);
    if (audioService.volume == 0) {
      volumeIcon = const FaIcon(FontAwesomeIcons.volumeXmark, color: Colors.white70, size: 18);
    } else if (audioService.volume < 0.5) {
      volumeIcon = const FaIcon(FontAwesomeIcons.volumeLow, color: Colors.white70, size: 18);
    }

    return Column(
      children: [
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 4, activeTrackColor: Colors.white, inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0, max: audioService.duration.inSeconds > 0 ? audioService.duration.inSeconds.toDouble() : 1.0,
            value: _isDragging 
                ? _dragValue.clamp(0.0, audioService.duration.inSeconds.toDouble())
                : audioService.position.inSeconds.toDouble().clamp(0.0, audioService.duration.inSeconds.toDouble()),
            onChangeStart: (value) => setState(() { _isDragging = true; _dragValue = value; }),
            onChanged: (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) async {
              final newPosition = Duration(seconds: value.toInt());
              await audioService.seek(newPosition);
              await audioService.resume();
              setState(() { _isDragging = false; });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(audioService.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(formatDuration(audioService.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Botón Aleatorio
            IconButton(
              icon: FaIcon(FontAwesomeIcons.shuffle, color: audioService.isShuffle ? mxp3AccentColor : Colors.white70, size: 20), 
              onPressed: () => audioService.toggleShuffle(),
            ),
            // Botón Anterior
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.backwardStep, color: Colors.white, size: 30), 
              onPressed: () => audioService.playPrevious(),
            ),
            // Botón Play/Pausa
            Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: FaIcon(audioService.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.black, size: 30),
                padding: const EdgeInsets.all(20),
                onPressed: () async { audioService.isPlaying ? await audioService.pause() : await audioService.resume(); },
              ),
            ),
            // Botón Siguiente
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.forwardStep, color: Colors.white, size: 30), 
              onPressed: () => audioService.playNext(),
            ),
            // Botón Repetir
            IconButton(
              icon: FaIcon(FontAwesomeIcons.repeat, color: audioService.isRepeat ? mxp3AccentColor : Colors.white70, size: 20), 
              onPressed: () => audioService.toggleRepeat(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Control de volumen
        Row(
          children: [
            volumeIcon,
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 2, 
                  activeTrackColor: Colors.white70, 
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white, 
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  value: audioService.volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) => audioService.setVolume(value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}