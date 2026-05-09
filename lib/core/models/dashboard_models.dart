// Dashboard Metrics Model
class DashboardMetrics {
  final double totalCostAllProjects;
  final double costThisMonth;
  final double totalInventoryValue;
  final double pendingPurchaseCost;
  final int activeProjectsCount;
  final int onHoldProjectsCount;
  final int completedProjectsCount;
  final int overBudgetProjects;
  final int nearLimitProjects;
  final int lowStockItems;
  final int pendingMaterialRequests;
  final int pendingPurchaseRequests;

  const DashboardMetrics({
    required this.totalCostAllProjects,
    required this.costThisMonth,
    required this.totalInventoryValue,
    required this.pendingPurchaseCost,
    required this.activeProjectsCount,
    required this.onHoldProjectsCount,
    required this.completedProjectsCount,
    required this.overBudgetProjects,
    required this.nearLimitProjects,
    required this.lowStockItems,
    required this.pendingMaterialRequests,
    required this.pendingPurchaseRequests,
  });

  factory DashboardMetrics.fromMap(Map<String, dynamic> map) {
    return DashboardMetrics(
      totalCostAllProjects:
          (map['total_cost_all_projects'] as num?)?.toDouble() ?? 0.0,
      costThisMonth: (map['cost_this_month'] as num?)?.toDouble() ?? 0.0,
      totalInventoryValue:
          (map['total_inventory_value'] as num?)?.toDouble() ?? 0.0,
      pendingPurchaseCost:
          (map['pending_purchase_cost'] as num?)?.toDouble() ?? 0.0,
      activeProjectsCount: map['active_projects_count'] as int? ?? 0,
      onHoldProjectsCount: map['on_hold_projects_count'] as int? ?? 0,
      completedProjectsCount: map['completed_projects_count'] as int? ?? 0,
      overBudgetProjects: map['over_budget_projects'] as int? ?? 0,
      nearLimitProjects: map['near_limit_projects'] as int? ?? 0,
      lowStockItems: map['low_stock_items'] as int? ?? 0,
      pendingMaterialRequests: map['pending_material_requests'] as int? ?? 0,
      pendingPurchaseRequests: map['pending_purchase_requests'] as int? ?? 0,
    );
  }
}

// Project Cost Summary Model
class ProjectCostSummary {
  final String projectId;
  final String projectName;
  final String status;
  final String? assignedEngineerId;
  final String? engineerName;
  final double budgetAmount;
  final double materialCost;
  final double laborCost;
  final double equipmentCost;
  final double otherCost;
  final double totalCost;
  final double budgetUsedPercentage;
  final BudgetStatus budgetStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectCostSummary({
    required this.projectId,
    required this.projectName,
    required this.status,
    this.assignedEngineerId,
    this.engineerName,
    required this.budgetAmount,
    required this.materialCost,
    required this.laborCost,
    required this.equipmentCost,
    required this.otherCost,
    required this.totalCost,
    required this.budgetUsedPercentage,
    required this.budgetStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectCostSummary.fromMap(Map<String, dynamic> map) {
    return ProjectCostSummary(
      projectId: map['project_id'] as String,
      projectName: map['project_name'] as String,
      status: map['status'] as String,
      assignedEngineerId: map['assigned_engineer_id'] as String?,
      engineerName: map['engineer_name'] as String?,
      budgetAmount: (map['budget_amount'] as num?)?.toDouble() ?? 0.0,
      materialCost: (map['material_cost'] as num?)?.toDouble() ?? 0.0,
      laborCost: (map['labor_cost'] as num?)?.toDouble() ?? 0.0,
      equipmentCost: (map['equipment_cost'] as num?)?.toDouble() ?? 0.0,
      otherCost: (map['other_cost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      budgetUsedPercentage:
          (map['budget_used_percentage'] as num?)?.toDouble() ?? 0.0,
      budgetStatus: BudgetStatus.fromString(map['budget_status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

// Budget Status Enum
enum BudgetStatus {
  noBudget('no_budget'),
  onTrack('on_track'),
  nearLimit('near_limit'),
  overBudget('over_budget');

  const BudgetStatus(this.value);
  final String value;

  static BudgetStatus fromString(String value) {
    return BudgetStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BudgetStatus.noBudget,
    );
  }
}

// Inventory Valuation Model
class InventoryValuation {
  final String id;
  final String productId;
  final String productName;
  final String? category;
  final int quantityAvailable;
  final double unitCost;
  final double totalValue;
  final int minimumStockLevel;
  final StockStatus stockStatus;
  final DateTime? lastRestockedAt;

  const InventoryValuation({
    required this.id,
    required this.productId,
    required this.productName,
    this.category,
    required this.quantityAvailable,
    required this.unitCost,
    required this.totalValue,
    required this.minimumStockLevel,
    required this.stockStatus,
    this.lastRestockedAt,
  });

  factory InventoryValuation.fromMap(Map<String, dynamic> map) {
    return InventoryValuation(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      category: map['category'] as String?,
      quantityAvailable: map['quantity_available'] as int? ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalValue: (map['total_value'] as num?)?.toDouble() ?? 0.0,
      minimumStockLevel: map['minimum_stock_level'] as int? ?? 0,
      stockStatus: StockStatus.fromString(map['stock_status'] as String),
      lastRestockedAt: map['last_restocked_at'] != null
          ? DateTime.parse(map['last_restocked_at'] as String)
          : null,
    );
  }
}

// Stock Status Enum
enum StockStatus {
  lowStock('low_stock'),
  mediumStock('medium_stock'),
  goodStock('good_stock');

  const StockStatus(this.value);
  final String value;

  static StockStatus fromString(String value) {
    return StockStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StockStatus.goodStock,
    );
  }
}

// Monthly Cost Analysis Model
class MonthlyCostAnalysis {
  final DateTime month;
  final String costType;
  final double totalCost;
  final int transactionCount;
  final List<String> projectIds;

  const MonthlyCostAnalysis({
    required this.month,
    required this.costType,
    required this.totalCost,
    required this.transactionCount,
    required this.projectIds,
  });

  factory MonthlyCostAnalysis.fromMap(Map<String, dynamic> map) {
    return MonthlyCostAnalysis(
      month: DateTime.parse(map['month'] as String),
      costType: map['cost_type'] as String,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      transactionCount: map['transaction_count'] as int? ?? 0,
      projectIds:
          (map['project_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

// Supplier Spending Analysis Model
class SupplierSpendingAnalysis {
  final String supplierId;
  final String supplierName;
  final double totalSpent;
  final int orderCount;
  final double avgOrderValue;

  const SupplierSpendingAnalysis({
    required this.supplierId,
    required this.supplierName,
    required this.totalSpent,
    required this.orderCount,
    required this.avgOrderValue,
  });

  factory SupplierSpendingAnalysis.fromMap(Map<String, dynamic> map) {
    return SupplierSpendingAnalysis(
      supplierId: map['supplier_id'] as String,
      supplierName: map['supplier_name'] as String,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      orderCount: map['order_count'] as int? ?? 0,
      avgOrderValue: (map['avg_order_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Top Cost Material Model
class TopCostMaterial {
  final String productId;
  final String productName;
  final String? category;
  final int totalQuantityUsed;
  final double totalCost;
  final double avgUnitPrice;

  const TopCostMaterial({
    required this.productId,
    required this.productName,
    this.category,
    required this.totalQuantityUsed,
    required this.totalCost,
    required this.avgUnitPrice,
  });

  factory TopCostMaterial.fromMap(Map<String, dynamic> map) {
    return TopCostMaterial(
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      category: map['category'] as String?,
      totalQuantityUsed: map['total_quantity_used'] as int? ?? 0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      avgUnitPrice: (map['avg_unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Project Budget Model
class ProjectBudget {
  final String id;
  final String projectId;
  final double budgetAmount;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectBudget({
    required this.id,
    required this.projectId,
    required this.budgetAmount,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectBudget.fromMap(Map<String, dynamic> map) {
    return ProjectBudget(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      budgetAmount: (map['budget_amount'] as num?)?.toDouble() ?? 0.0,
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'budget_amount': budgetAmount,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Cost Tracking Model
class CostTracking {
  final String id;
  final String projectId;
  final CostType costType;
  final String? description;
  final double amount;
  final DateTime dateIncurred;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CostTracking({
    required this.id,
    required this.projectId,
    required this.costType,
    this.description,
    required this.amount,
    required this.dateIncurred,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CostTracking.fromMap(Map<String, dynamic> map) {
    return CostTracking(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      costType: CostType.fromString(map['cost_type'] as String),
      description: map['description'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dateIncurred: DateTime.parse(map['date_incurred'] as String),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'cost_type': costType.value,
      'description': description,
      'amount': amount,
      'date_incurred': dateIncurred.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Cost Type Enum
enum CostType {
  material('material'),
  labor('labor'),
  equipment('equipment'),
  other('other');

  const CostType(this.value);
  final String value;

  static CostType fromString(String value) {
    return CostType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CostType.other,
    );
  }
}
