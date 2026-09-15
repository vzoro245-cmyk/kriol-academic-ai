import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_opener_service.dart';

final fileOpenerServiceProvider = Provider<FileOpenerService>((ref) {
  return FileOpenerService();
});
