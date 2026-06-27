import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/error_state.dart';
import '../providers/inventory_provider.dart';
import '../widgets/low_stock_alert_widget.dart';

/// Inventory Dashboard — entry point for the Inventory module.
/// Shows KPI cards, low stock alerts, and quick action buttons.
/// UI-003: Loading, empty, and error states on all data sections.
class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockLevelsAsync = ref.watch(stockLevelsProvider);
    final lowStockAsync = ref.watch(lowStockProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Inventory', style: AppTextStyles.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search materials',
            onPressed: () => context.go('/inventory/stock'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(stockLevelsProvider);
          ref.invalidate(lowStockProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── KPI Cards ───
              stockLevelsAsync.when(
                data: (items) {
                  final totalItems = items.length;
                  final lowStockCount = items.where((i) => i.isLowStock).length;
                  final outOfStockCount = items
                      .where((i) => i.isOutOfStock)
                      .length;
                  final criticalCount = items
                      .where((i) => i.isCritical && !i.isInStock)
                      .length;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      KpiCard(
                        title: 'Total Items',
                        value: totalItems.toString(),
                        icon: Icons.inventory_2_rounded,
                        onTap: () => context.go('/inventory/stock'),
                      ),
                      KpiCard(
                        title: 'Low Stock',
                        value: lowStockCount.toString(),
                        icon: Icons.trending_down_rounded,
                        valueColor: lowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                        onTap: () {
                          ref.read(stockFilterProvider.notifier).state =
                              const StockFilter(stockStatus: 'low_stock');
                          context.go('/inventory/stock');
                        },
                      ),
                      KpiCard(
                        title: 'Out of Stock',
                        value: outOfStockCount.toString(),
                        icon: Icons.remove_shopping_cart_rounded,
                        valueColor: outOfStockCount > 0
                            ? AppColors.danger
                            : AppColors.success,
                        onTap: () {
                          ref.read(stockFilterProvider.notifier).state =
                              const StockFilter(stockStatus: 'out_of_stock');
                          context.go('/inventory/stock');
                        },
                      ),
                      KpiCard(
                        title: 'Critical Items',
                        value: criticalCount.toString(),
                        icon: Icons.warning_amber_rounded,
                        valueColor: criticalCount > 0
                            ? AppColors.danger
                            : AppColors.textMuted,
                      ),
                    ],
                  );
                },
                loading: () => const LoadingSkeleton(itemCount: 4),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(stockLevelsProvider),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Low Stock Alert Widget ───
              LowStockAlertWidget(
                onViewAll: () {
                  ref.read(stockFilterProvider.notifier).state =
                      const StockFilter(stockStatus: 'low_stock');
                  context.go('/inventory/stock');
                },
              ),

              const SizedBox(height: 20),

              // ─── Quick Actions ───
              Text('QUICK ACTIONS', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),

              _QuickActionTile(
                icon: Icons.list_alt_rounded,
                title: 'Stock Levels',
                subtitle: 'View all material stock levels',
                onTap: () => context.go('/inventory/stock'),
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.history_rounded,
                title: 'Transaction History',
                subtitle: 'View stock movement history',
                onTap: () => context.go('/inventory/transactions'),
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.tune_rounded,
                title: 'Stock Adjustments',
                subtitle: 'Request or review adjustments',
                onTap: () => context.go('/inventory/adjustments'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
