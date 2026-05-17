import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Importamos el paquete de red
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importación para detectar la plataforma

import 'constants.dart'; // Importamos las constantes

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final Color mxp3AccentColor = const Color(0xFFE6007E);

  // 1. Controladores para extraer el texto de los campos
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Variable para el error de la contraseña
  String? _passwordError;

  // Variable para mostrar un indicador de carga
  bool _isLoading = false;

  // 2. Lógica de conexión con FastAPI
  Future<void> _registerUser() async {
    setState(() {
      _passwordError = null; // Reiniciamos el error en cada intento
    });

    // Validamos que no haya campos vacíos
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena todos los campos')),
      );
      return;
    }

    // Validamos que la contraseña sea de 8 caracteres o más
    if (_passwordController.text.length <= 7) {
      setState(() {
        _passwordError = 'La contraseña debe tener 8 caracteres o más';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Usamos la URL centralizada
      final Uri url = Uri.parse('${ApiConstants.baseUrl}/register');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10)); // Evitamos peticiones infinitas

      final responseData = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        // ¡Éxito! (Cumplimiento de RF-01)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada exitosamente!'), backgroundColor: Colors.green),
        );
        // Regresamos al Login
        Navigator.pop(context);
      } else {
        // Error desde el servidor (ej. "El correo ya está registrado")
        String errorMessage = 'Error al registrar';
        if (responseData['detail'] != null) {
          errorMessage = responseData['detail'] is String
              ? responseData['detail']
              : 'Por favor, verifica que el formato del correo sea válido';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Error de red (el servidor está apagado)
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

  // IMPORTANTE: Liberar memoria cuando la pantalla se destruye
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // Estructura para Windows/Linux (Mismo estilo que el login)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/registro.gif', fit: BoxFit.cover), // Fuente: Assets del repo
              Container(color: Colors.black.withOpacity(0.6)),
              const Center(
                child: Text(
                  'Únete a la revolución\nde alta fidelidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: _buildRegisterForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crea tu cuenta', style: TextStyle(fontFamily: 'Montserrat', color:Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        _buildTextField(controller: _nameController, label: '¿Cómo te llamas?', hint: 'Tu nombre artístico o real', icon: Icons.person_outline),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, label: 'Correo electrónico', hint: 'nombre@ejemplo.com', icon: Icons.email_outlined),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController, 
          label: 'Crea una contraseña', 
          hint: 'Mínimo 8 caracteres', 
          icon: Icons.lock_outline, 
          isPassword: true,
          errorText: _passwordError,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mxp3AccentColor,
            ),
            onPressed: _isLoading ? null : _registerUser, 
            child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.black) // Indicador visual de carga
                : const Text('Registrarme', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
        const Center(child: Text('Al registrarte, aceptas nuestros Términos y Condiciones.', style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey, fontSize: 10))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required String hint, 
    required IconData icon, 
    bool isPassword = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller, // <-- Asignado aquí
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            errorText: errorText,
            errorStyle: const TextStyle(color: Colors.redAccent),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 250,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/registro.gif'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
            color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: Text(
                  'Únete a la revolución\nde alta fidelidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: _buildRegisterForm(),
          ),
        ],
      ),
    );
  }
}