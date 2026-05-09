import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/models/product.dart';

/// All products provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final response = await supabase
      .from('products')
      .select()
      .order('name');
  return (response as List)
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Inventory provider with product details
final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final response = await supabase
      .from('inventory')
      .select('*, products(*)')
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Low stock items
final lowStockProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final items = await ref.watch(inventoryProvider.future);
  return items.where((item) => item.isLowStock || item.isOutOfStock).toList();
});

/// Inventory operations
class InventoryNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addProduct({
    required String name,
    required String unit,
    int minimumStockLevel = 0,
    String? category,
    int initialStock = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final productResponse = await supabase
          .from('products')
          .insert({
            'name': name,
            'unit': unit,
            'minimum_stock_level': minimumStockLevel,
            'category': category,
          })
          .select()
          .single();

      // Create initial inventory record
      await supabase.from('inventory').insert({
        'product_id': productResponse['id'],
        'quantity_available': initialStock,
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStock({
    required String inventoryId,
    required int newQuantity,
  }) async {
    state = const AsyncValue.loading();
    try {
      await supabase.from('inventory').update({
        'quantity_available': newQuantity,
        'last_restocked_at': DateTime.now().toIso8601String(),
      }).eq('id', inventoryId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final inventoryNotifierProvider =
    NotifierProvider<InventoryNotifier, AsyncValue<void>>(InventoryNotifier.new);
