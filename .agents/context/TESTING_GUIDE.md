# Testing Guide — Gas Pipeline ERP

> Every module MUST have tests before it is marked ✅ Done.
> Definition of Done (from AGENT_CONTEXT.md) requires unit tests for all UseCases.
> Follow these patterns exactly.

---

## Test Stack

| Tool | Purpose |
|------|---------|
| `flutter_test` | Unit + Widget tests |
| `mocktail` | Mocking repositories and services |
| `riverpod_test` | Testing AsyncNotifier providers |
| `fake_supabase` (if available) or `mocktail` | Mocking Supabase client |

Add to `pubspec.yaml` dev_dependencies:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^0.3.0
  riverpod_test: ^2.0.0
  build_runner: ^2.x.x
```

---

## Folder Structure

```
test/
├── core/
│   ├── utils/
│   │   ├── currency_utils_test.dart
│   │   └── date_utils_test.dart
│   └── errors/
│       └── app_exception_test.dart
│
└── features/
    ├── auth/
    │   └── domain/usecases/
    │       └── login_usecase_test.dart
    ├── projects/
    │   └── domain/usecases/
    │       ├── get_projects_usecase_test.dart
    │       └── create_project_usecase_test.dart
    ├── inventory/
    │   └── domain/usecases/
    │       ├── get_stock_levels_usecase_test.dart
    │       └── record_transaction_usecase_test.dart
    ├── material_requests/
    │   └── domain/usecases/
    │       ├── create_mr_usecase_test.dart
    │       └── approve_mr_usecase_test.dart
    └── ... (one folder per feature)
```

---

## Pattern 1 — UseCase Unit Test

```dart
// test/features/projects/domain/usecases/create_project_usecase_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gas_company/features/projects/domain/repositories/project_repository.dart';
import 'package:gas_company/features/projects/domain/usecases/create_project_usecase.dart';
import 'package:gas_company/features/projects/data/models/project_model.dart';
import 'package:gas_company/core/errors/app_exception.dart';

// Mock the repository
class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository mockRepo;
  late CreateProjectUseCase useCase;

  setUp(() {
    mockRepo = MockProjectRepository();
    useCase = CreateProjectUseCase(mockRepo);
  });

  group('CreateProjectUseCase', () {
    final validParams = CreateProjectParams(
      name: 'Test Project',
      clientId: 1,
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
      assignedEngineerId: 'user-uuid',
    );

    final mockProject = ProjectModel(
      id: 1,
      projectCode: 'PP-2024-0001',
      name: 'Test Project',
      clientId: 1,
      startDate: DateTime(2024, 1, 1),
      status: 'planning',
      assignedEngineerId: 'user-uuid',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('creates project successfully when params are valid', () async {
      when(() => mockRepo.create(validParams))
          .thenAnswer((_) async => mockProject);

      final result = await useCase.call(validParams);

      expect(result.projectCode, startsWith('PP-'));
      expect(result.name, equals('Test Project'));
      verify(() => mockRepo.create(validParams)).called(1);
    });

    test('throws AppException when end date is before start date', () async {
      final invalidParams = CreateProjectParams(
        name: 'Test',
        clientId: 1,
        startDate: DateTime(2024, 12, 31),
        endDate: DateTime(2024, 1, 1), // end before start
        assignedEngineerId: 'user-uuid',
      );

      expect(
        () => useCase.call(invalidParams),
        throwsA(isA<AppException>()),
      );

      verifyNever(() => mockRepo.create(any()));
    });
  });
}
```

---

## Pattern 2 — Inventory UseCase Test (BR-001)

```dart
// test/features/inventory/domain/usecases/record_transaction_usecase_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late MockInventoryRepository mockRepo;
  late RecordTransactionUseCase useCase;

  setUp(() {
    mockRepo = MockInventoryRepository();
    useCase = RecordTransactionUseCase(mockRepo);
  });

  group('RecordTransactionUseCase — BR-001', () {
    test('allows stock_in transaction', () async {
      final params = StockTransactionParams(
        materialId: 1,
        warehouseId: 1,
        type: 'stock_in',
        quantity: 100,
      );

      when(() => mockRepo.recordTransaction(params))
          .thenAnswer((_) async => StockTransactionModel(
                id: 1,
                materialId: 1,
                warehouseId: 1,
                transactionType: 'stock_in',
                quantity: 100,
                createdAt: DateTime.now(),
              ));

      final result = await useCase.call(params);
      expect(result.quantity, equals(100));
    });

    test('throws AppException for negative quantity on stock_out', () async {
      // The DB enforces this but the repository should also guard
      final params = StockTransactionParams(
        materialId: 1,
        warehouseId: 1,
        type: 'stock_out',
        quantity: -50, // invalid
      );

      expect(
        () => useCase.call(params),
        throwsA(isA<AppException>()),
      );
    });
  });
}
```

---

## Pattern 3 — MR Business Rule Tests (BR-012, BR-013)

```dart
// test/features/material_requests/domain/usecases/submit_mr_usecase_test.dart

void main() {
  group('SubmitMrUseCase — BR-012 status flow', () {
    test('draft MR can be submitted', () async {
      when(() => mockRepo.getById(1)).thenAnswer((_) async =>
          mrFixture(status: 'draft'));
      when(() => mockRepo.updateStatus(1, 'submitted'))
          .thenAnswer((_) async => mrFixture(status: 'submitted'));

      final result = await useCase.submit(1);
      expect(result.status, equals('submitted'));
    });

    test('already submitted MR cannot be submitted again', () async {
      when(() => mockRepo.getById(1)).thenAnswer((_) async =>
          mrFixture(status: 'submitted'));

      expect(
        () => useCase.submit(1),
        throwsA(isA<AppException>()),
      );
    });

    test('closed MR cannot be modified — BR-013', () async {
      when(() => mockRepo.getById(1)).thenAnswer((_) async =>
          mrFixture(status: 'closed'));

      expect(
        () => useCase.submit(1),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('BR-013'),
        )),
      );
    });
  });
}

// Helper fixture
MaterialRequestModel mrFixture({required String status}) =>
    MaterialRequestModel(
      id: 1,
      mrNumber: 'MR-2024-0001',
      projectId: 1,
      status: status,
      requestedBy: 'user-uuid',
      requiredDate: DateTime(2024, 3, 15),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
```

---

## Pattern 4 — Provider Test (Riverpod)

```dart
// test/features/projects/presentation/providers/project_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test('projectListProvider loads projects successfully', () async {
    final mockRepo = MockProjectRepository();
    when(() => mockRepo.getAll()).thenAnswer((_) async => [
          mockProject,
        ]);

    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(projectListProvider.future);
    expect(state, hasLength(1));
    expect(state.first.name, equals('Test Project'));
  });

  test('projectListProvider shows error on repository failure', () async {
    final mockRepo = MockProjectRepository();
    when(() => mockRepo.getAll()).thenThrow(
      AppException('Database error'),
    );

    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(projectListProvider);
    await expectLater(
      container.read(projectListProvider.future),
      throwsA(isA<AppException>()),
    );
  });
}
```

---

## Pattern 5 — Currency Utility Test

```dart
// test/core/utils/currency_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:gas_company/core/utils/currency_utils.dart';

void main() {
  group('CurrencyFormat extension — AD-027', () {
    test('formats Indian rupee correctly', () {
      expect(1250000.inr, equals('₹12,50,000.00'));
      expect(100.inr, equals('₹100.00'));
      expect(0.inr, equals('₹0.00'));
    });

    test('formats compact rupee values for dashboard', () {
      expect(1250000.inrCompact, contains('12.5L'));
      expect(10000000.inrCompact, contains('1Cr'));
    });
  });
}
```

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Run a specific test file
flutter test test/features/projects/domain/usecases/create_project_usecase_test.dart

# Run tests matching a pattern
flutter test --name "BR-012"
```

---

## Minimum Test Coverage Per Module

Before marking a module ✅ Done, ensure:

```
□ All UseCase classes have at least 1 happy-path test
□ All UseCase classes have at least 1 error/edge-case test
□ Business rule violations (BR-XXX) are explicitly tested
□ Status flow transitions are tested (valid + invalid)
□ Repository is mocked — never real Supabase in unit tests
□ Provider tests cover: loading state, success state, error state
□ Currency and date formatting utilities tested if used
```

---

## Test Naming Convention

```
[UseCaseName] — [BusinessRuleCode or scenario]
e.g.:
  CreateProjectUseCase — creates project with valid params
  CreateProjectUseCase — throws when end date before start date
  SubmitMrUseCase — BR-012 draft to submitted transition
  SubmitMrUseCase — BR-013 closed MR cannot be submitted
```
