/// Stock balance model — maps to `public.stock_balances` table.
/// Maintained by DB trigger only (AD-018). Never updated directly.
/// CHECK constraints: quantity >= 0, reserved_qty >= 0 (BR-001).
class StockBalanceModel {
  final int id;
  final int materialId;
  final int warehouseId;
  final double quantity;
  final double reservedQty;
  final DateTime updatedAt;

  const StockBalanceModel({
    required this.id,
    required this.materialId,
    required this.warehouseId,
    required this.quantity,
    required this.reservedQty,
    required this.updatedAt,
  });

  /// Available = quantity - reserved (AD-023). Computed, never stored.
  double get availableQty => quantity - reservedQty;

  factory StockBalanceModel.fromJson(Map<String, dynamic> json) {
    return StockBalanceModel(
      id: json['id'] as int,
      materialId: json['material_id'] as int,
      warehouseId: json['warehouse_id'] as int,
      quantity: _parseDouble(json['quantity']) ?? 0,
      reservedQty: _parseDouble(json['reserved_qty']) ?? 0,
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

double? _parseDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
