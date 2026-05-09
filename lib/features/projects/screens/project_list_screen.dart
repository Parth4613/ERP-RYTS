import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';
import 'package:gas_company/features/projects/screens/create_project_screen.dart';
import 'package:gas_company/features/projects/screens/edit_project_screen.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen()));
          ref.invalidate(projectsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: projects.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.business_outlined,
              title: 'No Projects',
              subtitle: 'Tap + to create a project',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(projectsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final p = list[i];
                return GestureDetector(
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => EditProjectScreen(project: p)),
                    );
                    if (updated == true) {
                      ref.invalidate(projectsProvider);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge.fromProjectStatus(p.status),
                          ],
                        ),
                        if (p.description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            p.description!,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.engineering_rounded, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.engineerName ?? 'Unassigned',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.engineerName != null
                                      ? AppColors.textSecondary
                                      : AppColors.warning,
                                  fontWeight: p.engineerName == null ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ),
                            const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            const Text(
                              'Tap to edit',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
