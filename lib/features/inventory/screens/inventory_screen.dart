import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';
import 'package:gas_company/features/inventory/screens/add_product_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
          ref.invalidate(inventoryProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: inventory.when(
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No Inventory Items', subtitle: 'Tap + to add a product');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inventoryProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final stockColor = item.isOutOfStock ? AppColors.error : item.isLowStock ? AppColors.warning : AppColors.success;
                final stockLabel = item.isOutOfStock ? 'OUT OF STOCK' : item.isLowStock ? 'LOW STOCK' : 'IN STOCK';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: stockColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.inventory_2_rounded, color: stockColor, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.product?.name ?? 'Unknown', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Qty: ${item.quantityAvailable} ${item.product?.unit ?? ''} • Min: ${item.product?.minimumStockLevel ?? 0}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    StatusBadge(label: stockLabel, color: stockColor),
                  ]),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
