import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../providers/inventory_provider.dart';
import '../widgets/transaction_tile.dart';

/// Transaction History Screen — timeline of all stock movements.
/// Filters: material, warehouse, type, date range.
/// UI-003: Loading, empty, error states.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Transaction History', style: AppTextStyles.pageTitle),
        actions: [
          if (filter.materialId != null ||
              filter.warehouseId != null ||
              filter.type != null ||
              filter.fromDate != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off_rounded),
              tooltip: 'Clear filters',
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).state =
                    const TransactionFilter();
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Active Filter Chips ───
          if (filter.type != null ||
              filter.fromDate != null ||
              filter.warehouseId != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (filter.type != null)
                      _ActiveFilterChip(
                        label: _typeLabel(filter.type!),
                        onRemove: () {
                          ref.read(transactionFilterProvider.notifier).state =
                              filter.copyWith(clearType: true);
                        },
                      ),
                    if (filter.fromDate != null)
                      _ActiveFilterChip(
                        label:
                            'From ${DateFormat('dd MMM').format(filter.fromDate!)}',
                        onRemove: () {
                          ref.read(transactionFilterProvider.notifier).state =
                              filter.copyWith(clearDates: true);
                        },
                      ),
                  ],
                ),
              ),
            ),

          // ─── Transaction List ───
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) => transactions.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Transactions',
                      subtitle: 'Stock movements will appear here',
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: () async {
                        ref.invalidate(transactionHistoryProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];

                          // Date separator
                          final showDateHeader = index == 0 ||
                              !_isSameDay(
                                transactions[index - 1].createdAt,
                                tx.createdAt,
                              );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 4),
                                  child: Text(
                                    _formatDateHeader(tx.createdAt),
                                    style: AppTextStyles.sectionTitle,
                                  ),
                                ),
                              TransactionTile(transaction: tx),
                            ],
                          );
                        },
                      ),
                    ),
              loading: () => const LoadingSkeleton(itemCount: 8),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(transactionHistoryProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Filter Transactions', style: AppTextStyles.pageTitle),
              const SizedBox(height: 16),

              // Transaction type filter
              Text('Transaction Type', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeFilterChip('stock_in', 'Stock In', Icons.arrow_downward_rounded, AppColors.success),
                  _typeFilterChip('stock_out', 'Stock Out', Icons.arrow_upward_rounded, AppColors.danger),
                  _typeFilterChip('return_in', 'Return', Icons.undo_rounded, AppColors.info),
                  _typeFilterChip('adjustment', 'Adjustment', Icons.tune_rounded, AppColors.warning),
                  _typeFilterChip('transfer_in', 'Transfer In', Icons.move_to_inbox_rounded, const Color(0xFF8B5CF6)),
                  _typeFilterChip('transfer_out', 'Transfer Out', Icons.outbox_rounded, const Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 16),

              // Date range
              Text('Date Range', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dateChip('Today', 0),
                  _dateChip('Last 7 Days', 7),
                  _dateChip('Last 30 Days', 30),
                  _dateChip('Last 90 Days', 90),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _typeFilterChip(
      String type, String label, IconData icon, Color color) {
    final current = ref.read(transactionFilterProvider);
    final selected = current.type == type;

    return GestureDetector(
      onTap: () {
        if (selected) {
          ref.read(transactionFilterProvider.notifier).state =
              current.copyWith(clearType: true);
        } else {
          ref.read(transactionFilterProvider.notifier).state =
              current.copyWith(type: type);
        }
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String label, int daysBack) {
    return GestureDetector(
      onTap: () {
        final current = ref.read(transactionFilterProvider);
        ref.read(transactionFilterProvider.notifier).state = current.copyWith(
          fromDate:
              daysBack == 0 ? DateTime.now().copyWith(hour: 0, minute: 0) :
              DateTime.now().subtract(Duration(days: daysBack)),
          toDate: DateTime.now(),
        );
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'TODAY';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  }

  String _typeLabel(String type) => switch (type) {
        'stock_in' => 'Stock In',
        'stock_out' => 'Stock Out',
        'return_in' => 'Return',
        'adjustment' => 'Adjustment',
        'transfer_in' => 'Transfer In',
        'transfer_out' => 'Transfer Out',
        _ => type,
      };
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
