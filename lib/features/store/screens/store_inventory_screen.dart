import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';
import 'package:gas_company/features/store/screens/store_procurement_screen.dart';
import 'package:gas_company/features/store/widgets/quick_purchase_request_dialog.dart';
import 'package:gas_company/features/store/widgets/stock_history_dialog.dart';

class StoreInventoryScreen extends ConsumerStatefulWidget {
  const StoreInventoryScreen({super.key});

  @override
  ConsumerState<StoreInventoryScreen> createState() =>
      _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends ConsumerState<StoreInventoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final metricsAsync = ref.watch(storeDashboardMetricsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Procurement',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoreProcurementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(inventoryProvider);
              ref.invalidate(storeDashboardMetricsProvider);
            },
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickPrDialog(),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Create PR'),
      ),
      body: Column(
        children: [
          // Metrics summary
          metricsAsync.when(
            data: (metrics) => _buildMetricsSummary(metrics),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),

          // Search and filter
          _buildSearchAndFilter(),

          // Inventory list
          Expanded(
            child: inventoryAsync.when(
              data: (items) => _buildInventoryList(items),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) =>
                  _buildErrorWidget('Failed to load inventory: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary(StoreDashboardMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricItem(
              'Total Items',
              '${metrics.lowStockItems + metrics.outOfStockItems}',
              Icons.inventory_2,
              AppColors.primary,
            ),
          ),
          Expanded(
            child: _buildMetricItem(
              'Low Stock',
              metrics.lowStockItems.toString(),
              Icons.warning,
              AppColors.warning,
            ),
          ),
          Expanded(
            child: _buildMetricItem(
              'Out of Stock',
              metrics.outOfStockItems.toString(),
              Icons.error_outline,
              AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Low Stock', 'low'),
                _buildFilterChip('Out of Stock', 'out'),
                _buildFilterChip('Good Stock', 'good'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildInventoryList(List<dynamic> items) {
    // Filter items based on search and filter
    var filteredItems = items.where((item) {
      final productName = item.product?.name?.toLowerCase() ?? '';
      final matchesSearch = productName.contains(_searchQuery);

      bool matchesFilter = true;
      if (_selectedFilter == 'low') {
        matchesFilter = item.isLowStock && !item.isOutOfStock;
      } else if (_selectedFilter == 'out') {
        matchesFilter = item.isOutOfStock;
      } else if (_selectedFilter == 'good') {
        matchesFilter = !item.isLowStock && !item.isOutOfStock;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    if (filteredItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(dynamic item) {
    final isOutOfStock = item.isOutOfStock;
    final isLowStock = item.isLowStock;

    Color statusColor;
    String statusLabel;

    if (isOutOfStock) {
      statusColor = AppColors.error;
      statusLabel = 'OUT OF STOCK';
    } else if (isLowStock) {
      statusColor = AppColors.warning;
      statusLabel = 'LOW STOCK';
    } else {
      statusColor = AppColors.success;
      statusLabel = 'IN STOCK';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.name ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Qty: ${item.quantityAvailable} ${item.product?.unit ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Min: ${item.product?.minimumStockLevel ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                _showStockHistory(item.product?.id);
              },
              icon: const Icon(Icons.history, color: AppColors.primary),
              tooltip: 'View Stock History',
            ),
            if (isLowStock || isOutOfStock)
              IconButton(
                onPressed: () => _openQuickPrDialog([
                  QuickPurchaseRequestItem(
                    productId: item.productId,
                    productName: item.product?.name ?? 'Product',
                    unit: item.product?.unit ?? 'pcs',
                    quantity: _recommendedQuantity(item),
                  ),
                ]),
                icon: const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: AppColors.warning,
                ),
                tooltip: 'Create Purchase Request',
              ),
          ],
        ),
      ),
    );
  }

  int _recommendedQuantity(dynamic item) {
    final minimum = item.product?.minimumStockLevel as int? ?? 0;
    final available = item.quantityAvailable as int? ?? 0;
    final reorder = (minimum * 2) - available;
    if (reorder > 0) return reorder;
    return minimum > 0 ? minimum : 1;
  }

  Future<void> _openQuickPrDialog([
    List<QuickPurchaseRequestItem> items = const [],
  ]) async {
    await showDialog<String>(
      context: context,
      builder: (_) => QuickPurchaseRequestDialog(initialItems: items),
    );
    ref.invalidate(storeProcurementItemsProvider);
    ref.invalidate(storePendingPurchaseRequestsProvider);
    ref.invalidate(storeDashboardMetricsProvider);
  }

  void _showStockHistory(String? productId) {
    if (productId == null) return;

    showDialog(
      context: context,
      builder: (context) => StockHistoryDialog(productId: productId),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(inventoryProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
