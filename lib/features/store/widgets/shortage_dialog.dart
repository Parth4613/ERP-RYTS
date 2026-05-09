import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';

/// Combined Shortage Dialog — shows ALL shortage items from an MR in one view
/// and creates a SINGLE combined Purchase Request for all of them.
class ShortageDialog extends ConsumerStatefulWidget {
  final String mrId;
  final String? projectName;

  const ShortageDialog({
    super.key,
    required this.mrId,
    this.projectName,
  });

  @override
  ConsumerState<ShortageDialog> createState() => _ShortageDialogState();
}

class _ShortageDialogState extends ConsumerState<ShortageDialog> {
  bool _isProcessing = false;
  bool _autoIssueAvailable = true;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingItemsAsync = ref.watch(
      pendingMRItemsForMRProvider(widget.mrId),
    );

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: pendingItemsAsync.when(
          data: (items) => _buildContent(items),
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $error',
                style: const TextStyle(color: AppColors.error)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<PendingMRItemWithStock> items) {
    final shortageItems = items
        .where(
          (item) =>
              item.issuanceStatus == IssuanceStatus.outOfStock ||
              item.issuanceStatus == IssuanceStatus.canPartiallyIssue,
        )
        .toList();

    final fullyIssuable = items
        .where(
            (item) => item.issuanceStatus == IssuanceStatus.canFullyIssue)
        .toList();

    if (shortageItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 64, color: AppColors.success),
            const SizedBox(height: 16),
            const Text(
              'No shortage items found!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All items have sufficient stock for full issuance.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.warning.withOpacity(0.12),
                AppColors.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_cart_checkout_rounded,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generate Combined Purchase Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.projectName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.projectName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _summaryChip(
                    '${shortageItems.length} Shortage Item(s)',
                    AppColors.error,
                  ),
                  if (fullyIssuable.isNotEmpty)
                    _summaryChip(
                      '${fullyIssuable.length} Can Fully Issue',
                      AppColors.success,
                    ),
                  _summaryChip(
                    '${_totalShortageQty(shortageItems)} Total Shortage',
                    AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Shortage items list
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shrinkWrap: true,
            itemCount: shortageItems.length,
            itemBuilder: (context, index) {
              final item = shortageItems[index];
              return _buildShortageItemTile(item, index + 1);
            },
          ),
        ),

        // Options
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              CheckboxListTile(
                dense: true,
                value: _autoIssueAvailable,
                onChanged: _isProcessing
                    ? null
                    : (v) => setState(() => _autoIssueAvailable = v ?? false),
                title: const Text(
                  'Also issue available stock automatically',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Issues whatever is in stock before creating the PR',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Urgency, preferred supplier, delivery instructions...',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              TextButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _processShortages(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Generate Combined PR (${shortageItems.length} items)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShortageItemTile(PendingMRItemWithStock item, int index) {
    final shortageQty = item.quantityPending - item.stockAvailable;
    final canPartiallyIssue =
        item.issuanceStatus == IssuanceStatus.canPartiallyIssue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canPartiallyIssue
              ? AppColors.warning.withOpacity(0.4)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Index badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Requested: ${item.quantityRequested} ${item.unit} · '
                  'Issued: ${item.quantityIssued} ${item.unit} · '
                  'In Stock: ${item.stockAvailable} ${item.unit}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Shortage quantity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Text(
              '${shortageQty > 0 ? shortageQty : item.quantityPending} ${item.unit}',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  int _totalShortageQty(List<PendingMRItemWithStock> items) {
    return items.fold<int>(0, (sum, item) {
      final shortage = item.quantityPending - item.stockAvailable;
      return sum + (shortage > 0 ? shortage : item.quantityPending);
    });
  }

  Future<void> _processShortages() async {
    setState(() => _isProcessing = true);

    final result = await ref
        .read(issuanceStateProvider.notifier)
        .processMRShortages(
          mrId: widget.mrId,
          autoIssue: _autoIssueAvailable,
          notes:
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

    setState(() => _isProcessing = false);

    if (result != null && mounted) {
      // Backend call issues stock (optional) but MUST NOT create PRs.
      // PR creation is explicit here and will append into draft/pending combined PR.
      final shortageItems = result['shortage_items'];
      final totalIssued = result['total_issued'] as int? ?? 0;

      final pendingItems = await ref.read(
        pendingMRItemsForMRProvider(widget.mrId).future,
      );
      final projectId = pendingItems.isEmpty ? null : pendingItems.first.projectId;

      // Build PR items from current shortage computations in UI (source of truth for explicit action)
      final items = pendingItems
          .where(
            (item) =>
                item.issuanceStatus == IssuanceStatus.outOfStock ||
                item.issuanceStatus == IssuanceStatus.canPartiallyIssue,
          )
          .map((item) {
        final shortageQty = item.quantityPending - item.stockAvailable;
        return QuickPurchaseRequestItem(
          productId: item.productId,
          productName: item.productName,
          unit: item.unit,
          quantity: shortageQty > 0 ? shortageQty : item.quantityPending,
        );
      }).toList();

      final prId = await ref
          .read(storeProcurementNotifierProvider.notifier)
          .createPurchaseRequest(
            items: items,
            projectId: projectId,
            mrId: widget.mrId,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      Navigator.of(context).pop({
        'success': prId != null,
        'purchase_request_id': prId,
        'shortage_items': shortageItems,
        'total_issued': totalIssued,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prId != null
                ? (totalIssued > 0
                    ? 'Issued available stock and created/updated combined PR.'
                    : 'Created/updated combined PR for shortages.')
                : 'Issuance processed, but failed to create PR.',
          ),
          backgroundColor: prId != null ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(issuanceStateProvider).error ??
                'Failed to process shortages',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
