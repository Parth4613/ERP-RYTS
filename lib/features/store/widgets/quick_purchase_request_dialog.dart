import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/store/providers/store_providers.dart';

class QuickPurchaseRequestDialog extends ConsumerStatefulWidget {
  const QuickPurchaseRequestDialog({
    super.key,
    this.initialItems = const [],
    this.projectId,
    this.mrId,
    this.title = 'Create Purchase Request',
  });

  final List<QuickPurchaseRequestItem> initialItems;
  final String? projectId;
  final String? mrId;
  final String title;

  @override
  ConsumerState<QuickPurchaseRequestDialog> createState() =>
      _QuickPurchaseRequestDialogState();
}

class _QuickPurchaseRequestDialogState
    extends ConsumerState<QuickPurchaseRequestDialog> {
  final _notesCtrl = TextEditingController();
  final Map<String, QuickPurchaseRequestItem> _selected = {};
  final Map<String, TextEditingController> _quantityCtrls = {};
  late DateTime _requiredDate;

  @override
  void initState() {
    super.initState();
    _requiredDate = DateTime.now().add(const Duration(days: 7));
    for (final item in widget.initialItems) {
      _selectItem(item);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final ctrl in _quantityCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProcurementNotifierProvider);
    final procurementItems = ref.watch(storeProcurementItemsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.initialItems.isNotEmpty)
                ...widget.initialItems.map(_selectedItemTile)
              else
                procurementItems.when(
                  data: (items) {
                    final suggested = items
                        .where((item) => item.needsProcurement)
                        .toList();
                    if (suggested.isEmpty) {
                      return const Text(
                        'No low-stock items need procurement right now.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    return Column(
                      children: suggested
                          .map(_selectableProcurementTile)
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(
                    'Unable to load low-stock items: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: state.isCreatingPr ? null : _pickRequiredDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Required Date',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(
                    '${_requiredDate.day}/${_requiredDate.month}/${_requiredDate.year}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText:
                      'Urgency, site delivery instruction, preferred supplier...',
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isCreatingPr ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: state.isCreatingPr || _selected.isEmpty ? null : _submit,
          icon: state.isCreatingPr
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(state.isCreatingPr ? 'Sending...' : 'Send to Purchase'),
        ),
      ],
    );
  }

  Widget _selectableProcurementTile(StoreProcurementItem item) {
    final quickItem = QuickPurchaseRequestItem(
      productId: item.productId,
      productName: item.productName,
      unit: item.unit,
      quantity: item.recommendedQuantity,
      requiredDate: _requiredDate,
    );
    final isSelected = _selected.containsKey(item.productId);
    final statusColor = switch (item.stockStatus) {
      'out_of_stock' => AppColors.error,
      'low_stock' => AppColors.warning,
      _ => AppColors.success,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectItem(quickItem);
            } else {
              _unselectItem(item.productId);
            }
          });
        },
        title: Text(
          item.productName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Available ${item.quantityAvailable}, reserved ${item.quantityReserved}, incoming ${item.incomingQuantity} ${item.unit}\nRecommended ${item.recommendedQuantity} ${item.unit}${item.recommendedSupplier == null ? '' : ' • ${item.recommendedSupplier}'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        secondary: Icon(Icons.inventory_2_rounded, color: statusColor),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _selectedItemTile(QuickPurchaseRequestItem item) {
    final ctrl = _quantityCtrls[item.productId]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    item.unit,
                    if (item.projectName != null) item.projectName!,
                    if (item.mrId != null) 'MR linked',
                  ].join(' • '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 118,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Qty',
                suffixText: item.unit,
                isDense: true,
              ),
              onChanged: (value) => _updateQuantity(item, value),
            ),
          ),
        ],
      ),
    );
  }

  void _selectItem(QuickPurchaseRequestItem item) {
    _selected[item.productId] = item;
    _quantityCtrls.putIfAbsent(
      item.productId,
      () => TextEditingController(text: item.quantity.toString()),
    );
  }

  void _unselectItem(String productId) {
    _selected.remove(productId);
    _quantityCtrls.remove(productId)?.dispose();
  }

  void _updateQuantity(QuickPurchaseRequestItem item, String value) {
    final quantity = int.tryParse(value) ?? item.quantity;
    _selected[item.productId] = QuickPurchaseRequestItem(
      productId: item.productId,
      productName: item.productName,
      unit: item.unit,
      quantity: quantity < 1 ? 1 : quantity,
      projectId: item.projectId,
      projectName: item.projectName,
      mrId: item.mrId,
      requiredDate: _requiredDate,
    );
  }

  Future<void> _pickRequiredDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _requiredDate = picked);
    }
  }

  Future<void> _submit() async {
    final items = _selected.values
        .map(
          (item) => QuickPurchaseRequestItem(
            productId: item.productId,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            projectId: item.projectId ?? widget.projectId,
            projectName: item.projectName,
            mrId: item.mrId ?? widget.mrId,
            requiredDate: _requiredDate,
          ),
        )
        .toList();

    final prId = await ref
        .read(storeProcurementNotifierProvider.notifier)
        .createPurchaseRequest(
          items: items,
          projectId: widget.projectId,
          mrId: widget.mrId,
          requiredDate: _requiredDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

    if (!mounted || prId == null) return;
    Navigator.pop(context, prId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Purchase Request ${prId.substring(0, 8).toUpperCase()} sent',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
