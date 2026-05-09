import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/user_profile.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/material_requests/screens/mr_list_screen.dart';
import 'package:gas_company/features/inventory/screens/add_product_screen.dart';
import 'package:gas_company/features/store/screens/store_inventory_screen.dart';
import 'package:gas_company/features/store/screens/store_procurement_screen.dart';

class StoreDashboard extends ConsumerWidget {
  final UserProfile profile;
  const StoreDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final mrs = ref.watch(allMaterialRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Store Dashboard'),
            Text(
              'Welcome, ${profile.name}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoreProcurementScreen()),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Create PR'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryProvider);
          ref.invalidate(allMaterialRequestsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Overview'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  MetricCard(
                    title: 'Inventory Items',
                    value:
                        inventory.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.storeColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StoreInventoryScreen(),
                      ),
                    ),
                  ),
                  MetricCard(
                    title: 'Pending MRs',
                    value:
                        mrs.whenOrNull(
                          data: (d) =>
                              '${d.where((m) => m.status.name == 'pending').length}',
                        ) ??
                        '—',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MRListScreen(isStore: true),
                      ),
                    ),
                  ),
                  MetricCard(
                    title: 'Low Stock',
                    value:
                        inventory.whenOrNull(
                          data: (d) => '${d.where((i) => i.isLowStock).length}',
                        ) ??
                        '—',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.error,
                  ),
                  MetricCard(
                    title: 'Total MRs',
                    value: mrs.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Quick Actions'),
              _actionTile(
                Icons.inventory_2_rounded,
                'View Inventory',
                'Check stock levels',
                AppColors.storeColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreInventoryScreen(),
                  ),
                ),
              ),
              _actionTile(
                Icons.add_shopping_cart_rounded,
                'Create Purchase Request',
                'Send shortages to Purchase',
                AppColors.purchaseColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreProcurementScreen(),
                  ),
                ),
              ),
              _actionTile(
                Icons.receipt_long_rounded,
                'Material Requests',
                'Review and issue materials',
                AppColors.warning,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MRListScreen(isStore: true),
                  ),
                ),
              ),
              _actionTile(
                Icons.add_box_rounded,
                'Add Product',
                'Register a new product',
                AppColors.info,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                ),
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Low Stock Alerts'),
              inventory.when(
                data: (items) {
                  final low = items
                      .where((i) => i.isLowStock || i.isOutOfStock)
                      .toList();
                  if (low.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.successLight.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success),
                          SizedBox(width: 12),
                          Text(
                            'All stock levels healthy',
                            style: TextStyle(color: AppColors.success),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: low
                        .map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color:
                                  (item.isOutOfStock
                                          ? AppColors.error
                                          : AppColors.warning)
                                      .withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (item.isOutOfStock
                                            ? AppColors.error
                                            : AppColors.warning)
                                        .withAlpha(50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.isOutOfStock
                                      ? Icons.error_outline
                                      : Icons.warning_amber_rounded,
                                  color: item.isOutOfStock
                                      ? AppColors.error
                                      : AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product?.name ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Available: ${item.quantityAvailable} ${item.product?.unit ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: item.isOutOfStock ? 'OUT' : 'LOW',
                                  color: item.isOutOfStock
                                      ? AppColors.error
                                      : AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String title,
    String sub,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
