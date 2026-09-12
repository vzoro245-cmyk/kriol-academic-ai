import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateConfig {
  final String latestVersion;
  final String minimumVersion;
  final String updateUrl;
  final String message;

  UpdateConfig({
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateUrl,
    required this.message,
  });

  factory UpdateConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UpdateConfig(
      latestVersion: data['latestVersion'] ?? '1.0.0',
      minimumVersion: data['minimumVersion'] ?? '1.0.0',
      updateUrl: data['updateUrl'] ?? '',
      message: data['message'] ?? 'Uma nova versão obrigatória está disponível. Por favor, atualize para continuar usando o aplicativo.',
    );
  }
}
