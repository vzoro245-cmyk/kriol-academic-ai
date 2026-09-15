import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:saf/saf.dart';
import 'package:dio/dio.dart';
import '../models/academic_work.dart';

enum FileOpenerResult { success, fileNotFound, permissionDenied, appNotFound, error }

class FileOpenerService {
  final Saf _saf = Saf();
  final Dio _dio = Dio();

  /// Tenta abrir o trabalho acadêmico de forma inteligente, lidando com SAF, arquivos locais e nuvem.
  Future<FileOpenerResult> openWork(AcademicWork work) async {
    try {
      debugPrint('DEBUG: Iniciando abertura de trabalho: ${work.title}');

      // 1. TENTATIVA 1: Caminho local absoluto (Fallback interno ou arquivos não SAF)
      if (work.localPath != null && !work.localPath!.startsWith('content')) {
        debugPrint('DEBUG: Tentando abrir via path local: ${work.localPath}');
        final file = File(work.localPath!);
        if (await file.exists()) {
          final result = await OpenFilex.open(work.localPath!);
          return _mapResult(result);
        }
        debugPrint('DEBUG: Arquivo local não encontrado em: ${work.localPath}');
      }

      // 2. TENTATIVA 2: URI do SAF (Storage Access Framework)
      // Usamos os bytes persistidos na Etapa 1 para reconstruir o arquivo em cache
      final uri = work.localUri ?? (work.localPath != null && work.localPath!.startsWith('content') ? work.localPath : null);
      if (uri != null) {
        debugPrint('DEBUG: Tentando abrir via SAF URI: $uri');
        try {
          final bytes = await _saf.readFileBytes(uri);
          if (bytes.isNotEmpty) {
            debugPrint('DEBUG: Leitura SAF bem-sucedida (${bytes.length} bytes).');
            return await _openFromBytes(bytes, work.fileName ?? "${work.title}.docx");
          }
          debugPrint('DEBUG: SAF retornou lista de bytes vazia.');
        } catch (e) {
          debugPrint('DEBUG WARNING: Falha na permissão persistente SAF ou arquivo movido: $e');
        }
      }

      // 3. TENTATIVA 3: Download da Nuvem (Fallback final se houver fileUrl)
      if (work.fileUrl != null && work.fileUrl!.isNotEmpty) {
        debugPrint('DEBUG: Tentando baixar da nuvem: ${work.fileUrl}');
        try {
          final response = await _dio.get(
            work.fileUrl!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.statusCode == 200) {
            debugPrint('DEBUG: Download concluído com sucesso.');
            return await _openFromBytes(Uint8List.fromList(response.data), work.fileName ?? "${work.title}.docx");
          }
        } catch (e) {
          debugPrint('DEBUG ERROR: Falha ao baixar arquivo da nuvem: $e');
        }
      }

      debugPrint('DEBUG: Todas as tentativas de abertura falharam.');
      return FileOpenerResult.fileNotFound;
    } catch (e) {
      debugPrint('DEBUG ERROR: Erro crítico no FileOpenerService: $e');
      return FileOpenerResult.error;
    }
  }

  /// Grava bytes em arquivo temporário e abre com app externo
  Future<FileOpenerResult> _openFromBytes(Uint8List bytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      final tempFile = File(tempPath);
      
      await tempFile.writeAsBytes(bytes);
      debugPrint('DEBUG: Arquivo temporário gravado em: $tempPath');
      
      final result = await OpenFilex.open(tempPath);
      return _mapResult(result);
    } catch (e) {
      debugPrint('DEBUG ERROR: Falha ao gravar/abrir arquivo temporário: $e');
      return FileOpenerResult.error;
    }
  }

  FileOpenerResult _mapResult(OpenResult result) {
    switch (result.type) {
      case ResultType.done:
        return FileOpenerResult.success;
      case ResultType.noAppToOpen:
        return FileOpenerResult.appNotFound;
      case ResultType.permissionDenied:
        return FileOpenerResult.permissionDenied;
      default:
        return FileOpenerResult.error;
    }
  }
}
