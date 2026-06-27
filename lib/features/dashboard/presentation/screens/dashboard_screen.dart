import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/notification_bell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/dashboard_kpi_row.dart';
import '../widgets/dashboard_alerts.dart';

/// Executive dashboard — entry point after login.
/// From DASHBOARD_QUERIES.md: Role-based KPI visibility.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final role = ref.watch(currentUserRoleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            userAsync.when(
              data: (user) => Text(
                user?.fullName ?? 'User',
                style: AppTextStyles.pageTitle,
              ),
              loading: () => const Text('Loading...', style: AppTextStyles.pageTitle),
              error: (_, _) => const Text('User', style: AppTextStyles.pageTitle),
            ),
          ],
        ),
        actions: [
          const NotificationBell(unreadCount: 0),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── KPI Cards ───
            const DashboardKpiRow(),
            const SizedBox(height: 24),

            // ─── Quick Actions ───
            Text(
              'QUICK ACTIONS',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context, role),
            const SizedBox(height: 24),

            // ─── Alerts ───
            const DashboardAlerts(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildQuickActions(BuildContext context, String? role) {
    final actions = <_QuickAction>[];

    // Role-specific quick actions
    if (role == 'admin' || role == 'owner') {
      actions.addAll([
        _QuickAction(
          icon: Icons.pending_actions_rounded,
          label: 'Approvals',
          color: AppColors.warning,
          onTap: () {},
        ),
        _QuickAction(
          icon: Icons.assessment_outlined,
          label: 'Reports',
          color: AppColors.info,
          onTap: () {},
        ),
      ]);
    }

    if (role == 'admin' || role == 'engineer') {
      actions.add(_QuickAction(
        icon: Icons.post_add_rounded,
        label: 'New MR',
        color: AppColors.success,
        onTap: () {},
      ));
    }

    if (role == 'admin' || role == 'store') {
      actions.add(_QuickAction(
        icon: Icons.inventory_outlined,
        label: 'Stock',
        color: AppColors.primary,
        onTap: () {},
      ));
    }

    if (role == 'admin' || role == 'purchase') {
      actions.add(_QuickAction(
        icon: Icons.shopping_cart_outlined,
        label: 'New PO',
        color: AppColors.info,
        onTap: () {},
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.chipText.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
