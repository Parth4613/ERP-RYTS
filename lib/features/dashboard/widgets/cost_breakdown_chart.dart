import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';

class CostBreakdownChart extends ConsumerWidget {
  const CostBreakdownChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyCostsAsync = ref.watch(monthlyCostAnalysisProvider);
    final topMaterialsAsync = ref.watch(topCostMaterialsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Monthly cost trend
            monthlyCostsAsync.when(
              data: (monthlyCosts) => _buildMonthlyCostTrend(monthlyCosts),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load monthly costs: $error'),
            ),
            
            const SizedBox(height: 24),
            
            // Top cost materials
            topMaterialsAsync.when(
              data: (materials) => _buildTopCostMaterials(materials),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load top materials: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCostTrend(List<MonthlyCostAnalysis> monthlyCosts) {
    // Group by month and cost type
    final Map<String, Map<String, double>> monthlyData = {};
    
    for (final cost in monthlyCosts) {
      final monthKey = DateFormat('MMM yyyy').format(cost.month);
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {};
      }
      monthlyData[monthKey]![cost.costType] = cost.totalCost;
    }
    
    final months = monthlyData.keys.take(6).toList(); // Last 6 months
    final costTypes = ['material', 'labor', 'equipment', 'other'];
    final colors = {
      'material': AppColors.primary,
      'labor': AppColors.secondary,
      'equipment': AppColors.success,
      'other': AppColors.warning,
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Cost Trend (Last 6 Months)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Simple bar chart representation
        Container(
          height: 200,
          child: months.isEmpty
              ? const Center(
                  child: Text(
                    'No cost data available',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: months.map((month) {
                    final monthData = monthlyData[month]!;
                    final totalCost = costTypes
                        .map((type) => monthData[type] ?? 0.0)
                        .reduce((a, b) => a + b);
                    final maxCost = monthlyData.values
                        .map((data) => costTypes
                            .map((type) => data[type] ?? 0.0)
                            .reduce((a, b) => a + b))
                        .reduce((a, b) => a > b ? a : b);
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Stacked bars
                            Container(
                              height: maxCost > 0 ? (totalCost / maxCost * 160) : 0,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                color: colors['material'],
                              ),
                            ),
                            if (monthData['labor'] != null && monthData['labor']! > 0)
                              Container(
                                height: maxCost > 0 ? (monthData['labor']! / maxCost * 160) : 0,
                                decoration: BoxDecoration(
                                  color: colors['labor'],
                                ),
                              ),
                            if (monthData['equipment'] != null && monthData['equipment']! > 0)
                              Container(
                                height: maxCost > 0 ? (monthData['equipment']! / maxCost * 160) : 0,
                                decoration: BoxDecoration(
                                  color: colors['equipment'],
                                ),
                              ),
                            if (monthData['other'] != null && monthData['other']! > 0)
                              Container(
                                height: maxCost > 0 ? (monthData['other']! / maxCost * 160) : 0,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  color: colors['other'],
                                ),
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // Month label
                            Text(
                              month,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // Total cost
                            Text(
                              NumberFormat.compactCurrency(symbol: '\$')
                                  .format(totalCost),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        
        const SizedBox(height: 16),
        
        // Legend
        Wrap(
          spacing: 16,
          children: costTypes.map((type) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[type],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  type.capitalize(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTopCostMaterials(List<TopCostMaterial> materials) {
    final topMaterials = materials.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Cost-Driving Materials',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        if (topMaterials.isEmpty)
          const Center(
            child: Text(
              'No material cost data available',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          Column(
            children: topMaterials.asMap().entries.map((entry) {
              final index = entry.key;
              final material = entry.value;
              final maxValue = topMaterials.first.totalCost;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Rank
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getRankColor(index),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Material info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.productName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                '${material.totalQuantityUsed} units',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (material.category != null) ...[
                                const Text(' • ', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                Text(
                                  material.category!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Cost bar
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            height: 8,
                            width: maxValue > 0 ? (material.totalCost / maxValue * 60) : 0,
                            decoration: BoxDecoration(
                              color: _getRankColor(index),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NumberFormat.compactCurrency(symbol: '\$')
                                .format(material.totalCost),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return AppColors.error; // Red for #1
      case 1:
        return AppColors.warning; // Orange for #2
      case 2:
        return AppColors.secondary; // Blue for #3
      default:
        return AppColors.primary; // Default blue
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
