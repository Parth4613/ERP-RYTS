import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/models/project.dart';

/// All projects provider
final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final response = await supabase
      .from('projects')
      .select('*, profiles!assigned_engineer_id(name)')
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => Project.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Single project provider
final projectByIdProvider =
    FutureProvider.family<Project?, String>((ref, id) async {
  final response = await supabase
      .from('projects')
      .select('*, profiles!assigned_engineer_id(name)')
      .eq('id', id)
      .maybeSingle();
  if (response == null) return null;
  return Project.fromJson(response);
});

/// Project CRUD operations
class ProjectNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> createProject({
    required String name,
    String? description,
    String? assignedEngineerId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await supabase.from('projects').insert({
        'name': name,
        'description': description,
        'assigned_engineer_id': assignedEngineerId,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
    String? assignedEngineerId,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (assignedEngineerId != null) {
        updates['assigned_engineer_id'] = assignedEngineerId;
      }
      if (status != null) updates['status'] = status;

      await supabase.from('projects').update(updates).eq('id', id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final projectNotifierProvider =
    NotifierProvider<ProjectNotifier, AsyncValue<void>>(ProjectNotifier.new);
