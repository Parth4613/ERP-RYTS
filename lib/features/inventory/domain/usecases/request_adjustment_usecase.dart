import '../../../../core/errors/app_exception.dart';
import '../../data/models/inventory_adjustment_model.dart';
import '../repositories/inventory_repository.dart';

/// Requests an inventory adjustment.
/// BR-004: Adjustments require approval. Validates input before calling repository.
class RequestAdjustmentUseCase {
  final InventoryRepository _repository;
  const RequestAdjustmentUseCase(this._repository);

  Future<InventoryAdjustmentModel> call(CreateAdjustmentParams params) async {
    // Validate: quantity must not be zero
    if (params.adjustmentQty == 0) {
      throw const AppException('Adjustment quantity cannot be zero');
    }

    // Validate: reason is required
    if (params.reason.trim().isEmpty) {
      throw const AppException('Reason is required for inventory adjustments');
    }

    return _repository.requestAdjustment(params);
  }
}
