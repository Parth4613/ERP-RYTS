import 'package:gas_company/core/utils/enums.dart';

class Project {
  final String id;
  final String name;
  final String? description;
  final String? assignedEngineerId;
  final String? engineerName;
  final ProjectStatus status;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    this.description,
    this.assignedEngineerId,
    this.engineerName,
    required this.status,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    String? engName;
    if (json['profiles'] != null && json['profiles'] is Map) {
      engName = json['profiles']['name'] as String?;
    }
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      assignedEngineerId: json['assigned_engineer_id'] as String?,
      engineerName: engName,
      status: ProjectStatus.fromString(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'assigned_engineer_id': assignedEngineerId,
        'status': status.name,
      };
}
