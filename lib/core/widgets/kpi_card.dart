import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// KPI metric card for dashboards.
/// From UI_SPEC.md: title, value, optional subtitle, trend, and icon.
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? valueColor;
  final String? trend;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.valueColor,
    this.trend,
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
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row with icon
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: AppTextStyles.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Value with optional trend
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.kpiValue.copyWith(
                        color: valueColor ?? AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(width: 8),
                    _TrendChip(trend: trend!),
                  ],
                ],
              ),

              // Subtitle
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String trend;

  const _TrendChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isPositive = trend.startsWith('+');
    final isNegative = trend.startsWith('-');

    final color = isPositive
        ? AppColors.success
        : isNegative
            ? AppColors.danger
            : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        trend,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
