import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});
  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _minStockCtrl = TextEditingController(text: '10');
  final _categoryCtrl = TextEditingController();
  final _initialStockCtrl = TextEditingController(text: '0');

  @override
  void dispose() { _nameCtrl.dispose(); _unitCtrl.dispose(); _minStockCtrl.dispose(); _categoryCtrl.dispose(); _initialStockCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(inventoryNotifierProvider.notifier).addProduct(
      name: _nameCtrl.text.trim(), unit: _unitCtrl.text.trim(),
      minimumStockLevel: int.tryParse(_minStockCtrl.text) ?? 0,
      category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      initialStock: int.tryParse(_initialStockCtrl.text) ?? 0);
    final state = ref.read(inventoryNotifierProvider);
    if (!state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully'), backgroundColor: AppColors.success));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(inventoryNotifierProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.inventory_2_outlined)),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g. pcs, kg, m)', prefixIcon: Icon(Icons.straighten_outlined))),
          const SizedBox(height: 16),
          TextFormField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Category (Optional)', prefixIcon: Icon(Icons.category_outlined))),
          const SizedBox(height: 16),
          TextFormField(controller: _minStockCtrl, decoration: const InputDecoration(labelText: 'Minimum Stock Level', prefixIcon: Icon(Icons.warning_amber_outlined)),
            keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextFormField(controller: _initialStockCtrl, decoration: const InputDecoration(labelText: 'Initial Stock Quantity', prefixIcon: Icon(Icons.add_box_outlined)),
            keyboardType: TextInputType.number),
          const SizedBox(height: 32),
          SizedBox(height: 52, child: ElevatedButton(onPressed: isLoading ? null : _submit,
            child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Add Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        ])),
      ),
    );
  }
}
