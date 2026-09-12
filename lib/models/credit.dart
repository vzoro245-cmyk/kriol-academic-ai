import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditTransactionType {
  purchase,
  usage;

  static CreditTransactionType fromString(String value) {
    return CreditTransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CreditTransactionType.purchase,
    );
  }
}

class CreditTransaction {
  final String id;
  final CreditTransactionType type;
  final int amount;
  final DateTime date;
  final String description;

  CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory CreditTransaction.fromMap(Map<String, dynamic> map, String id) {
    return CreditTransaction(
      id: id,
      type: CreditTransactionType.fromString(map['type'] ?? 'purchase'),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }
}

class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final double price; // in FCFA
  final String description;

  CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    required this.description,
  });

  factory CreditPackage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditPackage(
      id: doc.id,
      name: data['name'] ?? '',
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
    );
  }
}
