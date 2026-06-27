/// Material model — maps to `public.materials` table.
/// Master material catalog with category, UOM, HSN code, and critical flag.
class MaterialModel {
  final int id;
  final int? categoryId;
  final String? categoryName; // joined from material_categories
  final String? code;
  final String name;
  final String? description;
  final String unitOfMeasure;
  final double minStockLevel;
  final String? hsnCode;
  final bool isCritical;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const MaterialModel({
    required this.id,
    this.categoryId,
    this.categoryName,
    this.code,
    required this.name,
    this.description,
    required this.unitOfMeasure,
    this.minStockLevel = 0,
    this.hsnCode,
    this.isCritical = false,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    // Handle joined category name from nested object
    String? catName;
    if (json['material_categories'] is Map) {
      catName = (json['material_categories'] as Map)['name'] as String?;
    }

    return MaterialModel(
      id: json['id'] as int,
      categoryId: json['category_id'] as int?,
      categoryName: catName ?? json['category_name'] as String?,
      code: json['code'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      unitOfMeasure: json['unit_of_measure'] as String? ?? 'nos',
      minStockLevel: _parseDouble(json['min_stock_level']) ?? 0,
      hsnCode: json['hsn_code'] as String?,
      isCritical: json['is_critical'] as bool? ?? false,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'code': code,
        'name': name,
        'description': description,
        'unit_of_measure': unitOfMeasure,
        'min_stock_level': minStockLevel,
        'hsn_code': hsnCode,
        'is_critical': isCritical,
      };

  MaterialModel copyWith({
    int? categoryId,
    String? categoryName,
    String? code,
    String? name,
    String? description,
    String? unitOfMeasure,
    double? minStockLevel,
    String? hsnCode,
    bool? isCritical,
  }) {
    return MaterialModel(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      hsnCode: hsnCode ?? this.hsnCode,
      isCritical: isCritical ?? this.isCritical,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive,
    );
  }

  @override
  String toString() => '$code — $name';
}

double? _parseDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
