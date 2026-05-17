import 'package:flutter/material.dart';
import 'dart:async'; // Necesario para el Timer (Debounce)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../audio_player_service.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // === MAGIA DEL DEBOUNCE ===
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // Espera 500 milisegundos antes de ejecutar la búsqueda real
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'auth_token');
      
      final url = Uri.parse('${ApiConstants.baseUrl}/search?q=$query');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body)['tracks'] ?? [];
        });
      }
    } catch (e) {
      // Error silencioso para no interrumpir al usuario mientras teclea
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent, // Para que el HomeScreen maneje el fondo
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Buscar', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // === BARRA DE BÚSQUEDA ===
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Canciones, artistas o álbumes...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1), // Gris traslúcido
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // === LISTA DE RESULTADOS ===
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6007E)))
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(child: Text("No se encontraron coincidencias", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final track = _searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(track['cover_image_url'], width: 50, height: 50, fit: BoxFit.cover),
                            ),
                            title: Text(track['track_title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(track['artist_name'] ?? '', style: const TextStyle(color: Colors.white54)),
                            trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFE6007E), size: 30),
                            onTap: () async {
                              // Reproducir la canción tocada y cargar la lista de búsqueda como la Cola Actual
                              await audioService.setQueueAndPlay(
                                _searchResults, 
                                index, 
                                coverUrl: track['cover_image_url'], 
                                artistName: track['artist_name']
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlayerScreen(
                                    albumId: track['album_id'],
                                    albumTitle: track['album_title'],
                                    artistName: track['artist_name'],
                                    coverUrl: track['cover_image_url'],
                                    initialTrackId: track['track_id'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
            ),
            const SizedBox(height: 80), // Espacio de seguridad para el MiniPlayer
          ],
        ),
      ),
    );
  }
}