import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsServiceProvider).watchSettings();
});
