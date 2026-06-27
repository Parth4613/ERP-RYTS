import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/models/inventory_summary_model.dart';

/// Card widget displaying a single material's stock level.
/// Shows material name, code, category, qty/reserved/available, and status chip.
class StockLevelCard extends StatelessWidget {
  final InventorySummaryModel item;
  final VoidCallback? onTap;

  const StockLevelCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isCritical && !item.isInStock
                  ? AppColors.danger.withValues(alpha: 0.5)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Top row: name + status chip ───
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (item.code != null) ...[
                              Text(
                                item.code!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (item.categoryName != null)
                              Flexible(
                                child: Text(
                                  item.categoryName!,
                                  style: AppTextStyles.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: item.stockStatus),
                ],
              ),

              const SizedBox(height: 12),

              // ─── Stock quantity bar ───
              _buildQuantityBar(),

              const SizedBox(height: 12),

              // ─── Bottom row: qty details ───
              Row(
                children: [
                  _buildQtyInfo('Available', item.availableQty, AppColors.success),
                  const SizedBox(width: 16),
                  _buildQtyInfo('Reserved', item.reservedQty, AppColors.warning),
                  const SizedBox(width: 16),
                  _buildQtyInfo('Total', item.quantity, AppColors.textPrimary),
                  const Spacer(),
                  // UOM badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      item.uom,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Critical badge ───
              if (item.isCritical) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Critical Material',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityBar() {
    final total = item.quantity;
    final available = item.availableQty;
    final reserved = item.reservedQty;

    // Avoid division by zero
    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: AppColors.dangerDim,
        ),
      );
    }

    final availableFraction = (available / total).clamp(0.0, 1.0);
    final reservedFraction = (reserved / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: AppColors.surface,
        child: Row(
          children: [
            Flexible(
              flex: (availableFraction * 100).round().clamp(0, 100),
              child: Container(color: AppColors.success),
            ),
            Flexible(
              flex: (reservedFraction * 100).round().clamp(0, 100),
              child: Container(color: AppColors.warning),
            ),
            Flexible(
              flex: ((1 - availableFraction - reservedFraction) * 100)
                  .round()
                  .clamp(0, 100),
              child: Container(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyInfo(String label, double qty, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _formatQty(qty),
          style: AppTextStyles.body.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
}
