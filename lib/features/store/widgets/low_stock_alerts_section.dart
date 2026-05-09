import 'package:flutter/material.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/screens/store_procurement_screen.dart';

class LowStockAlertsSection extends StatelessWidget {
  final StoreDashboardMetrics metrics;

  const LowStockAlertsSection({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final totalAlerts = metrics.lowStockItems + metrics.outOfStockItems;

    if (totalAlerts == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppColors.warning.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  metrics.outOfStockItems > 0 ? Icons.error : Icons.warning,
                  color: metrics.outOfStockItems > 0
                      ? AppColors.error
                      : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stock Alerts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: metrics.outOfStockItems > 0
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalAlerts items',
                  style: TextStyle(
                    fontSize: 12,
                    color: metrics.outOfStockItems > 0
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildAlertItem(
                    'Low Stock',
                    metrics.lowStockItems.toString(),
                    Icons.inventory_2,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAlertItem(
                    'Out of Stock',
                    metrics.outOfStockItems.toString(),
                    Icons.error_outline,
                    AppColors.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoreProcurementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inventory, size: 18),
                    label: const Text('Review Stock'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoreProcurementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Create PR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: metrics.outOfStockItems > 0
                          ? AppColors.error
                          : AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
