import 'package:gas_company/core/utils/enums.dart';

class MaterialRequest {
  final String id;
  final String projectId;
  final String engineerId;
  final MRStatus status;
  final DateTime? approvedAt;
  final String? notes;
  final String? projectName;
  final String? engineerName;
  final String? engineerEmail;
  final DateTime createdAt;
  final List<MaterialRequestItem> items;

  const MaterialRequest({
    required this.id,
    required this.projectId,
    required this.engineerId,
    required this.status,
    this.approvedAt,
    this.notes,
    this.projectName,
    this.engineerName,
    this.engineerEmail,
    required this.createdAt,
    this.items = const [],
  });

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    String? projName;
    String? engName;
    if (json['project'] != null && json['project'] is Map) {
      projName = json['project']['name'] as String?;
    } else if (json['projects'] != null && json['projects'] is Map) {
      projName = json['projects']['name'] as String?;
    }

    String? engEmail;
    if (json['engineer'] != null && json['engineer'] is Map) {
      engName = json['engineer']['name'] as String?;
      engEmail = json['engineer']['email'] as String?;
    } else if (json['profiles'] != null && json['profiles'] is Map) {
      engName = json['profiles']['name'] as String?;
      engEmail = json['profiles']['email'] as String?;
    }

    List<MaterialRequestItem> items = [];
    if (json['material_request_items'] != null) {
      items = (json['material_request_items'] as List)
          .map((e) => MaterialRequestItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return MaterialRequest(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      engineerId: json['engineer_id'] as String,
      status: MRStatus.fromString(json['status'] as String? ?? 'pending'),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String?,
      projectName: projName,
      engineerName: engName,
      engineerEmail: engEmail,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: items,
    );
  }
}

class MaterialRequestItem {
  final String id;
  final String mrId;
  final String productId;
  final int quantityRequested;
  final int quantityIssued;
  final int quantityReserved;
  final String? productName;
  final String? productUnit;

  const MaterialRequestItem({
    required this.id,
    required this.mrId,
    required this.productId,
    required this.quantityRequested,
    required this.quantityIssued,
    this.quantityReserved = 0,
    this.productName,
    this.productUnit,
  });

  factory MaterialRequestItem.fromJson(Map<String, dynamic> json) {
    String? pName;
    String? pUnit;
    if (json['products'] != null && json['products'] is Map) {
      pName = json['products']['name'] as String?;
      pUnit = json['products']['unit'] as String?;
    }
    return MaterialRequestItem(
      id: json['id'] as String,
      mrId: json['mr_id'] as String,
      productId: json['product_id'] as String,
      quantityRequested: json['quantity_requested'] as int? ?? 0,
      quantityIssued: json['quantity_issued'] as int? ?? 0,
      quantityReserved: json['quantity_reserved'] as int? ?? 0,
      productName: pName,
      productUnit: pUnit,
    );
  }

  int get shortfall => quantityRequested - quantityIssued;
  int get remainingQuantity => quantityRequested - quantityIssued;
  bool get isFullyIssued => quantityIssued >= quantityRequested;
}
