import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/purchase.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/purchase/providers/purchase_provider.dart';
import 'package:gas_company/features/purchase/screens/create_po_screen.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';

class PRListScreen extends ConsumerWidget {
  const PRListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the enriched view that includes project, MR, and cost data.
    // Falls back to the basic provider if enriched view fails.
    final prs = ref.watch(enrichedPurchaseRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(enrichedPurchaseRequestsProvider);
              ref.invalidate(purchaseRequestsProvider);
            },
          ),
        ],
      ),
      body: prs.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'No Purchase Requests',
              subtitle: 'Purchase requests from the Store department will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(enrichedPurchaseRequestsProvider);
              ref.invalidate(purchaseRequestsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _PRCard(
                pr: list[i],
                onTap: list[i].status == PRStatus.pending
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatePOScreen(
                              prId: list[i].id,
                              items: list[i].items,
                            ),
                          ),
                        );
                        ref.invalidate(enrichedPurchaseRequestsProvider);
                        ref.invalidate(purchaseRequestsProvider);
                      }
                    : null,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $e', style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(enrichedPurchaseRequestsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PRCard extends StatelessWidget {
  const _PRCard({required this.pr, this.onTap});

  final PurchaseRequest pr;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(pr.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pr.status == PRStatus.pending
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with PR number + status
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pr.displayNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  StatusBadge.fromPRStatus(pr.status),
                ],
              ),
            ),

            // Body: project, MR, items, cost
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project + MR context
                  if (pr.projectName != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.business_rounded,
                            size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pr.projectName!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Metadata row
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _metaChip(
                        Icons.inventory_2_outlined,
                        '${pr.items.length} items',
                      ),
                      _metaChip(
                        Icons.calendar_today_outlined,
                        _formatDate(pr.createdAt),
                      ),
                      if (pr.createdFromMrId != null)
                        _metaChip(
                          Icons.description_outlined,
                          'MR Linked',
                        ),
                      if (pr.source != null)
                        _metaChip(
                          Icons.source_outlined,
                          _sourceLabel(pr.source!),
                        ),
                      if (pr.requiredDate != null)
                        _metaChip(
                          Icons.event_available_outlined,
                          'Due: ${pr.requiredDate}',
                        ),
                    ],
                  ),

                  if (pr.notes != null && pr.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      pr.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Items chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pr.items.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          '${item.productName ?? 'Product'} × ${item.quantityNeeded}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Estimated cost
                  if (pr.estimatedCost > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee_rounded,
                              size: 15, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Est. Cost: ₹${NumberFormat('#,##0.00').format(pr.estimatedCost)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tap hint for pending PRs
                  if (pr.status == PRStatus.pending) ...[
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tap to convert to Purchase Order →',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  String _sourceLabel(String source) {
    return switch (source) {
      'auto_shortage' => 'Auto',
      'auto_combined' => 'Auto-Combined',
      'store_combined' => 'Store',
      'store_quick' => 'Quick PR',
      'manual' => 'Manual',
      _ => source,
    };
  }

  Color _statusColor(PRStatus status) {
    return switch (status) {
      PRStatus.draft => AppColors.textMuted,
      PRStatus.pending => AppColors.warning,
      PRStatus.approved => AppColors.success,
      PRStatus.ordered => AppColors.info,
      PRStatus.delivered => AppColors.success,
      PRStatus.converted => AppColors.primary,
      PRStatus.rejected => AppColors.error,
    };
  }
}
