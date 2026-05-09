import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase.dart';
import '../models/store_models.dart';

class StoreRepository {
  final SupabaseClient _supabase;

  StoreRepository(this._supabase);

  // Get store dashboard metrics
  Future<StoreDashboardMetrics> getStoreDashboardMetrics() async {
    try {
      final response = await _supabase
          .from('store_dashboard_metrics')
          .select()
          .single();

      return StoreDashboardMetrics.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch store dashboard metrics: $e');
    }
  }

  // Get pending MR items with stock availability
  Future<List<PendingMRItemWithStock>> getPendingMRItemsWithStock() async {
    try {
      final response = await _supabase
          .from('pending_mr_items_with_stock')
          .select()
          .order('mr_created_at', ascending: false);

      return (response as List)
          .map(
            (item) =>
                PendingMRItemWithStock.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending MR items: $e');
    }
  }

  // Get pending MR items for a specific MR
  Future<List<PendingMRItemWithStock>> getPendingMRItemsForMR(
    String mrId,
  ) async {
    try {
      final response = await _supabase
          .from('pending_mr_items_with_stock')
          .select()
          .eq('mr_id', mrId)
          .order('product_name');

      return (response as List)
          .map(
            (item) =>
                PendingMRItemWithStock.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending MR items for MR: $e');
    }
  }

  // Issue materials to a project
  Future<IssuanceLog> issueMaterials({
    required String mrId,
    required String mrItemId,
    required String projectId,
    required String productId,
    required int quantityToIssue,
    required String issuedBy,
    String? notes,
  }) async {
    try {
      final result = await issueMaterialsSafe(
        mrId: mrId,
        mrItemId: mrItemId,
        productId: productId,
        quantityToIssue: quantityToIssue,
        notes: notes,
      );

      if (!result.success || result.issuanceLog == null) {
        throw Exception(result.error ?? result.message ?? 'No material issued');
      }

      return result.issuanceLog!;
    } catch (e) {
      throw Exception('Failed to issue materials: $e');
    }
  }

  Future<IssuanceResult> issueMaterialsSafe({
    required String mrId,
    required String mrItemId,
    required String productId,
    required int quantityToIssue,
    String? notes,
    bool autoCreatePr = false,
  }) async {
    try {
      final response = await _supabase.rpc(
        'issue_materials_safe',
        params: {
          'p_mr_id': mrId,
          'p_mr_item_id': mrItemId,
          'p_product_id': productId,
          'p_quantity_to_issue': quantityToIssue,
          'p_notes': notes,
          'p_auto_create_pr': autoCreatePr,
        },
      );

      return IssuanceResult.fromRpc(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      throw Exception('Failed to issue materials safely: $e');
    }
  }

  // Create issuance log directly (alternative method)
  Future<IssuanceLog> createIssuanceLog({
    required String mrId,
    required String mrItemId,
    required String projectId,
    required String productId,
    required int quantityIssued,
    required String issuedBy,
    String? notes,
  }) async {
    return issueMaterials(
      mrId: mrId,
      mrItemId: mrItemId,
      projectId: projectId,
      productId: productId,
      quantityToIssue: quantityIssued,
      issuedBy: issuedBy,
      notes: notes,
    );
  }

  // Inventory mutations are intentionally not exposed via direct table writes.
  // All inventory changes must be performed via transactional RPCs only.

  // Get stock history for a product
  Future<List<StockHistory>> getStockHistory({
    String? productId,
    int? limit,
    MovementType? movementType,
  }) async {
    try {
      var query = _supabase.from('stock_history').select();

      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      if (movementType != null) {
        query = query.eq('movement_type', movementType.value);
      }

      var finalQuery = query.order('performed_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      return (response as List)
          .map((item) => StockHistory.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch stock history: $e');
    }
  }

  // Get issuance logs for a project or MR
  Future<List<IssuanceLog>> getIssuanceLogs({
    String? projectId,
    String? mrId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      var query = _supabase.from('issuance_logs').select();

      if (projectId != null) {
        query = query.eq('project_id', projectId);
      }

      if (mrId != null) {
        query = query.eq('mr_id', mrId);
      }

      if (startDate != null) {
        query = query.gte('issued_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('issued_at', endDate.toIso8601String());
      }

      var finalQuery = query.order('issued_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      return (response as List)
          .map((item) => IssuanceLog.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch issuance logs: $e');
    }
  }

  // Get frequent shortages
  Future<List<FrequentShortage>> getFrequentShortages({int days = 30}) async {
    try {
      final response = await _supabase
          .from('frequent_shortages')
          .select()
          .order('shortage_count', ascending: false)
          .limit(20);

      return (response as List)
          .map((item) => FrequentShortage.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch frequent shortages: $e');
    }
  }

  Future<List<StoreProcurementItem>> getProcurementItems() async {
    try {
      final response = await _supabase
          .from('store_procurement_items')
          .select()
          .order('stock_sort')
          .order('product_name');

      return (response as List)
          .map(
            (item) =>
                StoreProcurementItem.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch procurement items: $e');
    }
  }

  Future<List<PurchaseRequest>> getPendingPurchaseRequests() async {
    try {
      final response = await _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*, products(name, unit))')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PurchaseRequest.fromJson(item as Map<String, dynamic>))
          .where(
            (pr) =>
                pr.status.name == 'pending' ||
                pr.status.name == 'approved' ||
                pr.status.name == 'ordered',
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch store purchase requests: $e');
    }
  }

  Future<List<PurchaseOrder>> getWaitingDeliveryOrders() async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select(
            '*, suppliers(name), purchase_order_items(*, products(name, unit))',
          )
          .eq('status', 'ordered')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PurchaseOrder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch waiting deliveries: $e');
    }
  }

  Future<String> createStorePurchaseRequest({
    required List<QuickPurchaseRequestItem> items,
    String? projectId,
    String? mrId,
    DateTime? requiredDate,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Select at least one item for purchase request');
    }

    try {
      final response = await _supabase.rpc(
        'create_store_purchase_request',
        params: {
          'p_items': items.map((item) => item.toRpcJson()).toList(),
          'p_project_id': projectId,
          'p_mr_id': mrId,
          'p_required_date':
              (requiredDate ?? DateTime.now().add(const Duration(days: 7)))
                  .toIso8601String()
                  .split('T')
                  .first,
          'p_notes': notes,
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      return map['purchase_request_id'] as String;
    } catch (e) {
      throw Exception('Failed to create purchase request: $e');
    }
  }

  /// Atomically processes an MR: issues available stock, collects shortages,
  /// and creates ONE combined PR for all remaining shortages.
  Future<Map<String, dynamic>> processMRShortages({
    required String mrId,
    bool autoIssue = false,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'process_mr_shortages',
        params: {
          'p_mr_id': mrId,
          'p_auto_issue': autoIssue,
          'p_notes': notes,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Failed to process MR shortages: $e');
    }
  }

  /// Fetch PRs using the enriched view that includes project name,
  /// MR reference, all items, and estimated cost.
  Future<List<PurchaseRequest>> getPurchaseRequestsWithDetails() async {
    try {
      final response = await _supabase
          .from('purchase_requests_with_details')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) =>
              PurchaseRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch enriched purchase requests: $e');
    }
  }

  // ── Edit/Delete PR (only draft/pending) ─────────────────────

  /// Update quantity of a specific item in a PR.
  Future<void> updatePRItem({
    required String prId,
    required String productId,
    required int quantity,
    String? remarks,
  }) async {
    try {
      await _supabase.rpc('update_pr_item', params: {
        'p_pr_id': prId,
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_remarks': remarks,
      });
    } catch (e) {
      throw Exception('Failed to update PR item: $e');
    }
  }

  /// Remove a specific item from a PR. Deletes PR if no items remain.
  Future<bool> removePRItem({
    required String prId,
    required String productId,
  }) async {
    try {
      final result = await _supabase.rpc('remove_pr_item', params: {
        'p_pr_id': prId,
        'p_product_id': productId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['pr_deleted'] as bool? ?? false;
    } catch (e) {
      throw Exception('Failed to remove PR item: $e');
    }
  }

  /// Delete an entire PR (only draft/pending). Returns result with pr_number.
  Future<Map<String, dynamic>> deletePurchaseRequest(String prId) async {
    try {
      final result = await _supabase.rpc('delete_purchase_request', params: {
        'p_pr_id': prId,
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'success': true, 'deleted_pr_id': prId};
    } catch (e) {
      throw Exception('Failed to delete purchase request: $e');
    }
  }

  /// Update notes on a PR (only draft/pending).
  Future<void> updatePRNotes({
    required String prId,
    required String notes,
  }) async {
    try {
      await _supabase.rpc('update_pr_notes', params: {
        'p_pr_id': prId,
        'p_notes': notes,
      });
    } catch (e) {
      throw Exception('Failed to update PR notes: $e');
    }
  }

  // ── Aggregate Demand ───────────────────────────────────────

  /// Get aggregate demand: total pending quantities across all active projects.
  Future<List<Map<String, dynamic>>> getAggregateDemand() async {
    try {
      final response = await _supabase
          .from('product_aggregate_demand')
          .select()
          .order('stock_level')
          .order('total_pending_demand', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch aggregate demand: $e');
    }
  }

  // Get issuance summary
  Future<List<IssuanceSummary>> getIssuanceSummary({int months = 12}) async {
    try {
      final response = await _supabase
          .from('issuance_summary')
          .select()
          .order('month', ascending: false)
          .limit(months);

      return (response as List)
          .map((item) => IssuanceSummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch issuance summary: $e');
    }
  }

  // Create purchase request from shortage
  Future<String> createPRFromShortage({
    required String mrId,
    required String productId,
    required int quantity,
    required String createdBy,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_pr_from_shortage',
        params: {
          'p_mr_id': mrId,
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_created_by': createdBy,
        },
      );

      return response as String;
    } catch (e) {
      throw Exception('Failed to create PR from shortage: $e');
    }
  }

  // Get current stock for a product
  Future<int> getCurrentStock(String productId) async {
    try {
      final response = await _supabase
          .from('inventory')
          .select('quantity_available')
          .eq('product_id', productId)
          .single();

      return response['quantity_available'] as int? ?? 0;
    } catch (e) {
      throw Exception('Failed to get current stock: $e');
    }
  }

  // Check if stock is sufficient for issuance
  Future<bool> isStockSufficient({
    required String productId,
    required int requiredQuantity,
  }) async {
    try {
      final currentStock = await getCurrentStock(productId);
      return currentStock >= requiredQuantity;
    } catch (e) {
      throw Exception('Failed to check stock sufficiency: $e');
    }
  }

  // Get issuance logs for today
  Future<List<IssuanceLog>> getTodayIssuances() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return await getIssuanceLogs(startDate: startOfDay, endDate: endOfDay);
    } catch (e) {
      throw Exception('Failed to fetch today\'s issuances: $e');
    }
  }
}
