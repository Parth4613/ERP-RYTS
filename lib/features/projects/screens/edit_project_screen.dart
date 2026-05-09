import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/core/models/project.dart';
import 'package:gas_company/core/utils/enums.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';

class EditProjectScreen extends ConsumerStatefulWidget {
  final Project project;
  const EditProjectScreen({super.key, required this.project});
  @override
  ConsumerState<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends ConsumerState<EditProjectScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  String? _selectedEngineerId;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description ?? '');
    _selectedEngineerId = widget.project.assignedEngineerId;
    _selectedStatus = widget.project.status.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name is required'), backgroundColor: AppColors.error),
      );
      return;
    }

    await ref.read(projectNotifierProvider.notifier).updateProject(
      id: widget.project.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      assignedEngineerId: _selectedEngineerId,
      status: _selectedStatus,
    );

    final state = ref.read(projectNotifierProvider);
    if (!state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project updated successfully'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${state.error}'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineers = ref.watch(engineersProvider);
    final isLoading = ref.watch(projectNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current info header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoLight.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Editing: ${widget.project.name}',
                      style: const TextStyle(fontSize: 14, color: AppColors.info, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                prefixIcon: Icon(Icons.business_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Assign Engineer
            engineers.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _selectedEngineerId,
                decoration: const InputDecoration(
                  labelText: 'Assigned Engineer',
                  prefixIcon: Icon(Icons.engineering_rounded),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...list.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedEngineerId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading engineers: $e',
                  style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 16),

            // Project Status
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Project Status',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              items: ProjectStatus.values.map((s) => DropdownMenuItem(
                value: s.name,
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s == ProjectStatus.active
                            ? AppColors.success
                            : s == ProjectStatus.completed
                                ? AppColors.info
                                : AppColors.warning,
                      ),
                    ),
                    Text(s.displayName),
                  ],
                ),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatus = v);
              },
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _submit,
                icon: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  isLoading ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
