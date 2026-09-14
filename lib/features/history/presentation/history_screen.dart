import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/work_provider.dart';
import '../../../models/academic_work.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isActionLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _getFileBytes(AcademicWork work) async {
    print('DEBUG: _getFileBytes iniciado para trabalho: ${work.title}');
    
    // 1. Tentar ler do arquivo local se for um caminho absoluto válido
    if (work.localPath != null) {
      print('DEBUG: Verificando path local: ${work.localPath}');
      
      // Ignora caminhos que começam com /document/ ou content:// (SAF)
      final isSafPath = work.localPath!.startsWith('/document/') || work.localPath!.startsWith('content://');
      
      if (!isSafPath) {
        final file = File(work.localPath!);
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            print('DEBUG: Leitura local bem-sucedida. Bytes lidos: ${bytes.length}');
            return bytes;
          } catch (e) {
            print('DEBUG ERROR: Falha ao ler arquivo local: $e');
          }
        } else {
          print('DEBUG: Arquivo local não existe fisicamente no dispositivo.');
        }
      } else {
        print('DEBUG: Path local é uma URI do SAF (/document/ ou content://). Ignorando leitura direta via File().');
      }
    }

    // 2. Fallback: Baixar da nuvem (fileUrl)
    if (work.fileUrl != null) {
      print('DEBUG: Tentando baixar da nuvem (fileUrl): ${work.fileUrl}');
      try {
        final dio = Dio();
        final response = await dio.get(
          work.fileUrl!,
          options: Options(responseType: ResponseType.bytes),
        );
        print('DEBUG: Resposta do download recebida. Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final bytes = Uint8List.fromList(response.data);
          print('DEBUG: Download concluído. Bytes recebidos: ${bytes.length}');
          return bytes;
        } else {
          print('DEBUG ERROR: Download falhou com status code: ${response.statusCode}');
        }
      } catch (e) {
        print('DEBUG ERROR: Exceção capturada no download (Dio): $e');
      }
    } else {
      print('DEBUG: fileUrl é nulo, impossível baixar arquivo.');
    }
    
    print('DEBUG: _getFileBytes retornando null (todas as tentativas falharam)');
    return null;
  }

  Future<void> _openWorkFile(AcademicWork work) async {
    print('DEBUG: _openWorkFile iniciado para: ${work.title}');
    setState(() => _isActionLoading = true);
    
    try {
      // Se arquivo local existe, abre direto
      if (work.localPath != null) {
        print('DEBUG: Checando existência local para abertura: ${work.localPath}');
        final file = File(work.localPath!);
        if (await file.exists()) {
          print('DEBUG: Arquivo local encontrado. Chamando OpenFilex.open');
          final result = await OpenFilex.open(work.localPath!);
          print('DEBUG: OpenFilex result (local): ${result.type} - ${result.message}');
          return;
        }
      }

      // Se não, baixa para pasta temporária e abre
      print('DEBUG: Arquivo local indisponível. Iniciando fluxo de bytes (cache/download).');
      final bytes = await _getFileBytes(work);
      
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/${work.fileName ?? "${work.title}.docx"}';
        print('DEBUG: Gravando bytes no arquivo temporário: $tempPath');
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(bytes);
        
        print('DEBUG: Arquivo temporário gravado. Chamando OpenFilex.open');
        final result = await OpenFilex.open(tempPath);
        print('DEBUG: OpenFilex result (temp): ${result.type} - ${result.message}');
      } else {
        print('DEBUG ERROR: Falha ao obter bytes para abertura (bytes == null)');
        if (mounted) {
          final isSafPath = work.localPath?.startsWith('/document/') ?? work.localPath?.startsWith('content://') ?? false;
          final message = isSafPath 
            ? 'Este arquivo foi salvo em uma pasta externa e não pode ser reaberto por aqui. Verifique o arquivo diretamente na pasta que você escolheu.'
            : 'Não foi possível obter o arquivo para abrir (Link de backup não disponível).';
            
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
          );
        }
      }
    } catch (e) {
      print('DEBUG ERROR: Exceção capturada em _openWorkFile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir arquivo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      print('DEBUG: _openWorkFile finalizado');
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _saveWorkAs(AcademicWork work) async {
    print('DEBUG: _saveWorkAs iniciado para: ${work.title}');
    setState(() => _isActionLoading = true);
    
    try {
      print('DEBUG: Obtendo bytes para salvamento...');
      final bytes = await _getFileBytes(work);
      
      if (bytes == null) {
        print('DEBUG ERROR: Falha ao obter bytes para salvamento (bytes == null)');
        if (mounted) {
          final isSafPath = work.localPath?.startsWith('/document/') ?? work.localPath?.startsWith('content://') ?? false;
          final message = isSafPath 
            ? 'Este arquivo foi salvo em uma pasta externa e não pode ser copiado por aqui. Verifique o arquivo original na pasta que você escolheu.'
            : 'Não foi possível obter os dados do arquivo (Link de backup não disponível).';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
          );
        }
        return;
      }

      final fileName = work.fileName ?? '${work.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.docx';
      
      print('DEBUG: Chamando FilePicker.saveFile com fileName: $fileName');
      final chosenUri = await FilePicker.saveFile(
        dialogTitle: 'Salvar Trabalho em...',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['docx'],
        bytes: bytes,
      );

      print('DEBUG: FilePicker.saveFile retornou chosenUri: $chosenUri');

      if (mounted && chosenUri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo salvo com sucesso!')),
        );
      }
    } catch (e) {
      print('DEBUG ERROR: Exceção capturada em _saveWorkAs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar arquivo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      print('DEBUG: _saveWorkAs finalizado');
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _regenerateWork(AcademicWork work) async {
    context.push('/create-work', extra: work);
  }

  Future<void> _shareWork(AcademicWork work) async {
    setState(() => _isActionLoading = true);
    try {
      if (work.localPath != null && await File(work.localPath!).exists()) {
        await SharePlus.instance.share(ShareParams(files: [XFile(work.localPath!)], text: work.title));
      } else {
        final bytes = await _getFileBytes(work);
        if (bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/${work.fileName ?? "${work.title}.docx"}';
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(bytes);
          await SharePlus.instance.share(ShareParams(files: [XFile(tempPath)], text: work.title));
        }
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Widget _buildWorkCard(BuildContext context, AcademicWork work) {
    Color statusColor = Colors.grey;
    String statusText = 'Pendente';

    switch (work.status) {
      case WorkStatus.completed:
        statusColor = Colors.green;
        statusText = 'Concluído';
        break;
      case WorkStatus.processing:
        statusColor = Colors.orange;
        statusText = 'Processando';
        break;
      case WorkStatus.failed:
        statusColor = Colors.red;
        statusText = 'Falha';
        break;
      default:
        break;
    }

    final dateStr = "${work.createdAt.day.toString().padLeft(2, '0')}/${work.createdAt.month.toString().padLeft(2, '0')}/${work.createdAt.year}";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        work.subject,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (work.status == WorkStatus.completed) ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
                    onPressed: () => _openWorkFile(work),
                    tooltip: 'Abrir',
                  ),
                  IconButton(
                    icon: const Icon(Icons.save_alt, color: Colors.green),
                    onPressed: () => _saveWorkAs(work),
                    tooltip: 'Salvar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.blueGrey),
                    onPressed: () => _shareWork(work),
                    tooltip: 'Partilhar',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  onPressed: () => _regenerateWork(work),
                  tooltip: 'Regenerar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worksAsync = ref.watch(userWorksProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho adaptativo
          isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meus Trabalhos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meus Trabalhos',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar trabalhos...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 32),
          Expanded(
            child: worksAsync.when(
              data: (works) {
                final filteredWorks = works.where((w) {
                  return w.title.toLowerCase().contains(_searchQuery) ||
                      w.subject.toLowerCase().contains(_searchQuery);
                }).toList();

                if (works.isEmpty) {
                  return _buildEmptyState();
                }

                if (filteredWorks.isEmpty) {
                  return const Center(child: Text('Nenhum trabalho encontrado para esta pesquisa.'));
                }

                // Conteúdo Principal: Cartões para Mobile, Tabela para Desktop
                final mainContent = isMobile
                  ? ListView.builder(
                      itemCount: filteredWorks.length,
                      itemBuilder: (context, index) => _buildWorkCard(context, filteredWorks[index]),
                    )
                  : Card(
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 100),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                              columns: const [
                                DataColumn(label: Text('Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Disciplina', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredWorks.map((work) => _buildDataRow(context, work)).toList(),
                            ),
                          ),
                        ),
                      ),
                    );

                return Stack(
                  children: [
                    mainContent,
                    if (_isActionLoading)
                      Container(
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erro ao carregar histórico: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Você ainda não possui trabalhos gerados.', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/create-work'),
            icon: const Icon(Icons.add),
            label: const Text('Criar meu primeiro trabalho'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, AcademicWork work) {
    Color statusColor = Colors.grey;
    String statusText = 'Pendente';

    switch (work.status) {
      case WorkStatus.completed:
        statusColor = Colors.green;
        statusText = 'Concluído';
        break;
      case WorkStatus.processing:
        statusColor = Colors.orange;
        statusText = 'Processando';
        break;
      case WorkStatus.failed:
        statusColor = Colors.red;
        statusText = 'Falha';
        break;
      default:
        break;
    }

    final dateStr = "${work.createdAt.day.toString().padLeft(2, '0')}/${work.createdAt.month.toString().padLeft(2, '0')}/${work.createdAt.year}";

    return DataRow(cells: [
      DataCell(Text(work.title, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(work.subject)),
      DataCell(Text(dateStr)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
      DataCell(
        Row(
          children: [
            if (work.status == WorkStatus.completed) ...[
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.blue), 
                onPressed: () => _openWorkFile(work),
                tooltip: 'Abrir arquivo',
              ),
              IconButton(
                icon: const Icon(Icons.save_alt, color: Colors.green),
                onPressed: () => _saveWorkAs(work),
                tooltip: 'Salvar como...',
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.blueGrey),
                onPressed: () => _shareWork(work),
                tooltip: 'Compartilhar',
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: () => _regenerateWork(work),
              tooltip: 'Regenerar (Usar mesmos dados)',
            ),
          ],
        ),
      ),
    ]);
  }
}
