import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_adjustment_model.dart';
import '../models/inventory_summary_model.dart';
import '../models/material_category_model.dart';
import '../models/material_model.dart';
import '../models/stock_transaction_model.dart';
import '../models/warehouse_model.dart';

/// Concrete inventory repository implementation.
/// AD-012: Repository → Supabase. Never call Supabase from UI.
/// AD-018: stock_balances is updated via triggers only — no direct writes.
class InventoryRepositoryImpl implements InventoryRepository {
  final SupabaseClient _client;

  InventoryRepositoryImpl(this._client);

  // ─── Stock Levels (inventory_summary view) ───

  @override
  Future<List<InventorySummaryModel>> getStockLevels({
    int? warehouseId,
    int? categoryId,
    String? search,
    String? stockStatus,
  }) async {
    try {
      var query = _client.from('inventory_summary').select();

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      if (categoryId != null) {
        // Filter by category name from the view
        final cat = await _client
            .from('material_categories')
            .select('name')
            .eq('id', categoryId)
            .maybeSingle();
        if (cat != null) {
          query = query.eq('category_name', cat['name']);
        }
      }
      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,code.ilike.%$search%');
      }
      if (stockStatus != null && stockStatus.isNotEmpty) {
        query = query.eq('stock_status', stockStatus);
      }

      final data = await query.order('name', ascending: true);
      return data.map((e) => InventorySummaryModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<List<InventorySummaryModel>> getLowStockItems() async {
    try {
      final data = await _client
          .from('inventory_summary')
          .select()
          .inFilter('stock_status', ['low_stock', 'out_of_stock'])
          .order('stock_status', ascending: true)
          .order('name', ascending: true);
      return data.map((e) => InventorySummaryModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  // ─── Materials CRUD ───

  @override
  Future<List<MaterialModel>> getAllMaterials({
    String? search,
    int? categoryId,
  }) async {
    try {
      var query = _client
          .from('materials')
          .select('*, material_categories(name)')
          .isFilter('deleted_at', null);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,code.ilike.%$search%');
      }

      final data = await query.order('name', ascending: true);
      return data.map((e) => MaterialModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<MaterialModel?> getMaterialById(int id) async {
    try {
      final data = await _client
          .from('materials')
          .select('*, material_categories(name)')
          .eq('id', id)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (data == null) return null;
      return MaterialModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<MaterialModel> createMaterial(CreateMaterialParams params) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final payload = {
        ...params.toJson(),
        'created_by': userId,
        'updated_by': userId,
      };

      final data = await _client
          .from('materials')
          .insert(payload)
          .select('*, material_categories(name)')
          .single();
      return MaterialModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<MaterialModel> updateMaterial(
      int id, UpdateMaterialParams params) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final payload = {
        ...params.toJson(),
        'updated_by': userId,
      };

      final data = await _client
          .from('materials')
          .update(payload)
          .eq('id', id)
          .select('*, material_categories(name)')
          .single();
      return MaterialModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<void> softDeleteMaterial(int id) async {
    try {
      // AD-002: Soft delete — set deleted_at, never DELETE
      await _client
          .from('materials')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_active': false,
            'updated_by': _client.auth.currentUser?.id,
          })
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  // ─── Categories ───

  @override
  Future<List<MaterialCategoryModel>> getCategories() async {
    try {
      final data = await _client
          .from('material_categories')
          .select()
          .isFilter('deleted_at', null)
          .order('name', ascending: true);
      return data.map((e) => MaterialCategoryModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  // ─── Warehouses ───

  @override
  Future<List<WarehouseModel>> getWarehouses() async {
    try {
      final data = await _client
          .from('warehouses')
          .select()
          .isFilter('deleted_at', null)
          .order('is_central', ascending: false)
          .order('name', ascending: true);
      return data.map((e) => WarehouseModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  // ─── Stock Transactions ───

  @override
  Future<List<StockTransactionModel>> getTransactions({
    int? materialId,
    int? warehouseId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client
          .from('stock_transactions')
          .select('*, materials(name, code), warehouses(name)');

      if (materialId != null) {
        query = query.eq('material_id', materialId);
      }
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      if (type != null && type.isNotEmpty) {
        query = query.eq('transaction_type', type);
      }
      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final data = await query.order('created_at', ascending: false).limit(200);
      return data.map((e) => StockTransactionModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  // ─── Inventory Adjustments ───

  @override
  Future<InventoryAdjustmentModel> requestAdjustment(
      CreateAdjustmentParams params) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final payload = {
        ...params.toJson(),
        'requested_by': userId,
        'created_by': userId,
        'updated_by': userId,
        'status': 'pending',
      };

      final data = await _client
          .from('inventory_adjustments')
          .insert(payload)
          .select('*, materials(name, code), warehouses(name)')
          .single();
      return InventoryAdjustmentModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<void> approveAdjustment(int id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'approved',
            'approved_by': userId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_by': userId,
          })
          .eq('id', id)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<void> rejectAdjustment(int id, String reason) async {
    try {
      final userId = _client.auth.currentUser?.id;
      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'updated_by': userId,
          })
          .eq('id', id)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<List<InventoryAdjustmentModel>> getPendingAdjustments() async {
    try {
      final data = await _client
          .from('inventory_adjustments')
          .select('*, materials(name, code), warehouses(name)')
          .eq('status', 'pending')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      return data.map((e) => InventoryAdjustmentModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<List<InventoryAdjustmentModel>> getAllAdjustments() async {
    try {
      final data = await _client
          .from('inventory_adjustments')
          .select('*, materials(name, code), warehouses(name)')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(100);
      return data.map((e) => InventoryAdjustmentModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }
}
