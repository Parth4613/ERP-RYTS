import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/supplier.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/suppliers/providers/supplier_providers.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final List<_ProductFormRow> _productRows = [];
  bool _isoCertificate = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    if (supplier != null) {
      _supplierCodeCtrl.text = supplier.supplierCode ?? '';
      _nameCtrl.text = supplier.name;
      _addressCtrl.text = supplier.address ?? '';
      _gstCtrl.text = supplier.gstNo ?? '';
      _panCtrl.text = supplier.panNo ?? '';
      _contactNameCtrl.text = supplier.contactName ?? '';
      _mobileCtrl.text = supplier.contactMobile ?? '';
      _emailCtrl.text = supplier.contactEmail ?? '';
      _isoCertificate = supplier.isoCertificate;
      _productRows.addAll(supplier.products.map(_ProductFormRow.fromProduct));
    }
    if (_productRows.isEmpty) _productRows.add(_ProductFormRow.empty());
  }

  @override
  void dispose() {
    _supplierCodeCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _contactNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    for (final row in _productRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addProductRow() {
    setState(() => _productRows.add(_ProductFormRow.empty()));
  }

  void _removeProductRow(int index) {
    if (_productRows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one supplied product is required'),
        ),
      );
      return;
    }
    final removed = _productRows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final products = _productRows.map((row) => row.toProduct()).toList();
    final supplier = Supplier(
      id: widget.supplier?.id ?? '',
      supplierCode: _emptyToNull(_supplierCodeCtrl.text),
      name: _nameCtrl.text.trim(),
      address: _emptyToNull(_addressCtrl.text),
      gstNo: _emptyToNull(_gstCtrl.text),
      panNo: _emptyToNull(_panCtrl.text),
      isoCertificate: _isoCertificate,
      contactName: _emptyToNull(_contactNameCtrl.text),
      contactMobile: _mobileCtrl.text.trim(),
      contactEmail: _emptyToNull(_emailCtrl.text),
    );

    final notifier = ref.read(supplierMutationProvider.notifier);
    final result = _isEditing
        ? await notifier.updateSupplier(supplier: supplier, products: products)
        : await notifier.createSupplier(supplier: supplier, products: products);

    final state = ref.read(supplierMutationProvider);
    if (!mounted) return;
    if (state.hasError || result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save supplier: ${state.error}')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Supplier updated' : 'Supplier created'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(supplierMutationProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormSection(
                title: 'Supplier Information',
                icon: Icons.business_rounded,
                children: [
                  _twoColumn(
                    TextFormField(
                      controller: _supplierCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Code',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name of Supplier *',
                        prefixIcon: Icon(Icons.storefront_rounded),
                      ),
                      validator: _required('Supplier name is required'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Registered Address *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: _required('Registered address is required'),
                  ),
                  const SizedBox(height: 14),
                  _twoColumn(
                    TextFormField(
                      controller: _gstCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GST No. *',
                        prefixIcon: Icon(Icons.receipt_long_rounded),
                      ),
                      validator: _required('GST number is required'),
                    ),
                    TextFormField(
                      controller: _panCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'PAN No. *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: _required('PAN number is required'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: _isoCertificate,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'ISO Certificate Available',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Upload can be added later through Supabase Storage',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    onChanged: (value) =>
                        setState(() => _isoCertificate = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormSection(
                title: 'Contact Person Details',
                icon: Icons.contact_phone_rounded,
                children: [
                  TextFormField(
                    controller: _contactNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _required('Contact person name is required'),
                  ),
                  const SizedBox(height: 14),
                  _twoColumn(
                    TextFormField(
                      controller: _mobileCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mobile No. *',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-\s]'),
                        ),
                      ],
                      validator: _phoneValidator,
                    ),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email ID *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormSection(
                title: 'Products Supplied',
                icon: Icons.inventory_2_outlined,
                trailing: TextButton.icon(
                  onPressed: _addProductRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Product'),
                ),
                children: [
                  for (var i = 0; i < _productRows.length; i++) ...[
                    _ProductEditor(
                      index: i,
                      row: _productRows[i],
                      onRemove: () => _removeProductRow(i),
                    ),
                    if (i != _productRows.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : _submit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(isSaving ? 'Saving...' : 'Save Supplier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoColumn(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

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
              Icon(icon, size: 20, color: AppColors.purchaseColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ProductEditor extends StatelessWidget {
  const _ProductEditor({
    required this.index,
    required this.row,
    required this.onRemove,
  });

  final int index;
  final _ProductFormRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product ${index + 1}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove product',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final nameField = TextFormField(
                controller: row.productNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: _required('Item name is required'),
              );
              final unitField = TextFormField(
                controller: row.unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                validator: _required('Unit is required'),
              );
              final priceField = TextFormField(
                controller: row.priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Price per Unit *',
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

              if (compact) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 12),
                    unitField,
                    const SizedBox(height: 12),
                    priceField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: nameField),
                  const SizedBox(width: 12),
                  Expanded(child: unitField),
                  const SizedBox(width: 12),
                  Expanded(child: priceField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: row.descriptionCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Product Description *',
              hintText: 'Size, grade, brand, specification, make, finish...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormRow {
  _ProductFormRow({
    this.id,
    required String productName,
    required String unit,
    required String price,
    required String description,
  }) : productNameCtrl = TextEditingController(text: productName),
       unitCtrl = TextEditingController(text: unit),
       priceCtrl = TextEditingController(text: price),
       descriptionCtrl = TextEditingController(text: description);

  factory _ProductFormRow.empty() =>
      _ProductFormRow(productName: '', unit: '', price: '', description: '');

  factory _ProductFormRow.fromProduct(SupplierProduct product) =>
      _ProductFormRow(
        id: product.id,
        productName: product.productName,
        unit: product.unit,
        price: product.price == 0 ? '' : product.price.toStringAsFixed(2),
        description: product.description,
      );

  final String? id;
  final TextEditingController productNameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController descriptionCtrl;

  SupplierProduct toProduct() {
    return SupplierProduct(
      id: id,
      productName: productNameCtrl.text.trim(),
      unit: unitCtrl.text.trim(),
      price: double.parse(priceCtrl.text.trim()),
      description: descriptionCtrl.text.trim(),
    );
  }

  void dispose() {
    productNameCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

String? Function(String?) _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

String? _phoneValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Mobile number is required';
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10 || digits.length > 15) {
    return 'Enter a valid mobile number';
  }
  return null;
}

String? _emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  return valid ? null : 'Enter a valid email address';
}

String? _priceValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Price is required';
  final price = double.tryParse(text);
  if (price == null || price < 0) return 'Enter a valid price';
  return null;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
