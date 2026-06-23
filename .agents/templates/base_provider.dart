// ============================================================
// BASE PROVIDER PATTERNS — Gas Pipeline ERP
// Copy and adapt for every feature's provider.
// File: .agents/templates/base_provider.dart
// ============================================================
//
// RULES:
// - Always use AsyncNotifier (not StateNotifier, not ChangeNotifier)
// - Never call Supabase directly from a provider
// - Use ref.invalidate() to force refresh
// - Use AsyncValue.guard() for all async mutations
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// -------------------------------------------------------
// PATTERN 1 — List provider with CRUD (most common)
// -------------------------------------------------------
//
// @riverpod
// class ProjectList extends _$ProjectList {
//   @override
//   Future<List<ProjectModel>> build() async {
//     final repo = ref.watch(projectRepositoryProvider);
//     return GetAllProjectsUseCase(repo).call();
//   }
//
//   Future<void> create(CreateProjectParams params) async {
//     state = const AsyncLoading();
//     state = await AsyncValue.guard(() async {
//       await CreateProjectUseCase(ref.read(projectRepositoryProvider)).call(params);
//       return _reload();
//     });
//   }
//
//   Future<void> update(int id, UpdateProjectParams params) async {
//     state = await AsyncValue.guard(() async {
//       await UpdateProjectUseCase(ref.read(projectRepositoryProvider)).call(id, params);
//       return _reload();
//     });
//   }
//
//   Future<void> softDelete(int id) async {
//     state = await AsyncValue.guard(() async {
//       await ref.read(projectRepositoryProvider).softDelete(id);
//       return _reload();
//     });
//   }
//
//   Future<List<ProjectModel>> _reload() =>
//       GetAllProjectsUseCase(ref.read(projectRepositoryProvider)).call();
// }

// -------------------------------------------------------
// PATTERN 2 — Single item provider (detail screen)
// -------------------------------------------------------
//
// @riverpod
// class ProjectDetail extends _$ProjectDetail {
//   @override
//   Future<ProjectModel?> build(int id) async {
//     final repo = ref.watch(projectRepositoryProvider);
//     return repo.getById(id);
//   }
//
//   Future<void> updateStatus(String newStatus) async {
//     state = await AsyncValue.guard(() async {
//       await ref.read(projectRepositoryProvider)
//           .update(arg, UpdateProjectParams(status: newStatus));
//       return ref.read(projectRepositoryProvider).getById(arg);
//     });
//   }
// }

// -------------------------------------------------------
// PATTERN 3 — Realtime stream provider
// -------------------------------------------------------
//
// @riverpod
// Stream<List<MaterialRequestModel>> pendingMrStream(PendingMrStreamRef ref) {
//   final repo = ref.watch(mrRepositoryProvider);
//   return repo.watchByStatus(['approved']);  // store sees approved MRs
// }

// -------------------------------------------------------
// PATTERN 4 — Filter/search state provider
// -------------------------------------------------------
//
// @riverpod
// class MrFilter extends _$MrFilter {
//   @override
//   MrFilterState build() => const MrFilterState();
//
//   void setStatus(String? status) =>
//       state = state.copyWith(status: status);
//   void setProject(int? projectId) =>
//       state = state.copyWith(projectId: projectId);
//   void setSearch(String query) =>
//       state = state.copyWith(searchQuery: query);
//   void reset() => state = const MrFilterState();
// }
//
// @freezed
// class MrFilterState with _$MrFilterState {
//   const factory MrFilterState({
//     String? status,
//     int? projectId,
//     @Default('') String searchQuery,
//     String? priority,
//   }) = _MrFilterState;
// }

// -------------------------------------------------------
// PATTERN 5 — Auth / current user provider
// -------------------------------------------------------
//
// @riverpod
// Stream<AuthState> authState(AuthStateRef ref) {
//   return Supabase.instance.client.auth.onAuthStateChange;
// }
//
// @riverpod
// User? currentUser(CurrentUserRef ref) {
//   return Supabase.instance.client.auth.currentUser;
// }
//
// @riverpod
// String? currentUserRole(CurrentUserRoleRef ref) {
//   final user = ref.watch(currentUserProvider);
//   return user?.appMetadata['role'] as String?;
// }
//
// @riverpod
// bool isAdminOrOwner(IsAdminOrOwnerRef ref) {
//   final role = ref.watch(currentUserRoleProvider);
//   return role == 'admin' || role == 'owner';
// }

// -------------------------------------------------------
// PATTERN 6 — Dashboard aggregated data provider
// -------------------------------------------------------
//
// @riverpod
// Future<DashboardData> dashboardData(DashboardDataRef ref) async {
//   final client = ref.watch(supabaseClientProvider);
//
//   // Run queries in parallel
//   final results = await Future.wait([
//     client.from('projects')
//       .select('status, count(*)')
//       .isFilter('deleted_at', null)
//       .execute(),
//     client.from('inventory_summary')
//       .select('stock_status, count(*), sum(quantity)')
//       .execute(),
//     client.from('approval_workflows')
//       .select('count(*)')
//       .eq('status', 'pending')
//       .execute(),
//   ]);
//
//   return DashboardData.fromResults(results);
// }

// -------------------------------------------------------
// PATTERN 7 — PDF generation provider
// -------------------------------------------------------
//
// @riverpod
// class IssueSlipPdf extends _$IssueSlipPdf {
//   @override
//   AsyncValue<Uint8List?> build(int slipId) => const AsyncData(null);
//
//   Future<void> generate() async {
//     state = const AsyncLoading();
//     state = await AsyncValue.guard(() async {
//       final slip = await ref.read(issueSlipDetailProvider(slipId).future);
//       if (slip == null) throw AppException('Issue slip not found');
//       final bytes = await generateIssueSlipPdf(slip);
//
//       // Upload to Supabase Storage
//       final url = await ref.read(storageServiceProvider)
//           .uploadPdf(bytes, 'issue-slips/${slip.slipNumber}.pdf');
//
//       // Save URL to DB
//       await ref.read(issueSlipRepositoryProvider)
//           .update(slipId, {'pdf_url': url});
//
//       return bytes;
//     });
//   }
// }

// -------------------------------------------------------
// REPOSITORY PROVIDER PATTERN (put in each feature's providers file)
// -------------------------------------------------------
//
// @riverpod
// SupabaseClient supabaseClient(SupabaseClientRef ref) =>
//     Supabase.instance.client;
//
// @riverpod
// ProjectRepository projectRepository(ProjectRepositoryRef ref) =>
//     ProjectRepositoryImpl(ref.watch(supabaseClientProvider));
//
// @riverpod
// InventoryRepository inventoryRepository(InventoryRepositoryRef ref) =>
//     InventoryRepositoryImpl(ref.watch(supabaseClientProvider));
