// ============================================================
// BASE USE CASE TEMPLATES — Gas Pipeline ERP
// Copy and extend these for every use case in every feature.
// File: .agents/templates/base_usecase.dart
// ============================================================

// -------------------------------------------------------
// PATTERN 1 — Simple future use case (no params)
// -------------------------------------------------------
// class GetAllProjectsUseCase {
//   final ProjectRepository _repository;
//   const GetAllProjectsUseCase(this._repository);
//   Future<List<ProjectModel>> call() => _repository.getAll();
// }

// -------------------------------------------------------
// PATTERN 2 — Use case with typed params
// -------------------------------------------------------
// class CreateProjectUseCase {
//   final ProjectRepository _repository;
//   const CreateProjectUseCase(this._repository);
//
//   Future<ProjectModel> call(CreateProjectParams params) async {
//     // Validate before calling repository
//     if (params.endDate != null && params.endDate!.isBefore(params.startDate)) {
//       throw AppException('End date cannot be before start date');
//     }
//     return _repository.create(params);
//   }
// }

// -------------------------------------------------------
// PARAMS PATTERN — Immutable params with Freezed
// -------------------------------------------------------
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../templates/base_usecase.freezed.dart';

// ---- Example Params ----
@freezed
class CreateProjectParams with _$CreateProjectParams {
  const factory CreateProjectParams({
    required String name,
    required int clientId,
    required DateTime startDate,
    DateTime? endDate,
    String? location,
    double? contractValue,
    required String assignedEngineerId,
    String? description,
  }) = _CreateProjectParams;
}

@freezed
class UpdateProjectParams with _$UpdateProjectParams {
  const factory UpdateProjectParams({
    String? name,
    DateTime? endDate,
    String? location,
    double? contractValue,
    String? assignedEngineerId,
    String? status,
    String? description,
  }) = _UpdateProjectParams;
}

@freezed
class CreateMrParams with _$CreateMrParams {
  const factory CreateMrParams({
    required int projectId,
    int? zoneId,
    required DateTime requiredDate,
    required String priority,
    String? remarks,
    required List<CreateMrItemParams> items,
  }) = _CreateMrParams;
}

@freezed
class CreateMrItemParams with _$CreateMrItemParams {
  const factory CreateMrItemParams({
    required int materialId,
    int? boqItemId,
    required double requestedQty,
    required String unitOfMeasure,
    String? remarks,
  }) = _CreateMrItemParams;
}

@freezed
class CreateIssueSlipParams with _$CreateIssueSlipParams {
  const factory CreateIssueSlipParams({
    required int mrId,
    required int projectId,
    required int warehouseId,
    required List<IssueSlipItemParams> items,
    String? notes,
  }) = _CreateIssueSlipParams;
}

@freezed
class IssueSlipItemParams with _$IssueSlipItemParams {
  const factory IssueSlipItemParams({
    required int mrItemId,
    required int materialId,
    required int warehouseId,
    int? boqItemId,
    required double requestedQty,
    required double issuedQty,
    required String unitOfMeasure,
  }) = _IssueSlipItemParams;
}

@freezed
class CreateConsumptionParams with _$CreateConsumptionParams {
  const factory CreateConsumptionParams({
    required int issueSlipItemId,
    int? boqItemId,
    required int projectId,
    int? zoneId,
    required int materialId,
    required double consumedQty,
    required DateTime entryDate,
    String? workDescription,
  }) = _CreateConsumptionParams;
}

@freezed
class StockAdjustmentParams with _$StockAdjustmentParams {
  const factory StockAdjustmentParams({
    required int materialId,
    required int warehouseId,
    required double adjustmentQty,
    required String reason,
  }) = _StockAdjustmentParams;
}

@freezed
class CreatePoParams with _$CreatePoParams {
  const factory CreatePoParams({
    int? prId,
    required int supplierId,
    int? projectId,
    required DateTime poDate,
    DateTime? expectedDelivery,
    String? paymentTerms,
    String? termsConditions,
    required List<CreatePoItemParams> items,
  }) = _CreatePoParams;
}

@freezed
class CreatePoItemParams with _$CreatePoItemParams {
  const factory CreatePoItemParams({
    int? prItemId,
    required int materialId,
    required double orderedQty,
    required double unitRate,
    required String unitOfMeasure,
  }) = _CreatePoItemParams;
}

@freezed
class CreateMrnParams with _$CreateMrnParams {
  const factory CreateMrnParams({
    required int poId,
    required int supplierId,
    required DateTime receivedDate,
    String? vehicleNumber,
    String? dcNumber,
    String? invoiceNumber,
    String? notes,
    required List<CreateMrnItemParams> items,
  }) = _CreateMrnParams;
}

@freezed
class CreateMrnItemParams with _$CreateMrnItemParams {
  const factory CreateMrnItemParams({
    required int poItemId,
    required int materialId,
    required int warehouseId,
    required double orderedQty,
    required double receivedQty,
    required double acceptedQty,
    required double rejectedQty,
    String? rejectionReason,
    required String unitOfMeasure,
  }) = _CreateMrnItemParams;
}
