import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../models/update_config.dart';

class ForceUpdateScreen extends StatefulWidget {
  final UpdateConfig config;

  const ForceUpdateScreen({super.key, required this.config});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      // Usamos um nome fixo para o APK temporário para evitar acumular arquivos
      final savePath = '${tempDir.path}/kriol_update.apk';

      // Garantir que o arquivo anterior seja removido antes de baixar o novo
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      print('DEBUG: Iniciando download do APK em: $savePath');

      await dio.download(
        widget.config.updateUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      print('DEBUG: Download concluído. Abrindo instalador...');

      // Abrir o instalador nativo do Android
      final result = await OpenFilex.open(savePath);
      
      print('DEBUG: OpenFilex result: ${result.type} - ${result.message}');

      // Se o usuário fechar o instalador sem instalar, permitimos que ele tente abrir de novo
      if (result.type != ResultType.done) {
        setState(() {
          _isDownloading = false;
        });
      }

    } catch (e) {
      print('DEBUG ERROR: Erro no download/instalação: $e');
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Falha ao baixar atualização. Verifique sua conexão e tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          padding: const EdgeInsets.all(32),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              Text(
                'Atualização Necessária',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.config.message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              if (_isDownloading) ...[
                // Barra de progresso para download interno
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Baixando... ${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ] else ...[
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    child: Text(
                      _errorMessage != null ? 'TENTAR NOVAMENTE' : 'ATUALIZAR AGORA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              Text(
                'Nova versão: ${widget.config.latestVersion}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
