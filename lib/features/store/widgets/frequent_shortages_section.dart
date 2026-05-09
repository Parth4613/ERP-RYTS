import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/widgets/quick_purchase_request_dialog.dart';

class FrequentShortagesSection extends StatelessWidget {
  final List<FrequentShortage> shortages;

  const FrequentShortagesSection({super.key, required this.shortages});

  @override
  Widget build(BuildContext context) {
    if (shortages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.error),
                const SizedBox(width: 8),
                const Text(
                  'Frequent Shortages (Last 30 Days)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${shortages.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...shortages
                .take(5)
                .map((shortage) => _buildShortageItem(context, shortage)),

            if (shortages.length > 5)
              TextButton(
                onPressed: () {
                  // Navigate to detailed shortage report
                },
                child: const Text('View all shortages →'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortageItem(BuildContext context, FrequentShortage shortage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  shortage.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (shortage.category != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    shortage.category!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.warning, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      '${shortage.shortageCount} times',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Last: ${DateFormat('MMM dd').format(shortage.lastShortageDate)}',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${shortage.totalShortageQuantity} units',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const Text(
                'total shortage',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              showDialog<String>(
                context: context,
                builder: (_) => QuickPurchaseRequestDialog(
                  initialItems: [
                    QuickPurchaseRequestItem(
                      productId: shortage.productId,
                      productName: shortage.productName,
                      unit: 'units',
                      quantity: shortage.totalShortageQuantity,
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
            tooltip: 'Create Purchase Request',
          ),
        ],
      ),
    );
  }
}
