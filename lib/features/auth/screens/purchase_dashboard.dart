import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/user_profile.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/purchase/providers/purchase_provider.dart';
import 'package:gas_company/features/purchase/screens/pr_list_screen.dart';
import 'package:gas_company/features/purchase/screens/po_list_screen.dart';
import 'package:gas_company/features/purchase/screens/supplier_list_screen.dart';

class PurchaseDashboard extends ConsumerWidget {
  final UserProfile profile;
  const PurchaseDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(purchaseRequestsProvider);
    final pos = ref.watch(purchaseOrdersProvider);
    final suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Purchase Dashboard'),
          Text('Welcome, ${profile.name}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () => ref.read(authNotifierProvider.notifier).signOut())],
      ),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(purchaseRequestsProvider); ref.invalidate(purchaseOrdersProvider); ref.invalidate(suppliersProvider); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Overview'),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
              children: [
                MetricCard(title: 'Purchase Requests', value: prs.whenOrNull(data: (d) => '${d.length}') ?? '—', icon: Icons.request_quote_rounded, color: AppColors.purchaseColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PRListScreen()))),
                MetricCard(title: 'Purchase Orders', value: pos.whenOrNull(data: (d) => '${d.length}') ?? '—', icon: Icons.shopping_cart_rounded, color: AppColors.info,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const POListScreen()))),
                MetricCard(title: 'Pending PRs', value: prs.whenOrNull(data: (d) => '${d.where((p) => p.status.name == 'pending').length}') ?? '—', icon: Icons.pending_actions_rounded, color: AppColors.warning),
                MetricCard(title: 'Suppliers', value: suppliers.whenOrNull(data: (d) => '${d.length}') ?? '—', icon: Icons.people_rounded, color: AppColors.adminColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen()))),
              ],
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Quick Actions'),
            _actionTile(Icons.request_quote_rounded, 'Purchase Requests', 'Review pending requests', AppColors.purchaseColor,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PRListScreen()))),
            _actionTile(Icons.shopping_cart_rounded, 'Purchase Orders', 'Manage purchase orders', AppColors.info,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const POListScreen()))),
            _actionTile(Icons.people_rounded, 'Suppliers', 'Manage supplier list', AppColors.adminColor,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen()))),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Recent Purchase Orders'),
            pos.when(
              data: (list) {
                if (list.isEmpty) return const EmptyState(icon: Icons.shopping_cart_outlined, title: 'No Purchase Orders');
                return Column(children: list.take(5).map((po) => Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(po.supplierName ?? 'Supplier', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('₹${po.totalAmount?.toStringAsFixed(2) ?? '0.00'} • ${po.items.length} items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    StatusBadge.fromPOStatus(po.status),
                  ]),
                )).toList());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ]),
    ));
  }
}
