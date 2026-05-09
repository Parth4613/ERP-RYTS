import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/models/purchase.dart';
export 'package:gas_company/features/suppliers/providers/supplier_providers.dart'
    show suppliersProvider;

/// All purchase requests — tries the enriched view first for richer data.
final purchaseRequestsProvider = FutureProvider<List<PurchaseRequest>>((
  ref,
) async {
  try {
    // Enriched view: includes project name, MR reference, estimated cost.
    final response = await supabase
        .from('purchase_requests_with_details')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => PurchaseRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Fallback to standard query if enriched view doesn't exist yet.
    final response = await supabase
        .from('purchase_requests')
        .select('*, purchase_request_items(*, products(name, unit))')
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => PurchaseRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
});

/// All purchase orders
final purchaseOrdersProvider = FutureProvider<List<PurchaseOrder>>((ref) async {
  final response = await supabase
      .from('purchase_orders')
      .select(
        '*, suppliers(name), purchase_order_items(*, products(name, unit))',
      )
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Purchase operations
class PurchaseNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Create a purchase order from a purchase request
  Future<String?> createPurchaseOrder({
    required String prId,
    required String supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = supabase.auth.currentUser!.id;

      double total = 0;
      for (final item in items) {
        total += (item['quantity'] as int) * (item['unit_price'] as double);
      }

      final poResponse = await supabase
          .from('purchase_orders')
          .insert({
            'pr_id': prId,
            'supplier_id': supplierId,
            'status': 'draft',
            'total_amount': total,
            'notes': notes,
            'created_by': userId,
          })
          .select()
          .single();

      final poId = poResponse['id'] as String;

      final poItems = items
          .map(
            (item) => {
              'po_id': poId,
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'unit_price': item['unit_price'],
            },
          )
          .toList();

      await supabase.from('purchase_order_items').insert(poItems);

      // Store-generated shortage PRs move into the purchase flow as ordered.
      await supabase
          .from('purchase_requests')
          .update({'status': 'ordered'})
          .eq('id', prId);

      state = const AsyncValue.data(null);
      return poId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update PO status
  Future<void> updatePOStatus({
    required String poId,
    required String status,
  }) async {
    state = const AsyncValue.loading();
    try {
      await supabase
          .from('purchase_orders')
          .update({'status': status})
          .eq('id', poId);

      final po = await supabase
          .from('purchase_orders')
          .select('pr_id')
          .eq('id', poId)
          .maybeSingle();
      final prId = po?['pr_id'] as String?;
      if (prId != null && (status == 'ordered' || status == 'delivered')) {
        await supabase
            .from('purchase_requests')
            .update({'status': status})
            .eq('id', prId);
      }

      // IMPORTANT: inventory updates must be transactional RPC-only.
      // Use a server-side receiving workflow (PO receive RPC) to update inventory and stock ledger.

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new supplier
  Future<void> addSupplier({
    required String name,
    String? contactInfo,
    String? email,
    String? phone,
    String? address,
  }) async {
    state = const AsyncValue.loading();
    try {
      await supabase.from('suppliers').insert({
        'name': name,
        'contact_info': contactInfo,
        'email': email,
        'phone': phone,
        'address': address,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a supplier
  Future<void> deleteSupplier(String id) async {
    state = const AsyncValue.loading();
    try {
      await supabase.from('suppliers').delete().eq('id', id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final purchaseNotifierProvider =
    NotifierProvider<PurchaseNotifier, AsyncValue<void>>(PurchaseNotifier.new);
