import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _whatsappController = TextEditingController();
  final _filesDirController = TextEditingController();

  @override
  void dispose() {
    _whatsappController.dispose();
    _filesDirController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(AppSettings currentSettings) async {
    final newSettings = currentSettings.copyWith(
      whatsappLink: _whatsappController.text,
    );

    try {
      // Save global to Firestore
      await ref.read(settingsServiceProvider).updateGlobalSettings(newSettings);
      // Save local to SharedPrefs
      await ref.read(settingsServiceProvider).saveLocalFilesDirectory(_filesDirController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar configurações: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      body: settingsAsync.when(
        data: (settings) {
          if (_whatsappController.text.isEmpty) {
            _whatsappController.text = settings.whatsappLink;
            _filesDirController.text = settings.defaultFilesDirectory;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                
                _buildSection(
                  context,
                  title: '👥 Alunos e turmas',
                  children: [
                    const ListTile(
                      title: Text('Limite de alunos por grupo'),
                      subtitle: Text('Atualmente fixado em 25 alunos.'),
                      trailing: Icon(Icons.lock_outline),
                    ),
                    const ListTile(
                      title: Text('Campos obrigatórios'),
                      subtitle: Text('Turma e Número do aluno são obrigatórios por padrão.'),
                      trailing: Icon(Icons.check_circle_outline, color: Colors.green),
                    ),
                  ],
                ),

                _buildSection(
                  context,
                  title: '📄 Trabalhos',
                  children: [
                    const ListTile(
                      title: Text('Padrão de formatação'),
                      subtitle: Text('Suporte a Regras Normais e ABNT.'),
                    ),
                    const ListTile(
                      title: Text('Modularização ABNT'),
                      subtitle: Text('Permite escolher seções específicas para aplicar as normas.'),
                    ),
                  ],
                ),

                _buildSection(
                  context,
                  title: '💳 Créditos',
                  children: [
                    TextField(
                      controller: _whatsappController,
                      decoration: const InputDecoration(
                        labelText: 'Link do WhatsApp para suporte *',
                        border: OutlineInputBorder(),
                        hintText: 'https://wa.me/...',
                        prefixIcon: Icon(Icons.chat),
                      ),
                    ),
                  ],
                ),

                _buildSection(
                  context,
                  title: '⚙️ Sistema',
                  children: [
                    const Text('Armazenamento de arquivos', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('No Android, os trabalhos gerados são salvos na pasta de documentos da aplicação. Você pode abri-los diretamente ou compartilhá-los com outros aplicativos (Google Drive, WhatsApp, etc.) a partir do seu histórico.'),
                  ],
                ),

                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _saveSettings(settings),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Salvar todas as alterações'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar configurações: $err')),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
