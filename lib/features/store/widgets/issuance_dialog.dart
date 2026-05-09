import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';
import 'package:flutter/scheduler.dart';

class IssuanceDialog extends ConsumerWidget {
  final PendingMRItemWithStock item;
  final String mrId;
  final String mrItemId;
  final String projectId;
  final String issuedBy;

  const IssuanceDialog({
    super.key,
    required this.item,
    required this.mrId,
    required this.mrItemId,
    required this.projectId,
    required this.issuedBy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAvailable = item.stockAvailable;
    final quantityPending = item.quantityPending;
    final shortage = quantityPending - stockAvailable;

    return AlertDialog(
      title: const Text('Material Issuance'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Requested', '$quantityPending ${item.unit}'),
            _buildInfoRow('Available', '$stockAvailable ${item.unit}'),
            if (shortage > 0)
              _buildInfoRow(
                'Shortage',
                '$shortage ${item.unit}',
                color: AppColors.warning,
              ),
          ],
        ),
      ),
      actions: _buildActions(context, ref, stockAvailable, quantityPending, shortage),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    int stockAvailable,
    int quantityPending,
    int shortage,
  ) {
    if (stockAvailable == 0) {
      // No stock available
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _showCreatePRDialog(Navigator.of(context).context, ref, quantityPending);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Purchase Request'),
        ),
      ];
    } else if (stockAvailable < quantityPending) {
      // Partial stock available
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _issueAvailableOnly(context, ref, stockAvailable);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
          ),
          child: const Text('Issue Available Only'),
        ),
        ElevatedButton(
          onPressed: () {
            final rootContext = Navigator.of(context).context;
            Navigator.of(context).pop();
            _issueAvailableAndCreatePR(rootContext, ref, stockAvailable, shortage);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Issue Available & Create PR'),
        ),
      ];
    } else {
      // Full stock available
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _issueFullQuantity(context, ref, quantityPending);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: const Text('Issue Material'),
        ),
      ];
    }
  }

  void _issueFullQuantity(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) {
    ref.read(issuanceStateProvider.notifier).issueMaterials(
      mrId: mrId,
      mrItemId: mrItemId,
      projectId: projectId,
      productId: item.productId,
      quantityToIssue: quantity,
      issuedBy: issuedBy,
    );
  }

  void _issueAvailableOnly(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) {
    ref.read(issuanceStateProvider.notifier).issueMaterials(
      mrId: mrId,
      mrItemId: mrItemId,
      projectId: projectId,
      productId: item.productId,
      quantityToIssue: quantity,
      issuedBy: issuedBy,
      notes: 'Partial issuance - remaining quantity unavailable',
    );
  }

  void _issueAvailableAndCreatePR(
    BuildContext context,
    WidgetRef ref,
    int issueQuantity,
    int prQuantity,
  ) {
    // First issue available quantity
    ref.read(issuanceStateProvider.notifier).issueMaterials(
      mrId: mrId,
      mrItemId: mrItemId,
      projectId: projectId,
      productId: item.productId,
      quantityToIssue: issueQuantity,
      issuedBy: issuedBy,
      notes: 'Partial issuance - PR created for shortage',
    );

    // Then show PR creation dialog
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showCreatePRDialog(context, ref, prQuantity);
    });
  }

  void _showCreatePRDialog(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Purchase Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${item.productName}'),
            const SizedBox(height: 8),
            Text('Quantity to Order: $quantity ${item.unit}'),
            const SizedBox(height: 16),
            const Text(
              'This will create a purchase request for the shortage quantity.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final prId = await ref.read(storeProcurementNotifierProvider.notifier).createPurchaseRequest(
                items: [
                  QuickPurchaseRequestItem(
                    productId: item.productId,
                    productName: item.productName,
                    unit: item.unit,
                    quantity: quantity,
                  ),
                ],
                mrId: mrId,
                projectId: projectId,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(prId != null 
                        ? 'Purchase Request created successfully' 
                        : 'Failed to create Purchase Request'),
                    backgroundColor: prId != null ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create PR'),
          ),
        ],
      ),
    );
  }
}
