import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/work_service.dart';
import '../models/academic_work.dart';
import 'auth_provider.dart';

final workServiceProvider = Provider<WorkService>((ref) {
  return WorkService();
});

final userWorksProvider = StreamProvider<List<AcademicWork>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  
  if (userId == null) return Stream.value([]);
  
  return ref.watch(workServiceProvider).getUserWorks(userId);
});
