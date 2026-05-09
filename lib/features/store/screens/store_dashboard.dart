import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';
import 'package:gas_company/features/store/widgets/metrics_card.dart';
import 'package:gas_company/features/store/widgets/pending_requests_section.dart';
import 'package:gas_company/features/store/widgets/low_stock_alerts_section.dart';
import 'package:gas_company/features/store/widgets/frequent_shortages_section.dart';
import 'package:gas_company/features/store/screens/store_procurement_screen.dart';

class StoreDashboard extends ConsumerStatefulWidget {
  const StoreDashboard({super.key});

  @override
  ConsumerState<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends ConsumerState<StoreDashboard> {
  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(storeDashboardMetricsProvider);
    final pendingItemsAsync = ref.watch(pendingMRItemsWithStockProvider);
    final frequentShortagesAsync = ref.watch(frequentShortagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Store Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(storeDashboardMetricsProvider);
              ref.invalidate(pendingMRItemsWithStockProvider);
              ref.invalidate(frequentShortagesProvider);
            },
            icon: const Icon(Icons.refresh, color: AppColors.primary),
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
          ref.invalidate(storeDashboardMetricsProvider);
          ref.invalidate(pendingMRItemsWithStockProvider);
          ref.invalidate(frequentShortagesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metrics section
              metricsAsync.when(
                data: (metrics) => _buildMetricsSection(metrics),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) =>
                    _buildErrorWidget('Failed to load metrics: $error'),
              ),

              const SizedBox(height: 24),

              // Pending material requests
              pendingItemsAsync.when(
                data: (items) => PendingRequestsSection(items: items),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => _buildErrorWidget(
                  'Failed to load pending requests: $error',
                ),
              ),

              const SizedBox(height: 24),

              // Low stock alerts
              metricsAsync.when(
                data: (metrics) => LowStockAlertsSection(metrics: metrics),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // Frequent shortages
              frequentShortagesAsync.when(
                data: (shortages) =>
                    FrequentShortagesSection(shortages: shortages),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) =>
                    _buildErrorWidget('Failed to load shortages: $error'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection(StoreDashboardMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Store Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            MetricsCard(
              title: 'Pending MRs',
              value: metrics.pendingMrs.toString(),
              subtitle: 'Awaiting approval',
              icon: Icons.pending_actions,
              color: AppColors.warning,
              onTap: () {
                // Navigate to pending MRs
              },
            ),
            MetricsCard(
              title: 'Partial Issues',
              value: metrics.partiallyIssuedMrs.toString(),
              subtitle: 'Balance pending',
              icon: Icons.call_split_rounded,
              color: AppColors.info,
              onTap: () {
                // Navigate to partial MRs
              },
            ),
            MetricsCard(
              title: 'Waiting Procurement',
              value: metrics.waitingProcurementMrs.toString(),
              subtitle: 'PR required',
              icon: Icons.shopping_cart_checkout_rounded,
              color: AppColors.error,
              onTap: () {
                // Navigate to procurement waits
              },
            ),
            MetricsCard(
              title: 'Low Stock Items',
              value: metrics.lowStockItems.toString(),
              subtitle: 'Need attention',
              icon: Icons.inventory_2,
              color: AppColors.warning,
              onTap: () {
                // Navigate to inventory
              },
            ),
            MetricsCard(
              title: 'Out of Stock',
              value: metrics.outOfStockItems.toString(),
              subtitle: 'Critical shortage',
              icon: Icons.error_outline,
              color: AppColors.error,
              onTap: () {
                // Navigate to out of stock items
              },
            ),
            MetricsCard(
              title: 'Issuances Today',
              value: metrics.issuancesToday.toString(),
              subtitle: '${metrics.itemsIssuedToday} items',
              icon: Icons.local_shipping,
              color: AppColors.success,
              onTap: () {
                // Navigate to issuance history
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String error) {
    return Card(
      color: AppColors.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.invalidate(storeDashboardMetricsProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
