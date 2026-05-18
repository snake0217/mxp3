import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Necesario para el efecto Blur
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:palette_generator/palette_generator.dart'; // Extractor de colores

import '../constants.dart';
import '../audio_player_service.dart';
import 'player_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumTitle;
  final String artistName;
  final String coverUrl;

  const AlbumDetailScreen({
    Key? key,
    required this.albumId,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
  }) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _tracks = [];
  String? _errorMessage;
  
  // Variables para el color dinámico del fondo
  Color _dominantColor = Colors.black;
  Color _accentColor = const Color(0xFFFF2D55); // Magenta Apple Music de referencia

  @override
  void initState() {
    super.initState();
    _fetchAlbumTracks();
    _updatePalette(); // Generar colores al iniciar
  }

  // === MAGIA: Extraer colores de la portada ===
  Future<void> _updatePalette() async {
    String safeCoverUrl = ApiConstants.fixUrl(widget.coverUrl);
    final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(safeCoverUrl),
      size: const Size(100, 100), // Tamaño pequeño para rapidez
    );
    
    if (mounted) {
      setState(() {
        _dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
        // Usamos el color vibrante como acento, o el magenta por defecto de la referencia
        _accentColor = paletteGenerator.vibrantColor?.color ?? const Color(0xFFFF2D55);
      });
    }
  }

  Future<void> _fetchAlbumTracks() async {
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'auth_token');
      final url = Uri.parse('${ApiConstants.baseUrl}/albums/${widget.albumId}/tracks');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        setState(() {
          _tracks = jsonDecode(response.body)['tracks'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _errorMessage = 'Error al cargar canciones.'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Error de red.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    // Calculamos el ancho para diseño responsivo
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    String safeCoverUrl = ApiConstants.fixUrl(widget.coverUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // === CAPA 1: FONDO DIFUMINADO DINÁMICO (Lava Lamp sutil) ===
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _dominantColor.withOpacity(0.8),
                      Colors.black,
                    ],
                    center: Alignment.topCenter,
                    radius: 1.2,
                  ),
                ),
              ),
            ),
          ),
          // Superposición negra tenue para legibilidad
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

          // === CAPA 2: CONTENIDO DESLIZABLE ===
          CustomScrollView(
            slivers: [
              // App Bar Transparente flotante
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white, size: 26),
                    onPressed: () {}, // Menú de opciones del álbum
                  ),
                ],
                pinned: true, // Se queda fijo al hacer scroll
              ),

              // === CABECERA DEL ÁLBUM (Imagen, Títulos, Botones) ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                  child: Column(
                    children: [
                      // Portada con Sombra (Estilo Referencia)
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              spreadRadius: 2, blurRadius: 20, offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            safeCoverUrl,
                            width: isDesktop ? 300 : screenWidth * 0.65,
                            height: isDesktop ? 300 : screenWidth * 0.65,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.music_note, color: Colors.grey, size: 50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Título del Álbum (Grande y Blanco)
                      Text(
                        widget.albumTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5, // Tipografía Apple
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Nombre del Artista (Magenta de Referencia)
                      Text(
                        widget.artistName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _accentColor, // Color dinámico extraído
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Metadatos (Año, Género - Gris)
                      const Text(
                        "POP · 2024", // TODO: Traer datos reales de la API
                        style: TextStyle(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 25),
                      
                      // === BOTONES DE ACCIÓN (Play y Shuffle - Estilo Referencia) ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(
                            icon: const FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 16),
                            text: "Reproducir",
                            onPressed: () async {
                              if (_tracks.isNotEmpty) {
                                await audioService.setQueueAndPlay(_tracks, 0, coverUrl: widget.coverUrl, artistName: widget.artistName);
                              }
                            },
                          ),
                          const SizedBox(width: 15),
                          _buildActionButton(
                            icon: const FaIcon(FontAwesomeIcons.shuffle, color: Colors.white, size: 16),
                            text: "Aleatorio",
                            onPressed: () async {
                              if (_tracks.isNotEmpty) {
                                // Activamos shuffle en el servicio y reproducimos uno al azar
                                if (!audioService.isShuffle) audioService.toggleShuffle();
                                await audioService.setQueueAndPlay(_tracks, 0, coverUrl: widget.coverUrl, artistName: widget.artistName);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // === LISTA DE CANCIONES (Estilo Referencia) ===
              _isLoading
                  ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white24)))
                  : _errorMessage != null
                      ? SliverFillRemaining(child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))))
                      : SliverPadding(
                          padding: const EdgeInsets.only(bottom: 120), // Espacio para miniplayer
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final track = _tracks[index];
                                final isCurrent = audioService.currentTrack?['track_id'] == track['track_id'];

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                    // Número de pista (Gris y pequeño)
                                    leading: Container(
                                      width: 25,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${track['track_number'] ?? (index + 1)}',
                                        style: TextStyle(
                                          color: isCurrent ? _accentColor : Colors.white30,
                                          fontSize: 14,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    // Título (Blanco y Negrita)
                                    title: Text(
                                      track['title'] ?? 'Canción...',
                                      style: TextStyle(
                                        color: isCurrent ? _accentColor : Colors.white,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    // Icono Opciones (Kebab horizontal gris)
                                    trailing: IconButton(
                                      icon: const Icon(Icons.more_horiz, color: Colors.white30, size: 22),
                                      onPressed: () {}, // Menú de opciones de la canción
                                    ),
                                    onTap: () async {
                                      await audioService.setQueueAndPlay(_tracks, index, coverUrl: widget.coverUrl, artistName: widget.artistName);
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(albumId: widget.albumId, albumTitle: widget.albumTitle, artistName: widget.artistName, coverUrl: widget.coverUrl, initialTrackId: track['track_id'])));
                                    },
                                  ),
                                );
                              },
                              childCount: _tracks.length,
                            ),
                          ),
                        ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para crear los botones grises de la referencia
  Widget _buildActionButton({required Widget icon, required String text, required VoidCallback onPressed}) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1), // Gris traslúcido
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}