import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  final String whatsappLink;
  final String defaultFilesDirectory;

  AppSettings({
    required this.whatsappLink,
    required this.defaultFilesDirectory,
  });

  factory AppSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppSettings(
      whatsappLink: data['whatsappLink'] ?? 'https://wa.me/245000000000',
      defaultFilesDirectory: data['defaultFilesDirectory'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'whatsappLink': whatsappLink,
      'defaultFilesDirectory': defaultFilesDirectory,
    };
  }

  AppSettings copyWith({
    String? whatsappLink,
    String? defaultFilesDirectory,
  }) {
    return AppSettings(
      whatsappLink: whatsappLink ?? this.whatsappLink,
      defaultFilesDirectory: defaultFilesDirectory ?? this.defaultFilesDirectory,
    );
  }
}
