import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';

class AlertsSection extends ConsumerWidget {
  const AlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final overBudgetAsync = ref.watch(overBudgetProjectsProvider);
    final lowStockAsync = ref.watch(lowStockItemsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            metricsAsync.when(
              data: (metrics) => _buildMetricsAlerts(metrics),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load alerts: $error'),
            ),
            
            const SizedBox(height: 16),
            
            overBudgetAsync.when(
              data: (projects) => _buildOverBudgetAlerts(projects),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 16),
            
            lowStockAsync.when(
              data: (items) => _buildLowStockAlerts(items),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsAlerts(DashboardMetrics metrics) {
    final alerts = <Widget>[];
    
    // Budget alerts
    if (metrics.overBudgetProjects > 0) {
      alerts.add(_buildAlertItem(
        'Budget Alert',
        '${metrics.overBudgetProjects} project(s) over budget',
        AppColors.error,
        Icons.warning,
        () {
          // Navigate to over budget projects
        },
      ));
    }
    
    if (metrics.nearLimitProjects > 0) {
      alerts.add(_buildAlertItem(
        'Budget Warning',
        '${metrics.nearLimitProjects} project(s) near budget limit',
        AppColors.warning,
        Icons.trending_up,
        () {
          // Navigate to near limit projects
        },
      ));
    }
    
    // Stock alerts
    if (metrics.lowStockItems > 0) {
      alerts.add(_buildAlertItem(
        'Stock Alert',
        '${metrics.lowStockItems} item(s) running low on stock',
        AppColors.warning,
        Icons.inventory,
        () {
          // Navigate to inventory
        },
      ));
    }
    
    // Request alerts
    final totalPending = metrics.pendingMaterialRequests + metrics.pendingPurchaseRequests;
    if (totalPending > 0) {
      alerts.add(_buildAlertItem(
        'Pending Requests',
        '$totalPending request(s) awaiting approval',
        AppColors.info,
        Icons.pending,
        () {
          // Navigate to requests
        },
      ));
    }
    
    if (alerts.isEmpty) {
      return _buildNoAlerts();
    }
    
    return Column(
      children: alerts,
    );
  }

  Widget _buildOverBudgetAlerts(List<ProjectCostSummary> projects) {
    if (projects.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Over Budget Projects',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                // Navigate to all over budget projects
              },
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ...projects.take(3).map((project) => _buildProjectAlertItem(project)),
        
        if (projects.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                // Navigate to all over budget projects
              },
              child: Text(
                'View ${projects.length - 3} more projects →',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLowStockAlerts(List<InventoryValuation> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Low Stock Items',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                // Navigate to inventory
              },
              child: const Text(
                'Manage Stock',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ...items.take(3).map((item) => _buildStockAlertItem(item)),
        
        if (items.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                // Navigate to all low stock items
              },
              child: Text(
                'View ${items.length - 3} more items →',
                style: const TextStyle(color: AppColors.warning),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertItem(
    String title,
    String description,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectAlertItem(ProjectCostSummary project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.projectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${project.budgetUsedPercentage.toStringAsFixed(1)}% over budget',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Over by ${((project.totalCost - project.budgetAmount) / project.budgetAmount * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertItem(InventoryValuation item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${item.quantityAvailable} units available (min: ${item.minimumStockLevel})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LOW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All systems operating normally',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
