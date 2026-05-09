import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/purchase.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';
import 'package:gas_company/features/store/widgets/quick_purchase_request_dialog.dart';

class StoreProcurementScreen extends ConsumerStatefulWidget {
  const StoreProcurementScreen({super.key});

  @override
  ConsumerState<StoreProcurementScreen> createState() =>
      _StoreProcurementScreenState();
}

class _StoreProcurementScreenState
    extends ConsumerState<StoreProcurementScreen> {
  final Set<String> _selectedProductIds = {};

  @override
  Widget build(BuildContext context) {
    final pendingPrs = ref.watch(enrichedPurchaseRequestsProvider);
    final aggregateDemand = ref.watch(aggregateDemandProvider);
    final waitingOrders = ref.watch(storeWaitingDeliveryOrdersProvider);
    final frequentItems = ref.watch(frequentShortagesProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Store Procurement'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Low Stock & Demand'),
              Tab(text: 'Purchase Requests'),
              Tab(text: 'Waiting Deliveries'),
              Tab(text: 'Frequent Items'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openQuickPrDialog(),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Create PR'),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Simplified low stock + aggregate demand
            aggregateDemand.when(
              data: _buildLowStockTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error('Unable to load stock: $e'),
            ),
            // Tab 2: PRs with edit/delete
            pendingPrs.when(
              data: _buildPendingPrsTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error('Unable to load PRs: $e'),
            ),
            // Tab 3: Waiting deliveries
            waitingOrders.when(
              data: _buildWaitingDeliveriesTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error('Unable to load deliveries: $e'),
            ),
            // Tab 4: Frequent items
            frequentItems.when(
              data: _buildFrequentItemsTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error('Unable to load frequent items: $e'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Simplified low stock cards ──────────────────────

  Widget _buildLowStockTab(List<Map<String, dynamic>> items) {
    final needsAction = items
        .where(
          (i) =>
              i['stock_level'] == 'critical' ||
              i['stock_level'] == 'low' ||
              (i['total_pending_demand'] as int? ?? 0) > 0,
        )
        .toList();

    if (needsAction.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Stock Is Healthy',
        subtitle: 'No items need procurement right now.',
      );
    }

    return Column(
      children: [
        // Selection bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedProductIds.length} selected',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedProductIds.length == needsAction.length) {
                      _selectedProductIds.clear();
                    } else {
                      _selectedProductIds
                        ..clear()
                        ..addAll(
                          needsAction.map((i) => i['product_id'] as String),
                        );
                    }
                  });
                },
                child: Text(
                  _selectedProductIds.length == needsAction.length
                      ? 'Clear'
                      : 'Select All',
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectedProductIds.isEmpty
                    ? null
                    : () => _createPrFromSelected(needsAction),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Create Combined PR'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: needsAction.length,
              itemBuilder: (context, index) {
                final item = needsAction[index];
                return _SimplifiedStockCard(
                  item: item,
                  selected: _selectedProductIds.contains(item['product_id']),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedProductIds.add(item['product_id'] as String);
                      } else {
                        _selectedProductIds.remove(item['product_id']);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _createPrFromSelected(List<Map<String, dynamic>> allItems) {
    final selected = allItems
        .where((i) => _selectedProductIds.contains(i['product_id']))
        .map(
          (i) => QuickPurchaseRequestItem(
            productId: i['product_id'] as String,
            productName: i['product_name'] as String? ?? 'Product',
            unit: i['unit'] as String? ?? 'pcs',
            quantity: (i['total_pending_demand'] as int? ?? 0) > 0
                ? i['total_pending_demand'] as int
                : (i['minimum_stock_level'] as int? ?? 10),
          ),
        )
        .toList();
    _openQuickPrDialog(selected);
  }

  // ── Tab 2: PR list with edit/delete ────────────────────────

  Widget _buildPendingPrsTab(List<PurchaseRequest> prs) {
    if (prs.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No Purchase Requests',
      );
    }

    final drafts = prs.where((pr) => pr.status == PRStatus.draft).toList();
    final pending = prs.where((pr) => pr.status == PRStatus.pending).toList();
    final others = prs
        .where(
          (pr) => pr.status != PRStatus.draft && pr.status != PRStatus.pending,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (drafts.isNotEmpty) ...[
            const SectionHeader(title: 'Draft PRs'),
            ...drafts.map((pr) => _EditablePRCard(pr: pr, onRefresh: _refresh)),
          ],
          if (pending.isNotEmpty) ...[
            const SectionHeader(title: 'Pending PRs'),
            ...pending.map(
              (pr) => _EditablePRCard(pr: pr, onRefresh: _refresh),
            ),
          ],
          if (others.isNotEmpty) ...[
            const SectionHeader(title: 'Processed PRs'),
            ...others.map((pr) => _ReadOnlyPRCard(pr: pr)),
          ],
        ],
      ),
    );
  }

  // ── Tab 3: Waiting deliveries (unchanged) ──────────────────

  Widget _buildWaitingDeliveriesTab(List<PurchaseOrder> orders) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No Waiting Deliveries',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            _PurchaseOrderCard(order: orders[index]),
      ),
    );
  }

  // ── Tab 4: Frequent items (unchanged) ──────────────────────

  Widget _buildFrequentItemsTab(List<FrequentShortage> shortages) {
    if (shortages.isEmpty) {
      return const EmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No Frequent Shortages',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: shortages.length,
        itemBuilder: (context, index) {
          final item = shortages[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${item.shortageCount} shortages • ${item.totalShortageQuantity} units',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Create Purchase Request',
                  onPressed: () => _openQuickPrDialog([
                    QuickPurchaseRequestItem(
                      productId: item.productId,
                      productName: item.productName,
                      unit: 'units',
                      quantity: item.totalShortageQuantity,
                    ),
                  ]),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _error(String message) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      subtitle: message,
    );
  }

  Future<void> _openQuickPrDialog([
    List<QuickPurchaseRequestItem>? items,
  ]) async {
    await showDialog<String>(
      context: context,
      builder: (_) =>
          QuickPurchaseRequestDialog(initialItems: items ?? const []),
    );
    _refresh();
  }

  void _refresh() {
    ref.invalidate(aggregateDemandProvider);
    ref.invalidate(enrichedPurchaseRequestsProvider);
    ref.invalidate(storePendingPurchaseRequestsProvider);
    ref.invalidate(storeWaitingDeliveryOrdersProvider);
    ref.invalidate(frequentShortagesProvider);
    ref.invalidate(storeDashboardMetricsProvider);
  }
}

// ═══════════════════════════════════════════════════════════════
// Simplified Stock Card — shows ONLY essential info
// ═══════════════════════════════════════════════════════════════

class _SimplifiedStockCard extends StatelessWidget {
  const _SimplifiedStockCard({
    required this.item,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, dynamic> item;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final level = item['stock_level'] as String? ?? 'healthy';
    final statusColor = switch (level) {
      'critical' => AppColors.error,
      'low' => AppColors.warning,
      _ => AppColors.success,
    };
    final statusLabel = switch (level) {
      'critical' => 'Critical',
      'low' => 'Low Stock',
      _ => 'Healthy',
    };
    final currentStock = item['current_stock'] as int? ?? 0;
    final minStock = item['minimum_stock_level'] as int? ?? 0;
    final totalDemand = item['total_pending_demand'] as int? ?? 0;
    final projectCount = item['projects_requesting'] as int? ?? 0;
    final unit = item['unit'] as String? ?? 'pcs';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['product_name'] as String? ?? 'Product',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    StatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 10),
                // Only essential metrics — no reserved/ordered
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metric(
                      'Current Stock',
                      '$currentStock $unit',
                      currentStock == 0 ? AppColors.error : null,
                    ),
                    _metric('Min Required', '$minStock $unit', null),
                    if (totalDemand > 0)
                      _metric(
                        'Total Requested',
                        '$totalDemand $unit',
                        AppColors.warning,
                      ),
                  ],
                ),
                if (projectCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Requested across $projectCount project(s)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color? highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight != null ? highlight.withAlpha(20) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight != null
              ? highlight.withAlpha(60)
              : AppColors.cardBorder,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: highlight ?? AppColors.textSecondary,
          fontSize: 12,
          fontWeight: highlight != null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Editable PR Card — for draft/pending with edit/delete controls
// ═══════════════════════════════════════════════════════════════

class _EditablePRCard extends ConsumerWidget {
  const _EditablePRCard({required this.pr, required this.onRefresh});

  final PurchaseRequest pr;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pr.displayNumber,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (pr.projectName != null)
                Expanded(
                  child: Text(
                    pr.projectName!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                const Spacer(),
              StatusBadge.fromPRStatus(pr.status),
            ],
          ),
          const SizedBox(height: 10),
          // Items with inline quantity display
          ...pr.items.map((item) => _editableItemRow(context, ref, item)),
          if (pr.notes != null && pr.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pr.notes!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _confirmDeletePR(context, ref),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Delete PR',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _editNotes(context, ref),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Edit Notes', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableItemRow(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.productName ?? 'Product'} × ${item.quantityNeeded}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          // Edit quantity
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Edit quantity',
            onPressed: () => _editItemQty(context, ref, item),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          // Remove item
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: AppColors.error,
            ),
            tooltip: 'Remove item',
            onPressed: () => _removeItem(context, ref, item),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Future<void> _editItemQty(
    BuildContext ctx,
    WidgetRef ref,
    PurchaseRequestItem item,
  ) async {
    final ctrl = TextEditingController(text: item.quantityNeeded.toString());
    final newQty = await showDialog<int>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit ${item.productName ?? "Item"}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(ctrl.text) ?? 0;
              Navigator.pop(c, q > 0 ? q : null);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newQty == null || newQty <= 0) return;

    final ok = await ref
        .read(prManagementNotifierProvider.notifier)
        .updateItemQuantity(
          prId: pr.id,
          productId: item.productId,
          quantity: newQty,
        );
    if (ok) onRefresh();
  }

  Future<void> _removeItem(
    BuildContext ctx,
    WidgetRef ref,
    PurchaseRequestItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Item'),
        content: Text('Remove ${item.productName ?? "this item"} from the PR?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(prManagementNotifierProvider.notifier)
        .removeItem(prId: pr.id, productId: item.productId);
    if (ok) onRefresh();
  }

  Future<void> _confirmDeletePR(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Purchase Request'),
        content: Text(
          'Are you sure you want to delete ${pr.displayNumber}?\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(prManagementNotifierProvider.notifier)
        .deletePR(pr.id);
    if (ok && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('${pr.displayNumber} deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      onRefresh();
    } else if (!ok && ctx.mounted) {
      final errorMsg = ref.read(prManagementNotifierProvider).error;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? 'Failed to delete purchase request'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _editNotes(BuildContext ctx, WidgetRef ref) async {
    final ctrl = TextEditingController(text: pr.notes ?? '');
    final newNotes = await showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Urgency, supplier preference, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newNotes == null) return;

    final ok = await ref
        .read(prManagementNotifierProvider.notifier)
        .updateNotes(prId: pr.id, notes: newNotes);
    if (ok) onRefresh();
  }
}

// ═══════════════════════════════════════════════════════════════
// Read-only PR Card — for approved/ordered/delivered
// ═══════════════════════════════════════════════════════════════

class _ReadOnlyPRCard extends StatelessWidget {
  const _ReadOnlyPRCard({required this.pr});
  final PurchaseRequest pr;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                pr.displayNumber,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              StatusBadge.fromPRStatus(pr.status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pr.items
                .map(
                  (item) => Chip(
                    label: Text(
                      '${item.productName ?? "Product"} × ${item.quantityNeeded}',
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Purchase Order Card (unchanged)
// ═══════════════════════════════════════════════════════════════

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({required this.order});
  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.supplierName ?? 'Supplier pending',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${order.items.length} items • ₹${order.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge.fromPOStatus(order.status),
        ],
      ),
    );
  }
}
