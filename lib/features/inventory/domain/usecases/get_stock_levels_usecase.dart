import '../../data/models/inventory_summary_model.dart';
import '../repositories/inventory_repository.dart';

/// Fetches stock levels with optional filters.
/// Used by the stock list screen.
class GetStockLevelsUseCase {
  final InventoryRepository _repository;
  const GetStockLevelsUseCase(this._repository);

  Future<List<InventorySummaryModel>> call({
    int? warehouseId,
    int? categoryId,
    String? search,
    String? stockStatus,
  }) =>
      _repository.getStockLevels(
        warehouseId: warehouseId,
        categoryId: categoryId,
        search: search,
        stockStatus: stockStatus,
      );
}
