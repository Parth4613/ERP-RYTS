import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_company/core/repositories/store_repository.dart';
import 'package:gas_company/core/models/purchase.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:riverpod/riverpod.dart';

// Repository provider
final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(Supabase.instance.client);
});

// Store dashboard metrics provider
final storeDashboardMetricsProvider = FutureProvider<StoreDashboardMetrics>((
  ref,
) async {
  final repository = ref.watch(storeRepositoryProvider);
  return await repository.getStoreDashboardMetrics();
});

// Pending MR items with stock provider
final pendingMRItemsWithStockProvider =
    FutureProvider<List<PendingMRItemWithStock>>((ref) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getPendingMRItemsWithStock();
    });

// Pending MR items for specific MR provider
final pendingMRItemsForMRProvider =
    FutureProvider.family<List<PendingMRItemWithStock>, String>((
      ref,
      mrId,
    ) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getPendingMRItemsForMR(mrId);
    });

// Frequent shortages provider
final frequentShortagesProvider = FutureProvider<List<FrequentShortage>>((
  ref,
) async {
  final repository = ref.watch(storeRepositoryProvider);
  return await repository.getFrequentShortages();
});

final storeProcurementItemsProvider =
    FutureProvider<List<StoreProcurementItem>>((ref) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getProcurementItems();
    });

final storePendingPurchaseRequestsProvider =
    FutureProvider<List<PurchaseRequest>>((ref) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getPendingPurchaseRequests();
    });

/// Enriched purchase requests with project name, MR link, cost estimate.
final enrichedPurchaseRequestsProvider =
    FutureProvider<List<PurchaseRequest>>((ref) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getPurchaseRequestsWithDetails();
    });

/// Aggregate demand: total pending quantities across all active projects.
final aggregateDemandProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getAggregateDemand();
    });

final storeWaitingDeliveryOrdersProvider = FutureProvider<List<PurchaseOrder>>((
  ref,
) async {
  final repository = ref.watch(storeRepositoryProvider);
  return await repository.getWaitingDeliveryOrders();
});

// Issuance summary provider
final issuanceSummaryProvider = FutureProvider<List<IssuanceSummary>>((
  ref,
) async {
  final repository = ref.watch(storeRepositoryProvider);
  return await repository.getIssuanceSummary();
});

// Stock history provider
final stockHistoryProvider =
    FutureProvider.family<List<StockHistory>, StockHistoryParams>((
      ref,
      params,
    ) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getStockHistory(
        productId: params.productId,
        limit: params.limit,
        movementType: params.movementType,
      );
    });

// Issuance logs provider
final issuanceLogsProvider =
    FutureProvider.family<List<IssuanceLog>, IssuanceLogsParams>((
      ref,
      params,
    ) async {
      final repository = ref.watch(storeRepositoryProvider);
      return await repository.getIssuanceLogs(
        projectId: params.projectId,
        mrId: params.mrId,
        startDate: params.startDate,
        endDate: params.endDate,
        limit: params.limit,
      );
    });

// Today's issuances provider
final todayIssuancesProvider = FutureProvider<List<IssuanceLog>>((ref) async {
  final repository = ref.watch(storeRepositoryProvider);
  return await repository.getTodayIssuances();
});

// Issuance state provider for UI state management
class IssuanceState {
  final bool isIssuing;
  final String? error;
  final List<String> shortageItems;
  final String? purchaseRequestId;

  const IssuanceState({
    this.isIssuing = false,
    this.error,
    this.shortageItems = const [],
    this.purchaseRequestId,
  });

  IssuanceState copyWith({
    bool? isIssuing,
    String? error,
    List<String>? shortageItems,
    String? purchaseRequestId,
  }) {
    return IssuanceState(
      isIssuing: isIssuing ?? this.isIssuing,
      error: error ?? this.error,
      shortageItems: shortageItems ?? this.shortageItems,
      purchaseRequestId: purchaseRequestId ?? this.purchaseRequestId,
    );
  }
}

class StoreProcurementState {
  final bool isCreatingPr;
  final String? error;
  final String? purchaseRequestId;

  const StoreProcurementState({
    this.isCreatingPr = false,
    this.error,
    this.purchaseRequestId,
  });

  StoreProcurementState copyWith({
    bool? isCreatingPr,
    String? error,
    String? purchaseRequestId,
  }) {
    return StoreProcurementState(
      isCreatingPr: isCreatingPr ?? this.isCreatingPr,
      error: error,
      purchaseRequestId: purchaseRequestId ?? this.purchaseRequestId,
    );
  }
}

class StoreProcurementNotifier extends Notifier<StoreProcurementState> {
  late final StoreRepository _repository;

  @override
  StoreProcurementState build() {
    _repository = StoreRepository(Supabase.instance.client);
    return const StoreProcurementState();
  }

  Future<String?> createPurchaseRequest({
    required List<QuickPurchaseRequestItem> items,
    String? projectId,
    String? mrId,
    DateTime? requiredDate,
    String? notes,
  }) async {
    state = state.copyWith(isCreatingPr: true, error: null);
    try {
      final prId = await _repository.createStorePurchaseRequest(
        items: items,
        projectId: projectId,
        mrId: mrId,
        requiredDate: requiredDate,
        notes: notes,
      );
      ref.invalidate(storePendingPurchaseRequestsProvider);
      ref.invalidate(storeProcurementItemsProvider);
      ref.invalidate(storeDashboardMetricsProvider);
      state = StoreProcurementState(purchaseRequestId: prId);
      return prId;
    } catch (e) {
      state = state.copyWith(isCreatingPr: false, error: e.toString());
      return null;
    }
  }
}

// PR management state
class PRManagementState {
  final bool isProcessing;
  final String? error;

  const PRManagementState({this.isProcessing = false, this.error});

  PRManagementState copyWith({bool? isProcessing, String? error}) =>
      PRManagementState(
        isProcessing: isProcessing ?? this.isProcessing,
        error: error,
      );
}

class PRManagementNotifier extends Notifier<PRManagementState> {
  late final StoreRepository _repository;

  @override
  PRManagementState build() {
    _repository = ref.read(storeRepositoryProvider);
    return const PRManagementState();
  }

  Future<bool> updateItemQuantity({
    required String prId,
    required String productId,
    required int quantity,
    String? remarks,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      await _repository.updatePRItem(
        prId: prId, productId: productId, quantity: quantity, remarks: remarks,
      );
      _invalidatePRProviders();
      state = const PRManagementState();
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeItem({
    required String prId,
    required String productId,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      await _repository.removePRItem(prId: prId, productId: productId);
      _invalidatePRProviders();
      state = const PRManagementState();
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deletePR(String prId) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      await _repository.deletePurchaseRequest(prId);
      _invalidatePRProviders();
      state = const PRManagementState();
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateNotes({
    required String prId,
    required String notes,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      await _repository.updatePRNotes(prId: prId, notes: notes);
      _invalidatePRProviders();
      state = const PRManagementState();
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return false;
    }
  }

  void _invalidatePRProviders() {
    ref.invalidate(enrichedPurchaseRequestsProvider);
    ref.invalidate(storePendingPurchaseRequestsProvider);
    ref.invalidate(storeDashboardMetricsProvider);
  }
}

final prManagementNotifierProvider =
    NotifierProvider<PRManagementNotifier, PRManagementState>(
      PRManagementNotifier.new,
    );

final storeProcurementNotifierProvider =
    NotifierProvider<StoreProcurementNotifier, StoreProcurementState>(
      StoreProcurementNotifier.new,
    );
class IssuanceNotifier extends Notifier<IssuanceState> {
  late final StoreRepository _repository;

  @override
  IssuanceState build() {
    _repository = StoreRepository(Supabase.instance.client);
    return const IssuanceState();
  }

  void setIssuing(bool issuing) {
    state = state.copyWith(isIssuing: issuing);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void setShortageItems(List<String> items) {
    state = state.copyWith(shortageItems: items);
  }

  void setPurchaseRequestId(String? prId) {
    state = state.copyWith(purchaseRequestId: prId);
  }

  Future<IssuanceResult> issueMaterials({
    required String mrId,
    required String mrItemId,
    required String projectId,
    required String productId,
    required int quantityToIssue,
    required String issuedBy,
    String? notes,
  }) async {
    setIssuing(true);
    clearError();

    try {
      if (quantityToIssue <= 0) {
        const error = 'Issued quantity must be greater than zero';
        setError(error);
        setIssuing(false);
        return IssuanceResult.failure(error);
      }

      final result = await _repository.issueMaterialsSafe(
        mrId: mrId,
        mrItemId: mrItemId,
        productId: productId,
        quantityToIssue: quantityToIssue,
        notes: notes,
        // Never auto-create PRs during issuance.
        autoCreatePr: false,
      );

      if (result.shortageItems.isNotEmpty) {
        setShortageItems(result.shortageItems);
      }
      if (result.purchaseRequestId != null) {
        setPurchaseRequestId(result.purchaseRequestId);
      }
      if (!result.success) {
        setError(result.error ?? result.message ?? 'No material issued');
      }

      setIssuing(false);
      return result;
    } catch (e) {
      setError('Failed to issue materials: $e');
      setIssuing(false);
      return IssuanceResult.failure(e.toString());
    }
  }

  // PR creation must remain explicit and combined via `create_store_purchase_request`.
  // Use `StoreProcurementNotifier.createPurchaseRequest` instead.

  void reset() {
    state = const IssuanceState();
  }

  /// Atomically process all MR shortages: issue available stock +
  /// create ONE combined PR for all remaining shortages.
  Future<Map<String, dynamic>?> processMRShortages({
    required String mrId,
    bool autoIssue = false,
    String? notes,
  }) async {
    setIssuing(true);
    clearError();

    try {
      final result = await _repository.processMRShortages(
        mrId: mrId,
        autoIssue: autoIssue,
        notes: notes,
      );

      final success = result['success'] as bool? ?? false;
      if (!success) {
        setError(result['error']?.toString() ?? 'Processing failed');
        setIssuing(false);
        return null;
      }

      setIssuing(false);
      return result;
    } catch (e) {
      setError('Failed to process MR shortages: $e');
      setIssuing(false);
      return null;
    }
  }
}

// Issuance state provider
final issuanceStateProvider = NotifierProvider<IssuanceNotifier, IssuanceState>(
  IssuanceNotifier.new,
);

// Parameters class for stock history
class StockHistoryParams {
  final String? productId;
  final int? limit;
  final MovementType? movementType;

  const StockHistoryParams({this.productId, this.limit, this.movementType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockHistoryParams &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          limit == other.limit &&
          movementType == other.movementType;

  @override
  int get hashCode =>
      productId.hashCode ^ limit.hashCode ^ movementType.hashCode;
}

// Parameters class for issuance logs
class IssuanceLogsParams {
  final String? projectId;
  final String? mrId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  const IssuanceLogsParams({
    this.projectId,
    this.mrId,
    this.startDate,
    this.endDate,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssuanceLogsParams &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          mrId == other.mrId &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          limit == other.limit;

  @override
  int get hashCode =>
      projectId.hashCode ^
      mrId.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      limit.hashCode;
}
