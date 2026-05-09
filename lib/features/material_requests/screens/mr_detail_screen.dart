import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/features/store/widgets/quick_purchase_request_dialog.dart';

class MRDetailScreen extends ConsumerStatefulWidget {
  final String mrId;
  const MRDetailScreen({super.key, required this.mrId});
  @override
  ConsumerState<MRDetailScreen> createState() => _MRDetailScreenState();
}

class _MRDetailScreenState extends ConsumerState<MRDetailScreen> {
  final Map<String, TextEditingController> _issueControllers = {};

  @override
  void dispose() {
    for (final c in _issueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mrAsync = ref.watch(materialRequestByIdProvider(widget.mrId));
    final profile = ref.watch(currentProfileProvider);
    final isStore =
        profile.whenOrNull(
          data: (p) => p?.role == UserRole.store || p?.role == UserRole.admin,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Request Details'),
        actions: [
          if (isStore)
            IconButton(
              tooltip: 'Create Purchase Request',
              onPressed: () async {
                final mr = await ref.read(
                  materialRequestByIdProvider(widget.mrId).future,
                );
                if (mr != null && context.mounted) {
                  _showQuickPurchaseRequestDialog(mr);
                }
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
            ),
        ],
      ),
      body: mrAsync.when(
        data: (mr) {
          if (mr == null) return const Center(child: Text('MR not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mr.projectName ?? 'Project',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          StatusBadge.fromMRStatus(mr.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.person_outline,
                        'Engineer',
                        mr.engineerName ?? 'Unknown',
                      ),
                      _infoRow(
                        Icons.calendar_today_outlined,
                        'Created',
                        _formatDate(mr.createdAt),
                      ),
                      if (mr.notes != null)
                        _infoRow(Icons.note_outlined, 'Notes', mr.notes!),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Items
                const SectionHeader(title: 'Requested Items'),
                ...mr.items.map((item) {
                  final key = item.id;
                  _issueControllers.putIfAbsent(
                    key,
                    () => TextEditingController(),
                  );
                  final remaining =
                      item.quantityRequested - item.quantityIssued;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                            Expanded(
                              child: Text(
                                item.productName ?? 'Product',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: item.isFullyIssued
                                  ? 'ISSUED'
                                  : '$remaining remaining',
                              color: item.isFullyIssued
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _chip(
                              'Requested: ${item.quantityRequested}',
                              AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            _chip(
                              'Issued: ${item.quantityIssued}',
                              AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            _chip(
                              item.productUnit ?? 'pcs',
                              AppColors.textMuted,
                            ),
                          ],
                        ),
                        // Issue field (store only, when not fully issued)
                        if (isStore &&
                            !item.isFullyIssued &&
                            ((mr.approvedAt != null) ||
                                mr.status == MRStatus.approved ||
                                mr.status == MRStatus.partiallyIssued ||
                                mr.status == MRStatus.waitingProcurement)) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _issueControllers[key],
                            decoration: InputDecoration(
                              labelText: 'Qty to issue (max $remaining)',
                              isDense: true,
                              suffixText: item.productUnit ?? 'pcs',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // Store actions
                if (isStore) ...[
                  const SizedBox(height: 20),
                  if (mr.status == MRStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateStatus('approved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            child: const Text('Approve & Reserve Stock'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateStatus('rejected'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((mr.approvedAt != null) ||
                      mr.status == MRStatus.approved ||
                      mr.status == MRStatus.partiallyIssued ||
                      mr.status == MRStatus.waitingProcurement) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _issueItems(mr),
                        icon: const Icon(Icons.local_shipping_rounded),
                        label: const Text('Issue Materials'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showQuickPurchaseRequestDialog(mr),
                        icon: const Icon(Icons.request_quote_rounded),
                        label: const Text(
                          'Create Purchase Request for Shortages',
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  Future<void> _updateStatus(String status) async {
    await ref
        .read(materialRequestNotifierProvider.notifier)
        .updateMRStatus(mrId: widget.mrId, status: status);
    ref.invalidate(materialRequestByIdProvider(widget.mrId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $status'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _issueItems(dynamic mr) async {
    final items = <Map<String, dynamic>>[];
    for (final item in mr.items) {
      final ctrl = _issueControllers[item.id];
      final qty = int.tryParse(ctrl?.text ?? '') ?? 0;
      if (qty > 0) {
        final max = item.quantityRequested - item.quantityIssued;
        items.add({
          'id': item.id,
          'product_id': item.productId,
          'quantity_to_issue': qty > max ? max : qty,
          'current_issued': item.quantityIssued,
          'total_requested': item.quantityRequested,
        });
      }
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter quantities to issue'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    await ref
        .read(materialRequestNotifierProvider.notifier)
        .issueItems(mrId: widget.mrId, issuedItems: items);
    ref.invalidate(materialRequestByIdProvider(widget.mrId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Items issued successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _showQuickPurchaseRequestDialog(dynamic mr) async {
    final items = <QuickPurchaseRequestItem>[];
    for (final item in mr.items) {
      final remaining = item.quantityRequested - item.quantityIssued;
      if (remaining > 0) {
        items.add(
          QuickPurchaseRequestItem(
            productId: item.productId,
            productName: item.productName ?? 'Product',
            unit: item.productUnit ?? 'pcs',
            quantity: remaining,
            projectId: mr.projectId,
            projectName: mr.projectName,
            mrId: mr.id,
            requiredDate: DateTime.now().add(const Duration(days: 7)),
          ),
        );
      }
    }

    await showDialog<String>(
      context: context,
      builder: (_) => QuickPurchaseRequestDialog(
        title: 'Create PR for MR Shortage',
        initialItems: items,
        projectId: mr.projectId,
        mrId: mr.id,
      ),
    );
  }
}
