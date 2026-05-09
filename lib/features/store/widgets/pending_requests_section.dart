import 'package:flutter/material.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/screens/store_mr_detail_screen.dart';

class PendingRequestsSection extends StatelessWidget {
  final List<PendingMRItemWithStock> items;

  const PendingRequestsSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // Group items by MR
    final groupedByMR = <String, List<PendingMRItemWithStock>>{};
    for (final item in items) {
      if (!groupedByMR.containsKey(item.mrId)) {
        groupedByMR[item.mrId] = [];
      }
      groupedByMR[item.mrId]!.add(item);
    }

    if (groupedByMR.isEmpty) {
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
                  'No pending material requests',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'Pending Material Requests',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${groupedByMR.length} requests',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...groupedByMR.entries.take(5).map((entry) {
              final mrId = entry.key;
              final mrItems = entry.value;
              final firstItem = mrItems.first;

              return _buildMRItem(context, mrId, firstItem, mrItems);
            }),

            if (groupedByMR.length > 5)
              TextButton(
                onPressed: () {
                  // Navigate to all pending MRs
                },
                child: const Text('View all requests →'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMRItem(
    BuildContext context,
    String mrId,
    PendingMRItemWithStock item,
    List<PendingMRItemWithStock> mrItems,
  ) {
    final itemCount = mrItems.length;
    final hasOutOfStock = mrItems.any(
      (item) => item.issuanceStatus == IssuanceStatus.outOfStock,
    );
    final hasPartial = mrItems.any(
      (item) => item.issuanceStatus == IssuanceStatus.canPartiallyIssue,
    );
    final statusColor = hasOutOfStock
        ? AppColors.error
        : hasPartial
        ? AppColors.warning
        : AppColors.success;
    final statusLabel = hasOutOfStock
        ? 'OUT OF STOCK'
        : hasPartial
        ? 'PARTIAL'
        : 'READY';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreMRDetailScreen(
                mrId: mrId,
                projectName: item.projectName,
                engineerName: item.engineerName,
                createdAt: item.mrCreatedAt,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.projectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.engineerName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$itemCount items',
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
            const SizedBox(width: 8),
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
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
