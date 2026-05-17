import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'audio_player_service.dart';
import 'login_screen.dart'; 
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    // Wrap the app with the Provider
    ChangeNotifierProvider(
      create: (context) => AudioPlayerService(),
      child: const Mxp3App(),
    ),
  );
}

class Mxp3App extends StatelessWidget {
  const Mxp3App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mxp3',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFE6007E),
        fontFamily: 'Montserrat', 
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE6007E),
            foregroundColor: Colors.black, 
          ),
        ),
      ),
      // En lugar de ir directo al Login, pasamos por el enrutador
      home: const AuthWrapper(),
    );
  }
}

// === WIDGET ENRUTADOR (Verifica si hay sesión activa) ===
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  bool _isLoading = true; // Para mostrar una pantalla de carga inicial
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Leemos el token que guardamos durante el Login
    String? token = await _storage.read(key: 'auth_token');
    
    // Si el token existe, consideramos que está autenticado
    // (En una etapa más avanzada, aquí podemos decodificar el JWT para ver si ya expiró)
    setState(() {
      _isAuthenticated = token != null;
      _isLoading = false; // Terminamos de cargar
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Mientras lee el almacenamiento, mostramos un spinner centrado
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE6007E)),
        ),
      );
    }

    // 2. Si tiene token, va a su música. Si no, va al login.
    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}