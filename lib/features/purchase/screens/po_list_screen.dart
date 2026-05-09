import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/features/purchase/providers/purchase_provider.dart';

class POListScreen extends ConsumerWidget {
  const POListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(purchaseOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: pos.when(
        data: (list) {
          if (list.isEmpty) return const EmptyState(icon: Icons.shopping_cart_outlined, title: 'No Purchase Orders');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: list.length,
              itemBuilder: (ctx, i) {
                final po = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('PO-${po.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                      StatusBadge.fromPOStatus(po.status),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
                      Text(po.supplierName ?? 'Supplier', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
                      const Icon(Icons.currency_rupee, size: 14, color: AppColors.textMuted), const SizedBox(width: 2),
                      Text('₹${po.totalAmount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text('${po.items.length} items • ${_formatDate(po.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (po.status != POStatus.delivered) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        if (po.status == POStatus.draft) Expanded(child: SizedBox(height: 36, child: ElevatedButton(
                          onPressed: () => _updateStatus(ref, context, po.id, 'ordered'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.info, padding: EdgeInsets.zero),
                          child: const Text('Mark Ordered', style: TextStyle(fontSize: 13))))),
                        if (po.status == POStatus.draft) const SizedBox(width: 10),
                        if (po.status == POStatus.ordered) Expanded(child: SizedBox(height: 36, child: ElevatedButton(
                          onPressed: () => _updateStatus(ref, context, po.id, 'delivered'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
                          child: const Text('Mark Delivered', style: TextStyle(fontSize: 13))))),
                      ]),
                    ],
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  Future<void> _updateStatus(WidgetRef ref, BuildContext context, String poId, String status) async {
    await ref.read(purchaseNotifierProvider.notifier).updatePOStatus(poId: poId, status: status);
    ref.invalidate(purchaseOrdersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'delivered' ? 'Marked as delivered & inventory updated' : 'Status updated'),
        backgroundColor: AppColors.success));
    }
  }
}
