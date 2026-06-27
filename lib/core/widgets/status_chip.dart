import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Consistent status chip used across all modules (AD-028).
/// Auto-colored via AppColors.statusColor().
class StatusChip extends StatelessWidget {
  final String status;
  final double? fontSize;

  const StatusChip({
    super.key,
    required this.status,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final dimColor = AppColors.statusDimColor(status);
    final label = status.replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dimColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.chipText.copyWith(
          color: color,
          fontSize: fontSize ?? 11,
        ),
      ),
    );
  }
}
