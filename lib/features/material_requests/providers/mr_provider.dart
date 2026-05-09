import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/models/material_request.dart';
import 'package:gas_company/core/utils/enums.dart';

/// All material requests (for store/admin)
final allMaterialRequestsProvider = FutureProvider<List<MaterialRequest>>((
  ref,
) async {
  final response = await supabase
      .from('material_requests_with_details')
      .select('*, material_request_items(*, products(name, unit))')
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => MaterialRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Engineer's own material requests
final myMaterialRequestsProvider = FutureProvider<List<MaterialRequest>>((
  ref,
) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('material_requests_with_details')
      .select('*, material_request_items(*, products(name, unit))')
      .eq('engineer_id', userId)
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => MaterialRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Single material request by ID
final materialRequestByIdProvider =
    FutureProvider.family<MaterialRequest?, String>((ref, id) async {
      final response = await supabase
          .from('material_requests_with_details')
          .select('*, material_request_items(*, products(name, unit))')
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return MaterialRequest.fromJson(response);
    });

/// Material request operations
class MaterialRequestNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Engineer creates a new MR
  Future<String?> createMaterialRequest({
    required String projectId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = supabase.auth.currentUser!.id;

      final mrResponse = await supabase
          .from('material_requests')
          .insert({
            'project_id': projectId,
            'engineer_id': userId,
            'notes': notes,
            'status': 'pending',
          })
          .select()
          .single();

      final mrId = mrResponse['id'] as String;

      final mrItems = items
          .map(
            (item) => {
              'mr_id': mrId,
              'product_id': item['product_id'],
              'quantity_requested': item['quantity_requested'],
            },
          )
          .toList();

      await supabase.from('material_request_items').insert(mrItems);

      state = const AsyncValue.data(null);
      return mrId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Store approves/rejects an MR
  Future<void> updateMRStatus({
    required String mrId,
    required String status,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (status == MRStatus.approved.databaseValue || status == 'approved') {
        await supabase.rpc(
          'approve_material_request_safe',
          params: {'p_mr_id': mrId},
        );
      } else {
        await supabase
            .from('material_requests')
            .update({'status': status})
            .eq('id', mrId);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Store issues items (partial or full)
  Future<void> issueItems({
    required String mrId,
    required List<Map<String, dynamic>> issuedItems,
  }) async {
    state = const AsyncValue.loading();
    try {
      for (final item in issuedItems) {
        final itemId = item['id'] as String;
        final qtyToIssue = item['quantity_to_issue'] as int;
        final productId = item['product_id'] as String;

        if (qtyToIssue <= 0) {
          throw ArgumentError('Issued quantity must be greater than zero');
        }

        await supabase.rpc(
          'issue_materials_safe',
          params: {
            'p_mr_id': mrId,
            'p_mr_item_id': itemId,
            'p_product_id': productId,
            'p_quantity_to_issue': qtyToIssue,
            'p_notes': item['notes'],
            // Never auto-create PRs during issuance.
            'p_auto_create_pr': false,
          },
        );
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Store creates a purchase request from an MR shortage
  Future<String?> createPurchaseRequestFromMR({
    required String mrId,
    required List<Map<String, dynamic>> shortageItems,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Deprecated: PR creation should be explicit and combined through Store workflow RPCs.
      // Use `create_store_purchase_request` / `create_combined_pr` from the Store UI.
      throw UnsupportedError(
        'Direct PR creation is deprecated. Use Store combined PR workflow.',
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final materialRequestNotifierProvider =
    NotifierProvider<MaterialRequestNotifier, AsyncValue<void>>(
      MaterialRequestNotifier.new,
    );
