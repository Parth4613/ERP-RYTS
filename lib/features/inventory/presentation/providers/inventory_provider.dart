import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/models/inventory_adjustment_model.dart';
import '../../data/models/inventory_summary_model.dart';
import '../../data/models/material_category_model.dart';
import '../../data/models/material_model.dart';
import '../../data/models/stock_transaction_model.dart';
import '../../data/models/warehouse_model.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/approve_adjustment_usecase.dart';
import '../../domain/usecases/get_low_stock_items_usecase.dart';
import '../../domain/usecases/get_stock_levels_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/request_adjustment_usecase.dart';

// ─── Repository Provider ───

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InventoryRepositoryImpl(client);
});

// ─── Categories Provider ───

final categoryListProvider =
    FutureProvider.autoDispose<List<MaterialCategoryModel>>((ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.getCategories();
    });

// ─── Warehouses Provider ───

final warehouseListProvider = FutureProvider.autoDispose<List<WarehouseModel>>((
  ref,
) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getWarehouses();
});

// ─── Low Stock Provider (for dashboard widget) ───

final lowStockProvider =
    FutureProvider.autoDispose<List<InventorySummaryModel>>((ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return GetLowStockItemsUseCase(repo).call();
    });

// ─── Stock Levels Provider ───

/// Filter state for the stock list screen
class StockFilter {
  final int? warehouseId;
  final int? categoryId;
  final String? search;
  final String? stockStatus;

  const StockFilter({
    this.warehouseId,
    this.categoryId,
    this.search,
    this.stockStatus,
  });

  StockFilter copyWith({
    int? warehouseId,
    int? categoryId,
    String? search,
    String? stockStatus,
    bool clearWarehouse = false,
    bool clearCategory = false,
    bool clearStatus = false,
  }) {
    return StockFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      search: search ?? this.search,
      stockStatus: clearStatus ? null : (stockStatus ?? this.stockStatus),
    );
  }
}

final stockFilterProvider = StateProvider<StockFilter>((ref) {
  return const StockFilter();
});

final stockLevelsProvider =
    FutureProvider.autoDispose<List<InventorySummaryModel>>((ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      final filter = ref.watch(stockFilterProvider);
      return GetStockLevelsUseCase(repo).call(
        warehouseId: filter.warehouseId,
        categoryId: filter.categoryId,
        search: filter.search,
        stockStatus: filter.stockStatus,
      );
    });

// ─── Material List Provider ───

final materialListProvider =
    AsyncNotifierProvider.autoDispose<
      MaterialListNotifier,
      List<MaterialModel>
    >(MaterialListNotifier.new);

class MaterialListNotifier
    extends AsyncNotifier<List<MaterialModel>> {
  @override
  Future<List<MaterialModel>> build() async {
    final repo = ref.watch(inventoryRepositoryProvider);
    return repo.getAllMaterials();
  }

  Future<void> createMaterial(CreateMaterialParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.createMaterial(params);
      return repo.getAllMaterials();
    });
  }

  Future<void> updateMaterial(int id, UpdateMaterialParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.updateMaterial(id, params);
      return repo.getAllMaterials();
    });
  }

  Future<void> softDelete(int id) async {
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.softDeleteMaterial(id);
      return repo.getAllMaterials();
    });
  }
}

// ─── Transaction History Provider ───

/// Filter state for transaction history
class TransactionFilter {
  final int? materialId;
  final int? warehouseId;
  final String? type;
  final DateTime? fromDate;
  final DateTime? toDate;

  const TransactionFilter({
    this.materialId,
    this.warehouseId,
    this.type,
    this.fromDate,
    this.toDate,
  });

  TransactionFilter copyWith({
    int? materialId,
    int? warehouseId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearMaterial = false,
    bool clearWarehouse = false,
    bool clearType = false,
    bool clearDates = false,
  }) {
    return TransactionFilter(
      materialId: clearMaterial ? null : (materialId ?? this.materialId),
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      type: clearType ? null : (type ?? this.type),
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
    );
  }
}

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  return const TransactionFilter();
});

final transactionHistoryProvider =
    FutureProvider.autoDispose<List<StockTransactionModel>>((ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      final filter = ref.watch(transactionFilterProvider);
      return GetTransactionsUseCase(repo).call(
        materialId: filter.materialId,
        warehouseId: filter.warehouseId,
        type: filter.type,
        fromDate: filter.fromDate,
        toDate: filter.toDate,
      );
    });

// ─── Adjustment Provider ───

final adjustmentListProvider =
    AsyncNotifierProvider.autoDispose<
      AdjustmentListNotifier,
      List<InventoryAdjustmentModel>
    >(AdjustmentListNotifier.new);

class AdjustmentListNotifier
    extends AsyncNotifier<List<InventoryAdjustmentModel>> {
  @override
  Future<List<InventoryAdjustmentModel>> build() async {
    final repo = ref.watch(inventoryRepositoryProvider);
    return repo.getAllAdjustments();
  }

  Future<void> requestAdjustment(CreateAdjustmentParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await RequestAdjustmentUseCase(repo).call(params);
      return repo.getAllAdjustments();
    });
  }

  Future<void> approve(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await ApproveAdjustmentUseCase(repo).call(id);
      return repo.getAllAdjustments();
    });
  }

  Future<void> reject(int id, String reason) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.rejectAdjustment(id, reason);
      return repo.getAllAdjustments();
    });
  }
}

// ─── Pending Adjustments (for dashboard badge) ───

final pendingAdjustmentsProvider =
    FutureProvider.autoDispose<List<InventoryAdjustmentModel>>((ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.getPendingAdjustments();
    });
