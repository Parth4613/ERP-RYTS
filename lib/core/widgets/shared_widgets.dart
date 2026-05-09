import 'package:flutter/material.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/utils/enums.dart';

/// Status badge widget with color coding
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
  });

  factory StatusBadge.fromMRStatus(MRStatus status) {
    return StatusBadge(label: status.displayName, color: _mrColor(status));
  }

  factory StatusBadge.fromPRStatus(PRStatus status) {
    return StatusBadge(label: status.displayName, color: _prColor(status));
  }

  factory StatusBadge.fromPOStatus(POStatus status) {
    return StatusBadge(label: status.displayName, color: _poColor(status));
  }

  factory StatusBadge.fromProjectStatus(ProjectStatus status) {
    return StatusBadge(label: status.displayName, color: _projectColor(status));
  }

  static Color _mrColor(MRStatus status) {
    switch (status) {
      case MRStatus.pending:
        return AppColors.warning;
      case MRStatus.approved:
        return AppColors.info;
      case MRStatus.fullyIssued:
        return AppColors.success;
      case MRStatus.partiallyIssued:
        return AppColors.warning;
      case MRStatus.waitingProcurement:
        return AppColors.error;
      case MRStatus.completed:
        return AppColors.success;
      case MRStatus.rejected:
        return AppColors.error;
    }
  }

  static Color _prColor(PRStatus status) {
    switch (status) {
      case PRStatus.draft:
        return AppColors.textMuted;
      case PRStatus.pending:
        return AppColors.warning;
      case PRStatus.approved:
        return AppColors.info;
      case PRStatus.ordered:
        return AppColors.warning;
      case PRStatus.delivered:
        return AppColors.success;
      case PRStatus.converted:
        return AppColors.success;
      case PRStatus.rejected:
        return AppColors.error;
    }
  }

  static Color _poColor(POStatus status) {
    switch (status) {
      case POStatus.draft:
        return AppColors.textMuted;
      case POStatus.ordered:
        return AppColors.info;
      case POStatus.delivered:
        return AppColors.success;
    }
  }

  static Color _projectColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active:
        return AppColors.success;
      case ProjectStatus.completed:
        return AppColors.info;
      case ProjectStatus.on_hold:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Metric card for dashboards
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

/// Section header widget
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
