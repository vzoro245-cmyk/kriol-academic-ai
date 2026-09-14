import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus {
  active,
  disabled;

  static UserStatus fromString(String status) {
    return UserStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => UserStatus.active,
    );
  }
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String username;
  final String phone;
  final int credits;
  final UserStatus status;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    required this.phone,
    required this.credits,
    required this.status,
    required this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      phone: data['phone'] ?? '',
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      status: UserStatus.fromString(data['status'] ?? 'active'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'username': username,
      'phone': phone,
      'credits': credits,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? name,
    String? username,
    String? phone,
    int? credits,
    UserStatus? status,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      credits: credits ?? this.credits,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
