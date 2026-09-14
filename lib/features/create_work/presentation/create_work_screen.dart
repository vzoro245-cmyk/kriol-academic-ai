import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:saf/saf.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/work_provider.dart';
import '../../../providers/credit_provider.dart';
import '../../../providers/persistence_provider.dart';
import '../../../models/academic_work.dart';

class CreateWorkScreen extends ConsumerStatefulWidget {
  final AcademicWork? initialWork;
  const CreateWorkScreen({super.key, this.initialWork});

  @override
  ConsumerState<CreateWorkScreen> createState() => _CreateWorkScreenState();
}

class _CreateWorkScreenState extends ConsumerState<CreateWorkScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String _loadingMessage = 'Preparando trabalho...';
  int _loadingStep = 0; // 0: IA, 1: Crédito, 2: Preparando, 3: Formatando, 4: Salvando
  bool _isIndividual = true;
  final List<Student> _students = [];
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();

  // Form Controllers
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _disciplineController = TextEditingController();
  final _institutionController = TextEditingController();
  final _professorController = TextEditingController();
  final _courseController = TextEditingController();
  final _classController = TextEditingController();
  final _cityController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  final _pagesController = TextEditingController(text: '10');
  final _instructionsController = TextEditingController();

  String _selectedLevel = 'Universidade';
  String _selectedType = 'Trabalho de pesquisa';
  String _selectedLanguage = 'Português';

  // Work Structure Settings
  String _selectedFormat = 'abnt'; // 'abnt', 'professional', 'apa'
  Map<String, bool> _includedSections = {
    'Capa': true,
    'Folha de rosto': true,
    'Sumário': true,
    'Introdução': true,
    'Desenvolvimento': true,
    'Conclusão': true,
    'Referências': true,
  };

  AcademicWork? _generatedWork;
  Map<String, dynamic>? _structuredContent;

  @override
  void initState() {
    super.initState();
    if (widget.initialWork != null) {
      final work = widget.initialWork!;
      _titleController.text = work.title;
      _subtitleController.text = work.subtitle ?? '';
      _disciplineController.text = work.subject;
      _institutionController.text = work.institution ?? '';
      _professorController.text = work.professor ?? '';
      _courseController.text = work.course ?? '';
      _classController.text = work.studentClass;
      _cityController.text = work.city ?? '';
      _yearController.text = work.year ?? DateTime.now().year.toString();
      _instructionsController.text = work.instructions ?? '';
      
      _selectedLevel = work.level;
      _selectedType = work.type;
      _pagesController.text = work.pageCount.toString();
      _selectedLanguage = work.language;
      
      // Mapeamento de compatibilidade
      if (work.isAbnt) {
        _selectedFormat = 'abnt';
      } else {
        _selectedFormat = 'professional';
      }
      
      if (work.abntSections.isNotEmpty) {
        _includedSections.updateAll((key, value) => work.abntSections.contains(key));
      }

      if (work.students.isNotEmpty) {
        if (work.students.length == 1) {
          _isIndividual = true;
          _studentNameController.text = work.students.first.name;
          _studentNumberController.text = work.students.first.studentNumber;
        } else {
          _isIndividual = false;
          _students.addAll(work.students);
        }
      }
    }
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _studentNumberController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _disciplineController.dispose();
    _institutionController.dispose();
    _professorController.dispose();
    _courseController.dispose();
    _classController.dispose();
    _cityController.dispose();
    _yearController.dispose();
    _pagesController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  int _calculateCredits(int pages) {
    if (pages < 5) return 1;
    return ((pages - 5) ~/ 5) + 1;
  }

  void _addStudent() {
    if (_students.length >= 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este grupo já atingiu o limite máximo de 25 alunos.')),
      );
      return;
    }

    if (_studentNameController.text.isNotEmpty && _studentNumberController.text.isNotEmpty) {
      setState(() {
        _students.add(Student(
          name: _studentNameController.text,
          studentNumber: _studentNumberController.text,
        ));
        _studentNameController.clear();
        _studentNumberController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e o número do aluno.')),
      );
    }
  }

  void _removeStudent(int index) {
    setState(() {
      _students.removeAt(index);
    });
  }

  Future<void> _generateContent() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _loadingStep = 0;
      _loadingMessage = 'Gerando conteúdo...';
    });

    try {
      final aiService = ref.read(aiServiceProvider);

      final includedSectionsList = _includedSections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final pages = int.tryParse(_pagesController.text) ?? 10;
      final cost = _calculateCredits(pages);

      final structuredContent = await aiService.generateStructuredContent(
        title: _titleController.text,
        subtitle: _subtitleController.text,
        theme: _titleController.text,
        subject: _disciplineController.text,
        type: _selectedType,
        level: _selectedLevel,
        pages: pages,
        language: _selectedLanguage,
        instructions: _instructionsController.text,
        isAbnt: _selectedFormat == 'abnt',
        abntSections: includedSectionsList,
        // Adicionando campo extra para o backend identificar a norma específica
        extraParams: {
          'formattingStandard': _selectedFormat,
        },
      );

      final finalStudents = _isIndividual
          ? [Student(name: _studentNameController.text, studentNumber: _studentNumberController.text)]
          : _students;

      setState(() {
        _structuredContent = structuredContent;
        _generatedWork = AcademicWork(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _titleController.text,
          subtitle: _subtitleController.text.isEmpty ? null : _subtitleController.text,
          subject: _disciplineController.text,
          theme: _titleController.text,
          type: _selectedType,
          level: _selectedLevel,
          language: _selectedLanguage,
          pageCount: pages,
          content: jsonEncode(structuredContent),
          status: WorkStatus.completed,
          createdAt: DateTime.now(),
          costInCredits: cost,
          course: _courseController.text.isEmpty ? null : _courseController.text,
          studentClass: _classController.text,
          institution: _institutionController.text.isEmpty ? null : _institutionController.text,
          professor: _professorController.text.isEmpty ? null : _professorController.text,
          city: _cityController.text.isEmpty ? null : _cityController.text,
          year: _yearController.text.isEmpty ? null : _yearController.text,
          instructions: _instructionsController.text.isEmpty ? null : _instructionsController.text,
          students: finalStudents,
          isAbnt: _selectedFormat == 'abnt',
          abntSections: includedSectionsList,
        );
        _currentStep++; // Move to review step
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeAndSave() async {
    print('DEBUG: _finalizeAndSave iniciado');
    if (_generatedWork == null || _structuredContent == null) {
      print('DEBUG: _generatedWork ou _structuredContent é nulo');
      return;
    }

    // Obtendo o perfil do usuário (Fonte de Verdade)
    final userProfileAsync = ref.read(userProfileProvider);
    final user = userProfileAsync.value;

    if (user == null) {
      print('DEBUG: Usuário é nulo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Perfil de usuário não carregado.')),
        );
      }
      return;
    }

    // 1. Verificação de Créditos
    final int currentCredits = user.credits;
    final int cost = _generatedWork!.costInCredits;
    print('DEBUG: Créditos atuais: $currentCredits, Custo: $cost');

    if (currentCredits < cost) {
      print('DEBUG: Créditos insuficientes');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Créditos Insuficientes'),
            content: Text('Você não possui créditos suficientes para gerar este trabalho ($cost necessários). Deseja comprar mais?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/credits');
                  },
                  child: const Text('Comprar Créditos')
              ),
            ],
          ),
        );
      }
      return;
    }

    // Diálogo de confirmação final de custo
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Geração'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Título: ${_generatedWork!.title}'),
            const SizedBox(height: 8),
            Text('Tamanho: ${_generatedWork!.pageCount} páginas'),
            Text('Custo: $cost créditos'),
            const Divider(height: 32),
            Text('Seu saldo: $currentCredits créditos', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
            child: const Text('Confirmar e Gerar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _loadingStep = 1;
      _loadingMessage = 'Processando crédito...';
    });

    try {
      // 2. Debitar Crédito (com valor dinâmico)
      print('DEBUG: Chamando useCredit para user: ${user.uid}, cost: $cost');
      await ref.read(creditServiceProvider).useCredit(
        user.uid, 
        _generatedWork!.title, 
        amount: cost, 
        pages: _generatedWork!.pageCount
      );
      print('DEBUG: useCredit concluído com sucesso');

      setState(() {
        _loadingStep = 2;
        _loadingMessage = 'Preparando documento...';
      });

      // 3. Criar registro inicial como 'processing'
      final initialWork = _generatedWork!.copyWith(status: WorkStatus.processing);
      print('DEBUG: Salvando trabalho inicial (saveWork)');
      await ref.read(workServiceProvider).saveWork(initialWork);
      print('DEBUG: saveWork concluído');

      setState(() {
        _loadingStep = 3;
        _loadingMessage = 'Aplicando formatação profissional...';
      });

      final aiService = ref.read(aiServiceProvider);
      final userData = {
        'workId': _generatedWork!.id,
        'userId': user.uid,
        'title': _generatedWork!.title,
        'subtitle': _generatedWork!.subtitle,
        'theme': _generatedWork!.theme,
        'subject': _generatedWork!.subject,
        'type': _generatedWork!.type,
        'level': _generatedWork!.level,
        'language': _generatedWork!.language,
        'institution': _institutionController.text,
        'professor': _professorController.text,
        'course': _courseController.text,
        'studentClass': _generatedWork!.studentClass,
        'students': _generatedWork!.students.map((e) => e.toMap()).toList(),
        'city': _cityController.text,
        'year': _yearController.text,
        'isAbnt': _selectedFormat == 'abnt',
        'formattingStandard': _selectedFormat,
        'abntSections': _generatedWork!.abntSections,
      };

      print('DEBUG: Chamando generateDocx na API');
      final bytes = await aiService.generateDocx(
        userData: userData,
        content: _structuredContent!,
      );
      print('DEBUG: generateDocx recebeu ${bytes.length} bytes');

      setState(() {
        _loadingStep = 4;
        _loadingMessage = 'Salvando DOCX...';
      });

      final safeTitle = _generatedWork!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '$safeTitle.docx';
      Uri? chosenUri;

      print('DEBUG: Iniciando fluxo de salvamento');

      try {
        // 1. Tentar salvar via Seletor Nativo (Storage Access Framework)
        print('DEBUG: Abrindo seletor de arquivos');
        chosenUri = await FilePicker.saveFile(
          dialogTitle: 'Salvar Trabalho Acadêmico',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['docx'],
          bytes: bytes, // Grava os bytes diretamente se o usuário escolher o local
        );
      } catch (e) {
        print('DEBUG: Erro ao abrir seletor: $e');
      }

      String finalPath;
      bool savedInExternalStorage = chosenUri != null;

      if (savedInExternalStorage) {
        finalPath = chosenUri.toString();
        print('DEBUG: Arquivo salvo pelo usuário em: $finalPath');
        
        // ETAPA 1: Persistir permissão e registrar no Firestore (Nova Estrutura)
        await ref.read(workPersistenceServiceProvider).persistAndRegister(
          workId: _generatedWork!.id,
          userId: user.uid,
          uri: finalPath,
          fileName: fileName,
          pages: _generatedWork!.pageCount,
          norm: _selectedFormat.toUpperCase(),
        );
      } else {
        // 2. Fallback: Salvar na pasta interna do App se o usuário cancelar ou ocorrer erro
        print('DEBUG: Usando salvamento interno (fallback)');
        final directory = await getApplicationDocumentsDirectory();
        finalPath = '${directory.path}/$fileName';
        final file = File(finalPath);
        await file.writeAsBytes(bytes);
        print('DEBUG: Arquivo salvo internamente em: $finalPath');

        // Atualizar Firestore para o fallback (Nova Estrutura)
        await ref.read(workServiceProvider).updateWorkStatus(
          _generatedWork!.id,
          WorkStatus.completed,
          localPath: finalPath,
          fileName: fileName,
          norm: _selectedFormat.toUpperCase(),
          pages: _generatedWork!.pageCount,
          userId: user.uid,
        );
      }

      // 3. Mostrar Diálogo de Ação Final (Mantendo Abrir e Compartilhar)
      if (mounted) {
        print('DEBUG: Mostrando diálogo de sucesso');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Trabalho Gerado'),
            content: Text(savedInExternalStorage
                ? 'O arquivo foi salvo com sucesso em:\n$fileName'
                : 'O seletor foi cancelado. O arquivo foi salvo temporariamente nos documentos do app.'),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (!savedInExternalStorage) {
                      SharePlus.instance.share(ShareParams(files: [XFile(finalPath)], text: 'Meu trabalho acadêmico: $fileName'));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Arquivo já salvo na pasta escolhida. Use o app de arquivos para compartilhar.')),
                      );
                    }
                    context.go('/dashboard');
                  },
                  child: const Text('Compartilhar')
              ),
              ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (!savedInExternalStorage) {
                      await OpenFilex.open(finalPath);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Use o app de arquivos ou Google Drive para abrir o documento salvo.')),
                      );
                    }
                    if (mounted) context.go('/dashboard');
                  },
                  child: const Text('Abrir Arquivo')
              ),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/dashboard');
                  },
                  child: const Text('Fechar')
              ),
            ],
          ),
        );
      }
      print('DEBUG: Fluxo finalizado com sucesso');

    } catch (e) {
      print('DEBUG ERROR: Erro capturado em _finalizeAndSave: $e');
      // 3. Marcar como falha no Firestore (Nova Estrutura)
      if (_generatedWork != null) {
        try {
          await ref.read(workServiceProvider).updateWorkStatus(
            _generatedWork!.id,
            WorkStatus.failed,
            userId: user.uid,
          );
          print('DEBUG: Status atualizado para failed no catch');
        } catch (saveErr) {
          print('DEBUG ERROR: Falha ao atualizar status para failed: $saveErr');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      print('DEBUG: _finalizeAndSave finalizado (finally)');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Dados do Trabalho
        if (_titleController.text.trim().isEmpty || _disciplineController.text.trim().isEmpty || _classController.text.trim().isEmpty || _professorController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título, Disciplina, Turma e Professor são obrigatórios.')));
          return false;
        }
        return true;
      case 2: // Conteúdo (IA)
        final pages = int.tryParse(_pagesController.text) ?? 0;
        if (pages < 5 || pages > 25) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O número de páginas deve estar entre 5 e 25.')));
          return false;
        }
        return true;
      case 1: // Alunos
        if (_isIndividual) {
          if (_studentNameController.text.trim().isEmpty || _studentNumberController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e Número do aluno são obrigatórios.')));
            return false;
          }
        } else if (_students.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um integrante.')));
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Trabalho Acadêmico'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinearProgressIndicator(
                      value: (_loadingStep + 1) / 5,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 48),
                    _buildLoadingStep('Gerando rascunho com IA', 0),
                    _buildLoadingStep('Validando créditos', 1),
                    _buildLoadingStep('Preparando estrutura', 2),
                    _buildLoadingStep('Aplicando formatação ABNT/Profissional', 3),
                    _buildLoadingStep('Finalizando arquivo DOCX', 4),
                  ],
                ),
              ),
            )
          : Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_validateCurrentStep()) {
            if (_currentStep == 2) {
              _generateContent();
            } else if (_currentStep == 5) {
              _finalizeAndSave();
            } else {
              setState(() => _currentStep++);
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        steps: [
          Step(
            title: const Text('Dados do Trabalho'),
            isActive: _currentStep >= 0,
            content: _buildWorkDataStep(),
          ),
          Step(
            title: const Text('Alunos'),
            isActive: _currentStep >= 1,
            content: _buildAutoriaStep(),
          ),
          Step(
            title: const Text('Conteúdo (IA)'),
            isActive: _currentStep >= 2,
            content: _buildConfigurationStep(),
          ),
          Step(
            title: const Text('Formatação'),
            isActive: _currentStep >= 3,
            content: _buildFormattingStep(),
          ),
          Step(
            title: const Text('Estrutura do Trabalho'),
            isActive: _currentStep >= 4,
            content: _buildStructureStep(),
          ),
          Step(
            title: const Text('Revisão e Geração'),
            isActive: _currentStep >= 5,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStep(String label, int stepIndex) {
    bool isCompleted = _loadingStep > stepIndex;
    bool isCurrent = _loadingStep == stepIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (isCompleted)
            const Icon(Icons.check_circle, color: Colors.green, size: 24)
          else if (isCurrent)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.circle_outlined, color: Colors.grey[300], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Theme.of(context).colorScheme.primary : (isCompleted ? Colors.black87 : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDataStep() {
    return Column(
      children: [
        TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título do Trabalho *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _subtitleController, decoration: const InputDecoration(labelText: 'Subtítulo (Opcional)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _disciplineController, decoration: const InputDecoration(labelText: 'Disciplina *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _classController, decoration: const InputDecoration(labelText: 'Turma *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _courseController, decoration: const InputDecoration(labelText: 'Curso (Opcional)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _institutionController, decoration: const InputDecoration(labelText: 'Instituição', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _professorController, decoration: const InputDecoration(labelText: 'Professor/Orientador *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _yearController, decoration: const InputDecoration(labelText: 'Ano', border: OutlineInputBorder()))),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoriaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(label: const Text('Individual'), selected: _isIndividual, onSelected: (v) => setState(() => _isIndividual = v)),
            const SizedBox(width: 12),
            ChoiceChip(label: const Text('Grupo'), selected: !_isIndividual, onSelected: (v) => setState(() => _isIndividual = !v)),
          ],
        ),
        const SizedBox(height: 16),
        if (_isIndividual)
          Column(
            children: [
              TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: 'Nome do Aluno *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: _studentNumberController,
                decoration: const InputDecoration(labelText: 'Número do Aluno *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _studentNumberController,
                    decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  )),
                  IconButton(onPressed: _addStudent, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Integrantes: ${_students.length}/25', style: const TextStyle(fontWeight: FontWeight.bold)),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _students.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(_students[i].name),
                  subtitle: Text('Nº ${_students[i].studentNumber}'),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _removeStudent(i)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildConfigurationStep() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedLanguage,
          decoration: const InputDecoration(labelText: 'Idioma', border: OutlineInputBorder()),
          items: ['Português', 'Inglês', 'Francês'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _selectedLanguage = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pagesController,
          decoration: InputDecoration(
            labelText: 'Tamanho (5 a 25 páginas) *',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.auto_stories_outlined),
            helperText: 'Custo: ${_calculateCredits(int.tryParse(_pagesController.text) ?? 5)} crédito(s)',
            helperStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(controller: _instructionsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Instruções Adicionais', border: OutlineInputBorder())),
      ],
    );
  }

  Widget _buildFormattingStep() {
    return Column(
      children: [
        RadioListTile<String>(
            title: const Text('ABNT (Normas Brasileiras)'),
            subtitle: const Text('Margens 3/3/2/2, Espaçamento 1.5 e formatação rígida.'),
            value: 'abnt',
            groupValue: _selectedFormat,
            onChanged: (v) => setState(() => _selectedFormat = v!)
        ),
        RadioListTile<String>(
            title: const Text('Normal / Profissional'),
            subtitle: const Text('Estética moderna, limpa e elegante para documentos executivos.'),
            value: 'professional',
            groupValue: _selectedFormat,
            onChanged: (v) => setState(() => _selectedFormat = v!)
        ),
        RadioListTile<String>(
            title: const Text('APA (7ª Edição)'),
            subtitle: const Text('Padrão internacional. Espaçamento duplo e margens de 2.54cm.'),
            value: 'apa',
            groupValue: _selectedFormat,
            onChanged: (v) => setState(() => _selectedFormat = v!)
        ),
      ],
    );
  }

  Widget _buildStructureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecione as seções que devem constar no documento final:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Todas as seções'), 
          value: _includedSections.values.every((v) => v), 
          onChanged: (v) => setState(() => _includedSections.updateAll((k, val) => v!))
        ),
        const Divider(),
        ..._includedSections.keys.map((k) => CheckboxListTile(
          title: Text(k), 
          value: _includedSections[k], 
          onChanged: (v) => setState(() => _includedSections[k] = v!)
        )),
      ],
    );
  }

  Widget _buildReviewStep() {
    if (_generatedWork == null) return const Text('Gere o conteúdo no passo anterior.');
    return const Column(
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        SizedBox(height: 12),
        Text('Conteúdo estruturado pronto!', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Clique em "Continuar" para salvar e gerar o arquivo final.'),
      ],
    );
  }
}