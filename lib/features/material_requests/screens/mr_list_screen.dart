import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';
import 'package:gas_company/features/material_requests/screens/mr_detail_screen.dart';

class MRListScreen extends ConsumerWidget {
  final bool isStore;
  const MRListScreen({super.key, required this.isStore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mrs = ref.watch(isStore ? allMaterialRequestsProvider : myMaterialRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isStore ? 'All Material Requests' : 'My Material Requests')),
      body: mrs.when(
        data: (list) {
          if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No Material Requests');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(isStore ? allMaterialRequestsProvider : myMaterialRequestsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: list.length,
              itemBuilder: (ctx, i) {
                final mr = list[i];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => MRDetailScreen(mrId: mr.id)));
                    ref.invalidate(isStore ? allMaterialRequestsProvider : myMaterialRequestsProvider);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(mr.projectName ?? 'Project', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        StatusBadge.fromMRStatus(mr.status),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
                        Text(mr.engineerName ?? 'Unknown', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(width: 16),
                        const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
                        Text('${mr.items.length} items', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                      if (mr.notes != null && mr.notes!.isNotEmpty) ...[const SizedBox(height: 6),
                        Text(mr.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)],
                    ]),
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
