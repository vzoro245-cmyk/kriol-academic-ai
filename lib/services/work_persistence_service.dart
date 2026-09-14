import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/academic_work.dart';
import 'work_service.dart';

class WorkPersistenceService {
  final WorkService _workService;
  // Canal customizado do projeto Kriol
  static const _permissionChannel = MethodChannel('kriol/storage_permissions');

  WorkPersistenceService(this._workService);

  Future<void> persistAndRegister({
    required String workId,
    required String userId,
    required String uri,
    required String fileName,
    required int pages,
    required String norm,
  }) async {
    bool permissionPersisted = false;

    try {
      print('DEBUG: Solicitando persistência nativa para: $uri');

      // Chamada ao código Kotlin nativo que implementamos
      final result = await _permissionChannel.invokeMethod<bool>(
        'takePersistableUriPermission',
        {'uri': uri},
      );
      
      permissionPersisted = result ?? false;
      
      if (permissionPersisted) {
        print('✅ DEBUG: Permissão persistida com sucesso para URI: $uri');
      } else {
        print('⚠️ DEBUG: Código nativo retornou falso para a persistência.');
      }
    } on PlatformException catch (e) {
      print('❌ DEBUG ERROR: Falha crítica no MethodChannel nativo: ${e.message}');
    } catch (e) {
      print('❌ DEBUG ERROR: Erro inesperado na persistência: $e');
    }

    // Registro no Firestore com campo de controle
    print('DEBUG: Registrando trabalho no Firestore (Sub-coleção)...');
    await _workService.updateWorkStatus(
      workId,
      WorkStatus.completed,
      localUri: uri,
      localPath: uri,
      fileName: fileName,
      norm: norm,
      pages: pages,
      userId: userId,
    );

    // Salvando o status da permissão separadamente para auditoria/fallback futuro
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('works')
        .doc(workId)
        .update({'permissionPersisted': permissionPersisted});

    print('DEBUG: Fluxo de finalização concluído.');
  }
}
