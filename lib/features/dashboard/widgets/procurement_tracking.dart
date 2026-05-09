import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';

class ProcurementTracking extends ConsumerWidget {
  const ProcurementTracking({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierSpendingAsync = ref.watch(supplierSpendingAnalysisProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Procurement Tracking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Pending purchases summary
            metricsAsync.when(
              data: (metrics) => _buildPendingPurchases(metrics),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load metrics: $error'),
            ),
            
            const SizedBox(height: 24),
            
            // Supplier spending analysis
            supplierSpendingAsync.when(
              data: (suppliers) => _buildSupplierSpending(suppliers),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load supplier data: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPurchases(DashboardMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  color: metrics.pendingPurchaseCost > 0 ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Purchase Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: metrics.pendingPurchaseCost > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildPendingCard(
                    'Total Amount',
                    NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                        .format(metrics.pendingPurchaseCost),
                    Icons.account_balance_wallet,
                    metrics.pendingPurchaseCost > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPendingCard(
                    'Material Requests',
                    metrics.pendingMaterialRequests.toString(),
                    Icons.request_page,
                    metrics.pendingMaterialRequests > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildPendingCard(
                    'Purchase Requests',
                    metrics.pendingPurchaseRequests.toString(),
                    Icons.receipt_long,
                    metrics.pendingPurchaseRequests > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPendingCard(
                    'Total Pending',
                    (metrics.pendingMaterialRequests + metrics.pendingPurchaseRequests).toString(),
                    Icons.pending,
                    (metrics.pendingMaterialRequests + metrics.pendingPurchaseRequests) > 0 
                        ? AppColors.warning 
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            
            if (metrics.pendingPurchaseCost > 0 || 
                metrics.pendingMaterialRequests > 0 || 
                metrics.pendingPurchaseRequests > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to purchase order management
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Review Pending Orders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSpending(List<SupplierSpendingAnalysis> suppliers) {
    // Calculate total spending
    final totalSpending = suppliers.fold<double>(
      0.0,
      (sum, supplier) => sum + supplier.totalSpent,
    );
    
    // Sort by spending
    final sortedSuppliers = List<SupplierSpendingAnalysis>.from(suppliers)
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Supplier Spending Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Navigate to detailed supplier reports
                  },
                  child: const Text('View Report'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Total spending summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Supplier Spending',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                            .format(totalSpending),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${suppliers.length} suppliers',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Top suppliers list
            if (sortedSuppliers.isEmpty)
              const Center(
                child: Text(
                  'No supplier spending data available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Column(
                children: [
                  // Header
                  const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Orders', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Avg Order', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Supplier list
                  ...sortedSuppliers.take(10).map((supplier) => _buildSupplierItem(supplier, totalSpending)),
                  
                  if (suppliers.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: () {
                          // Show all suppliers
                        },
                        child: Text(
                          'View all ${suppliers.length} suppliers →',
                          style: const TextStyle(color: AppColors.primary),
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

  Widget _buildSupplierItem(SupplierSpendingAnalysis supplier, double totalSpending) {
    final percentage = totalSpending > 0 ? (supplier.totalSpent / totalSpending * 100) : 0.0;
    
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
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.supplierName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}% of total spending',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              supplier.orderCount.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              NumberFormat.compactCurrency(symbol: '\$')
                  .format(supplier.avgOrderValue),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.compactCurrency(symbol: '\$')
                      .format(supplier.totalSpent),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                // Visual indicator of spending
                Container(
                  height: 4,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage.clamp(0.0, 100.0) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
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
