import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../models/update_config.dart';

class ForceUpdateScreen extends StatelessWidget {
  final UpdateConfig config;

  const ForceUpdateScreen({super.key, required this.config});

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
                config.message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => launchUrlString(
                    config.updateUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'ATUALIZAR AGORA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nova versão: ${config.latestVersion}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}