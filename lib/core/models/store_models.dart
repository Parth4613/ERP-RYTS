// Issuance Log Model
class IssuanceLog {
  final String id;
  final String mrId;
  final String mrItemId;
  final String projectId;
  final String productId;
  final int quantityIssued;
  final String issuedBy;
  final DateTime issuedAt;
  final String? notes;
  final DateTime createdAt;

  const IssuanceLog({
    required this.id,
    required this.mrId,
    required this.mrItemId,
    required this.projectId,
    required this.productId,
    required this.quantityIssued,
    required this.issuedBy,
    required this.issuedAt,
    this.notes,
    required this.createdAt,
  });

  factory IssuanceLog.fromMap(Map<String, dynamic> map) {
    return IssuanceLog(
      id: map['id'] as String,
      mrId: map['mr_id'] as String,
      mrItemId: map['mr_item_id'] as String,
      projectId: map['project_id'] as String,
      productId: map['product_id'] as String,
      quantityIssued: map['quantity_issued'] as int,
      issuedBy: map['issued_by'] as String,
      issuedAt: DateTime.parse(map['issued_at'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mr_id': mrId,
      'mr_item_id': mrItemId,
      'project_id': projectId,
      'product_id': productId,
      'quantity_issued': quantityIssued,
      'issued_by': issuedBy,
      'issued_at': issuedAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Stock History Model
class StockHistory {
  final String id;
  final String productId;
  final MovementType movementType;
  final int quantity;
  final int previousQuantity;
  final int newQuantity;
  final ReferenceType referenceType;
  final String? referenceId;
  final String? performedBy;
  final DateTime performedAt;
  final String? notes;
  final DateTime createdAt;

  const StockHistory({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.referenceType,
    this.referenceId,
    this.performedBy,
    required this.performedAt,
    this.notes,
    required this.createdAt,
  });

  factory StockHistory.fromMap(Map<String, dynamic> map) {
    return StockHistory(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      movementType: MovementType.fromString(map['movement_type'] as String),
      quantity: map['quantity'] as int,
      previousQuantity: map['previous_quantity'] as int,
      newQuantity: map['new_quantity'] as int,
      referenceType: ReferenceType.fromString(map['reference_type'] as String),
      referenceId: map['reference_id'] as String?,
      performedBy: map['performed_by'] as String?,
      performedAt: DateTime.parse(map['performed_at'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

// Movement Type Enum
enum MovementType {
  inward('inward'),
  outward('outward');

  const MovementType(this.value);
  final String value;

  static MovementType fromString(String value) {
    return MovementType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MovementType.inward,
    );
  }
}

// Reference Type Enum
enum ReferenceType {
  issuance('issuance'),
  purchaseOrder('purchase_order'),
  adjustment('adjustment'),
  initial('initial');

  const ReferenceType(this.value);
  final String value;

  static ReferenceType fromString(String value) {
    return ReferenceType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReferenceType.adjustment,
    );
  }
}

// Store Dashboard Metrics Model
class StoreDashboardMetrics {
  final int pendingMrs;
  final int approvedMrs;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalInventoryValue;
  final int issuancesToday;
  final int issuancesThisWeek;
  final int itemsIssuedToday;
  final int partiallyIssuedMrs;
  final int waitingProcurementMrs;

  const StoreDashboardMetrics({
    required this.pendingMrs,
    this.approvedMrs = 0,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.totalInventoryValue,
    required this.issuancesToday,
    required this.issuancesThisWeek,
    required this.itemsIssuedToday,
    required this.partiallyIssuedMrs,
    this.waitingProcurementMrs = 0,
  });

  factory StoreDashboardMetrics.fromMap(Map<String, dynamic> map) {
    return StoreDashboardMetrics(
      pendingMrs: map['pending_mrs'] as int? ?? 0,
      approvedMrs: map['approved_mrs'] as int? ?? 0,
      lowStockItems: map['low_stock_items'] as int? ?? 0,
      outOfStockItems: map['out_of_stock_items'] as int? ?? 0,
      totalInventoryValue:
          (map['total_inventory_value'] as num?)?.toDouble() ?? 0.0,
      issuancesToday: map['issuances_today'] as int? ?? 0,
      issuancesThisWeek: map['issuances_this_week'] as int? ?? 0,
      itemsIssuedToday: map['items_issued_today'] as int? ?? 0,
      partiallyIssuedMrs: map['partially_issued_mrs'] as int? ?? 0,
      waitingProcurementMrs: map['waiting_procurement_mrs'] as int? ?? 0,
    );
  }
}

// Pending MR Item with Stock Model
class PendingMRItemWithStock {
  final String mrItemId;
  final String mrId;
  final String projectId;
  final String projectName;
  final String engineerId;
  final String engineerName;
  final String mrStatus;
  final String productId;
  final String productName;
  final String unit;
  final int quantityRequested;
  final int quantityIssued;
  final int quantityReserved;
  final int quantityPending;
  final int stockAvailable;
  final int minimumStockLevel;
  final int incomingQuantity;
  final IssuanceStatus issuanceStatus;
  final DateTime mrCreatedAt;

  const PendingMRItemWithStock({
    required this.mrItemId,
    required this.mrId,
    required this.projectId,
    required this.projectName,
    required this.engineerId,
    required this.engineerName,
    this.mrStatus = 'pending',
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantityRequested,
    required this.quantityIssued,
    this.quantityReserved = 0,
    required this.quantityPending,
    required this.stockAvailable,
    this.minimumStockLevel = 0,
    this.incomingQuantity = 0,
    required this.issuanceStatus,
    required this.mrCreatedAt,
  });

  factory PendingMRItemWithStock.fromMap(Map<String, dynamic> map) {
    return PendingMRItemWithStock(
      mrItemId: map['mr_item_id'] as String,
      mrId: map['mr_id'] as String,
      projectId: map['project_id'] as String,
      projectName: map['project_name'] as String,
      engineerId: map['engineer_id'] as String,
      engineerName: map['engineer_name'] as String? ?? 'Unknown engineer',
      mrStatus: map['mr_status'] as String? ?? 'pending',
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      unit: map['unit'] as String,
      quantityRequested: map['quantity_requested'] as int,
      quantityIssued: map['quantity_issued'] as int,
      quantityReserved: map['quantity_reserved'] as int? ?? 0,
      quantityPending: map['quantity_pending'] as int,
      stockAvailable: map['stock_available'] as int? ?? 0,
      minimumStockLevel: map['minimum_stock_level'] as int? ?? 0,
      incomingQuantity: map['incoming_quantity'] as int? ?? 0,
      issuanceStatus: IssuanceStatus.fromString(
        map['issuance_status'] as String,
      ),
      mrCreatedAt: DateTime.parse(map['mr_created_at'] as String),
    );
  }
}

// Issuance Status Enum
enum IssuanceStatus {
  canFullyIssue('can_fully_issue'),
  canPartiallyIssue('can_partially_issue'),
  outOfStock('out_of_stock');

  const IssuanceStatus(this.value);
  final String value;

  static IssuanceStatus fromString(String value) {
    return IssuanceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => IssuanceStatus.outOfStock,
    );
  }
}

// Frequent Shortage Model
class FrequentShortage {
  final String productId;
  final String productName;
  final String? category;
  final int shortageCount;
  final int totalShortageQuantity;
  final DateTime lastShortageDate;

  const FrequentShortage({
    required this.productId,
    required this.productName,
    this.category,
    required this.shortageCount,
    required this.totalShortageQuantity,
    required this.lastShortageDate,
  });

  factory FrequentShortage.fromMap(Map<String, dynamic> map) {
    return FrequentShortage(
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      category: map['category'] as String?,
      shortageCount: map['shortage_count'] as int,
      totalShortageQuantity: map['total_shortage_quantity'] as int,
      lastShortageDate: DateTime.parse(map['last_shortage_date'] as String),
    );
  }
}

class StoreProcurementItem {
  final String productId;
  final String productName;
  final String unit;
  final String? category;
  final int quantityAvailable;
  final int quantityReserved;
  final int minimumStockLevel;
  final int incomingQuantity;
  final int recommendedQuantity;
  final String stockStatus;
  final String? recommendedSupplier;
  final double? lastPurchasePrice;
  final String? lastOrderedSupplier;
  final int estimatedDeliveryDays;

  const StoreProcurementItem({
    required this.productId,
    required this.productName,
    required this.unit,
    this.category,
    required this.quantityAvailable,
    required this.quantityReserved,
    required this.minimumStockLevel,
    required this.incomingQuantity,
    required this.recommendedQuantity,
    required this.stockStatus,
    this.recommendedSupplier,
    this.lastPurchasePrice,
    this.lastOrderedSupplier,
    required this.estimatedDeliveryDays,
  });

  factory StoreProcurementItem.fromMap(Map<String, dynamic> map) {
    return StoreProcurementItem(
      productId: map['product_id'] as String,
      productName: map['product_name'] as String? ?? 'Unknown product',
      unit: map['unit'] as String? ?? 'pcs',
      category: map['category'] as String?,
      quantityAvailable: map['quantity_available'] as int? ?? 0,
      quantityReserved: map['quantity_reserved'] as int? ?? 0,
      minimumStockLevel: map['minimum_stock_level'] as int? ?? 0,
      incomingQuantity: map['incoming_quantity'] as int? ?? 0,
      recommendedQuantity: map['recommended_quantity'] as int? ?? 0,
      stockStatus: map['stock_status'] as String? ?? 'healthy',
      recommendedSupplier: map['recommended_supplier'] as String?,
      lastPurchasePrice: (map['last_purchase_price'] as num?)?.toDouble(),
      lastOrderedSupplier: map['last_ordered_supplier'] as String?,
      estimatedDeliveryDays: map['estimated_delivery_days'] as int? ?? 7,
    );
  }

  bool get needsProcurement => recommendedQuantity > 0;
}

class QuickPurchaseRequestItem {
  final String productId;
  final String productName;
  final String unit;
  final int quantity;
  final String? projectId;
  final String? projectName;
  final String? mrId;
  final DateTime? requiredDate;

  const QuickPurchaseRequestItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    this.projectId,
    this.projectName,
    this.mrId,
    this.requiredDate,
  });

  Map<String, dynamic> toRpcJson() {
    return {
      'product_id': productId,
      'quantity_needed': quantity,
      if (projectId != null) 'project_id': projectId,
      if (mrId != null) 'mr_id': mrId,
      if (requiredDate != null)
        'required_date': requiredDate!.toIso8601String().split('T').first,
    };
  }
}

// Issuance Summary Model
class IssuanceSummary {
  final String projectId;
  final String projectName;
  final DateTime month;
  final int issuanceCount;
  final int totalQuantityIssued;
  final int uniqueProductsIssued;
  final int uniqueIssuers;

  const IssuanceSummary({
    required this.projectId,
    required this.projectName,
    required this.month,
    required this.issuanceCount,
    required this.totalQuantityIssued,
    required this.uniqueProductsIssued,
    required this.uniqueIssuers,
  });

  factory IssuanceSummary.fromMap(Map<String, dynamic> map) {
    return IssuanceSummary(
      projectId: map['project_id'] as String,
      projectName: map['project_name'] as String,
      month: DateTime.parse(map['month'] as String),
      issuanceCount: map['issuance_count'] as int,
      totalQuantityIssued: map['total_quantity_issued'] as int,
      uniqueProductsIssued: map['unique_products_issued'] as int,
      uniqueIssuers: map['unique_issuers'] as int,
    );
  }
}

// Issuance Request Model (for creating issuance)
class IssuanceRequest {
  final String mrItemId;
  final int quantityToIssue;
  final String? notes;

  const IssuanceRequest({
    required this.mrItemId,
    required this.quantityToIssue,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'mr_item_id': mrItemId,
      'quantity_to_issue': quantityToIssue,
      'notes': notes,
    };
  }
}

// Issuance Result Model
class IssuanceResult {
  final bool success;
  final String? error;
  final IssuanceLog? issuanceLog;
  final List<String> shortageItems;
  final String? purchaseRequestId;
  final int quantityIssued;
  final int remainingQuantity;
  final int availableQuantity;
  final String? materialRequestStatus;
  final bool purchaseRequestCreated;
  final String? message;

  const IssuanceResult({
    required this.success,
    this.error,
    this.issuanceLog,
    this.shortageItems = const [],
    this.purchaseRequestId,
    this.quantityIssued = 0,
    this.remainingQuantity = 0,
    this.availableQuantity = 0,
    this.materialRequestStatus,
    this.purchaseRequestCreated = false,
    this.message,
  });

  factory IssuanceResult.success({
    IssuanceLog? issuanceLog,
    List<String> shortageItems = const [],
    String? purchaseRequestId,
    int quantityIssued = 0,
    int remainingQuantity = 0,
    int availableQuantity = 0,
    String? materialRequestStatus,
    bool purchaseRequestCreated = false,
    String? message,
  }) {
    return IssuanceResult(
      success: true,
      issuanceLog: issuanceLog,
      shortageItems: shortageItems,
      purchaseRequestId: purchaseRequestId,
      quantityIssued: quantityIssued,
      remainingQuantity: remainingQuantity,
      availableQuantity: availableQuantity,
      materialRequestStatus: materialRequestStatus,
      purchaseRequestCreated: purchaseRequestCreated,
      message: message,
    );
  }

  factory IssuanceResult.failure(String error) {
    return IssuanceResult(success: false, error: error);
  }

  factory IssuanceResult.fromRpc(Map<String, dynamic> map) {
    final logMap = map['issuance_log'];
    final issued = map['quantity_issued'] as int? ?? 0;
    return IssuanceResult(
      success: map['success'] as bool? ?? false,
      error: map['error'] as String?,
      issuanceLog: logMap is Map
          ? IssuanceLog.fromMap(Map<String, dynamic>.from(logMap))
          : null,
      shortageItems:
          (map['shortage_items'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      purchaseRequestId: map['purchase_request_id'] as String?,
      quantityIssued: issued,
      remainingQuantity: map['remaining_quantity'] as int? ?? 0,
      availableQuantity: map['available_quantity'] as int? ?? 0,
      materialRequestStatus: map['material_request_status'] as String?,
      purchaseRequestCreated: map['purchase_request_created'] as bool? ?? false,
      message: map['message'] as String?,
    );
  }
}
