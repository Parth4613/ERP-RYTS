import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../providers/inventory_provider.dart';
import '../widgets/stock_level_card.dart';

/// Stock List Screen — filterable list of all materials with stock levels.
/// Filters: search, warehouse, category, stock status.
/// UI-003: Loading, empty, error states. UI-004: Search + filter + sort.
class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Sync search controller with current filter
    final currentFilter = ref.read(stockFilterProvider);
    _searchController.text = currentFilter.search ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final current = ref.read(stockFilterProvider);
      ref.read(stockFilterProvider.notifier).state = current.copyWith(
        search: value.isEmpty ? null : value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockLevelsProvider);
    final filter = ref.watch(stockFilterProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Stock Levels', style: AppTextStyles.pageTitle),
        actions: [
          if (filter.warehouseId != null ||
              filter.categoryId != null ||
              filter.stockStatus != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off_rounded),
              tooltip: 'Clear filters',
              onPressed: () {
                ref.read(stockFilterProvider.notifier).state = StockFilter(
                  search: filter.search,
                );
                _searchController.text = filter.search ?? '';
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ───
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                isDense: true,
              ),
            ),
          ),

          // ─── Filter Chips ───
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Stock status chips
                  _FilterChip(
                    label: 'All',
                    selected: filter.stockStatus == null,
                    onTap: () {
                      ref.read(stockFilterProvider.notifier).state = filter
                          .copyWith(clearStatus: true);
                    },
                  ),
                  _FilterChip(
                    label: 'In Stock',
                    selected: filter.stockStatus == 'in_stock',
                    color: AppColors.success,
                    onTap: () {
                      ref.read(stockFilterProvider.notifier).state = filter
                          .copyWith(stockStatus: 'in_stock');
                    },
                  ),
                  _FilterChip(
                    label: 'Low Stock',
                    selected: filter.stockStatus == 'low_stock',
                    color: AppColors.warning,
                    onTap: () {
                      ref.read(stockFilterProvider.notifier).state = filter
                          .copyWith(stockStatus: 'low_stock');
                    },
                  ),
                  _FilterChip(
                    label: 'Out of Stock',
                    selected: filter.stockStatus == 'out_of_stock',
                    color: AppColors.danger,
                    onTap: () {
                      ref.read(stockFilterProvider.notifier).state = filter
                          .copyWith(stockStatus: 'out_of_stock');
                    },
                  ),

                  const SizedBox(width: 8),

                  // Warehouse dropdown
                  warehousesAsync.when(
                    data: (warehouses) => _DropdownChip(
                      label: filter.warehouseId != null
                          ? warehouses
                                    .where((w) => w.id == filter.warehouseId)
                                    .firstOrNull
                                    ?.name ??
                                'Warehouse'
                          : 'Warehouse',
                      selected: filter.warehouseId != null,
                      onTap: () => _showWarehousePicker(context, ref),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(width: 4),

                  // Category dropdown
                  categoriesAsync.when(
                    data: (categories) => _DropdownChip(
                      label: filter.categoryId != null
                          ? categories
                                    .where((c) => c.id == filter.categoryId)
                                    .firstOrNull
                                    ?.name ??
                                'Category'
                          : 'Category',
                      selected: filter.categoryId != null,
                      onTap: () => _showCategoryPicker(context, ref),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ─── Result count ───
          stockAsync.when(
            data: (items) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${items.length} item${items.length != 1 ? 's' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ─── List Content ───
          Expanded(
            child: stockAsync.when(
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No Items Found',
                      subtitle: 'Try adjusting your filters or search query',
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: () async {
                        ref.invalidate(stockLevelsProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return StockLevelCard(
                            item: item,
                            onTap: () => _showMaterialDetail(context, item),
                          );
                        },
                      ),
                    ),
              loading: () => const LoadingSkeleton(itemCount: 6),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(stockLevelsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWarehousePicker(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.read(warehouseListProvider);
    warehousesAsync.whenData((warehouses) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Warehouse', style: AppTextStyles.pageTitle),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('All Warehouses'),
              leading: const Icon(Icons.clear_all_rounded),
              selected: ref.read(stockFilterProvider).warehouseId == null,
              onTap: () {
                ref.read(stockFilterProvider.notifier).state = ref
                    .read(stockFilterProvider)
                    .copyWith(clearWarehouse: true);
                Navigator.pop(context);
              },
            ),
            ...warehouses.map(
              (w) => ListTile(
                title: Text(w.name),
                subtitle: w.location != null ? Text(w.location!) : null,
                leading: Icon(
                  w.isCentral ? Icons.warehouse_rounded : Icons.store_rounded,
                ),
                selected: ref.read(stockFilterProvider).warehouseId == w.id,
                onTap: () {
                  ref.read(stockFilterProvider.notifier).state = ref
                      .read(stockFilterProvider)
                      .copyWith(warehouseId: w.id);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.read(categoryListProvider);
    categoriesAsync.whenData((categories) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Category', style: AppTextStyles.pageTitle),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('All Categories'),
              leading: const Icon(Icons.clear_all_rounded),
              selected: ref.read(stockFilterProvider).categoryId == null,
              onTap: () {
                ref.read(stockFilterProvider.notifier).state = ref
                    .read(stockFilterProvider)
                    .copyWith(clearCategory: true);
                Navigator.pop(context);
              },
            ),
            ...categories.map(
              (c) => ListTile(
                title: Text(c.name),
                leading: const Icon(Icons.category_rounded),
                selected: ref.read(stockFilterProvider).categoryId == c.id,
                onTap: () {
                  ref.read(stockFilterProvider.notifier).state = ref
                      .read(stockFilterProvider)
                      .copyWith(categoryId: c.id);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  void _showMaterialDetail(BuildContext context, dynamic item) {
    // Show a bottom sheet with material details and actions
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(item.name, style: AppTextStyles.pageTitle),
              if (item.code != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.code!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Stock info
              _DetailRow('Category', item.categoryName ?? '—'),
              _DetailRow('UOM', item.uom),
              _DetailRow('Warehouse', item.warehouseName),
              const Divider(color: AppColors.border, height: 24),
              _DetailRow('Total Quantity', _formatQty(item.quantity)),
              _DetailRow('Reserved', _formatQty(item.reservedQty)),
              _DetailRow(
                'Available',
                _formatQty(item.availableQty),
                valueColor: item.availableQty > 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
              _DetailRow('Min Stock Level', _formatQty(item.minStockLevel)),
              const Divider(color: AppColors.border, height: 24),
              _DetailRow('Status', item.stockStatusLabel),
              if (item.isCritical)
                _DetailRow('Critical', 'Yes', valueColor: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
}

// ─── Helper Widgets ───

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? AppColors.primary).withValues(alpha: 0.15)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? (color ?? AppColors.primary) : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? (color ?? AppColors.primary)
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DropdownChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
