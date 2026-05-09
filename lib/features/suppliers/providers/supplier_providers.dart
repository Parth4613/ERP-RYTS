import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/supplier.dart';
import 'package:gas_company/core/repositories/supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository();
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  return ref.watch(supplierRepositoryProvider).fetchSuppliers();
});

final supplierProvider = FutureProvider.family<Supplier, String>((
  ref,
  supplierId,
) {
  return ref.watch(supplierRepositoryProvider).fetchSupplier(supplierId);
});

final productRevisionsProvider =
    FutureProvider.family<List<SupplierProductRevision>, String>((
      ref,
      productId,
    ) {
      return ref
          .watch(supplierRepositoryProvider)
          .fetchProductRevisions(productId);
    });

class SupplierMutationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<Supplier?> createSupplier({
    required Supplier supplier,
    required List<SupplierProduct> products,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await ref
          .read(supplierRepositoryProvider)
          .createSupplier(supplier: supplier, products: products);
      ref.invalidate(suppliersProvider);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Supplier?> updateSupplier({
    required Supplier supplier,
    required List<SupplierProduct> products,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref
          .read(supplierRepositoryProvider)
          .updateSupplier(supplier: supplier, products: products);
      ref.invalidate(suppliersProvider);
      ref.invalidate(supplierProvider(supplier.id));
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(supplierRepositoryProvider).deleteSupplier(supplierId);
      ref.invalidate(suppliersProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProductPriceDescription({
    required String supplierId,
    required String supplierProductId,
    required double price,
    required String description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(supplierRepositoryProvider)
          .updateProductPriceDescription(
            supplierProductId: supplierProductId,
            price: price,
            description: description,
          );
      ref.invalidate(suppliersProvider);
      ref.invalidate(supplierProvider(supplierId));
      ref.invalidate(productRevisionsProvider(supplierProductId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final supplierMutationProvider =
    NotifierProvider<SupplierMutationNotifier, AsyncValue<void>>(
      SupplierMutationNotifier.new,
    );
