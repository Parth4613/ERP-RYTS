import 'package:gas_company/core/utils/enums.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'engineer'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
      };
}
