import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/user_profile.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/dashboard/screens/admin_cost_dashboard.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/purchase/providers/purchase_provider.dart';
import 'package:gas_company/features/projects/screens/project_list_screen.dart';
import 'package:gas_company/features/projects/screens/create_project_screen.dart';
import 'package:gas_company/features/inventory/screens/inventory_screen.dart';
import 'package:gas_company/features/material_requests/screens/mr_list_screen.dart';
import 'package:gas_company/features/purchase/screens/pr_list_screen.dart';
import 'package:gas_company/features/purchase/screens/po_list_screen.dart';
import 'package:gas_company/features/purchase/screens/supplier_list_screen.dart';

class AdminDashboard extends ConsumerWidget {
  final UserProfile profile;

  const AdminDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final inventory = ref.watch(inventoryProvider);
    final mrs = ref.watch(allMaterialRequestsProvider);
    // ignore: unused_local_variable
    final prs = ref.watch(purchaseRequestsProvider);
    final pos = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Dashboard'),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectsProvider);
          ref.invalidate(inventoryProvider);
          ref.invalidate(allMaterialRequestsProvider);
          ref.invalidate(purchaseRequestsProvider);
          ref.invalidate(purchaseOrdersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Metrics
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
                    title: 'Projects',
                    value: projects.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.business_rounded,
                    color: AppColors.engineerColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProjectListScreen(),
                      ),
                    ),
                  ),
                  MetricCard(
                    title: 'Inventory Items',
                    value:
                        inventory.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.storeColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    ),
                  ),
                  MetricCard(
                    title: 'Material Requests',
                    value: mrs.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.warning,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MRListScreen(isStore: false),
                      ),
                    ),
                  ),
                  MetricCard(
                    title: 'Purchase Orders',
                    value: pos.whenOrNull(data: (d) => '${d.length}') ?? '—',
                    icon: Icons.shopping_cart_rounded,
                    color: AppColors.purchaseColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const POListScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Cost Control Dashboard
              const SectionHeader(title: 'Cost Control'),
              _ActionTile(
                icon: Icons.dashboard_rounded,
                title: 'Cost Control Dashboard',
                subtitle: 'Track project costs and budgets',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCostDashboard(),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Quick Actions
              const SectionHeader(title: 'Quick Actions'),
              _ActionTile(
                icon: Icons.add_business_rounded,
                title: 'Create Project',
                subtitle: 'Add a new construction project',
                color: AppColors.engineerColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateProjectScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.receipt_long_rounded,
                title: 'View Material Requests',
                subtitle: 'Review all material requests',
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MRListScreen(isStore: true),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.request_quote_rounded,
                title: 'Purchase Requests',
                subtitle: 'View pending purchase requests',
                color: AppColors.purchaseColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PRListScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.people_outline_rounded,
                title: 'Manage Suppliers',
                subtitle: 'View and add suppliers',
                color: AppColors.adminColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SupplierListScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Low Stock Alert
              const SectionHeader(title: 'Low Stock Alerts'),
              inventory.when(
                data: (items) {
                  final lowStock = items
                      .where((i) => i.isLowStock || i.isOutOfStock)
                      .toList();
                  if (lowStock.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.successLight.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.success.withAlpha(40)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success),
                          SizedBox(width: 12),
                          Text(
                            'All stock levels are healthy',
                            style: TextStyle(color: AppColors.success),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: lowStock
                        .map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: (item.isOutOfStock
                                        ? AppColors.error
                                        : AppColors.warning)
                                    .withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (item.isOutOfStock
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
                                    label: item.isOutOfStock
                                        ? 'OUT OF STOCK'
                                        : 'LOW STOCK',
                                    color: item.isOutOfStock
                                        ? AppColors.error
                                        : AppColors.warning,
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 28),

              // Pending MRs
              const SectionHeader(title: 'Pending Material Requests'),
              mrs.when(
                data: (items) {
                  final pending =
                      items.where((m) => m.status.name == 'pending').toList();
                  if (pending.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No pending requests',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: pending
                        .take(5)
                        .map((mr) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mr.projectName ?? 'Project',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'By: ${mr.engineerName ?? 'Unknown'} • ${mr.items.length} items',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge.fromMRStatus(mr.status),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
