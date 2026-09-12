import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';
import 'auth_provider.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) {
  // Observa o estado de autenticação para garantir que a checagem 
  // ocorra somente quando o usuário estiver logado (evita erro de permissão no Firestore)
  final authState = ref.watch(authStateProvider);
  
  if (authState.value == null) {
    return UpdateCheckResult(isUpdateRequired: false);
  }

  return ref.watch(updateServiceProvider).checkForUpdate();
});
