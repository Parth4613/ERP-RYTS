import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';
import 'package:gas_company/features/store/widgets/issuance_item_card.dart';
import 'package:gas_company/features/store/widgets/quick_purchase_request_dialog.dart';
import 'package:gas_company/features/store/widgets/shortage_dialog.dart';
import 'package:gas_company/features/store/widgets/pdf_receipt_dialog.dart';

class StoreMRDetailScreen extends ConsumerStatefulWidget {
  final String mrId;
  final String projectName;
  final String engineerName;
  final DateTime createdAt;

  const StoreMRDetailScreen({
    super.key,
    required this.mrId,
    required this.projectName,
    required this.engineerName,
    required this.createdAt,
  });

  @override
  ConsumerState<StoreMRDetailScreen> createState() =>
      _StoreMRDetailScreenState();
}

class _StoreMRDetailScreenState extends ConsumerState<StoreMRDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final pendingItemsAsync = ref.watch(
      pendingMRItemsForMRProvider(widget.mrId),
    );
    final issuanceState = ref.watch(issuanceStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Material Request Details'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showQuickPurchaseRequestDialog(),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            tooltip: 'Create Purchase Request',
          ),
          if (issuanceState.shortageItems.isNotEmpty)
            IconButton(
              onPressed: () => _showShortageDialog(),
              icon: const Icon(Icons.shopping_cart, color: AppColors.warning),
              tooltip: 'Combined Shortage PR',
            ),
        ],
      ),
      body: pendingItemsAsync.when(
        data: (items) => _buildContent(items, issuanceState),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) =>
            _buildErrorWidget('Failed to load MR items: $error'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShortageDialog(),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_checkout_rounded),
        label: const Text('Generate Combined PR'),
      ),
    );
  }

  Widget _buildContent(
    List<PendingMRItemWithStock> items,
    IssuanceState issuanceState,
  ) {
    return Column(
      children: [
        // MR Header
        _buildMRHeader(),

        // Items List
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: AppColors.success,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All items have been issued',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final canIssueFromStatus =
                        item.mrStatus == 'approved' ||
                        item.mrStatus == 'partially_issued' ||
                        item.mrStatus == 'partial' ||
                        item.mrStatus == 'waiting_procurement';
                    return IssuanceItemCard(
                      item: item,
                      onIssue: (quantity) =>
                          _confirmAndIssueMaterial(item, quantity),
                      onCreatePR: () => _createPurchaseRequestForItem(item),
                      isIssuing: issuanceState.isIssuing,
                      issuanceEnabled: canIssueFromStatus,
                    );
                  },
                ),
        ),

        // Bottom Action Bar
        if (items.isNotEmpty) _buildBottomBar(items, issuanceState),
      ],
    );
  }

  Widget _buildMRHeader() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.projectName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.engineerName,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, yyyy').format(widget.createdAt),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    List<PendingMRItemWithStock> items,
    IssuanceState issuanceState,
  ) {
    final mrStatus = items.isEmpty ? 'pending' : items.first.mrStatus;
    final isPendingApproval = mrStatus == 'pending';
    final canIssueFromStatus =
        mrStatus == 'approved' ||
        mrStatus == 'partially_issued' ||
        mrStatus == 'partial' ||
        mrStatus == 'waiting_procurement';
    final canIssueAll = items.every(
      (item) => item.issuanceStatus == IssuanceStatus.canFullyIssue,
    );
    final canIssuePartial = items.any(
      (item) => item.issuanceStatus == IssuanceStatus.canPartiallyIssue,
    );
    final outOfStockItems = items
        .where((item) => item.issuanceStatus == IssuanceStatus.outOfStock)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPendingApproval) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: issuanceState.isIssuing
                        ? null
                        : () => _approveCurrentRequest(),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Approve & Reserve Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (outOfStockItems > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$outOfStockItems item(s) out of stock',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showShortageDialog(),
                    icon: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 16,
                    ),
                    label: const Text('Generate Combined PR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (canIssueFromStatus)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: canIssueAll && !issuanceState.isIssuing
                        ? () => _issueAllItems(items)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textSecondary
                          .withOpacity(0.3),
                    ),
                    child: issuanceState.isIssuing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Issue All'),
                  ),
                ),
                if (canIssuePartial && !canIssueAll) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !issuanceState.isIssuing
                          ? () => _issueAvailableItems(items)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Issue Available'),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _approveCurrentRequest() async {
    await ref
        .read(materialRequestNotifierProvider.notifier)
        .updateMRStatus(mrId: widget.mrId, status: 'approved');
    ref.invalidate(pendingMRItemsForMRProvider(widget.mrId));
    ref.invalidate(pendingMRItemsWithStockProvider);
    ref.invalidate(storeDashboardMetricsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Material request approved and stock reserved'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _confirmAndIssueMaterial(
    PendingMRItemWithStock item,
    int requestedQuantity,
  ) async {
    final hasStock = item.stockAvailable > 0;
    final issueQuantity = hasStock
        ? (requestedQuantity > item.stockAvailable
              ? item.stockAvailable
              : requestedQuantity)
        : 0;
    final shortageQty = item.quantityPending - issueQuantity;
    final isPartial = hasStock && shortageQty > 0;
    // Fully available path is handled in the final confirmation branch below.

    // ── Case 1: Fully out of stock ─────────────────────────────
    if (!hasStock) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Stock Unavailable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('Product', item.productName),
              _confirmRow('Requested', '${item.quantityPending} ${item.unit}'),
              _confirmRow(
                'Available',
                '0 ${item.unit}',
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This item is out of stock. No material can be issued.',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Would you like to create a Purchase Request for this shortage?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'create_pr'),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Create Purchase Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (action == 'create_pr') {
        await _showQuickPurchaseRequestDialog([_quickItemFromPending(item)]);
      }
      return;
    }

    // ── Case 2: Partial stock available ────────────────────────
    if (isPartial) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Insufficient Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('Product', item.productName),
              _confirmRow('Requested', '${item.quantityPending} ${item.unit}'),
              _confirmRow(
                'Available',
                '$issueQuantity ${item.unit}',
                color: AppColors.warning,
              ),
              _confirmRow(
                'Shortage',
                '$shortageQty ${item.unit}',
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withAlpha(60)),
                ),
                child: Text(
                  'Only $issueQuantity ${item.unit} can be issued. '
                  'Remaining $shortageQty ${item.unit} is unavailable.',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'issue_only'),
              child: const Text('Issue Available Only'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'issue_and_pr'),
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Issue & Create PR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (action == 'issue_and_pr') {
        await _issueMaterial(item, issueQuantity);
        if (mounted) {
          await _showQuickPurchaseRequestDialog([_quickItemFromPending(item)]);
        }
      } else if (action == 'issue_only') {
        await _issueMaterial(item, issueQuantity);
      }
      return;
    }

    // ── Case 3: Fully available — normal confirmation ──────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Issuance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Product', item.productName),
            _confirmRow('Quantity to issue', '$issueQuantity ${item.unit}'),
            _confirmRow(
              'Available stock',
              '${item.stockAvailable} ${item.unit}',
            ),
            _confirmRow(
              'After issuance',
              '${item.stockAvailable - issueQuantity} ${item.unit}',
              color: AppColors.success,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('Issue Material'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _issueMaterial(item, issueQuantity);
    }
  }

  Widget _confirmRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _issueMaterial(PendingMRItemWithStock item, int quantity) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final result = await ref
        .read(issuanceStateProvider.notifier)
        .issueMaterials(
          mrId: item.mrId,
          mrItemId: item.mrItemId,
          projectId: item.projectId,
          productId: item.productId,
          quantityToIssue: quantity,
          issuedBy: currentUserId,
        );

    // Always refresh on any outcome.
    ref.invalidate(pendingMRItemsForMRProvider(widget.mrId));
    ref.invalidate(pendingMRItemsWithStockProvider);
    ref.invalidate(storeDashboardMetricsProvider);
    ref.invalidate(frequentShortagesProvider);

    if (!mounted) return;

    if (result.success && result.quantityIssued > 0) {
      // ✅ Issuance succeeded
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Material issued successfully — ${result.quantityIssued} ${item.unit} of ${item.productName}',
          ),
          backgroundColor: AppColors.success,
          action: result.issuanceLog != null
              ? SnackBarAction(
                  label: 'View Receipt',
                  textColor: Colors.white,
                  onPressed: () => _showReceiptDialog(result.issuanceLog!),
                )
              : null,
        ),
      );
    } else if (!result.success) {
      // ❌ Issuance failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error ?? 'Failed to issue material. Please try again.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _issueAllItems(List<PendingMRItemWithStock> items) async {
    final issuable = items
        .where((item) => item.issuanceStatus == IssuanceStatus.canFullyIssue)
        .toList();
    if (await _confirmBulkIssuance(issuable, 'Issue All') != true) {
      return;
    }
    for (final item in issuable) {
      await _issueMaterial(item, item.quantityPending);
    }
  }

  Future<void> _issueAvailableItems(List<PendingMRItemWithStock> items) async {
    final issuable = items
        .where(
          (item) =>
              item.issuanceStatus == IssuanceStatus.canFullyIssue ||
              item.issuanceStatus == IssuanceStatus.canPartiallyIssue,
        )
        .toList();
    if (await _confirmBulkIssuance(issuable, 'Issue Available') != true) {
      return;
    }
    for (final item in issuable) {
      final quantityToIssue = item.stockAvailable < item.quantityPending
          ? item.stockAvailable
          : item.quantityPending;
      await _issueMaterial(item, quantityToIssue);
    }
  }

  Future<bool?> _confirmBulkIssuance(
    List<PendingMRItemWithStock> items,
    String title,
  ) {
    final totalRequested = items.fold<int>(
      0,
      (sum, item) => sum + item.quantityPending,
    );
    final totalIssuing = items.fold<int>(0, (sum, item) {
      final issueQty = item.stockAvailable < item.quantityPending
          ? item.stockAvailable
          : item.quantityPending;
      return sum + issueQty;
    });
    final totalRemaining = totalRequested - totalIssuing;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Items', items.length.toString()),
            _confirmRow('Requested pending', totalRequested.toString()),
            _confirmRow('Quantity to issue', totalIssuing.toString()),
            _confirmRow(
              'Remaining balance',
              totalRemaining.toString(),
              color: totalRemaining > 0 ? AppColors.warning : AppColors.success,
            ),
            if (totalRemaining > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'Only available stock will be issued. Shortages will require a manual Purchase Request.',
                style: TextStyle(color: AppColors.warning),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: totalIssuing <= 0
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShortageDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) =>
          ShortageDialog(mrId: widget.mrId, projectName: widget.projectName),
    );

    if (result != null && mounted) {
      // Refresh all relevant data after combined PR creation.
      ref.invalidate(pendingMRItemsForMRProvider(widget.mrId));
      ref.invalidate(pendingMRItemsWithStockProvider);
      ref.invalidate(storeDashboardMetricsProvider);
      ref.invalidate(storePendingPurchaseRequestsProvider);
      ref.invalidate(enrichedPurchaseRequestsProvider);
      ref.invalidate(frequentShortagesProvider);
    }
  }

  Future<void> _showQuickPurchaseRequestDialog([
    List<QuickPurchaseRequestItem>? items,
  ]) async {
    final pendingItems = await ref.read(
      pendingMRItemsForMRProvider(widget.mrId).future,
    );
    final shortageItems =
        items ??
        pendingItems
            .where(
              (item) =>
                  item.stockAvailable < item.quantityPending ||
                  item.issuanceStatus == IssuanceStatus.outOfStock,
            )
            .map(_quickItemFromPending)
            .toList();

    if (!mounted) return;
    await showDialog<String>(
      context: context,
      builder: (_) => QuickPurchaseRequestDialog(
        title: 'Create PR for MR Shortage',
        initialItems: shortageItems,
        mrId: widget.mrId,
        projectId: pendingItems.isEmpty ? null : pendingItems.first.projectId,
      ),
    );
    if (!mounted) return;
    ref.invalidate(pendingMRItemsForMRProvider(widget.mrId));
    ref.invalidate(pendingMRItemsWithStockProvider);
    ref.invalidate(storePendingPurchaseRequestsProvider);
  }

  QuickPurchaseRequestItem _quickItemFromPending(PendingMRItemWithStock item) {
    final remaining = item.quantityPending - item.stockAvailable;
    return QuickPurchaseRequestItem(
      productId: item.productId,
      productName: item.productName,
      unit: item.unit,
      quantity: remaining > 0 ? remaining : item.quantityPending,
      projectId: item.projectId,
      projectName: item.projectName,
      mrId: item.mrId,
      requiredDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  Future<void> _createPurchaseRequestForItem(
    PendingMRItemWithStock item,
  ) async {
    final quantity = item.quantityPending - item.stockAvailable;
    if (quantity <= 0) return;
    await _showQuickPurchaseRequestDialog([_quickItemFromPending(item)]);
  }

  void _showReceiptDialog(IssuanceLog issuanceLog) {
    showDialog(
      context: context,
      builder: (context) => PDFReceiptDialog(issuanceLog: issuanceLog),
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
                ref.invalidate(pendingMRItemsForMRProvider(widget.mrId));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
