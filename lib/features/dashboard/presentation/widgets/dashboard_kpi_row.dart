import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/kpi_card.dart';

/// Dashboard KPI row — shows key metrics.
/// From DASHBOARD_QUERIES.md — Owner/Admin sees all KPIs.
class DashboardKpiRow extends StatelessWidget {
  const DashboardKpiRow({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: const [
            KpiCard(
              title: 'Active Projects',
              value: '—',
              icon: Icons.engineering_rounded,
              subtitle: 'Loading...',
            ),
            KpiCard(
              title: 'Pending Approvals',
              value: '—',
              icon: Icons.pending_actions_rounded,
              valueColor: AppColors.warning,
              subtitle: 'Loading...',
            ),
            KpiCard(
              title: 'Total Inventory',
              value: '—',
              icon: Icons.inventory_2_outlined,
              subtitle: 'Loading...',
            ),
            KpiCard(
              title: 'Open POs',
              value: '—',
              icon: Icons.local_shipping_outlined,
              subtitle: 'Loading...',
            ),
          ],
        );
      },
    );
  }
}
