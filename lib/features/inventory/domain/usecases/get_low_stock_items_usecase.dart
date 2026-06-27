import '../../data/models/inventory_summary_model.dart';
import '../repositories/inventory_repository.dart';

/// Fetches items with low or zero stock levels.
/// Used by the dashboard low-stock alert widget.
class GetLowStockItemsUseCase {
  final InventoryRepository _repository;
  const GetLowStockItemsUseCase(this._repository);

  Future<List<InventorySummaryModel>> call() => _repository.getLowStockItems();
}
