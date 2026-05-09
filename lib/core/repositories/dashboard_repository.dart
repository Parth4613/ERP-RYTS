import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepository(this._supabase);

  // Get dashboard metrics
  Future<DashboardMetrics> getDashboardMetrics() async {
    try {
      final response = await _supabase
          .from('dashboard_metrics')
          .select()
          .single();

      return DashboardMetrics.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch dashboard metrics: $e');
    }
  }

  // Get project cost summaries
  Future<List<ProjectCostSummary>> getProjectCostSummaries() async {
    try {
      final response = await _supabase
          .from('project_cost_summary')
          .select()
          .order('updated_at', ascending: false);

      return (response as List)
          .map((item) => ProjectCostSummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch project cost summaries: $e');
    }
  }

  // Get single project cost summary
  Future<ProjectCostSummary?> getProjectCostSummary(String projectId) async {
    try {
      final response = await _supabase
          .from('project_cost_summary')
          .select()
          .eq('project_id', projectId)
          .maybeSingle();

      return response != null ? ProjectCostSummary.fromMap(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch project cost summary: $e');
    }
  }

  // Get inventory valuation
  Future<List<InventoryValuation>> getInventoryValuation({
    int? limit,
    StockStatus? stockStatus,
  }) async {
    try {
      final baseQuery = _supabase
          .from('inventory_valuation')
          .select();

      PostgrestFilterBuilder filteredQuery = baseQuery;
      if (stockStatus != null) {
        filteredQuery = filteredQuery.eq('stock_status', stockStatus.value);
      }

      final query = filteredQuery.order('total_value', ascending: false);

      dynamic finalQuery = query;
      if (limit != null) {
        finalQuery = query.limit(limit);
      }

      final response = await finalQuery;

      return (response as List)
          .map((item) => InventoryValuation.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch inventory valuation: $e');
    }
  }

  // Get monthly cost analysis
  Future<List<MonthlyCostAnalysis>> getMonthlyCostAnalysis({int months = 12}) async {
    try {
      final response = await _supabase
          .from('monthly_cost_analysis')
          .select()
          .order('month', ascending: false)
          .limit(months * 4); // 4 cost types per month

      return (response as List)
          .map((item) => MonthlyCostAnalysis.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch monthly cost analysis: $e');
    }
  }

  // Get supplier spending analysis
  Future<List<SupplierSpendingAnalysis>> getSupplierSpendingAnalysis({
    int? limit,
  }) async {
    try {
      var query = _supabase
          .from('supplier_spending_analysis')
          .select()
          .order('total_spent', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((item) => SupplierSpendingAnalysis.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch supplier spending analysis: $e');
    }
  }

  // Get top cost materials
  Future<List<TopCostMaterial>> getTopCostMaterials({int limit = 20}) async {
    try {
      final response = await _supabase
          .from('top_cost_materials')
          .select()
          .order('total_cost', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => TopCostMaterial.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch top cost materials: $e');
    }
  }

  // Create or update project budget
  Future<ProjectBudget> upsertProjectBudget({
    required String projectId,
    required double budgetAmount,
    String? approvedBy,
  }) async {
    try {
      final response = await _supabase
          .from('project_budgets')
          .upsert({
            'project_id': projectId,
            'budget_amount': budgetAmount,
            'approved_by': approvedBy,
            if (approvedBy != null) 'approved_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return ProjectBudget.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upsert project budget: $e');
    }
  }

  // Get project budget
  Future<ProjectBudget?> getProjectBudget(String projectId) async {
    try {
      final response = await _supabase
          .from('project_budgets')
          .select()
          .eq('project_id', projectId)
          .maybeSingle();

      return response != null ? ProjectBudget.fromMap(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch project budget: $e');
    }
  }

  // Add cost tracking entry
  Future<CostTracking> addCostTracking({
    required String projectId,
    required CostType costType,
    String? description,
    required double amount,
    DateTime? dateIncurred,
    String? createdBy,
  }) async {
    try {
      final response = await _supabase
          .from('cost_tracking')
          .insert({
            'project_id': projectId,
            'cost_type': costType.value,
            'description': description,
            'amount': amount,
            'date_incurred': dateIncurred?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'created_by': createdBy,
          })
          .select()
          .single();

      return CostTracking.fromMap(response);
    } catch (e) {
      throw Exception('Failed to add cost tracking entry: $e');
    }
  }

  // Get cost tracking for a project
  Future<List<CostTracking>> getCostTracking(String projectId) async {
    try {
      final response = await _supabase
          .from('cost_tracking')
          .select()
          .eq('project_id', projectId)
          .order('date_incurred', ascending: false);

      return (response as List)
          .map((item) => CostTracking.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch cost tracking: $e');
    }
  }

  // Update cost tracking entry
  Future<CostTracking> updateCostTracking({
    required String id,
    CostType? costType,
    String? description,
    double? amount,
    DateTime? dateIncurred,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (costType != null) updateData['cost_type'] = costType.value;
      if (description != null) updateData['description'] = description;
      if (amount != null) updateData['amount'] = amount;
      if (dateIncurred != null) updateData['date_incurred'] = dateIncurred.toIso8601String();

      final response = await _supabase
          .from('cost_tracking')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return CostTracking.fromMap(response);
    } catch (e) {
      throw Exception('Failed to update cost tracking entry: $e');
    }
  }

  // Delete cost tracking entry
  Future<void> deleteCostTracking(String id) async {
    try {
      await _supabase
          .from('cost_tracking')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete cost tracking entry: $e');
    }
  }

  // Get low stock items
  Future<List<InventoryValuation>> getLowStockItems() async {
    return getInventoryValuation(stockStatus: StockStatus.lowStock);
  }

  // Get over budget projects
  Future<List<ProjectCostSummary>> getOverBudgetProjects() async {
    try {
      final response = await _supabase
          .from('project_cost_summary')
          .select()
          .eq('budget_status', BudgetStatus.overBudget.value)
          .order('budget_used_percentage', ascending: false);

      return (response as List)
          .map((item) => ProjectCostSummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch over budget projects: $e');
    }
  }

  // Get projects near budget limit
  Future<List<ProjectCostSummary>> getNearLimitProjects() async {
    try {
      final response = await _supabase
          .from('project_cost_summary')
          .select()
          .eq('budget_status', BudgetStatus.nearLimit.value)
          .order('budget_used_percentage', ascending: false);

      return (response as List)
          .map((item) => ProjectCostSummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch near limit projects: $e');
    }
  }
}
