import 'package:gas_company/core/utils/enums.dart';

class PurchaseRequest {
  final String id;
  final String? prNumber;
  final String? createdFromMrId;
  final String? projectId;
  final String? projectName;
  final String? requiredDate;
  final String? source;
  final PRStatus status;
  final String? notes;
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final double estimatedCost;
  final List<PurchaseRequestItem> items;

  const PurchaseRequest({
    required this.id,
    this.prNumber,
    this.createdFromMrId,
    this.projectId,
    this.projectName,
    this.requiredDate,
    this.source,
    required this.status,
    this.notes,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.estimatedCost = 0,
    this.items = const [],
  });

  /// Display-friendly PR identifier.
  String get displayNumber =>
      prNumber ?? 'PR-${id.substring(0, 8).toUpperCase()}';

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    List<PurchaseRequestItem> items = [];
    if (json['purchase_request_items'] != null) {
      items = (json['purchase_request_items'] as List)
          .map((e) => PurchaseRequestItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Support the enriched view (items_detail as jsonb array).
    if (items.isEmpty && json['items_detail'] != null) {
      final detail = json['items_detail'];
      if (detail is List) {
        items = detail
            .map((e) => PurchaseRequestItem.fromDetailJson(
                  e as Map<String, dynamic>,
                  json['id'] as String,
                ))
            .toList();
      }
    }

    return PurchaseRequest(
      id: json['id'] as String,
      prNumber: json['pr_number'] as String?,
      createdFromMrId: json['created_from_mr_id'] as String? ?? json['mr_id'] as String?,
      projectId: json['project_id'] as String?,
      projectName: json['project_name'] as String?,
      requiredDate: json['required_date'] as String?,
      source: json['source'] as String?,
      status: PRStatus.fromString(json['status'] as String? ?? 'pending'),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      items: items,
    );
  }
}

class PurchaseRequestItem {
  final String id;
  final String prId;
  final String productId;
  final int quantityNeeded;
  final String? productName;
  final String? productUnit;

  const PurchaseRequestItem({
    required this.id,
    required this.prId,
    required this.productId,
    required this.quantityNeeded,
    this.productName,
    this.productUnit,
  });

  factory PurchaseRequestItem.fromJson(Map<String, dynamic> json) {
    String? pName;
    String? pUnit;
    if (json['products'] != null && json['products'] is Map) {
      pName = json['products']['name'] as String?;
      pUnit = json['products']['unit'] as String?;
    }
    return PurchaseRequestItem(
      id: json['id'] as String,
      prId: json['pr_id'] as String,
      productId: json['product_id'] as String,
      quantityNeeded: json['quantity_needed'] as int? ?? 0,
      productName: pName,
      productUnit: pUnit,
    );
  }

  /// Parse from the enriched `items_detail` jsonb produced by the view.
  factory PurchaseRequestItem.fromDetailJson(
    Map<String, dynamic> json,
    String prId,
  ) {
    return PurchaseRequestItem(
      id: json['id'] as String? ?? '',
      prId: prId,
      productId: json['product_id'] as String,
      quantityNeeded: json['quantity_needed'] as int? ?? 0,
      productName: json['product_name'] as String?,
      productUnit: json['unit'] as String?,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String? prId;
  final String? supplierId;
  final POStatus status;
  final double? totalAmount;
  final String? notes;
  final String? createdBy;
  final String? supplierName;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;

  const PurchaseOrder({
    required this.id,
    this.prId,
    this.supplierId,
    required this.status,
    this.totalAmount,
    this.notes,
    this.createdBy,
    this.supplierName,
    required this.createdAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    String? supName;
    if (json['suppliers'] != null && json['suppliers'] is Map) {
      supName = json['suppliers']['name'] as String?;
    }

    List<PurchaseOrderItem> items = [];
    if (json['purchase_order_items'] != null) {
      items = (json['purchase_order_items'] as List)
          .map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return PurchaseOrder(
      id: json['id'] as String,
      prId: json['pr_id'] as String?,
      supplierId: json['supplier_id'] as String?,
      status: POStatus.fromString(json['status'] as String? ?? 'draft'),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      supplierName: supName,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: items,
    );
  }
}

class PurchaseOrderItem {
  final String id;
  final String poId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final String? productName;
  final String? productUnit;

  const PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productName,
    this.productUnit,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    String? pName;
    String? pUnit;
    if (json['products'] != null && json['products'] is Map) {
      pName = json['products']['name'] as String?;
      pUnit = json['products']['unit'] as String?;
    }
    return PurchaseOrderItem(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      productName: pName,
      productUnit: pUnit,
    );
  }

  double get totalPrice => quantity * unitPrice;
}
