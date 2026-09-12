import 'dart:io';
import 'package:flutter/foundation.dart';

class EnvConfig {
  // Use o seu IP local para testar no Android físico
  // Para emulador Android use 10.0.2.2
  // Para Windows use localhost
  static String get apiUrl {
    if (kReleaseMode) {
      return 'https://kriol-academic-ai-backend.onrender.com/'; // Alterado para teste do APK
    }
    
    if (Platform.isAndroid) {
      return 'https://kriol-academic-ai-backend.onrender.com/'; // Emulador (Padrão para Dev)
      // return 'http://192.168.1.100:3000'; // Exemplo de IP Local do PC (Altere para o seu se usar físico)
    }
    
    return 'http://localhost:3000';
  }
}
