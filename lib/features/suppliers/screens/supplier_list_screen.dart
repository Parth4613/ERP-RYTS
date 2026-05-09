import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/supplier.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/suppliers/providers/supplier_providers.dart';
import 'package:gas_company/features/suppliers/screens/supplier_detail_screen.dart';
import 'package:gas_company/features/suppliers/screens/supplier_form_screen.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push<Supplier>(
      context,
      MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
    );
    if (result != null) ref.invalidate(suppliersProvider);
  }

  Future<void> _openEdit(Supplier supplier) async {
    final result = await Navigator.push<Supplier>(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: supplier)),
    );
    if (result != null) ref.invalidate(suppliersProvider);
  }

  Future<void> _confirmDelete(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Supplier'),
        content: Text(
          'Delete ${supplier.name} and all mapped products?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(supplierMutationProvider.notifier)
        .deleteSupplier(supplier.id);
    final state = ref.read(supplierMutationProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError ? 'Unable to delete supplier' : 'Supplier deleted',
        ),
        backgroundColor: state.hasError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final isMutating = ref.watch(supplierMutationProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isMutating ? null : _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Supplier'),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          final filtered = _filterSuppliers(suppliers);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(suppliersProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryBand(suppliers: suppliers),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search supplier, code, contact, or product',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: suppliers.isEmpty ? 'No Suppliers' : 'No Matches',
                    subtitle: suppliers.isEmpty
                        ? 'Add supplier details and product specifications.'
                        : 'Try a different supplier or product search.',
                    action: suppliers.isEmpty
                        ? ElevatedButton.icon(
                            onPressed: _openCreate,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Supplier'),
                          )
                        : null,
                  )
                else
                  ...filtered.map(
                    (supplier) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SupplierTile(
                        supplier: supplier,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SupplierDetailScreen(supplierId: supplier.id),
                          ),
                        ),
                        onEdit: () => _openEdit(supplier),
                        onDelete: () => _confirmDelete(supplier),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load suppliers',
            subtitle: e.toString(),
          ),
        ),
      ),
    );
  }

  List<Supplier> _filterSuppliers(List<Supplier> suppliers) {
    if (_query.isEmpty) return suppliers;
    final query = _query.toLowerCase();
    return suppliers.where((supplier) {
      final productText = supplier.products
          .map((product) => '${product.productName} ${product.description}')
          .join(' ')
          .toLowerCase();
      final supplierText = [
        supplier.supplierCode,
        supplier.name,
        supplier.contactName,
        supplier.contactMobile,
        supplier.contactEmail,
        supplier.gstNo,
        supplier.panNo,
        productText,
      ].whereType<String>().join(' ').toLowerCase();
      return supplierText.contains(query);
    }).toList();
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    final totalProducts = suppliers.fold<int>(
      0,
      (total, supplier) => total + supplier.products.length,
    );
    final isoSuppliers = suppliers
        .where((supplier) => supplier.isoCertificate)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final cards = [
          _SummaryCard(
            label: 'Suppliers',
            value: suppliers.length.toString(),
            icon: Icons.people_rounded,
            color: AppColors.adminColor,
          ),
          _SummaryCard(
            label: 'Mapped Products',
            value: totalProducts.toString(),
            icon: Icons.inventory_2_rounded,
            color: AppColors.purchaseColor,
          ),
          _SummaryCard(
            label: 'ISO Certified',
            value: isoSuppliers.toString(),
            icon: Icons.verified_rounded,
            color: AppColors.success,
          ),
        ];

        if (compact) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Supplier supplier;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final productPreview = supplier.products
        .take(2)
        .map((e) => e.productName)
        .join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.purchaseColor.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                color: AppColors.purchaseColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (supplier.supplierCode != null)
                        StatusBadge(
                          label: supplier.supplierCode!,
                          color: AppColors.info,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    supplier.contactMobile ?? 'No mobile number',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (supplier.contactEmail?.isNotEmpty == true)
                    Text(
                      supplier.contactEmail!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  if (productPreview.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      productPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Supplier actions',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
