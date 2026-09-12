import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditCodeStatus {
  available,
  used;

  static CreditCodeStatus fromString(String status) {
    return CreditCodeStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => CreditCodeStatus.available,
    );
  }
}

class CreditCode {
  final String id;
  final String code;
  final int credits;
  final CreditCodeStatus status;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedBy;

  CreditCode({
    required this.id,
    required this.code,
    required this.credits,
    required this.status,
    required this.createdAt,
    this.usedAt,
    this.usedBy,
  });

  factory CreditCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditCode(
      id: doc.id,
      code: data['code'] ?? '',
      credits: (data['credits'] ?? 0) as int,
      status: CreditCodeStatus.fromString(data['status'] ?? 'available'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      usedBy: data['usedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'credits': credits,
      'status': status.name,
      'createdAt': createdAt,
      'usedAt': usedAt,
      'usedBy': usedBy,
    };
  }
}
