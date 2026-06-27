/// Inventory adjustment model — maps to `public.inventory_adjustments` table.
/// BR-004: Adjustments require approval before stock is modified.
/// On approval, DB trigger creates a stock_transaction automatically.
class InventoryAdjustmentModel {
  final int id;
  final int materialId;
  final int warehouseId;
  final double adjustmentQty;
  final String reason;
  final String status; // pending, approved, rejected
  final String? requestedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  // Joined fields
  final String? materialName;
  final String? materialCode;
  final String? warehouseName;

  const InventoryAdjustmentModel({
    required this.id,
    required this.materialId,
    required this.warehouseId,
    required this.adjustmentQty,
    required this.reason,
    required this.status,
    this.requestedBy,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.materialName,
    this.materialCode,
    this.warehouseName,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPositive => adjustmentQty > 0;

  factory InventoryAdjustmentModel.fromJson(Map<String, dynamic> json) {
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

    return InventoryAdjustmentModel(
      id: json['id'] as int,
      materialId: json['material_id'] as int,
      warehouseId: json['warehouse_id'] as int,
      adjustmentQty: _parseDouble(json['adjustment_qty']) ?? 0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requestedBy: json['requested_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] as bool? ?? true,
      materialName: matName ?? json['material_name'] as String?,
      materialCode: matCode ?? json['material_code'] as String?,
      warehouseName: whName ?? json['warehouse_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'material_id': materialId,
        'warehouse_id': warehouseId,
        'adjustment_qty': adjustmentQty,
        'reason': reason,
      };
}

double? _parseDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
