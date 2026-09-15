import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
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
  int _loadingStep = 0;
  bool _isIndividual = true;
  final List<Student> _students = [];
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();

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
  String _selectedFormat = 'abnt'; 

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
      _selectedFormat = work.isAbnt ? 'abnt' : 'professional';
    }
  }

  @override
  void dispose() {
    _studentNameController.dispose(); _studentNumberController.dispose();
    _titleController.dispose(); _subtitleController.dispose();
    _disciplineController.dispose(); _institutionController.dispose();
    _professorController.dispose(); _courseController.dispose();
    _classController.dispose(); _cityController.dispose();
    _yearController.dispose(); _pagesController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  int _calculateCredits(int pages) => pages < 5 ? 1 : ((pages - 5) ~/ 5) + 1;

  Future<void> _generateContent() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    setState(() { _isLoading = true; _loadingStep = 0; _loadingMessage = 'Gerando conteúdo...'; });

    try {
      final pages = int.tryParse(_pagesController.text) ?? 10;
      final cost = _calculateCredits(pages);

      // O App não envia mais a lista de seções, o backend decide pela norma
      final structuredContent = await ref.read(aiServiceProvider).generateStructuredContent(
        title: _titleController.text, subtitle: _subtitleController.text,
        theme: _titleController.text, subject: _disciplineController.text,
        type: _selectedType, level: _selectedLevel, pages: pages,
        language: _selectedLanguage, instructions: _instructionsController.text,
        isAbnt: _selectedFormat == 'abnt',
        abntSections: [], 
        extraParams: {'formattingStandard': _selectedFormat},
      );

      setState(() {
        _structuredContent = structuredContent;
        _generatedWork = AcademicWork(
          id: const Uuid().v4(), userId: user.uid,
          title: _titleController.text,
          subtitle: _subtitleController.text.isEmpty ? null : _subtitleController.text,
          subject: _disciplineController.text, theme: _titleController.text,
          type: _selectedType, level: _selectedLevel, language: _selectedLanguage,
          pageCount: pages, content: jsonEncode(structuredContent),
          status: WorkStatus.completed, createdAt: DateTime.now(), costInCredits: cost,
          course: _courseController.text.isEmpty ? null : _courseController.text,
          studentClass: _classController.text,
          institution: _institutionController.text.isEmpty ? null : _institutionController.text,
          professor: _professorController.text.isEmpty ? null : _professorController.text,
          city: _cityController.text.isEmpty ? null : _cityController.text,
          year: _yearController.text.isEmpty ? null : _yearController.text,
          instructions: _instructionsController.text.isEmpty ? null : _instructionsController.text,
          students: _isIndividual ? [Student(name: _studentNameController.text, studentNumber: _studentNumberController.text)] : _students,
          isAbnt: _selectedFormat == 'abnt',
          abntSections: [], // Armazenamos vazio, Python cuidará do mapping
        );
        _currentStep = 4; // Vai para Finalizar
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _finalizeAndSave() async {
    if (_generatedWork == null || _structuredContent == null) return;
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final cost = _generatedWork!.costInCredits;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Geração'),
        content: Text('Custo: $cost créditos. Saldo: ${user.credits}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gerar Agora')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() { _isLoading = true; _loadingStep = 1; _loadingMessage = 'Processando...'; });

    try {
      await ref.read(creditServiceProvider).useCredit(user.uid, _generatedWork!.title, amount: cost, pages: _generatedWork!.pageCount);
      setState(() { _loadingStep = 2; _loadingMessage = 'Formatando...'; });
      
      final bytes = await ref.read(aiServiceProvider).generateDocx(
        userData: {
          'workId': _generatedWork!.id, 'userId': user.uid, 'title': _generatedWork!.title,
          'subtitle': _generatedWork!.subtitle, 'theme': _generatedWork!.theme,
          'subject': _generatedWork!.subject, 'type': _generatedWork!.type,
          'level': _generatedWork!.level, 'language': _generatedWork!.language,
          'institution': _institutionController.text, 'professor': _professorController.text,
          'course': _courseController.text, 'studentClass': _generatedWork!.studentClass,
          'students': _generatedWork!.students.map((e) => e.toMap()).toList(),
          'city': _cityController.text, 'year': _yearController.text,
          'formattingStandard': _selectedFormat, 'isAbnt': _selectedFormat == 'abnt',
          'abntSections': [], // Backend aplicará o mapping obrigatório
        },
        content: _structuredContent!,
      );

      final fileName = '${_generatedWork!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.docx';
      final directory = await getApplicationDocumentsDirectory();
      final finalPath = '${directory.path}/$fileName';
      await File(finalPath).writeAsBytes(bytes);

      if (mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
          title: const Text('Sucesso'), content: const Text('Trabalho pronto no Histórico!'),
          actions: [TextButton(onPressed: () => context.go('/dashboard'), child: const Text('OK'))],
        ));
      }
      await ref.read(workServiceProvider).saveWork(_generatedWork!.copyWith(status: WorkStatus.completed, localPath: finalPath, fileName: fileName));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Trabalho Acadêmico')),
      body: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              LinearProgressIndicator(value: (_loadingStep + 1) / 5),
              const SizedBox(height: 32),
              Text(_loadingMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]))
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 2) _generateContent();
                else if (_currentStep == 4) _finalizeAndSave();
                else setState(() => _currentStep++);
              },
              onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep--) : null,
              steps: [
                Step(title: const Text('Identificação'), content: _buildWorkDataStep(), isActive: _currentStep >= 0),
                Step(title: const Text('Autoria'), content: _buildAutoriaStep(), isActive: _currentStep >= 1),
                Step(title: const Text('Tamanho e Idioma'), content: _buildConfigurationStep(), isActive: _currentStep >= 2),
                Step(title: const Text('Estilo de Formatação'), content: _buildFormattingStep(), isActive: _currentStep >= 3),
                Step(title: const Text('Finalizar'), content: const Center(child: Text('Clique em Continuar para gerar o rascunho.')), isActive: _currentStep >= 4),
              ],
            ),
    );
  }

  Widget _buildWorkDataStep() => Column(children: [
    TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título *', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _disciplineController, decoration: const InputDecoration(labelText: 'Disciplina *', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _professorController, decoration: const InputDecoration(labelText: 'Professor/Orientador *', border: OutlineInputBorder())),
  ]);

  Widget _buildAutoriaStep() => TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: 'Nome Completo do Aluno *', border: OutlineInputBorder()));

  Widget _buildConfigurationStep() => Column(children: [
    TextField(controller: _pagesController, decoration: InputDecoration(labelText: 'Quantidade de Páginas (5-25)', helperText: 'Custo: ${_calculateCredits(int.tryParse(_pagesController.text) ?? 5)} créditos'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
    const SizedBox(height: 12),
    DropdownButtonFormField(value: _selectedLanguage, items: ['Português', 'Inglês', 'Francês'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _selectedLanguage = v as String)),
  ]);

  Widget _buildFormattingStep() => Column(children: [
    RadioListTile(title: const Text('ABNT (Capa, Sumário, Arial 12)'), value: 'abnt', groupValue: _selectedFormat, onChanged: (v) => setState(() => _selectedFormat = v!)),
    RadioListTile(title: const Text('NORMAL (Minimalista, Calibri 11)'), value: 'professional', groupValue: _selectedFormat, onChanged: (v) => setState(() => _selectedFormat = v!)),
    RadioListTile(title: const Text('APA (Padrão Americano, Times 12)'), value: 'apa', groupValue: _selectedFormat, onChanged: (v) => setState(() => _selectedFormat = v!)),
  ]);
}
