import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';

class StockHistoryDialog extends ConsumerStatefulWidget {
  final String productId;

  const StockHistoryDialog({super.key, required this.productId});

  @override
  ConsumerState<StockHistoryDialog> createState() => _StockHistoryDialogState();
}

class _StockHistoryDialogState extends ConsumerState<StockHistoryDialog> {
  MovementType? _selectedMovementType;

  @override
  Widget build(BuildContext context) {
    final stockHistoryAsync = ref.watch(stockHistoryProvider(
      StockHistoryParams(
        productId: widget.productId,
        limit: 50,
        movementType: _selectedMovementType,
      ),
    ));

    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Stock History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Filter chips
            Container(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    _buildFilterChip('Inward', MovementType.inward),
                    _buildFilterChip('Outward', MovementType.outward),
                  ],
                ),
              ),
            ),

            // History list
            Expanded(
              child: stockHistoryAsync.when(
                data: (history) => _buildHistoryList(history),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => _buildErrorWidget('Failed to load history: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, MovementType? value) {
    final isSelected = _selectedMovementType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedMovementType = value;
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildHistoryList(List<StockHistory> history) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No stock history available',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return _buildHistoryItem(item);
      },
    );
  }

  Widget _buildHistoryItem(StockHistory item) {
    final isInward = item.movementType == MovementType.inward;
    final color = isInward ? AppColors.success : AppColors.error;
    final icon = isInward ? Icons.arrow_downward : Icons.arrow_upward;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInward ? 'Stock Added' : 'Stock Issued',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Quantity: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${item.previousQuantity} → ${item.newQuantity}',
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
                  DateFormat('MMM dd, HH:mm').format(item.performedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getReferenceTypeText(item.referenceType),
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getReferenceTypeText(ReferenceType type) {
    switch (type) {
      case ReferenceType.issuance:
        return 'Issuance';
      case ReferenceType.purchaseOrder:
        return 'PO';
      case ReferenceType.adjustment:
        return 'Adjust';
      case ReferenceType.initial:
        return 'Initial';
    }
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
