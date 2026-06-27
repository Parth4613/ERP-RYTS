import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/models/stock_transaction_model.dart';

/// Timeline tile widget for a single stock transaction entry.
/// Shows type icon/color, material name, qty change, reference, and timestamp.
class TransactionTile extends StatelessWidget {
  final StockTransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIn = transaction.isInflow;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Type icon ───
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 20),
            ),

            const SizedBox(width: 12),

            // ─── Content ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label + qty
                  Row(
                    children: [
                      Text(
                        transaction.typeLabel,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${isIn ? '+' : ''}${_formatQty(transaction.quantity)}',
                        style: AppTextStyles.body.copyWith(
                          color: isIn ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Material name
                  if (transaction.materialName != null)
                    Text(
                      '${transaction.materialCode ?? ''} ${transaction.materialName!}'
                          .trim(),
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 2),

                  // Reference + warehouse + date
                  Row(
                    children: [
                      if (transaction.referenceType != null) ...[
                        Icon(Icons.link, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '${transaction.referenceType!.toUpperCase()} #${transaction.referenceId ?? '—'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (transaction.warehouseName != null) ...[
                        Icon(
                          Icons.warehouse_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            transaction.warehouseName!,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatDate(transaction.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),

                  // Notes (if any)
                  if (transaction.notes != null &&
                      transaction.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.notes!,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _typeIcon => switch (transaction.transactionType) {
    'stock_in' => Icons.arrow_downward_rounded,
    'stock_out' => Icons.arrow_upward_rounded,
    'return_in' => Icons.undo_rounded,
    'adjustment' => Icons.tune_rounded,
    'transfer_in' => Icons.move_to_inbox_rounded,
    'transfer_out' => Icons.outbox_rounded,
    _ => Icons.swap_vert_rounded,
  };

  Color get _typeColor => switch (transaction.transactionType) {
    'stock_in' => AppColors.success,
    'stock_out' => AppColors.danger,
    'return_in' => AppColors.info,
    'adjustment' => AppColors.warning,
    'transfer_in' => const Color(0xFF8B5CF6),
    'transfer_out' => const Color(0xFF8B5CF6),
    _ => AppColors.textMuted,
  };

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
