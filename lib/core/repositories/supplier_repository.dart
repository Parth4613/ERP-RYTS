import 'package:gas_company/core/models/supplier.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierRepository {
  SupplierRepository({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  Future<List<Supplier>> fetchSuppliers() async {
    final response = await _client
        .from('suppliers')
        .select('*, supplier_products(*)')
        .order('name');

    final suppliers = (response as List)
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();

    return suppliers.map(_sortProducts).toList();
  }

  Future<Supplier> fetchSupplier(String id) async {
    final response = await _client
        .from('suppliers')
        .select('*, supplier_products(*)')
        .eq('id', id)
        .single();

    return _sortProducts(Supplier.fromJson(response));
  }

  Future<Supplier> createSupplier({
    required Supplier supplier,
    required List<SupplierProduct> products,
  }) async {
    final inserted = await _client
        .from('suppliers')
        .insert(supplier.toJson())
        .select()
        .single();

    final supplierId = inserted['id'] as String;
    if (products.isNotEmpty) {
      await _client
          .from('supplier_products')
          .insert(
            products
                .map((product) => product.toJson(supplierId: supplierId))
                .toList(),
          );
    }

    return fetchSupplier(supplierId);
  }

  Future<Supplier> updateSupplier({
    required Supplier supplier,
    required List<SupplierProduct> products,
  }) async {
    await _client
        .from('suppliers')
        .update(supplier.toJson())
        .eq('id', supplier.id);

    final existing = await _client
        .from('supplier_products')
        .select('id')
        .eq('supplier_id', supplier.id);
    final existingIds = (existing as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toSet();
    final submittedIds = products.map((e) => e.id).whereType<String>().toSet();

    for (final staleId in existingIds.difference(submittedIds)) {
      await _client.from('supplier_products').delete().eq('id', staleId);
    }

    for (final product in products) {
      if (product.id == null) {
        await _client
            .from('supplier_products')
            .insert(product.toJson(supplierId: supplier.id));
      } else {
        await _client
            .from('supplier_products')
            .update(product.toJson(supplierId: supplier.id))
            .eq('id', product.id!);
      }
    }

    return fetchSupplier(supplier.id);
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _client.from('suppliers').delete().eq('id', supplierId);
  }

  Future<SupplierProduct> updateProductPriceDescription({
    required String supplierProductId,
    required double price,
    required String description,
  }) async {
    final response = await _client
        .from('supplier_products')
        .update({'price': price, 'description': description.trim()})
        .eq('id', supplierProductId)
        .select()
        .single();

    return SupplierProduct.fromJson(response);
  }

  Future<List<SupplierProductRevision>> fetchProductRevisions(
    String supplierProductId,
  ) async {
    final response = await _client
        .from('revision_history')
        .select()
        .eq('supplier_product_id', supplierProductId)
        .order('updated_at', ascending: false);

    return (response as List)
        .map((e) => SupplierProductRevision.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Supplier _sortProducts(Supplier supplier) {
    final sortedProducts = [...supplier.products]
      ..sort((a, b) => a.productName.compareTo(b.productName));
    return supplier.copyWith(products: sortedProducts);
  }
}
