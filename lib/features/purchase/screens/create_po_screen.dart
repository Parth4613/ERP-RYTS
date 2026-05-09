import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/purchase.dart';
import 'package:gas_company/features/purchase/providers/purchase_provider.dart';

class CreatePOScreen extends ConsumerStatefulWidget {
  final String prId;
  final List<PurchaseRequestItem> items;
  const CreatePOScreen({super.key, required this.prId, required this.items});
  @override
  ConsumerState<CreatePOScreen> createState() => _CreatePOScreenState();
}

class _CreatePOScreenState extends ConsumerState<CreatePOScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  String? _selectedSupplierId;
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _priceControllers[item.productId] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final c in _priceControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier'), backgroundColor: AppColors.error));
      return;
    }
    final poItems = widget.items.map((item) {
      final price = double.tryParse(_priceControllers[item.productId]?.text ?? '0') ?? 0;
      return {'product_id': item.productId, 'quantity': item.quantityNeeded, 'unit_price': price};
    }).toList();

    final poId = await ref.read(purchaseNotifierProvider.notifier).createPurchaseOrder(
      prId: widget.prId, supplierId: _selectedSupplierId!, notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(), items: poItems);
    if (poId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order created'), backgroundColor: AppColors.success));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final isLoading = ref.watch(purchaseNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Purchase Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.infoLight.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20), const SizedBox(width: 10),
              Expanded(child: Text('Creating PO from PR-${widget.prId.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 13, color: AppColors.info))),
            ]),
          ),
          const SizedBox(height: 20),
          suppliers.when(
            data: (list) {
              if (list.isEmpty) return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.warningLight.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: const Text('No suppliers found. Please add suppliers first.', style: TextStyle(color: AppColors.warning)));
              return DropdownButtonFormField<String>(
                value: _selectedSupplierId, decoration: const InputDecoration(labelText: 'Select Supplier', prefixIcon: Icon(Icons.people_outline)),
                items: list.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _selectedSupplierId = v),
                validator: (v) => v == null ? 'Required' : null);
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.note_outlined)), maxLines: 2),
          const SizedBox(height: 24),
          const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...widget.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Quantity needed: ${item.quantityNeeded} ${item.productUnit ?? 'pcs'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              TextFormField(controller: _priceControllers[item.productId], decoration: const InputDecoration(labelText: 'Unit Price (₹)', isDense: true, prefixIcon: Icon(Icons.currency_rupee)),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            ]),
          )),
          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(onPressed: isLoading ? null : _submit,
            child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Create Purchase Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        ])),
      ),
    );
  }
}
