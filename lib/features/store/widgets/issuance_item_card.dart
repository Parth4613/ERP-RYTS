import 'package:flutter/material.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';

class IssuanceItemCard extends StatefulWidget {
  final PendingMRItemWithStock item;
  final Function(int) onIssue;
  final VoidCallback? onCreatePR;
  final bool isIssuing;
  final bool issuanceEnabled;

  const IssuanceItemCard({
    super.key,
    required this.item,
    required this.onIssue,
    this.onCreatePR,
    this.isIssuing = false,
    this.issuanceEnabled = true,
  });

  @override
  State<IssuanceItemCard> createState() => _IssuanceItemCardState();
}

class _IssuanceItemCardState extends State<IssuanceItemCard> {
  late TextEditingController _quantityController;
  int _maxQuantity = 0;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _maxQuantity = _calculateMaxQuantity();
    _quantityController.text = _maxQuantity.toString();
  }

  @override
  void didUpdateWidget(covariant IssuanceItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.stockAvailable != widget.item.stockAvailable ||
        oldWidget.item.quantityPending != widget.item.quantityPending) {
      _maxQuantity = _calculateMaxQuantity();
      _quantityController.text = _maxQuantity.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canIssue =
        widget.issuanceEnabled &&
        widget.item.issuanceStatus != IssuanceStatus.outOfStock &&
        _maxQuantity > 0;
    final statusColor = _getStatusColor(widget.item.issuanceStatus);
    final statusText = _getStatusText(widget.item.issuanceStatus);
    final shortage = widget.item.quantityPending - widget.item.stockAvailable;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested: ${widget.item.quantityRequested} ${widget.item.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.item.quantityIssued > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Already Issued: ${widget.item.quantityIssued} ${widget.item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                      if (widget.item.quantityReserved > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reserved: ${widget.item.quantityReserved} ${widget.item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Stock info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.item.stockAvailable} ${widget.item.unit}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.item.stockAvailable > 0
                                ? AppColors.textPrimary
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.item.quantityPending} ${widget.item.unit}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _stockChip(
                  'Reserved',
                  '${widget.item.quantityReserved} ${widget.item.unit}',
                  AppColors.info,
                ),
                _stockChip(
                  'Minimum',
                  '${widget.item.minimumStockLevel} ${widget.item.unit}',
                  AppColors.textMuted,
                ),
                _stockChip(
                  'Incoming',
                  '${widget.item.incomingQuantity} ${widget.item.unit}',
                  AppColors.success,
                ),
                if (shortage > 0)
                  _stockChip(
                    'Shortage',
                    '$shortage ${widget.item.unit}',
                    AppColors.error,
                  ),
              ],
            ),

            if (canIssue) ...[
              const SizedBox(height: 12),

              // Quantity input and issue button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to Issue',
                        border: const OutlineInputBorder(),
                        suffixText: widget.item.unit,
                        helperText: 'Max: $_maxQuantity',
                      ),
                      enabled: !widget.isIssuing,
                      onChanged: (value) {
                        final qty = int.tryParse(value);
                        if (qty != null && qty > _maxQuantity) {
                          _quantityController.text = _maxQuantity.toString();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.isIssuing
                          ? null
                          : () {
                              final quantity = int.tryParse(
                                _quantityController.text,
                              );
                              if (quantity != null &&
                                  quantity > 0 &&
                                  quantity <= _maxQuantity) {
                                widget.onIssue(quantity);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Enter a quantity from 1 to $_maxQuantity',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: widget.isIssuing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Issue'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.stockAvailable == 0
                                ? 'Out of Stock'
                                : 'Cannot Issue',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.item.stockAvailable == 0)
                            const Text(
                              'Stock is unavailable. Create a Purchase Request.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.item.stockAvailable == 0)
                      TextButton(
                        onPressed: () {
                          widget.onCreatePR?.call();
                        },
                        child: const Text('Create PR'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _calculateMaxQuantity() {
    if (widget.item.stockAvailable <= 0 || widget.item.quantityPending <= 0) {
      return 0;
    }
    return widget.item.stockAvailable < widget.item.quantityPending
        ? widget.item.stockAvailable
        : widget.item.quantityPending;
  }

  Color _getStatusColor(IssuanceStatus status) {
    switch (status) {
      case IssuanceStatus.canFullyIssue:
        return AppColors.success;
      case IssuanceStatus.canPartiallyIssue:
        return AppColors.warning;
      case IssuanceStatus.outOfStock:
        return AppColors.error;
    }
  }

  String _getStatusText(IssuanceStatus status) {
    switch (status) {
      case IssuanceStatus.canFullyIssue:
        return 'CAN ISSUE';
      case IssuanceStatus.canPartiallyIssue:
        return 'PARTIAL';
      case IssuanceStatus.outOfStock:
        return 'NO STOCK';
    }
  }

  Widget _stockChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
