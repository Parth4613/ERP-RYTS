#!/bin/bash
# ============================================================
# FEATURE SCAFFOLD — Gas Pipeline ERP
# Usage: bash .agents/templates/feature_scaffold.sh <feature_name>
# Example: bash .agents/templates/feature_scaffold.sh material_requests
#
# Creates the full Clean Architecture folder structure for one feature.
# Run from the Flutter project root (where lib/ lives).
# ============================================================

set -e

FEATURE="${1:-}"

if [ -z "$FEATURE" ]; then
  echo "❌ Usage: bash feature_scaffold.sh <feature_name>"
  echo "   Example: bash feature_scaffold.sh material_requests"
  exit 1
fi

BASE="lib/features/$FEATURE"

if [ -d "$BASE" ]; then
  echo "⚠️  Feature '$FEATURE' already exists at $BASE"
  exit 1
fi

echo "🏗  Scaffolding feature: $FEATURE"

# ---- Directory structure ----
mkdir -p "$BASE/data/models"
mkdir -p "$BASE/data/datasources"
mkdir -p "$BASE/data/repositories"
mkdir -p "$BASE/domain/entities"
mkdir -p "$BASE/domain/repositories"
mkdir -p "$BASE/domain/usecases"
mkdir -p "$BASE/presentation/providers"
mkdir -p "$BASE/presentation/screens"
mkdir -p "$BASE/presentation/widgets"

# Convert snake_case to CamelCase for class names
CAMEL=$(echo "$FEATURE" | sed -r 's/(^|_)([a-z])/\U\2/g')

# ---- data/models/<feature>_model.dart ----
cat > "$BASE/data/models/${FEATURE}_model.dart" << EOF
import 'package:freezed_annotation/freezed_annotation.dart';

part '${FEATURE}_model.freezed.dart';
part '${FEATURE}_model.g.dart';

@freezed
class ${CAMEL}Model with _\$${CAMEL}Model {
  const factory ${CAMEL}Model({
    required int id,
    // TODO: add fields
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    @Default(true) bool isActive,
  }) = _${CAMEL}Model;

  factory ${CAMEL}Model.fromJson(Map<String, dynamic> json) =>
      _\$${CAMEL}ModelFromJson(json);
}
EOF

# ---- domain/repositories/<feature>_repository.dart ----
cat > "$BASE/domain/repositories/${FEATURE}_repository.dart" << EOF
import '../../data/models/${FEATURE}_model.dart';

abstract class ${CAMEL}Repository {
  Future<List<${CAMEL}Model>> getAll();
  Future<${CAMEL}Model?> getById(int id);
  Future<${CAMEL}Model> create(Map<String, dynamic> payload);
  Future<${CAMEL}Model> update(int id, Map<String, dynamic> payload);
  Future<void> softDelete(int id);
  Stream<List<${CAMEL}Model>> watchAll();
}
EOF

# ---- data/repositories/<feature>_repository_impl.dart ----
cat > "$BASE/data/repositories/${FEATURE}_repository_impl.dart" << EOF
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/repositories/base_repository.dart';
import '../../data/models/${FEATURE}_model.dart';
import '../../domain/repositories/${FEATURE}_repository.dart';

class ${CAMEL}RepositoryImpl extends BaseRepository<${CAMEL}Model>
    implements ${CAMEL}Repository {

  ${CAMEL}RepositoryImpl(super.client);

  @override
  String get tableName => '${FEATURE}';  // TODO: verify table name

  @override
  ${CAMEL}Model fromJson(Map<String, dynamic> json) =>
      ${CAMEL}Model.fromJson(json);

  // TODO: override methods that need custom queries (joins, filters)
  // Example:
  // @override
  // Future<List<${CAMEL}Model>> getAll() async {
  //   final data = await client
  //       .from(tableName)
  //       .select('*, related_table(*)')
  //       .isFilter('deleted_at', null)
  //       .order('created_at', ascending: false);
  //   return data.map((e) => fromJson(e)).toList();
  // }
}
EOF

# ---- domain/usecases/get_all_<feature>_usecase.dart ----
cat > "$BASE/domain/usecases/get_all_${FEATURE}_usecase.dart" << EOF
import '../models/${FEATURE}_model.dart';  // adjust path
import '../repositories/${FEATURE}_repository.dart';

class GetAll${CAMEL}UseCase {
  final ${CAMEL}Repository _repository;
  const GetAll${CAMEL}UseCase(this._repository);

  Future<List<${CAMEL}Model>> call() => _repository.getAll();
}
EOF

# ---- presentation/providers/<feature>_provider.dart ----
cat > "$BASE/presentation/providers/${FEATURE}_provider.dart" << EOF
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/${FEATURE}_model.dart';
import '../../data/repositories/${FEATURE}_repository_impl.dart';
import '../../domain/repositories/${FEATURE}_repository.dart';
import '../../domain/usecases/get_all_${FEATURE}_usecase.dart';

part '${FEATURE}_provider.g.dart';

@riverpod
${CAMEL}Repository ${FEATURE}Repository(${CAMEL}RepositoryRef ref) =>
    ${CAMEL}RepositoryImpl(Supabase.instance.client);

@riverpod
class ${CAMEL}List extends _\$${CAMEL}List {
  @override
  Future<List<${CAMEL}Model>> build() async {
    final repo = ref.watch(${FEATURE}RepositoryProvider);
    return GetAll${CAMEL}UseCase(repo).call();
  }

  // TODO: add create, update, softDelete methods
  // See .agents/templates/base_provider.dart for patterns
}
EOF

# ---- presentation/screens/<feature>_list_screen.dart ----
cat > "$BASE/presentation/screens/${FEATURE}_list_screen.dart" << EOF
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/loading_skeleton.dart';
import '../providers/${FEATURE}_provider.dart';
import '../widgets/${FEATURE}_list_item.dart';

class ${CAMEL}ListScreen extends ConsumerWidget {
  const ${CAMEL}ListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(${FEATURE}ListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('${CAMEL}'),  // TODO: proper title
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {/* TODO: filters */},
          ),
        ],
      ),
      body: asyncData.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No records yet',
                subtitle: 'Create the first one to get started.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (ctx, i) => ${CAMEL}ListItem(item: items[i]),
              ),
        loading: () => const LoadingSkeleton(itemCount: 8),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.toString(), style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(${FEATURE}ListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {/* TODO: navigate to create screen */},
        label: const Text('New'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
EOF

# ---- presentation/widgets/<feature>_list_item.dart ----
cat > "$BASE/presentation/widgets/${FEATURE}_list_item.dart" << EOF
import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../data/models/${FEATURE}_model.dart';

class ${CAMEL}ListItem extends StatelessWidget {
  final ${CAMEL}Model item;
  const ${CAMEL}ListItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceAlt,
      child: ListTile(
        title: Text('ID: \${item.id}'),  // TODO: use proper field
        subtitle: Text(item.createdAt.toString()),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () {/* TODO: navigate to detail */},
      ),
    );
  }
}
EOF

echo ""
echo "✅ Feature '$FEATURE' scaffolded at $BASE"
echo ""
echo "📋 Next steps:"
echo "  1. Add fields to ${BASE}/data/models/${FEATURE}_model.dart"
echo "  2. Update table name in ${BASE}/data/repositories/${FEATURE}_repository_impl.dart"
echo "  3. Run: flutter pub run build_runner build --delete-conflicting-outputs"
echo "  4. Add route to lib/core/router/app_router.dart"
echo "  5. Add repository provider to ${BASE}/presentation/providers/${FEATURE}_provider.dart"
echo "  6. Build create/edit screen and detail screen"
echo "  7. Add to PROGRESS.md"