import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gas_company/core/models/dashboard_models.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/dashboard/providers/dashboard_providers.dart';
import 'package:gas_company/features/dashboard/widgets/project_budget_dialog.dart';

class ProjectsOverview extends ConsumerStatefulWidget {
  const ProjectsOverview({super.key});

  @override
  ConsumerState<ProjectsOverview> createState() => _ProjectsOverviewState();
}

class _ProjectsOverviewState extends ConsumerState<ProjectsOverview> {
  String _selectedStatus = 'all';
  String _selectedBudgetStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectCostSummariesProvider);
    final overBudgetAsync = ref.watch(overBudgetProjectsProvider);
    final nearLimitAsync = ref.watch(nearLimitProjectsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Filters
          _buildFilters(),
          
          // Alert sections
          _buildAlertSections(overBudgetAsync, nearLimitAsync),
          
          // Projects list
          Expanded(
            child: projectsAsync.when(
              data: (projects) => _buildProjectsList(projects),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorWidget('Failed to load projects: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projects Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Project Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBudgetStatus,
                  decoration: const InputDecoration(
                    labelText: 'Budget Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Budget')),
                    DropdownMenuItem(value: 'over_budget', child: Text('Over Budget')),
                    DropdownMenuItem(value: 'near_limit', child: Text('Near Limit')),
                    DropdownMenuItem(value: 'on_track', child: Text('On Track')),
                    DropdownMenuItem(value: 'no_budget', child: Text('No Budget')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBudgetStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSections(
    AsyncValue<List<ProjectCostSummary>> overBudgetAsync,
    AsyncValue<List<ProjectCostSummary>> nearLimitAsync,
  ) {
    return Column(
      children: [
        // Over budget projects
        overBudgetAsync.when(
          data: (projects) {
            if (projects.isEmpty) return const SizedBox.shrink();
            return _buildAlertSection(
              'Over Budget Projects',
              projects,
              AppColors.error,
              Icons.warning,
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
        
        // Near limit projects
        nearLimitAsync.when(
          data: (projects) {
            if (projects.isEmpty) return const SizedBox.shrink();
            return _buildAlertSection(
              'Projects Near Budget Limit',
              projects,
              AppColors.warning,
              Icons.trending_up,
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildAlertSection(
    String title,
    List<ProjectCostSummary> projects,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${projects.length} projects',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...projects.take(3).map((project) => _buildAlertProjectItem(project)),
          if (projects.length > 3)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedBudgetStatus = color == AppColors.error ? 'over_budget' : 'near_limit';
                });
              },
              child: Text(
                'View all ${projects.length} projects →',
                style: TextStyle(color: color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertProjectItem(ProjectCostSummary project) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.projectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${project.budgetUsedPercentage.toStringAsFixed(1)}% of budget used',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                .format(project.totalCost),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(List<ProjectCostSummary> projects) {
    // Apply filters
    var filteredProjects = projects.where((project) {
      if (_selectedStatus != 'all' && project.status != _selectedStatus) {
        return false;
      }
      if (_selectedBudgetStatus != 'all' && project.budgetStatus.value != _selectedBudgetStatus) {
        return false;
      }
      return true;
    }).toList();

    if (filteredProjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No projects found',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        final project = filteredProjects[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(ProjectCostSummary project) {
    Color statusColor = _getBudgetStatusColor(project.budgetStatus);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.projectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (project.engineerName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Engineer: ${project.engineerName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getBudgetStatusText(project.budgetStatus),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Budget progress bar
            if (project.budgetAmount > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget Usage',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${project.budgetUsedPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: project.budgetUsedPercentage.clamp(0.0, 100.0) / 100.0,
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Cost breakdown
            Row(
              children: [
                Expanded(
                  child: _buildCostItem('Material', project.materialCost),
                ),
                Expanded(
                  child: _buildCostItem('Labor', project.laborCost),
                ),
                Expanded(
                  child: _buildCostItem('Equipment', project.equipmentCost),
                ),
                Expanded(
                  child: _buildCostItem('Other', project.otherCost),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Total and actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Cost',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                            .format(project.totalCost),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (project.budgetAmount > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Budget',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                            .format(project.budgetAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit_budget':
                        _showEditBudgetDialog(project);
                        break;
                      case 'view_details':
                        // Navigate to project details
                        break;
                      case 'add_cost':
                        // Navigate to add cost
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_budget',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Budget'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_details',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_cost',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 8),
                          Text('Add Cost'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostItem(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0)
              .format(amount),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
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

  String _getBudgetStatusText(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.overBudget:
        return 'OVER BUDGET';
      case BudgetStatus.nearLimit:
        return 'NEAR LIMIT';
      case BudgetStatus.onTrack:
        return 'ON TRACK';
      case BudgetStatus.noBudget:
        return 'NO BUDGET';
    }
  }

  void _showEditBudgetDialog(ProjectCostSummary project) {
    showDialog(
      context: context,
      builder: (context) => ProjectBudgetDialog(project: project),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.refresh(projectCostSummariesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
