import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../providers/inventory_provider.dart';

/// Adjustment Form Screen — request new adjustments and view existing ones.
/// BR-004: All adjustments require admin approval before affecting stock.
/// Shows pending/approved/rejected adjustments and a form to create new ones.
class AdjustmentFormScreen extends ConsumerStatefulWidget {
  const AdjustmentFormScreen({super.key});

  @override
  ConsumerState<AdjustmentFormScreen> createState() =>
      _AdjustmentFormScreenState();
}

class _AdjustmentFormScreenState extends ConsumerState<AdjustmentFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Stock Adjustments', style: AppTextStyles.pageTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'New Request'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdjustmentListTab(),
          _AdjustmentFormTab(
            onSubmitted: () {
              _tabController.animateTo(0);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Adjustment List Tab ───

class _AdjustmentListTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustmentsAsync = ref.watch(adjustmentListProvider);

    return adjustmentsAsync.when(
      data: (adjustments) => adjustments.isEmpty
          ? const EmptyState(
              icon: Icons.tune_rounded,
              title: 'No Adjustments',
              subtitle: 'Stock adjustments will appear here',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                ref.invalidate(adjustmentListProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: adjustments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final adj = adjustments[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // ±qty badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: adj.isPositive
                                    ? AppColors.successDim
                                    : AppColors.dangerDim,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${adj.isPositive ? '+' : ''}${_formatQty(adj.adjustmentQty)}',
                                style: TextStyle(
                                  color: adj.isPositive
                                      ? AppColors.success
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                adj.materialName ?? 'Material #${adj.materialId}',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip(status: adj.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          adj.reason,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (adj.warehouseName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.warehouse_outlined,
                                  size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                adj.warehouseName!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (adj.isRejected &&
                            adj.rejectionReason != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerDim,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    adj.rejectionReason!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.danger,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
      loading: () => const LoadingSkeleton(itemCount: 4),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(adjustmentListProvider),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
}

// ─── Adjustment Form Tab ───

class _AdjustmentFormTab extends ConsumerStatefulWidget {
  final VoidCallback? onSubmitted;

  const _AdjustmentFormTab({this.onSubmitted});

  @override
  ConsumerState<_AdjustmentFormTab> createState() =>
      _AdjustmentFormTabState();
}

class _AdjustmentFormTabState extends ConsumerState<_AdjustmentFormTab> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedMaterialId;
  int? _selectedWarehouseId;
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isPositive = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterialId == null || _selectedWarehouseId == null) return;

    setState(() => _isSubmitting = true);

    final qty = double.tryParse(_qtyController.text) ?? 0;
    final params = CreateAdjustmentParams(
      materialId: _selectedMaterialId!,
      warehouseId: _selectedWarehouseId!,
      adjustmentQty: _isPositive ? qty : -qty,
      reason: _reasonController.text.trim(),
    );

    try {
      await ref.read(adjustmentListProvider.notifier).requestAdjustment(params);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Adjustment request submitted for approval'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        // Clear form
        _qtyController.clear();
        _reasonController.clear();
        setState(() {
          _selectedMaterialId = null;
          _selectedWarehouseId = null;
          _isPositive = true;
        });

        widget.onSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Adjustments require admin approval before they affect stock levels.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Material selector ───
            Text('Material *', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            materialsAsync.when(
              data: (materials) => DropdownButtonFormField<int>(
                value: _selectedMaterialId,
                decoration: const InputDecoration(
                  hintText: 'Select material',
                ),
                dropdownColor: AppColors.surfaceAlt,
                items: materials
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            '${m.code ?? ''} ${m.name}'.trim(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMaterialId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading materials'),
            ),
            const SizedBox(height: 16),

            // ─── Warehouse selector ───
            Text('Warehouse *', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            warehousesAsync.when(
              data: (warehouses) => DropdownButtonFormField<int>(
                value: _selectedWarehouseId,
                decoration: const InputDecoration(
                  hintText: 'Select warehouse',
                ),
                dropdownColor: AppColors.surfaceAlt,
                items: warehouses
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWarehouseId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading warehouses'),
            ),
            const SizedBox(height: 16),

            // ─── Adjustment type toggle ───
            Text('Adjustment Type', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPositive = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isPositive
                            ? AppColors.successDim
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isPositive
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: _isPositive
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add Stock',
                            style: TextStyle(
                              color: _isPositive
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPositive = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isPositive
                            ? AppColors.dangerDim
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_isPositive
                              ? AppColors.danger
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                            color: !_isPositive
                                ? AppColors.danger
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Remove Stock',
                            style: TextStyle(
                              color: !_isPositive
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Quantity ───
            Text('Quantity *', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            TextFormField(
              controller: _qtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter quantity',
                prefixIcon: Icon(
                  _isPositive
                      ? Icons.add_rounded
                      : Icons.remove_rounded,
                  color: _isPositive ? AppColors.success : AppColors.danger,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final qty = double.tryParse(v);
                if (qty == null || qty <= 0) {
                  return 'Enter a valid positive quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ─── Reason ───
            Text('Reason *', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Explain why this adjustment is needed...',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Reason is required for adjustments';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ─── Submit Button ───
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit for Approval',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
