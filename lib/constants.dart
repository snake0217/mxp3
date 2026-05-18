import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Para probar en tu CELULAR FÍSICO, debes poner la IP de tu computadora en la red Wi-Fi.
  // Por ejemplo: '192.168.1.15' (búscala con 'ipconfig' en Windows o 'ip a' en Linux/Mac)
  
  static const String _mobileIp = '192.168.100.168'; // <-- IP para tu celular (cámbiala si tu IP Wi-Fi cambia)
  static const String _pcIp = '127.0.0.1';         // <-- IP local para probar en PC

  static String get ip {
    if (kIsWeb) {
      return _pcIp;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _mobileIp; // Devuelve la IP Wi-Fi si estás en celular
    }
    return _pcIp; // Devuelve Localhost si estás en PC
  }

  static String get baseUrl => 'http://$ip:8000/api/v1';

  // NUEVO: Método para arreglar URLs de imágenes y audio dinámicamente
  static String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // 1. Si es una ruta relativa que empiece con /static
    if (url.startsWith('/static')) {
      return 'http://$ip:8000$url';
    }
    
    // 2. Si es una URL guardada con una IP antigua (ej. "http://192.168.1.201:8000/...")
    if (url.startsWith('http')) {
      try {
        final uri = Uri.parse(url);
        // Reemplazamos la IP antigua por la dinámica actual, conservando la ruta del archivo
        if (uri.port == 8000) {
          return 'http://$ip:8000${uri.path}';
        }
      } catch (e) {
        return url;
      }
    }
    
    return url;
  }
}