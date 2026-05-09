import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/supplier.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/widgets/shared_widgets.dart';
import 'package:gas_company/features/suppliers/providers/supplier_providers.dart';
import 'package:gas_company/features/suppliers/screens/supplier_form_screen.dart';
import 'package:intl/intl.dart';

class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          supplierAsync.maybeWhen(
            data: (supplier) => IconButton(
              tooltip: 'Edit supplier',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final result = await Navigator.push<Supplier>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupplierFormScreen(supplier: supplier),
                  ),
                );
                if (result != null) {
                  ref.invalidate(supplierProvider(supplierId));
                }
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: supplierAsync.when(
        data: (supplier) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(supplierProvider(supplierId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SupplierHeader(supplier: supplier),
              const SizedBox(height: 16),
              _InfoSection(
                title: 'Supplier Information',
                icon: Icons.business_rounded,
                rows: [
                  _InfoRow('Supplier Code', supplier.supplierCode),
                  _InfoRow('Registered Address', supplier.address),
                  _InfoRow('GST No.', supplier.gstNo),
                  _InfoRow('PAN No.', supplier.panNo),
                  _InfoRow(
                    'ISO Certificate',
                    supplier.isoCertificate ? 'Available' : 'Not available',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoSection(
                title: 'Contact Person Details',
                icon: Icons.contact_phone_rounded,
                rows: [
                  _InfoRow('Name', supplier.contactName),
                  _InfoRow('Mobile No.', supplier.contactMobile),
                  _InfoRow('Email ID', supplier.contactEmail),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Products Supplied',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<Supplier>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SupplierFormScreen(supplier: supplier),
                        ),
                      );
                      if (result != null) {
                        ref.invalidate(supplierProvider(supplierId));
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Manage Products'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (supplier.products.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No Products Mapped',
                  subtitle:
                      'Add supplied products to compare pricing and specs.',
                )
              else
                ...supplier.products.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EditableProductTile(
                      supplierId: supplier.id,
                      product: product,
                    ),
                  ),
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load supplier',
            subtitle: e.toString(),
          ),
        ),
      ),
    );
  }
}

class _SupplierHeader extends StatelessWidget {
  const _SupplierHeader({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.purchaseColor.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.purchaseColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${supplier.products.length} product${supplier.products.length == 1 ? '' : 's'} mapped',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: supplier.isoCertificate ? 'ISO' : 'NO ISO',
            color: supplier.isoCertificate
                ? AppColors.success
                : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.info),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value?.trim().isNotEmpty == true ? row.value! : '-',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;
}

class _EditableProductTile extends ConsumerStatefulWidget {
  const _EditableProductTile({required this.supplierId, required this.product});

  final String supplierId;
  final SupplierProduct product;

  @override
  ConsumerState<_EditableProductTile> createState() =>
      _EditableProductTileState();
}

class _EditableProductTileState extends ConsumerState<_EditableProductTile> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descriptionCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.product.price.toStringAsFixed(2),
    );
    _descriptionCtrl = TextEditingController(text: widget.product.description);
  }

  @override
  void didUpdateWidget(covariant _EditableProductTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.price != widget.product.price ||
        oldWidget.product.description != widget.product.description) {
      _priceCtrl.text = widget.product.price.toStringAsFixed(2);
      _descriptionCtrl.text = widget.product.description;
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || widget.product.id == null) return;
    await ref
        .read(supplierMutationProvider.notifier)
        .updateProductPriceDescription(
          supplierId: widget.supplierId,
          supplierProductId: widget.product.id!,
          price: double.parse(_priceCtrl.text.trim()),
          description: _descriptionCtrl.text.trim(),
        );

    final state = ref.read(supplierMutationProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError ? 'Unable to update product' : 'Product updated',
        ),
        backgroundColor: state.hasError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(supplierMutationProvider).isLoading;
    final revisionsAsync = widget.product.id == null
        ? null
        : ref.watch(productRevisionsProvider(widget.product.id!));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.productName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit: ${widget.product.unit}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (revisionsAsync != null)
                  revisionsAsync.maybeWhen(
                    data: (items) => Text(
                      items.isEmpty
                          ? 'No revisions'
                          : 'Last revised ${DateFormat('dd MMM').format(items.first.updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final priceField = TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Price per Unit',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: _priceValidator,
                );
                final descriptionField = TextFormField(
                  controller: _descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Product Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Description is required'
                      : null,
                );

                if (compact) {
                  return Column(
                    children: [
                      priceField,
                      const SizedBox(height: 12),
                      descriptionField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: priceField),
                    const SizedBox(width: 12),
                    Expanded(child: descriptionField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _save,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _priceValidator(String? value) {
  final text = value?.trim() ?? '';
  final price = double.tryParse(text);
  if (price == null || price < 0) return 'Enter a valid price';
  return null;
}
