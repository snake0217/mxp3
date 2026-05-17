import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http; // Paquete para peticiones de red
import 'dart:convert'; // Para codificar/decodificar JSON
import 'package:flutter/foundation.dart'; // Importación para detectar la plataforma
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'register_screen.dart';
import 'constants.dart'; // Importamos las constantes
import 'screens/home_screen.dart'; // Importa la pantalla principal

// 1. Cambiado a StatefulWidget
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color mxp3AccentColor = const Color(0xFFE6007E);
  final _storage = const FlutterSecureStorage();
  // 2. Controladores para capturar el texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 3. Variable de estado para la carga
  bool _isLoading = false;

  // 4. Lógica de Inicio de Sesión
  Future<void> _loginUser() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor, llena todos los campos')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final Uri url = Uri.parse('${ApiConstants.baseUrl}/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      }),
    ).timeout(const Duration(seconds: 10));

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // PERSISTENCIA DEL TOKEN (Seguridad y Control de Sesión)
      // Guardamos el token recibido del backend de forma cifrada en el dispositivo
      final String token = responseData['access_token'];
      await _storage.write(key: 'auth_token', value: token);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bienvenido de nuevo!'), backgroundColor: Colors.green),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(responseData['detail'] ?? 'Error al iniciar sesión'), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    print("===== ERROR CRÍTICO =====");
    print(e.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error de conexión con el servidor'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  // Liberamos recursos
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout(context);
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/login.gif',
                fit: BoxFit.cover, 
              ),
              Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: _buildLoginForm(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¡Hola de nuevo!',
          style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa tus credenciales para acceder a tu música.',
          style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 40),
        
        // 5. Asignar controladores a los campos
        _buildTextField(
          controller: _emailController, 
          label: 'Email', 
          hint: 'nombre@ejemplo.com', 
          icon: Icons.email_outlined
        ),
        const SizedBox(height: 20),
        
        _buildTextField(
          controller: _passwordController, 
          label: 'Contraseña', 
          hint: '••••••••', 
          icon: Icons.lock_outline, 
          isPassword: true
        ),
        
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 30),
        
        // 6. Conectar el botón a la lógica
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            // Deshabilitar botón mientras carga y asignar función
            onPressed: _isLoading ? null : _loginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: mxp3AccentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            // Mostrar indicador de carga si _isLoading es true
            child: _isLoading 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text('Iniciar Sesión', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 40),

        const Center(child: Text('O continúa con', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 20)),
            const SizedBox(width: 20),
            _buildSocialIcon(const FaIcon(FontAwesomeIcons.apple, color: Colors.white, size: 20)),
            const SizedBox(width: 20),
            _buildSocialIcon(const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 20)),
          ],
        ),
        const SizedBox(height: 20),
        const Center(child: Text('¿No tienes una cuenta?', style: TextStyle(color: Colors.grey))),
        
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            child: const Text('Regístrate aquí', style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey)),
          ),
        ),
      ],
    );
  }
  
  // 7. Modificar el constructor del widget para aceptar el controlador
  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required String hint, 
    required IconData icon, 
    bool isPassword = false
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller, // Asignar controlador aquí
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(Widget iconWidget) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: iconWidget, 
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/login.gif',
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withOpacity(0.6),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: _buildLoginForm(context),
          ),
        ),
      ],
    );
  }
}