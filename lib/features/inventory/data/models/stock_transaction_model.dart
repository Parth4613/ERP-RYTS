/// Stock transaction model — maps to `public.stock_transactions` table.
/// Immutable audit trail — no updated_at, no deleted_at (BR-002).
/// Types: stock_in, stock_out, return_in, adjustment, transfer_in, transfer_out
class StockTransactionModel {
  final int id;
  final int materialId;
  final int warehouseId;
  final String transactionType;
  final double quantity;
  final String? referenceType;
  final int? referenceId;
  final int? projectId;
  final String? notes;
  final DateTime createdAt;
  final String? createdBy;

  // Joined fields (from Supabase nested select)
  final String? materialName;
  final String? materialCode;
  final String? warehouseName;

  const StockTransactionModel({
    required this.id,
    required this.materialId,
    required this.warehouseId,
    required this.transactionType,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.projectId,
    this.notes,
    required this.createdAt,
    this.createdBy,
    this.materialName,
    this.materialCode,
    this.warehouseName,
  });

  /// Whether this transaction adds stock (positive flow)
  bool get isInflow =>
      transactionType == 'stock_in' ||
      transactionType == 'return_in' ||
      transactionType == 'transfer_in' ||
      (transactionType == 'adjustment' && quantity > 0);

  /// Human-readable transaction type label
  String get typeLabel => switch (transactionType) {
        'stock_in' => 'Stock In',
        'stock_out' => 'Stock Out',
        'return_in' => 'Return',
        'adjustment' => 'Adjustment',
        'transfer_in' => 'Transfer In',
        'transfer_out' => 'Transfer Out',
        _ => transactionType,
      };

  factory StockTransactionModel.fromJson(Map<String, dynamic> json) {
    // Handle joined material data
    String? matName;
    String? matCode;
    if (json['materials'] is Map) {
      matName = (json['materials'] as Map)['name'] as String?;
      matCode = (json['materials'] as Map)['code'] as String?;
    }

    // Handle joined warehouse data
    String? whName;
    if (json['warehouses'] is Map) {
      whName = (json['warehouses'] as Map)['name'] as String?;
    }

    return StockTransactionModel(
      id: json['id'] as int,
      materialId: json['material_id'] as int,
      warehouseId: json['warehouse_id'] as int,
      transactionType: json['transaction_type'] as String,
      quantity: _parseDouble(json['quantity']) ?? 0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      projectId: json['project_id'] as int?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      createdBy: json['created_by'] as String?,
      materialName: matName ?? json['material_name'] as String?,
      materialCode: matCode ?? json['material_code'] as String?,
      warehouseName: whName ?? json['warehouse_name'] as String?,
    );
  }
}

double? _parseDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
