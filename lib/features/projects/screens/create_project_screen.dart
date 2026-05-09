import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/theme/app_theme.dart';
import 'package:gas_company/features/auth/providers/auth_provider.dart';
import 'package:gas_company/features/projects/providers/project_provider.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});
  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedEngineerId;

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(projectNotifierProvider.notifier).createProject(
      name: _nameCtrl.text.trim(), description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(), assignedEngineerId: _selectedEngineerId);
    final state = ref.read(projectNotifierProvider);
    if (!state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project created successfully'), backgroundColor: AppColors.success));
      Navigator.pop(context);
    } else if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${state.error}'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineers = ref.watch(engineersProvider);
    final isLoading = ref.watch(projectNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Project Name', prefixIcon: Icon(Icons.business_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (Optional)', prefixIcon: Icon(Icons.description_outlined)),
            maxLines: 3),
          const SizedBox(height: 16),
          engineers.when(
            data: (list) => DropdownButtonFormField<String>(
              value: _selectedEngineerId, decoration: const InputDecoration(labelText: 'Assign Engineer', prefixIcon: Icon(Icons.person_outline)),
              items: [const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))],
              onChanged: (v) => setState(() => _selectedEngineerId = v)),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading engineers: $e'),
          ),
          const SizedBox(height: 32),
          SizedBox(height: 52, child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Create Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        ])),
      ),
    );
  }
}
