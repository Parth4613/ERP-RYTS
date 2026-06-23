Flutter Patterns — Gas Pipeline ERP

> Every Flutter file follows these patterns exactly.
> Do not use StatefulWidget for business logic. Do not call Supabase from UI.

---

## Folder Structure

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        ← tokens from UI_SPEC.md
│   │   ├── app_text_styles.dart
│   │   └── app_constants.dart     ← thresholds, enums
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── failure.dart
│   ├── router/
│   │   └── app_router.dart        ← all Go Router routes
│   ├── services/
│   │   └── supabase_service.dart  ← Supabase client singleton
│   ├── utils/
│   │   ├── currency_utils.dart    ← ₹ formatting
│   │   ├── date_utils.dart
│   │   └── pdf_utils.dart
│   └── widgets/                   ← shared reusable widgets
│       ├── app_card.dart
│       ├── kpi_card.dart
│       ├── status_chip.dart
│       ├── erp_data_table.dart
│       ├── empty_state.dart
│       ├── loading_skeleton.dart
│       ├── app_alert_banner.dart
│       └── confirmation_dialog.dart
│
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── models/auth_model.dart
    │   │   ├── datasources/auth_remote_datasource.dart
    │   │   └── repositories/auth_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/user_entity.dart
    │   │   ├── repositories/auth_repository.dart
    │   │   └── usecases/login_usecase.dart
    │   └── presentation/
    │       ├── providers/auth_provider.dart
    │       ├── screens/login_screen.dart
    │       └── widgets/
    │
    ├── projects/          ← same structure as auth
    ├── inventory/
    ├── material_requests/
    ├── procurement/
    ├── suppliers/
    ├── mrn/
    ├── consumption/
    ├── costs/
    ├── documents/
    ├── approvals/
    ├── reports/
    └── dashboard/
```

---

## Model Pattern (Freezed + JsonSerializable)

```dart
// features/projects/data/models/project_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_model.freezed.dart';
part 'project_model.g.dart';

@freezed
class ProjectModel with _$ProjectModel {
  const factory ProjectModel({
    required int id,
    required String projectCode,
    required String name,
    required int clientId,
    String? clientName,        // joined from clients table
    String? location,
    @JsonKey(fromJson: _parseDecimal) double? contractValue,
    required DateTime startDate,
    DateTime? endDate,
    required String status,
    required String assignedEngineerId,
    String? assignedEngineerName,  // joined
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    @Default(true) bool isActive,
  }) = _ProjectModel;

  factory ProjectModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectModelFromJson(json);
}

double? _parseDecimal(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
```

---

## Repository Pattern

```dart
// features/projects/domain/repositories/project_repository.dart
abstract class ProjectRepository {
  Future<List<ProjectModel>> getAll();
  Future<ProjectModel?> getById(int id);
  Future<ProjectModel> create(CreateProjectParams params);
  Future<ProjectModel> update(int id, UpdateProjectParams params);
  Future<void> softDelete(int id);
  Stream<List<ProjectModel>> watchAll();
  Future<List<ProjectModel>> getByEngineer(String engineerId);
}

// features/projects/data/repositories/project_repository_impl.dart
class ProjectRepositoryImpl extends BaseRepository<ProjectModel>
    implements ProjectRepository {

  ProjectRepositoryImpl(super.client);

  @override
  String get tableName => 'projects';

  @override
  ProjectModel fromJson(Map<String, dynamic> json) =>
      ProjectModel.fromJson(json);

  @override
  Future<List<ProjectModel>> getAll() async {
    final data = await client
        .from('projects')
        .select('*, clients(name), users!assigned_engineer_id(full_name)')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return data.map((e) => ProjectModel.fromJson(e)).toList();
  }

  @override
  Future<List<ProjectModel>> getByEngineer(String engineerId) async {
    final data = await client
        .from('projects')
        .select('*, clients(name)')
        .eq('assigned_engineer_id', engineerId)
        .isFilter('deleted_at', null);
    return data.map((e) => ProjectModel.fromJson(e)).toList();
  }
}
```

---

## UseCase Pattern

```dart
// features/projects/domain/usecases/get_projects_usecase.dart
class GetProjectsUseCase {
  final ProjectRepository _repository;
  const GetProjectsUseCase(this._repository);

  Future<List<ProjectModel>> call() => _repository.getAll();
}

// features/projects/domain/usecases/create_project_usecase.dart
class CreateProjectUseCase {
  final ProjectRepository _repository;
  const CreateProjectUseCase(this._repository);

  Future<ProjectModel> call(CreateProjectParams params) async {
    // Validate business rules before calling repository
    if (params.endDate != null && params.endDate!.isBefore(params.startDate)) {
      throw AppException('End date cannot be before start date');
    }
    return _repository.create(params);
  }
}
```

---

## Provider Pattern (AsyncNotifier)

```dart
// features/projects/presentation/providers/project_provider.dart

@riverpod
class ProjectList extends _$ProjectList {
  @override
  Future<List<ProjectModel>> build() async {
    final repo = ref.watch(projectRepositoryProvider);
    final useCase = GetProjectsUseCase(repo);
    return useCase.call();
  }

  Future<void> createProject(CreateProjectParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(projectRepositoryProvider);
      await CreateProjectUseCase(repo).call(params);
      return GetProjectsUseCase(repo).call();
    });
  }

  Future<void> softDelete(int id) async {
    state = await AsyncValue.guard(() async {
      final repo = ref.read(projectRepositoryProvider);
      await repo.softDelete(id);
      return GetProjectsUseCase(repo).call();
    });
  }
}

// Repository provider
@riverpod
ProjectRepository projectRepository(ProjectRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProjectRepositoryImpl(client);
}
```

---

## Screen Pattern

```dart
// features/projects/presentation/screens/project_list_screen.dart

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context, ref),
          ),
        ],
      ),
      body: Column(children: [
        _SearchBar(ref: ref),
        _FilterChips(ref: ref),
        Expanded(
          child: projectsAsync.when(
            data: (projects) => projects.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_open,
                    title: 'No Projects Yet',
                    subtitle: 'Create your first project to get started',
                  )
                : _ProjectList(projects: projects),
            loading: () => const LoadingSkeleton(itemCount: 6),
            error: (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(projectListProvider),
            ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/projects/create'),
        label: const Text('New Project'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## Supabase Realtime Pattern

```dart
// Watch a table for real-time updates
@riverpod
Stream<List<ProjectModel>> projectStream(ProjectStreamRef ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchAll();  // uses BaseRepository.stream()
}

// In screen:
final projectsAsync = ref.watch(projectStreamProvider);
```

---

## Error Handling Pattern

```dart
// core/errors/app_exception.dart
class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});

  @override
  String toString() => message;

  factory AppException.fromSupabase(PostgrestException e) {
    return switch(e.code) {
      '23505'  => AppException('This record already exists'),
      '23503'  => AppException('Related record not found'),
      'P0001'  => AppException(e.message),  // custom business rule errors
      _        => AppException('Database error: ${e.message}'),
    };
  }
}

// In repository:
try {
  final data = await client.from('projects').insert(payload).select().single();
  return ProjectModel.fromJson(data);
} on PostgrestException catch (e) {
  throw AppException.fromSupabase(e);
}
```

---

## PDF Generation Pattern (Issue Slip)

```dart
// core/utils/pdf_utils.dart
Future<Uint8List> generateIssueSlipPdf(IssueSlipModel slip) async {
  final pdf = pw.Document();

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (ctx) => pw.Column(children: [
      // Header
      pw.Row(children: [
        pw.Text('ISSUE SLIP', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Spacer(),
        pw.Text(slip.slipNumber, style: pw.TextStyle(fontSize: 14)),
      ]),
      pw.Divider(),

      // Project info
      _buildInfoRow('Project', slip.projectName),
      _buildInfoRow('Zone', slip.zoneName ?? '-'),
      _buildInfoRow('Engineer', slip.engineerName),
      _buildInfoRow('Date', DateFormat('dd MMM yyyy').format(slip.issuedAt)),
      pw.Divider(),

      // Items table
      pw.Table(
        border: pw.TableBorder.all(),
        children: [
          pw.TableRow(children: ['Material', 'Unit', 'Requested', 'Issued']
              .map((h) => pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))
              .toList()),
          ...slip.items.map((item) => pw.TableRow(children: [
            pw.Text(item.materialName),
            pw.Text(item.unit),
            pw.Text(item.requestedQty.toString()),
            pw.Text(item.issuedQty.toString()),
          ])),
        ],
      ),
      pw.SizedBox(height: 40),

      // Signatures
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureLine('Issued By (Store)'),
          _buildSignatureLine('Received By (Engineer)'),
        ],
      ),
    ]),
  ));

  return pdf.save();
}

// Share via WhatsApp
Future<void> shareViaWhatsApp(Uint8List pdfBytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(pdfBytes);
  await Share.shareXFiles([XFile(file.path)], text: 'Issue Slip - $filename');
}
```

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.x.x

  # State + Architecture
  flutter_riverpod: ^2.x.x
  riverpod_annotation: ^2.x.x
  go_router: ^13.x.x

  # Models
  freezed_annotation: ^2.x.x
  json_annotation: ^4.x.x

  # UI
  fl_chart: ^0.x.x

  # PDF + Sharing
  pdf: ^3.x.x
  printing: ^5.x.x
  share_plus: ^7.x.x

  # Excel Export
  excel: ^4.x.x

  # Camera / Scanner
  mobile_scanner: ^5.x.x
  qr_flutter: ^4.x.x
  image_picker: ^1.x.x

  # Location
  geolocator: ^11.x.x

  # Utils
  intl: ^0.x.x
  url_launcher: ^6.x.x
  path_provider: ^2.x.x

dev_dependencies:
  build_runner: ^2.x.x
  freezed: ^2.x.x
  json_serializable: ^6.x.x
  riverpod_generator: ^2.x.x
  flutter_test:
    sdk: flutter
```