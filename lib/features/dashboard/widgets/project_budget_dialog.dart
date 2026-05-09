import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';

class ProjectBudgetDialog extends ConsumerStatefulWidget {
  final ProjectCostSummary project;

  const ProjectBudgetDialog({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<ProjectBudgetDialog> createState() => _ProjectBudgetDialogState();
}

class _ProjectBudgetDialogState extends ConsumerState<ProjectBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _budgetController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: widget.project.budgetAmount > 0
          ? widget.project.budgetAmount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Budget - ${widget.project.projectName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current budget info
            if (widget.project.budgetAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Budget',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                          .format(widget.project.budgetAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Cost: ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(widget.project.totalCost)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Budget Used: ${widget.project.budgetUsedPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getBudgetStatusColor(widget.project.budgetStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // New budget input
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Budget Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 to remove budget',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a budget amount';
                }
                final amount = double.tryParse(value);
                if (amount == null) {
                  return 'Please enter a valid number';
                }
                if (amount < 0) {
                  return 'Budget cannot be negative';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Budget recommendations
            _buildBudgetRecommendations(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBudget,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Budget'),
        ),
      ],
    );
  }

  Widget _buildBudgetRecommendations() {
    final recommendedBudget = widget.project.totalCost * 1.2; // 20% buffer
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, 
                       color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Budget Recommendations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            'Current Cost + 20% Buffer',
            recommendedBudget,
            'Recommended for safety margin',
          ),
          _buildRecommendationItem(
            'Current Cost + 10% Buffer',
            widget.project.totalCost * 1.1,
            'Minimum recommended',
          ),
          if (widget.project.budgetAmount > 0)
            _buildRecommendationItem(
              'Current Budget',
              widget.project.budgetAmount,
              'Keep existing budget',
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String label, double amount, String description) {
    return InkWell(
      onTap: () {
        _budgetController.text = amount.toStringAsFixed(2);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(amount),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, 
                     size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final budgetAmount = double.parse(_budgetController.text);
      
      await ref.read(projectBudgetNotifierProvider(widget.project.projectId).notifier)
          .updateBudget(budgetAmount);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              budgetAmount > 0
                  ? 'Budget updated successfully'
                  : 'Budget removed successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update budget: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getBudgetStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.overBudget:
        return AppColors.error;
      case BudgetStatus.nearLimit:
        return AppColors.warning;
      case BudgetStatus.onTrack:
        return AppColors.success;
      case BudgetStatus.noBudget:
        return AppColors.textSecondary;
    }
  }
}
