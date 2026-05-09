import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';
import 'package:gas_company/features/inventory/providers/inventory_provider.dart';
import 'package:gas_company/features/material_requests/providers/mr_provider.dart';

class CreateMRScreen extends ConsumerStatefulWidget {
  const CreateMRScreen({super.key});
  @override
  ConsumerState<CreateMRScreen> createState() => _CreateMRScreenState();
}

class _CreateMRScreenState extends ConsumerState<CreateMRScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  String? _selectedProjectId;
  final List<_MRItem> _items = [];

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  void _addItem() {
    setState(() => _items.add(_MRItem()));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project'), backgroundColor: AppColors.error));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item'), backgroundColor: AppColors.error));
      return;
    }
    final itemsMaps = _items.where((i) => i.productId != null && i.quantity > 0).map((i) => {'product_id': i.productId!, 'quantity_requested': i.quantity}).toList();
    if (itemsMaps.isEmpty) return;

    final mrId = await ref.read(materialRequestNotifierProvider.notifier).createMaterialRequest(
      projectId: _selectedProjectId!, notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(), items: itemsMaps);
    if (mrId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material request created'), backgroundColor: AppColors.success));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final products = ref.watch(productsProvider);
    final isLoading = ref.watch(materialRequestNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Material Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Project selector
          projects.when(
            data: (list) => DropdownButtonFormField<String>(
              value: _selectedProjectId, decoration: const InputDecoration(labelText: 'Select Project', prefixIcon: Icon(Icons.business_rounded)),
              items: list.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (v) => setState(() => _selectedProjectId = v),
              validator: (v) => v == null ? 'Required' : null),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.note_outlined)), maxLines: 2),
          const SizedBox(height: 24),

          // Items header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8))),
          ]),
          const SizedBox(height: 12),

          // Items list
          if (_items.isEmpty) Container(
            padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: const Center(child: Text('No items added yet', style: TextStyle(color: AppColors.textSecondary))),
          ),
          ...List.generate(_items.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
              child: Column(children: [
                Row(children: [
                  Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20), onPressed: () => _removeItem(index)),
                ]),
                const SizedBox(height: 8),
                products.when(
                  data: (prods) => DropdownButtonFormField<String>(
                    value: _items[index].productId, decoration: const InputDecoration(labelText: 'Product', isDense: true),
                    items: prods.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.unit})'))).toList(),
                    onChanged: (v) => setState(() => _items[index].productId = v),
                    validator: (v) => v == null ? 'Required' : null),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _items[index].quantity > 0 ? '${_items[index].quantity}' : '',
                  decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _items[index].quantity = int.tryParse(v) ?? 0,
                  validator: (v) => v == null || v.isEmpty || (int.tryParse(v) ?? 0) <= 0 ? 'Enter valid quantity' : null),
              ]),
            );
          }),

          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(onPressed: isLoading || _items.isEmpty ? null : _submit,
            child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        ])),
      ),
    );
  }
}

class _MRItem {
  String? productId;
  int quantity = 0;
}
