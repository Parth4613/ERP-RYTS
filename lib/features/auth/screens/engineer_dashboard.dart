import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/user_profile.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/material_requests/screens/create_mr_screen.dart';
import 'package:gas_company/features/material_requests/screens/mr_list_screen.dart';
import 'package:gas_company/features/material_requests/screens/mr_detail_screen.dart';

class EngineerDashboard extends ConsumerWidget {
  final UserProfile profile;
  const EngineerDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final mrs = ref.watch(myMaterialRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Engineer Dashboard'),
          Text('Welcome, ${profile.name}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () => ref.read(authNotifierProvider.notifier).signOut()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMRScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New MR'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectsProvider);
          ref.invalidate(myMaterialRequestsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Overview'),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
              children: [
                MetricCard(title: 'My Projects', value: projects.whenOrNull(data: (d) => '${d.length}') ?? '—', icon: Icons.business_rounded, color: AppColors.engineerColor),
                MetricCard(title: 'My Requests', value: mrs.whenOrNull(data: (d) => '${d.length}') ?? '—', icon: Icons.receipt_long_rounded, color: AppColors.warning,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MRListScreen(isStore: false)))),
              ],
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'My Projects'),
            projects.when(
              data: (list) {
                if (list.isEmpty) return const EmptyState(icon: Icons.business_outlined, title: 'No Projects Assigned');
                return Column(children: list.map((p) => _projectTile(p)).toList());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 28),
            SectionHeader(title: 'Recent Requests', trailing: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MRListScreen(isStore: false))), child: const Text('View All'))),
            mrs.when(
              data: (list) {
                if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No Material Requests', subtitle: 'Tap + to create your first request');
                return Column(children: list.take(5).map((mr) => _mrTile(context, mr)).toList());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _projectTile(dynamic p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.engineerColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.business_rounded, color: AppColors.engineerColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (p.description != null) Text(p.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        StatusBadge.fromProjectStatus(p.status),
      ]),
    );
  }

  Widget _mrTile(BuildContext context, dynamic mr) {
    final diff = DateTime.now().difference(mr.createdAt);
    final ago = diff.inDays > 0 ? '${diff.inDays}d ago' : diff.inHours > 0 ? '${diff.inHours}h ago' : 'Just now';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MRDetailScreen(mrId: mr.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mr.projectName ?? 'Project', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('${mr.items.length} items • $ago', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          StatusBadge.fromMRStatus(mr.status),
        ]),
      ),
    );
  }
}
