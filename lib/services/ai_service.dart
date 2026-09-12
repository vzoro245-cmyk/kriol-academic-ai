import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/config/env_config.dart';

class AIService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EnvConfig.apiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 300), 
  ));

  Future<Map<String, dynamic>> generateStructuredContent({
    required String title,
    String? subtitle,
    required String subject,
    required String theme,
    required String type,
    required String level,
    required int pages,
    String? language,
    String? instructions,
    bool isAbnt = false,
    List<String> abntSections = const [],
  }) async {
    try {
      final response = await _dio.post('/generate', data: {
        'title': title,
        'subtitle': subtitle,
        'subject': subject,
        'theme': theme,
        'type': type,
        'level': level,
        'pages': pages,
        'language': language ?? 'Português',
        'instructions': instructions ?? '',
        'isAbnt': isAbnt,
        'abntSections': abntSections,
      });

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw 'Erro no servidor: ${response.data['error'] ?? 'Erro desconhecido'}';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw 'A conexão com o servidor de IA demorou muito. Tente novamente.';
      }
      throw 'Erro ao gerar conteúdo: ${e.message}';
    } catch (e) {
      throw 'Ocorreu um erro inesperado: $e';
    }
  }

  Future<Uint8List> generateDocx({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> content,
  }) async {
    try {
      final response = await _dio.post(
        '/generate-docx',
        data: {
          'userData': userData,
          'content': content,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data);
      } else {
        throw 'Falha ao gerar o arquivo Word.';
      }
    } catch (e) {
      throw 'Erro na geração do DOCX: $e';
    }
  }
}
