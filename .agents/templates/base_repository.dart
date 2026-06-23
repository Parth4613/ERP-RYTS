// ============================================================
// REPOSITORY BASE — Gas Pipeline ERP
// All repositories extend this class.
// ============================================================
//
// Usage:
//   class ProjectRepository extends BaseRepository<ProjectModel> {
//     ProjectRepository(super.client);
//
//     @override
//     String get tableName => 'projects';
//
//     @override
//     ProjectModel fromJson(Map<String, dynamic> json) => ProjectModel.fromJson(json);
//   }
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BaseRepository<T> {
  final SupabaseClient client;

  const BaseRepository(this.client);

  String get tableName;
  T fromJson(Map<String, dynamic> json);

  // Base query — always excludes soft-deleted rows (AD-002)
  SupabaseQueryBuilder get _query =>
      client.from(tableName).select().isFilter('deleted_at', null);

  Future<List<T>> getAll() async {
    final data = await _query;
    return data.map((e) => fromJson(e)).toList();
  }

  Future<T?> getById(int id) async {
    final data = await _query.eq('id', id).maybeSingle();
    return data == null ? null : fromJson(data);
  }

  Future<T> create(Map<String, dynamic> payload) async {
    final data = await client
        .from(tableName)
        .insert({
          ...payload,
          'created_by': client.auth.currentUser?.id,
          'updated_by': client.auth.currentUser?.id,
        })
        .select()
        .single();
    return fromJson(data);
  }

  Future<T> update(int id, Map<String, dynamic> payload) async {
    final data = await client
        .from(tableName)
        .update({
          ...payload,
          'updated_by': client.auth.currentUser?.id,
          // updated_at handled by DB trigger
        })
        .eq('id', id)
        .select()
        .single();
    return fromJson(data);
  }

  /// Soft delete — sets deleted_at, never issues a DELETE (AD-002, DB-004)
  Future<void> softDelete(int id) async {
    await client.from(tableName).update({
      'deleted_at': DateTime.now().toIso8601String(),
      'is_active': false,
      'updated_by': client.auth.currentUser?.id,
    }).eq('id', id);
  }

  // Realtime stream — excludes soft-deleted rows
  Stream<List<T>> stream({String orderBy = 'created_at'}) {
    return client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order(orderBy)
        .map((data) => data
            .where((e) => e['deleted_at'] == null)
            .map((e) => fromJson(e))
            .toList());
  }
}
