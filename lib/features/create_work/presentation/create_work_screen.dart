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
import '../../../providers/ai_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/work_provider.dart';
import '../../../providers/credit_provider.dart';
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
  final _instructionsController = TextEditingController();

  String _selectedLevel = 'Universidade';
  String _selectedType = 'Trabalho de pesquisa';
  String _selectedPages = '10';
  String _selectedLanguage = 'Português';

  // ABNT Settings
  bool _isAbnt = true;
  Map<String, bool> _abntSections = {
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
      _selectedPages = work.pageCount.toString();
      _selectedLanguage = work.language;
      _isAbnt = work.isAbnt;
      
      if (work.abntSections.isNotEmpty) {
        _abntSections.updateAll((key, value) => work.abntSections.contains(key));
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
    _instructionsController.dispose();
    super.dispose();
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
      _loadingMessage = 'Gerando conteúdo...';
    });

    try {
      final aiService = ref.read(aiServiceProvider);

      final selectedAbntSections = _isAbnt
          ? _abntSections.entries.where((e) => e.value).map((e) => e.key).toList()
          : <String>[];

      final structuredContent = await aiService.generateStructuredContent(
        title: _titleController.text,
        subtitle: _subtitleController.text,
        theme: _titleController.text,
        subject: _disciplineController.text,
        type: _selectedType,
        level: _selectedLevel,
        pages: int.tryParse(_selectedPages) ?? 10,
        language: _selectedLanguage,
        instructions: _instructionsController.text,
        isAbnt: _isAbnt,
        abntSections: selectedAbntSections,
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
          pageCount: int.tryParse(_selectedPages) ?? 10,
          content: jsonEncode(structuredContent),
          status: WorkStatus.completed,
          createdAt: DateTime.now(),
          costInCredits: 0,
          course: _courseController.text.isEmpty ? null : _courseController.text,
          studentClass: _classController.text,
          institution: _institutionController.text.isEmpty ? null : _institutionController.text,
          professor: _professorController.text.isEmpty ? null : _professorController.text,
          city: _cityController.text.isEmpty ? null : _cityController.text,
          year: _yearController.text.isEmpty ? null : _yearController.text,
          instructions: _instructionsController.text.isEmpty ? null : _instructionsController.text,
          students: finalStudents,
          isAbnt: _isAbnt,
          abntSections: selectedAbntSections,
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

    // 1. Verificação de Créditos (Usando o campo direto do perfil como única fonte de verdade)
    final int currentCredits = user.credits;
    print('DEBUG: Créditos atuais: $currentCredits');

    if (currentCredits < 1) {
      print('DEBUG: Créditos insuficientes');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Créditos Insuficientes'),
            content: const Text('Você não possui créditos suficientes para gerar este trabalho. Deseja comprar mais?'),
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

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Processando crédito...';
    });

    try {
      // 2. Debitar Crédito
      print('DEBUG: Chamando useCredit para user: ${user.uid}');
      await ref.read(creditServiceProvider).useCredit(user.uid, _generatedWork!.title);
      print('DEBUG: useCredit concluído com sucesso');

      setState(() {
        _loadingMessage = 'Preparando documento...';
      });

      // 3. Criar registro inicial como 'processing'
      final initialWork = _generatedWork!.copyWith(status: WorkStatus.processing);
      print('DEBUG: Salvando trabalho inicial (saveWork)');
      await ref.read(workServiceProvider).saveWork(initialWork);
      print('DEBUG: saveWork concluído');

      setState(() {
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
        'isAbnt': _generatedWork!.isAbnt,
        'abntSections': _generatedWork!.abntSections,
      };

      print('DEBUG: Chamando generateDocx na API');
      final bytes = await aiService.generateDocx(
        userData: userData,
        content: _structuredContent!,
      );
      print('DEBUG: generateDocx recebeu ${bytes.length} bytes');

      setState(() {
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
      } else {
        // 2. Fallback: Salvar na pasta interna do App se o usuário cancelar ou ocorrer erro
        print('DEBUG: Usando salvamento interno (fallback)');
        final directory = await getApplicationDocumentsDirectory();
        finalPath = '${directory.path}/$fileName';
        final file = File(finalPath);
        await file.writeAsBytes(bytes);
        print('DEBUG: Arquivo salvo internamente em: $finalPath');
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
                    // Compartilhar só é confiável a partir do arquivo interno (path de sistema de arquivos real).
                    // Quando salvo via SAF (content URI), o próprio app de arquivos/Drive já permite compartilhar.
                    if (!savedInExternalStorage) {
                      SharePlus.instance.share(ShareParams(files: [XFile(finalPath)], text: 'Meu trabalho acadêmico: $fileName'));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Arquivo já salvo na pasta escolhida. Use o app de arquivos para compartilhar.')),
                      );
                    }
                  },
                  child: const Text('Compartilhar')
              ),
              ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Abrir diretamente só funciona com path de sistema de arquivos real (fallback interno).
                    if (!savedInExternalStorage) {
                      await OpenFilex.open(finalPath);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Use o app de arquivos ou Google Drive para abrir o documento salvo.')),
                      );
                    }
                  },
                  child: const Text('Abrir Arquivo')
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar')
              ),
            ],
          ),
        );
      }

      // 4. Atualizar para 'completed' com o caminho do arquivo final
      print('DEBUG: Atualizando status para completed no service com path: $finalPath');
      await ref.read(workServiceProvider).updateWorkStatus(
        _generatedWork!.id,
        WorkStatus.completed,
        localPath: finalPath,
        fileName: fileName,
      );
      print('DEBUG: updateWorkStatus concluído');

    } catch (e) {
      print('DEBUG ERROR: Erro capturado em _finalizeAndSave: $e');
      // 3. Marcar como falha no Firestore
      if (_generatedWork != null) {
        try {
          await ref.read(workServiceProvider).updateWorkStatus(
            _generatedWork!.id,
            WorkStatus.failed,
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
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(_loadingMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ))
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
            title: const Text('ABNT'),
            isActive: _currentStep >= 4,
            content: _isAbnt ? _buildAbntStep() : const Text('Formatação normal selecionada.'),
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedPages,
          decoration: const InputDecoration(labelText: 'Tamanho (Páginas)', border: OutlineInputBorder()),
          items: ['5', '10', '20', '30'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _selectedPages = v!),
        ),
        const SizedBox(height: 12),
        TextField(controller: _instructionsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Instruções Adicionais', border: OutlineInputBorder())),
      ],
    );
  }

  Widget _buildFormattingStep() {
    return Column(
      children: [
        RadioListTile<bool>(
            title: const Text('ABNT (Associação Brasileira de Normas Técnicas)'),
            subtitle: const Text('Margens 3/3/2/2, Espaçamento 1.5 e formatação rígida.'),
            value: true,
            // ignore: deprecated_member_use
            groupValue: _isAbnt,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _isAbnt = v!)
        ),
        RadioListTile<bool>(
            title: const Text('Normal / Profissional'),
            subtitle: const Text('Estética moderna, limpa e elegante para documentos executivos.'),
            value: false,
            // ignore: deprecated_member_use
            groupValue: _isAbnt,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _isAbnt = v!)
        ),
      ],
    );
  }

  Widget _buildAbntStep() {
    return Column(
      children: [
        CheckboxListTile(title: const Text('Todo o trabalho'), value: _abntSections.values.every((v) => v), onChanged: (v) => setState(() => _abntSections.updateAll((k, val) => v!))),
        ..._abntSections.keys.map((k) => CheckboxListTile(title: Text(k), value: _abntSections[k], onChanged: (v) => setState(() => _abntSections[k] = v!))),
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