import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_company/core/repositories/dashboard_repository.dart';
import 'package:gas_company/core/models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(Supabase.instance.client);
});

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getDashboardMetrics();
});

final projectCostSummariesProvider = FutureProvider<List<ProjectCostSummary>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getProjectCostSummaries();
});

final projectCostSummaryProvider =
    FutureProvider.family<ProjectCostSummary?, String>((ref, projectId) async {
      final repository = ref.watch(dashboardRepositoryProvider);
      return await repository.getProjectCostSummary(projectId);
    });

final inventoryValuationProvider =
    FutureProvider.family<List<InventoryValuation>, InventoryValuationParams>((
      ref,
      params,
    ) async {
      final repository = ref.watch(dashboardRepositoryProvider);
      return await repository.getInventoryValuation(
        limit: params.limit,
        stockStatus: params.stockStatus,
      );
    });

final monthlyCostAnalysisProvider = FutureProvider<List<MonthlyCostAnalysis>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getMonthlyCostAnalysis();
});

final supplierSpendingAnalysisProvider =
    FutureProvider<List<SupplierSpendingAnalysis>>((ref) async {
      final repository = ref.watch(dashboardRepositoryProvider);
      return await repository.getSupplierSpendingAnalysis();
    });

final topCostMaterialsProvider = FutureProvider<List<TopCostMaterial>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getTopCostMaterials();
});

final lowStockItemsProvider = FutureProvider<List<InventoryValuation>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getLowStockItems();
});

final overBudgetProjectsProvider = FutureProvider<List<ProjectCostSummary>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getOverBudgetProjects();
});

final nearLimitProjectsProvider = FutureProvider<List<ProjectCostSummary>>((
  ref,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getNearLimitProjects();
});

final projectBudgetProvider = FutureProvider.family<ProjectBudget?, String>((
  ref,
  projectId,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getProjectBudget(projectId);
});

final costTrackingProvider = FutureProvider.family<List<CostTracking>, String>((
  ref,
  projectId,
) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getCostTracking(projectId);
});

class DashboardState {
  final bool isLoading;
  final String? error;
  final bool refreshing;

  const DashboardState({
    this.isLoading = false,
    this.error,
    this.refreshing = false,
  });

  DashboardState copyWith({bool? isLoading, String? error, bool? refreshing}) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void setRefreshing(bool refreshing) {
    state = state.copyWith(refreshing: refreshing);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> refreshAllData() async {
    setRefreshing(true);
    clearError();

    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      setError('Failed to refresh data: $e');
    } finally {
      setRefreshing(false);
    }
  }
}

final dashboardStateProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier();
    });

class ProjectBudgetNotifier extends StateNotifier<AsyncValue<ProjectBudget?>> {
  final DashboardRepository _repository;
  final String projectId;

  ProjectBudgetNotifier(this._repository, this.projectId)
    : super(const AsyncValue.loading()) {
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    state = const AsyncValue.loading();
    try {
      final budget = await _repository.getProjectBudget(projectId);
      state = AsyncValue.data(budget);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateBudget(double budgetAmount, {String? approvedBy}) async {
    state = const AsyncValue.loading();
    try {
      final budget = await _repository.upsertProjectBudget(
        projectId: projectId,
        budgetAmount: budgetAmount,
        approvedBy: approvedBy,
      );
      state = AsyncValue.data(budget);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final projectBudgetNotifierProvider =
    StateNotifierProvider.family<
      ProjectBudgetNotifier,
      AsyncValue<ProjectBudget?>,
      String
    >((ref, projectId) {
      final repository = ref.watch(dashboardRepositoryProvider);
      return ProjectBudgetNotifier(repository, projectId);
    });

class CostTrackingNotifier
    extends StateNotifier<AsyncValue<List<CostTracking>>> {
  final DashboardRepository _repository;
  final String projectId;

  CostTrackingNotifier(this._repository, this.projectId)
    : super(const AsyncValue.loading()) {
    _loadCostTracking();
  }

  Future<void> _loadCostTracking() async {
    state = const AsyncValue.loading();
    try {
      final costTracking = await _repository.getCostTracking(projectId);
      state = AsyncValue.data(costTracking);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addCost({
    required CostType costType,
    String? description,
    required double amount,
    DateTime? dateIncurred,
    String? createdBy,
  }) async {
    try {
      await _repository.addCostTracking(
        projectId: projectId,
        costType: costType,
        description: description,
        amount: amount,
        dateIncurred: dateIncurred,
        createdBy: createdBy,
      );
      await _loadCostTracking(); // Refresh the list
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateCost({
    required String id,
    CostType? costType,
    String? description,
    double? amount,
    DateTime? dateIncurred,
  }) async {
    try {
      await _repository.updateCostTracking(
        id: id,
        costType: costType,
        description: description,
        amount: amount,
        dateIncurred: dateIncurred,
      );
      await _loadCostTracking(); // Refresh the list
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> deleteCost(String id) async {
    try {
      await _repository.deleteCostTracking(id);
      await _loadCostTracking(); // Refresh the list
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Cost tracking provider family
final costTrackingNotifierProvider =
    StateNotifierProvider.family<
      CostTrackingNotifier,
      AsyncValue<List<CostTracking>>,
      String
    >((ref, projectId) {
      final repository = ref.watch(dashboardRepositoryProvider);
      return CostTrackingNotifier(repository, projectId);
    });

// Parameters class for inventory valuation
class InventoryValuationParams {
  final int? limit;
  final StockStatus? stockStatus;

  const InventoryValuationParams({this.limit, this.stockStatus});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryValuationParams &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          stockStatus == other.stockStatus;

  @override
  int get hashCode => limit.hashCode ^ stockStatus.hashCode;
}
