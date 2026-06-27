/// Inventory summary model — maps to `public.inventory_summary` DB view.
/// Pre-joined view of materials × warehouses × stock_balances with stock status.
/// Used for the main stock list screen and low-stock alerts.
class InventorySummaryModel {
  final int materialId;
  final String? code;
  final String name;
  final String uom;
  final double minStockLevel;
  final bool isCritical;
  final String? categoryName;
  final int warehouseId;
  final String warehouseName;
  final double quantity;
  final double reservedQty;
  final double availableQty;
  final String stockStatus; // in_stock, low_stock, out_of_stock

  const InventorySummaryModel({
    required this.materialId,
    this.code,
    required this.name,
    required this.uom,
    this.minStockLevel = 0,
    this.isCritical = false,
    this.categoryName,
    required this.warehouseId,
    required this.warehouseName,
    this.quantity = 0,
    this.reservedQty = 0,
    this.availableQty = 0,
    this.stockStatus = 'in_stock',
  });

  bool get isLowStock => stockStatus == 'low_stock';
  bool get isOutOfStock => stockStatus == 'out_of_stock';
  bool get isInStock => stockStatus == 'in_stock';

  /// Human-readable stock status label
  String get stockStatusLabel => switch (stockStatus) {
        'in_stock' => 'In Stock',
        'low_stock' => 'Low Stock',
        'out_of_stock' => 'Out of Stock',
        _ => stockStatus,
      };

  factory InventorySummaryModel.fromJson(Map<String, dynamic> json) {
    return InventorySummaryModel(
      materialId: json['material_id'] as int,
      code: json['code'] as String?,
      name: json['name'] as String,
      uom: json['uom'] as String? ?? 'nos',
      minStockLevel: _parseDouble(json['min_stock_level']) ?? 0,
      isCritical: json['is_critical'] as bool? ?? false,
      categoryName: json['category_name'] as String?,
      warehouseId: json['warehouse_id'] as int,
      warehouseName: json['warehouse_name'] as String? ?? '',
      quantity: _parseDouble(json['quantity']) ?? 0,
      reservedQty: _parseDouble(json['reserved_qty']) ?? 0,
      availableQty: _parseDouble(json['available_qty']) ?? 0,
      stockStatus: json['stock_status'] as String? ?? 'in_stock',
    );
  }
}

double? _parseDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
