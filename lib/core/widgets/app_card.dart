import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Consistent elevated card used across all modules.
/// From UI_SPEC.md reusable components.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderColor,
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
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? AppColors.border,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
