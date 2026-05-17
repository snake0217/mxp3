import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import '../login_screen.dart';
import '../constants.dart'; 
import 'player_screen.dart';
import '../mini_player.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color mxp3AccentColor = const Color(0xFFE6007E);
  final Color darkSurface = const Color(0xFF121212);
  final Color cardSurface = const Color(0xFF1E1E1E);

  int _selectedMenuIndex = 0;
  // Variable de estado para controlar qué menú se muestra en PC
  bool _showSettingsMenu = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _forYouList = [];
  List<dynamic> _recentList = [];

  @override
  void initState() {
    super.initState();
    // Al abrir la pantalla, pedimos los datos al servidor
    _fetchHomeFeed();
  }

  Future<void> _fetchHomeFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'auth_token');

      // Si por alguna razón no hay token, lo mandamos al login
      if (token == null) {
        _logout(context);
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/home-feed');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // <-- AQUÍ ENVIAMOS EL TOKEN JWT
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _forYouList = data['for_you'] ?? [];
          _recentList = data['recent'] ?? [];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        _logout(context);
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión. Revisa tu red o el servidor.';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    
    if (!context.mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // === DISEÑO ESCRITORIO / PC ===
        if (constraints.maxWidth > 800) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 240,
                        color: darkSurface,
                        // Si _showSettingsMenu es true, mostramos configuración. Si no, menú normal.
                        child: _showSettingsMenu ? _buildSettingsMenuPC() : _buildMainMenuPC(),
                      ),
                      Expanded(
                        child: _buildMainContent(),
                      ),
                    ],
                  ),
                ),
                const MiniPlayer(), // Mini reproductor en la base para PC
              ],
            ),
          );
        }
        
        // === DISEÑO MÓVIL ===
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Mxp3 Music', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                // Botón de engranaje en móvil que abre una ventana nueva
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.gear, size: 20, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => MobileSettingsScreen(onLogout: () => _logout(context)))
                    );
                  },
                )
              ],
            ),
            body: _buildMainContent(),
            // 2. Usamos la propiedad bottomNavigationBar con la Columna que propusiste
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min, // ¡CRUCIAL para que no ocupe toda la pantalla!
              children: [
                const MiniPlayer(), // El MiniPlayer flotará ARRIBA del menú
                BottomNavigationBar(
                  backgroundColor: darkSurface,
                  selectedItemColor: mxp3AccentColor,
                  unselectedItemColor: Colors.grey,
                  currentIndex: _selectedMenuIndex > 2 ? 0 : _selectedMenuIndex,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) {
                    setState(() {
                      _selectedMenuIndex = index;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.house, size: 18), label: 'Escuchar'),
                    BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.compass, size: 18), label: 'Explorar'),
                    BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.towerBroadcast, size: 18), label: 'Radio'),
                  ],
                ),
              ],
            ),
          );
      },
    );
  }

  // === MENÚ PRINCIPAL PC ===
  Widget _buildMainMenuPC() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headphones_rounded, color: mxp3AccentColor, size: 28),
              const SizedBox(width: 10),
              const Text('Mxp3 Music', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.house), label: 'Escuchar', index: 0),
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.compass), label: 'Explorar', index: 1),
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.towerBroadcast), label: 'Radio', index: 2),
          
          const SizedBox(height: 24),
          const Text('BIBLIOTECA', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.clock), label: 'Reciente', index: 3),
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.microphone), label: 'Artistas', index: 4),
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.compactDisc), label: 'Álbumes', index: 5),
          _buildSidebarItem(icon: const FaIcon(FontAwesomeIcons.heart), label: 'Favoritos', index: 6),
          
          const Spacer(),
          
          // Botón para acceder al submenú de configuración en PC
          _buildActionItem(
            icon: const FaIcon(FontAwesomeIcons.gear), 
            label: 'Configuración', 
            color: Colors.grey,
            onTap: () => setState(() => _showSettingsMenu = true),
          ),
        ],
      ),
    );
  }

  // === SUBMENÚ DE CONFIGURACIÓN PC ===
  Widget _buildSettingsMenuPC() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _showSettingsMenu = false), // Volver al menú principal
              ),
              const Text('Configuración', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildActionItem(icon: const FaIcon(FontAwesomeIcons.user), label: 'Mi Perfil', color: Colors.white, onTap: (){}),
          _buildActionItem(icon: const FaIcon(FontAwesomeIcons.sliders), label: 'Calidad de Audio', color: Colors.white, onTap: (){}),
          _buildActionItem(icon: const FaIcon(FontAwesomeIcons.circleQuestion), label: 'Ayuda', color: Colors.white, onTap: (){}),
          
          const Spacer(),
          
          // Botón de Cerrar Sesión en rojo
          _buildActionItem(
            icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket), 
            label: 'Cerrar Sesión', 
            color: Colors.redAccent,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // Elemento estándar de menú con estado activo/inactivo
  Widget _buildSidebarItem({required Widget icon, required String label, required int index}) {
    bool isActive = _selectedMenuIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMenuIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? mxp3AccentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            IconTheme(
              data: IconThemeData(
                color: isActive ? mxp3AccentColor : Colors.grey,
                size: 18,
              ),
              child: icon,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Elemento de acción directo (sin selección de estado)
  Widget _buildActionItem({required Widget icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            IconTheme(
              data: IconThemeData(
                color: color,
                size: 18,
              ),
              child: icon,
            ),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // 1. Mostrar estado de carga
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: mxp3AccentColor));
    }

    // 2. Mostrar estado de error
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.redAccent, size: 40),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchHomeFeed,
              child: const Text('Reintentar'),
            )
          ],
        ),
      );
    }

    // 3. Mostrar el catálogo real
    int crossAxisCount = MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Para ti', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          if (_forYouList.isEmpty)
            const Text('No hay recomendaciones disponibles', style: TextStyle(color: Colors.grey))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              itemCount: _forYouList.length,
              itemBuilder: (context, index) {
                final album = _forYouList[index];
                return _buildMusicCard(
  albumId: album['album_id'], // <- NUEVO PARÁMETRO
  title: album['title'],
  subtitle: album['artist_name'],
  imageUrl: album['cover_image_url'],
);
              },
            ),
          
          const SizedBox(height: 40),
          const Text('Escuchado Recientemente', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          if (_recentList.isEmpty)
            const Text('No has escuchado nada recientemente', style: TextStyle(color: Colors.grey))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              itemCount: _recentList.length,
              itemBuilder: (context, index) {
                final album = _recentList[index];
                return _buildMusicCard(
  albumId: album['album_id'], // <- NUEVO PARÁMETRO
  title: album['title'],
  subtitle: album['artist_name'],
  imageUrl: album['cover_image_url'],
);
              },
            ),
        ],
      ),
    );
  }

  // === TARJETA DE MÚSICA===
  Widget _buildMusicCard({required String albumId, required String title, required String subtitle, required String imageUrl}) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
              albumId: albumId,
              albumTitle: title,
              artistName: subtitle,
              coverUrl: imageUrl,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0); // Deslizar desde abajo
              const end = Offset.zero;
              const curve = Curves.ease;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardSurface, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Center(child: FaIcon(FontAwesomeIcons.music, color: Colors.grey, size: 40)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// === PANTALLA COMPLETA DE CONFIGURACIÓN PARA MÓVIL ===
class MobileSettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  
  const MobileSettingsScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.user, color: Colors.white),
            title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.sliders, color: Colors.white),
            title: const Text('Calidad de Audio', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            onTap: () {},
          ),
          const Divider(color: Colors.grey, height: 40),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.arrowRightFromBracket, color: Colors.redAccent),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}