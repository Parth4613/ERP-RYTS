import 'package:gas_company/features/inventory/data/models/inventory_adjustment_model.dart';
import 'package:gas_company/features/inventory/data/models/inventory_summary_model.dart';
import 'package:gas_company/features/inventory/data/models/material_category_model.dart';
import 'package:gas_company/features/inventory/data/models/material_model.dart';
import 'package:gas_company/features/inventory/data/models/stock_transaction_model.dart';
import 'package:gas_company/features/inventory/data/models/warehouse_model.dart';

/// Parameters for creating a new material
class CreateMaterialParams {
  final int? categoryId;
  final String? code;
  final String name;
  final String? description;
  final String unitOfMeasure;
  final double minStockLevel;
  final String? hsnCode;
  final bool isCritical;

  const CreateMaterialParams({
    this.categoryId,
    this.code,
    required this.name,
    this.description,
    required this.unitOfMeasure,
    this.minStockLevel = 0,
    this.hsnCode,
    this.isCritical = false,
  });

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
}

/// Parameters for updating a material
class UpdateMaterialParams {
  final int? categoryId;
  final String? code;
  final String? name;
  final String? description;
  final String? unitOfMeasure;
  final double? minStockLevel;
  final String? hsnCode;
  final bool? isCritical;

  const UpdateMaterialParams({
    this.categoryId,
    this.code,
    this.name,
    this.description,
    this.unitOfMeasure,
    this.minStockLevel,
    this.hsnCode,
    this.isCritical,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (categoryId != null) map['category_id'] = categoryId;
    if (code != null) map['code'] = code;
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (unitOfMeasure != null) map['unit_of_measure'] = unitOfMeasure;
    if (minStockLevel != null) map['min_stock_level'] = minStockLevel;
    if (hsnCode != null) map['hsn_code'] = hsnCode;
    if (isCritical != null) map['is_critical'] = isCritical;
    return map;
  }
}

/// Parameters for requesting a stock adjustment
class CreateAdjustmentParams {
  final int materialId;
  final int warehouseId;
  final double adjustmentQty;
  final String reason;

  const CreateAdjustmentParams({
    required this.materialId,
    required this.warehouseId,
    required this.adjustmentQty,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'material_id': materialId,
    'warehouse_id': warehouseId,
    'adjustment_qty': adjustmentQty,
    'reason': reason,
  };
}

/// Abstract inventory repository interface.
/// AD-012: UI → Provider → UseCase → Repository → Supabase
abstract class InventoryRepository {
  // ─── Stock Levels (from inventory_summary view) ───
  Future<List<InventorySummaryModel>> getStockLevels({
    int? warehouseId,
    int? categoryId,
    String? search,
    String? stockStatus,
  });

  Future<List<InventorySummaryModel>> getLowStockItems();

  // ─── Materials CRUD ───
  Future<List<MaterialModel>> getAllMaterials({
    String? search,
    int? categoryId,
  });

  Future<MaterialModel?> getMaterialById(int id);

  Future<MaterialModel> createMaterial(CreateMaterialParams params);

  Future<MaterialModel> updateMaterial(int id, UpdateMaterialParams params);

  Future<void> softDeleteMaterial(int id);

  // ─── Categories ───
  Future<List<MaterialCategoryModel>> getCategories();

  // ─── Warehouses ───
  Future<List<WarehouseModel>> getWarehouses();

  // ─── Stock Transactions ───
  Future<List<StockTransactionModel>> getTransactions({
    int? materialId,
    int? warehouseId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
  });

  // ─── Inventory Adjustments ───
  Future<InventoryAdjustmentModel> requestAdjustment(
    CreateAdjustmentParams params,
  );

  Future<void> approveAdjustment(int id);

  Future<void> rejectAdjustment(int id, String reason);

  Future<List<InventoryAdjustmentModel>> getPendingAdjustments();

  Future<List<InventoryAdjustmentModel>> getAllAdjustments();
}
