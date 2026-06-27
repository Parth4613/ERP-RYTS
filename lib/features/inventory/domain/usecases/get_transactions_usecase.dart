import '../../data/models/stock_transaction_model.dart';
import '../repositories/inventory_repository.dart';

/// Fetches stock transaction history with optional filters.
/// Used by the transaction history screen.
class GetTransactionsUseCase {
  final InventoryRepository _repository;
  const GetTransactionsUseCase(this._repository);

  Future<List<StockTransactionModel>> call({
    int? materialId,
    int? warehouseId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _repository.getTransactions(
        materialId: materialId,
        warehouseId: warehouseId,
        type: type,
        fromDate: fromDate,
        toDate: toDate,
      );
}
