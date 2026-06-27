/// User profile model — maps to `public.users` table.
/// AD-011: Models use manual immutability (no Freezed codegen needed for this simple model).
class UserModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final String? employeeId;
  final String? designation;
  final String? email;
  final String? role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.employeeId,
    this.designation,
    this.email,
    this.role,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      employeeId: json['employee_id'] as String?,
      designation: json['designation'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'employee_id': employeeId,
        'designation': designation,
      };

  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? employeeId,
    String? designation,
    String? role,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      employeeId: employeeId ?? this.employeeId,
      designation: designation ?? this.designation,
      email: email,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive,
    );
  }
}
