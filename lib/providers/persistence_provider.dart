import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/work_persistence_service.dart';
import 'work_provider.dart';

final workPersistenceServiceProvider = Provider<WorkPersistenceService>((ref) {
  final workService = ref.watch(workServiceProvider);
  return WorkPersistenceService(workService);
});
