/// Material category model — maps to `public.material_categories` table.
/// Hierarchical categories with optional parent_id for nesting.
class MaterialCategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const MaterialCategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory MaterialCategoryModel.fromJson(Map<String, dynamic> json) {
    return MaterialCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: json['parent_id'] as int?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'parent_id': parentId,
        'description': description,
      };

  MaterialCategoryModel copyWith({
    String? name,
    int? parentId,
    String? description,
  }) {
    return MaterialCategoryModel(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive,
    );
  }

  @override
  String toString() => name;
}
