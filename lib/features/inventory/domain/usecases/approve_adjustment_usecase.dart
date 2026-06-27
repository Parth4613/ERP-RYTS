import '../repositories/inventory_repository.dart';

/// Approves a pending inventory adjustment.
/// DB trigger automatically creates stock_transaction and updates stock_balances.
class ApproveAdjustmentUseCase {
  final InventoryRepository _repository;
  const ApproveAdjustmentUseCase(this._repository);

  Future<void> call(int adjustmentId) =>
      _repository.approveAdjustment(adjustmentId);
}
