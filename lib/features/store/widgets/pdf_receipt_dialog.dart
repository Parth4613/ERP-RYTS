import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/models/store_models.dart';
import 'package:gas_company/core/services/pdf_service.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';

class PDFReceiptDialog extends ConsumerWidget {
  final IssuanceLog issuanceLog;

  const PDFReceiptDialog({super.key, required this.issuanceLog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return AlertDialog(
      title: const Text('Issuance Receipt'),
      content: profileAsync.when(
        data: (profile) => _buildContent(context, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Text('Error: $error'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => _generatePDF(context, ref),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, dynamic profile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.receipt_long,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Material Issuance Receipt',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Receipt ID', issuanceLog.id.substring(0, 8).toUpperCase()),
        _buildDetailRow('Date Issued', _formatDate(issuanceLog.issuedAt)),
        _buildDetailRow('Quantity', '${issuanceLog.quantityIssued} units'),
        if (issuanceLog.notes != null && issuanceLog.notes!.isNotEmpty)
          _buildDetailRow('Notes', issuanceLog.notes!),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click "Download PDF" to generate and print the receipt',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _generatePDF(BuildContext context, WidgetRef ref) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;

    final pdfService = PDFService();

    // For now, we'll use placeholder data. In a real implementation,
    // you would fetch the actual project and product details
    await pdfService.generateIssuanceReceipt(
      issuanceLog: issuanceLog,
      projectName: 'Project Name', // Fetch from database
      engineerName: 'Engineer Name', // Fetch from database
      productName: 'Product Name', // Fetch from database
      unit: 'units', // Fetch from database
      storeUserName: profile.name,
    );
  }
}
