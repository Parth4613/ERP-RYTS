import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';
import 'package:gas_company/features/dashboard/widgets/metrics_card.dart';
import 'package:gas_company/features/dashboard/widgets/projects_overview.dart';
import 'package:gas_company/features/dashboard/widgets/cost_breakdown_chart.dart';
import 'package:gas_company/features/dashboard/widgets/inventory_insights.dart';
import 'package:gas_company/features/dashboard/widgets/alerts_section.dart';
import 'package:gas_company/features/dashboard/widgets/procurement_tracking.dart';

class AdminCostDashboard extends ConsumerStatefulWidget {
  const AdminCostDashboard({super.key});

  @override
  ConsumerState<AdminCostDashboard> createState() => _AdminCostDashboardState();
}

class _AdminCostDashboardState extends ConsumerState<AdminCostDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cost Control Dashboard',
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
            onPressed: dashboardState.refreshing 
                ? null 
                : () => ref.read(dashboardStateProvider.notifier).refreshAllData(),
            icon: dashboardState.refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Projects'),
            Tab(text: 'Inventory'),
            Tab(text: 'Procurement'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(metricsAsync),
          const ProjectsOverviewTab(),
          const InventoryInsightsTab(),
          const ProcurementTrackingTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(AsyncValue<DashboardMetrics> metricsAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardStateProvider.notifier).refreshAllData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // High-level metrics section
            metricsAsync.when(
              data: (metrics) => _buildMetricsSection(metrics),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load metrics: $error'),
            ),
            
            const SizedBox(height: 24),
            
            // Alerts section
            const AlertsSection(),
            
            const SizedBox(height: 24),
            
            // Cost breakdown chart
            const CostBreakdownChart(),
            
            const SizedBox(height: 24),
            
            // Quick stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(DashboardMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'High-Level Metrics',
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
              title: 'Total Cost',
              value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(metrics.totalCostAllProjects),
              subtitle: 'All Projects',
              icon: Icons.account_balance_wallet,
              color: AppColors.primary,
              onTap: () {
                // Navigate to detailed cost view
              },
            ),
            MetricsCard(
              title: 'Cost This Month',
              value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(metrics.costThisMonth),
              subtitle: 'Current Month',
              icon: Icons.calendar_today,
              color: AppColors.secondary,
              onTap: () {
                // Navigate to monthly cost breakdown
              },
            ),
            MetricsCard(
              title: 'Inventory Value',
              value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(metrics.totalInventoryValue),
              subtitle: 'Total Stock',
              icon: Icons.inventory_2,
              color: AppColors.success,
              onTap: () {
                _tabController.animateTo(2); // Switch to Inventory tab
              },
            ),
            MetricsCard(
              title: 'Pending Purchases',
              value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(metrics.pendingPurchaseCost),
              subtitle: 'Awaiting Approval',
              icon: Icons.shopping_cart,
              color: AppColors.warning,
              onTap: () {
                _tabController.animateTo(3); // Switch to Procurement tab
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    
    return metricsAsync.when(
      data: (metrics) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Active Projects',
                      metrics.activeProjectsCount.toString(),
                      Icons.play_circle,
                      AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'On Hold',
                      metrics.onHoldProjectsCount.toString(),
                      Icons.pause_circle,
                      AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Completed',
                      metrics.completedProjectsCount.toString(),
                      Icons.check_circle,
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Over Budget',
                      metrics.overBudgetProjects.toString(),
                      Icons.warning,
                      AppColors.error,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Low Stock',
                      metrics.lowStockItems.toString(),
                      Icons.inventory,
                      AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Pending Requests',
                      (metrics.pendingMaterialRequests + metrics.pendingPurchaseRequests).toString(),
                      Icons.pending,
                      AppColors.info,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading stats: $error'),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
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
          textAlign: TextAlign.center,
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
              onPressed: () => ref.read(dashboardStateProvider.notifier).refreshAllData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab content widgets
class ProjectsOverviewTab extends ConsumerWidget {
  const ProjectsOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProjectsOverview();
  }
}

class InventoryInsightsTab extends ConsumerWidget {
  const InventoryInsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const InventoryInsights();
  }
}

class ProcurementTrackingTab extends ConsumerWidget {
  const ProcurementTrackingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProcurementTracking();
  }
}
