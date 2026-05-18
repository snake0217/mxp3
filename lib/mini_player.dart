import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'audio_player_service.dart';
import 'screens/player_screen.dart'; 
import 'constants.dart'; 

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    if (audioService.currentTrack == null) {
      return const SizedBox.shrink(); 
    }

    double progress = 0.0;
    if (audioService.duration.inSeconds > 0) {
      progress = audioService.position.inSeconds / audioService.duration.inSeconds;
    }

    // Lógica para cambiar el ícono de volumen dinámicamente
    Widget volumeIcon = const FaIcon(FontAwesomeIcons.volumeHigh, color: Colors.grey, size: 16);
    if (audioService.volume == 0) {
      volumeIcon = const FaIcon(FontAwesomeIcons.volumeXmark, color: Colors.grey, size: 16); // Mute
    } else if (audioService.volume < 0.5) {
      volumeIcon = const FaIcon(FontAwesomeIcons.volumeLow, color: Colors.grey, size: 16); // Volumen bajo
    }

    // Leemos el ancho de la ventana para hacer el diseño responsivo
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
              albumId: audioService.currentTrack!['album_id'] ?? '',
              albumTitle: audioService.currentTrack!['album_title'] ?? 'Reproduciendo Ahora',
              artistName: audioService.currentTrack!['artist_name'] ?? 'Artista',
              coverUrl: audioService.currentTrack!['cover_image_url'] ?? '',
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        height: 70, // Un poco más alto para que respiren los controles
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), 
          border: Border(top: BorderSide(color: Colors.grey.shade900, width: 1)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    // === 1. PORTADA ===
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        ApiConstants.fixUrl(audioService.currentTrack!['cover_image_url']), 
                        width: 44, height: 44, fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // === 2. TEXTOS ===
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audioService.currentTrack?['title'] ?? 'Cargando...',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            audioService.currentTrack?['artist_name'] ?? '', 
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // === 3. CONTROLES PRINCIPALES (Anterior, Play, Siguiente) ===
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.backwardStep, color: Colors.white, size: 20),
                          onPressed: () => audioService.playPrevious(), // TODO: Pista anterior
                        ),
                        
                        // Botón de Play/Pausa envuelto en un círculo blanco
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: IconButton(
                            icon: FaIcon(
                              audioService.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, 
                              color: Colors.black, 
                              size: 16
                            ),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(), // Evita que el botón sea gigante
                            onPressed: () {
                              audioService.isPlaying ? audioService.pause() : audioService.resume();
                            },
                          ),
                        ),

                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.forwardStep, color: Colors.white, size: 20),
                          onPressed: () => audioService.playNext(), // TODO: Pista siguiente
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),
                    
                    // === 4. CONTROL DE VOLUMEN (Solo visible en pantallas anchas) ===
                    if (screenWidth > 600)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          volumeIcon,
                          SizedBox(
                            width: 100, // Ancho fijo para la barra de volumen
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: Colors.grey.shade300,
                                inactiveTrackColor: Colors.grey.shade700,
                                thumbColor: Colors.white,
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
                ),
              ),
            ),
            // === BARRA DE PROGRESO INFERIOR ===
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE6007E)),
              minHeight: 2,
            ),
          ],
        ),
      ),
    );
  }
}