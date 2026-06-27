/// Warehouse model — maps to `public.warehouses` table.
/// Physical storage locations; central vs project-site warehouses.
class WarehouseModel {
  final int id;
  final String name;
  final String? location;
  final int? projectId;
  final bool isCentral;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const WarehouseModel({
    required this.id,
    required this.name,
    this.location,
    this.projectId,
    this.isCentral = false,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      location: json['location'] as String?,
      projectId: json['project_id'] as int?,
      isCentral: json['is_central'] as bool? ?? false,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'project_id': projectId,
        'is_central': isCentral,
      };

  WarehouseModel copyWith({
    String? name,
    String? location,
    int? projectId,
    bool? isCentral,
  }) {
    return WarehouseModel(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      projectId: projectId ?? this.projectId,
      isCentral: isCentral ?? this.isCentral,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive,
    );
  }

  @override
  String toString() => name;
}
