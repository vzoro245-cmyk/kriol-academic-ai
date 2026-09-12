import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/credit_service.dart';
import '../models/credit.dart';
import 'auth_provider.dart';

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService();
});

final userCreditsProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  
  if (userId == null) return Stream.value(0);
  
  // Sincronizando com a fonte de verdade (userProfileProvider)
  // Mas mantendo como StreamProvider para compatibilidade com a CreditsScreen
  return ref.watch(creditServiceProvider).getUserCredits(userId);
});

final creditHistoryProvider = StreamProvider<List<CreditTransaction>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(creditServiceProvider).getCreditHistory(userId);
});

final creditPackagesProvider = FutureProvider<List<CreditPackage>>((ref) {
  return ref.watch(creditServiceProvider).getCreditPackages();
});
