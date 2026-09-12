import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _localDirPathKey = 'local_files_directory';

  // --- Global Settings (Firestore) ---

  Future<AppSettings> getSettings() async {
    final doc = await _db.collection('settings').doc('global').get();
    final localDir = await getLocalFilesDirectory();
    
    if (doc.exists) {
      final settings = AppSettings.fromFirestore(doc);
      return settings.copyWith(defaultFilesDirectory: localDir ?? settings.defaultFilesDirectory);
    }
    
    return AppSettings(
      whatsappLink: 'https://wa.me/245969217939',
      defaultFilesDirectory: localDir ?? '',
    );
  }

  Stream<AppSettings> watchSettings() async* {
    final prefs = await SharedPreferences.getInstance();
    
    yield* _db.collection('settings').doc('global').snapshots().map((doc) {
      final settings = AppSettings.fromFirestore(doc);
      final localDir = prefs.getString(_localDirPathKey);
      return settings.copyWith(defaultFilesDirectory: localDir ?? settings.defaultFilesDirectory);
    });
  }

  Future<void> updateGlobalSettings(AppSettings settings) async {
    // Only update the link to Firestore, directory is local
    await _db.collection('settings').doc('global').set({
      'whatsappLink': settings.whatsappLink,
    }, SetOptions(merge: true));
  }

  // --- Local Settings (Shared Preferences) ---

  Future<void> saveLocalFilesDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localDirPathKey, path);
  }

  Future<String?> getLocalFilesDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localDirPathKey);
  }
}
