import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkStatus {
  pending,
  processing,
  completed,
  failed;

  static WorkStatus fromString(String status) {
    return WorkStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => WorkStatus.pending,
    );
  }
}

class Student {
  final String name;
  final String studentNumber;

  Student({required this.name, required this.studentNumber});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentNumber': studentNumber,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      name: map['name'] ?? '',
      studentNumber: map['studentNumber'] ?? '',
    );
  }
}

class AcademicWork {
  final String id;
  final String userId;
  final String title;
  final String? subtitle;
  final String subject;
  final String theme;
  final String type;
  final String level;
  final String language;
  final int pageCount;
  final String? content;
  final WorkStatus status;
  final DateTime createdAt;
  final int costInCredits;
  final String? course;
  final String studentClass; // "Turma"
  final String? institution;
  final String? professor;
  final String? city;
  final String? year;
  final String? instructions;
  final List<Student> students;
  final bool isAbnt;
  final List<String> abntSections;
  final String? fileName;
  final String? localPath;
  final String? localUri; // Novo campo para URI do SAF
  final String? fileUrl;
  final String? norm; // ABNT, APA, NORMAL
  final DateTime? savedAt;

  AcademicWork({
    required this.id,
    required this.userId,
    required this.title,
    this.subtitle,
    required this.subject,
    required this.theme,
    required this.type,
    required this.level,
    required this.language,
    required this.pageCount,
    this.content,
    required this.status,
    required this.createdAt,
    required this.costInCredits,
    this.course,
    required this.studentClass,
    this.institution,
    this.professor,
    this.city,
    this.year,
    this.instructions,
    required this.students,
    this.isAbnt = false,
    this.abntSections = const [],
    this.fileName,
    this.localPath,
    this.localUri,
    this.fileUrl,
    this.norm,
    this.savedAt,
  });

  factory AcademicWork.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AcademicWork(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'],
      subject: data['subject'] ?? '',
      theme: data['theme'] ?? '',
      type: data['type'] ?? '',
      level: data['level'] ?? '',
      language: data['language'] ?? 'Português',
      pageCount: (data['pageCount'] ?? 1) as int,
      content: data['content'],
      status: WorkStatus.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      costInCredits: (data['costInCredits'] ?? 0) as int,
      course: data['course'],
      studentClass: data['studentClass'] ?? '',
      institution: data['institution'],
      professor: data['professor'],
      city: data['city'],
      year: data['year'],
      instructions: data['instructions'],
      students: (data['students'] as List<dynamic>?)
              ?.map((e) => Student.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isAbnt: data['isAbnt'] ?? false,
      abntSections: List<String>.from(data['abntSections'] ?? []),
      fileName: data['fileName'],
      localPath: data['localPath'],
      localUri: data['localUri'],
      fileUrl: data['fileUrl'],
      norm: data['norm'],
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'subtitle': subtitle,
      'subject': subject,
      'theme': theme,
      'type': type,
      'level': level,
      'language': language,
      'pages': pageCount, // Usando 'pages' conforme solicitado
      'content': content,
      'status': status.name,
      'createdAt': createdAt,
      'costInCredits': costInCredits,
      'course': course,
      'studentClass': studentClass,
      'institution': institution,
      'professor': professor,
      'city': city,
      'year': year,
      'instructions': instructions,
      'students': students.map((e) => e.toMap()).toList(),
      'isAbnt': isAbnt,
      'abntSections': abntSections,
      'fileName': fileName,
      'localPath': localPath,
      'localUri': localUri,
      'fileUrl': fileUrl,
      'norm': norm,
      'savedAt': savedAt != null ? Timestamp.fromDate(savedAt!) : null,
    };
  }

  AcademicWork copyWith({
    WorkStatus? status,
    String? localPath,
    String? localUri,
    String? fileName,
    String? fileUrl,
    String? norm,
    DateTime? savedAt,
  }) {
    return AcademicWork(
      id: id,
      userId: userId,
      title: title,
      subtitle: subtitle,
      subject: subject,
      theme: theme,
      type: type,
      level: level,
      language: language,
      pageCount: pageCount,
      content: content,
      status: status ?? this.status,
      createdAt: createdAt,
      costInCredits: costInCredits,
      course: course,
      studentClass: studentClass,
      institution: institution,
      professor: professor,
      city: city,
      year: year,
      instructions: instructions,
      students: students,
      isAbnt: isAbnt,
      abntSections: abntSections,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      localUri: localUri ?? this.localUri,
      fileUrl: fileUrl ?? this.fileUrl,
      norm: norm ?? this.norm,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
