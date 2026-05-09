import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';

class InventoryInsights extends ConsumerWidget {
  const InventoryInsights({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryValuationProvider(
      const InventoryValuationParams(limit: 50),
    ));
    final lowStockAsync = ref.watch(lowStockItemsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Insights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Low stock alerts
            lowStockAsync.when(
              data: (lowStockItems) => _buildLowStockAlerts(lowStockItems),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load low stock items: $error'),
            ),
            
            const SizedBox(height: 24),
            
            // Inventory valuation
            inventoryAsync.when(
              data: (inventory) => _buildInventoryValuation(inventory),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load inventory: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts(List<InventoryValuation> lowStockItems) {
    if (lowStockItems.isEmpty) {
      return Card(
        color: AppColors.success.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'All items are sufficiently stocked',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppColors.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: AppColors.error),
                const SizedBox(width: 8),
                Text(
                  'Low Stock Alert - ${lowStockItems.length} items',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Navigate to inventory management
                  },
                  child: const Text(
                    'Manage Stock',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ...lowStockItems.take(5).map((item) => _buildLowStockItem(item)),
            
            if (lowStockItems.length > 5)
              TextButton(
                onPressed: () {
                  // Show all low stock items
                },
                child: Text(
                  'View all ${lowStockItems.length} items →',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockItem(InventoryValuation item) {
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
                if (item.category != null)
                  Text(
                    item.category!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantityAvailable} units',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              Text(
                'Min: ${item.minimumStockLevel}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
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

  Widget _buildInventoryValuation(List<InventoryValuation> inventory) {
    // Calculate totals
    final totalValue = inventory.fold<double>(
      0.0,
      (sum, item) => sum + item.totalValue,
    );
    final totalItems = inventory.fold<int>(
      0,
      (sum, item) => sum + item.quantityAvailable,
    );
    
    // Group by stock status
    final stockStatusCounts = <StockStatus, int>{};
    for (final item in inventory) {
      stockStatusCounts[item.stockStatus] = (stockStatusCounts[item.stockStatus] ?? 0) + 1;
    }
    
    // Group by category
    final categoryTotals = <String, double>{};
    for (final item in inventory) {
      if (item.category != null) {
        categoryTotals[item.category!] = (categoryTotals[item.category!] ?? 0) + item.totalValue;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Value',
                NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                    .format(totalValue),
                Icons.account_balance_wallet,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Total Items',
                NumberFormat.compact().format(totalItems),
                Icons.inventory_2,
                AppColors.secondary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Stock status breakdown
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stock Status Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: StockStatus.values.map((status) {
                    final count = stockStatusCounts[status] ?? 0;
                    final percentage = inventory.isNotEmpty ? (count / inventory.length * 100) : 0.0;
                    
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStockStatusColor(status).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getStockStatusColor(status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _getStockStatusText(status),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStockStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Category breakdown
        if (categoryTotals.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Value by Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ...categoryTotals.entries.map((entry) {
                    final category = entry.key;
                    final value = entry.value;
                    final percentage = totalValue > 0 ? (value / totalValue * 100) : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}% of total value',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                                .format(value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Top value items
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Highest Value Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                ...inventory.take(10).map((item) => _buildInventoryItem(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(InventoryValuation item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                Row(
                  children: [
                    Text(
                      '${item.quantityAvailable} units',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.category != null) ...[
                      const Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        item.category!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                    .format(item.totalValue),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '@ ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(item.unitCost)}/unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStockStatusColor(item.stockStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStockStatusText(item.stockStatus),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _getStockStatusColor(item.stockStatus),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStockStatusColor(StockStatus status) {
    switch (status) {
      case StockStatus.lowStock:
        return AppColors.error;
      case StockStatus.mediumStock:
        return AppColors.warning;
      case StockStatus.goodStock:
        return AppColors.success;
    }
  }

  String _getStockStatusText(StockStatus status) {
    switch (status) {
      case StockStatus.lowStock:
        return 'LOW';
      case StockStatus.mediumStock:
        return 'MEDIUM';
      case StockStatus.goodStock:
        return 'GOOD';
    }
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
