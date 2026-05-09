class Supplier {
  final String id;
  final String? supplierCode;
  final String name;
  final String? address;
  final String? gstNo;
  final String? panNo;
  final bool isoCertificate;
  final String? contactName;
  final String? contactMobile;
  final String? contactEmail;
  final List<SupplierProduct> products;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.id,
    this.supplierCode,
    required this.name,
    this.address,
    this.gstNo,
    this.panNo,
    this.isoCertificate = false,
    this.contactName,
    this.contactMobile,
    this.contactEmail,
    this.products = const [],
    this.createdAt,
    this.updatedAt,
  });

  String? get contactInfo => contactName;
  String? get email => contactEmail;
  String? get phone => contactMobile;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['supplier_products'];
    final products = rawProducts is List
        ? rawProducts
              .map((e) => SupplierProduct.fromJson(e as Map<String, dynamic>))
              .toList()
        : <SupplierProduct>[];

    return Supplier(
      id: json['id'] as String,
      supplierCode: json['supplier_code'] as String?,
      name: json['name'] as String,
      address: json['address'] as String?,
      gstNo: json['gst_no'] as String?,
      panNo: json['pan_no'] as String?,
      isoCertificate: json['iso_certificate'] as bool? ?? false,
      contactName:
          json['contact_name'] as String? ?? json['contact_info'] as String?,
      contactMobile:
          json['contact_mobile'] as String? ?? json['phone'] as String?,
      contactEmail:
          json['contact_email'] as String? ?? json['email'] as String?,
      products: products,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'supplier_code': _emptyToNull(supplierCode),
    'name': name,
    'address': _emptyToNull(address),
    'gst_no': _emptyToNull(gstNo),
    'pan_no': _emptyToNull(panNo),
    'iso_certificate': isoCertificate,
    'contact_name': _emptyToNull(contactName),
    'contact_mobile': _emptyToNull(contactMobile),
    'contact_email': _emptyToNull(contactEmail),
    // Keep legacy columns populated for older reports/screens.
    'contact_info': _emptyToNull(contactName),
    'phone': _emptyToNull(contactMobile),
    'email': _emptyToNull(contactEmail),
  };

  Supplier copyWith({
    String? id,
    String? supplierCode,
    String? name,
    String? address,
    String? gstNo,
    String? panNo,
    bool? isoCertificate,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
    List<SupplierProduct>? products,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      supplierCode: supplierCode ?? this.supplierCode,
      name: name ?? this.name,
      address: address ?? this.address,
      gstNo: gstNo ?? this.gstNo,
      panNo: panNo ?? this.panNo,
      isoCertificate: isoCertificate ?? this.isoCertificate,
      contactName: contactName ?? this.contactName,
      contactMobile: contactMobile ?? this.contactMobile,
      contactEmail: contactEmail ?? this.contactEmail,
      products: products ?? this.products,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupplierProduct {
  final String? id;
  final String? supplierId;
  final String productName;
  final String unit;
  final double price;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupplierProduct({
    this.id,
    this.supplierId,
    required this.productName,
    required this.unit,
    required this.price,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    return SupplierProduct(
      id: json['id'] as String?,
      supplierId: json['supplier_id'] as String?,
      productName: json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      price: _parseDouble(json['price']),
      description: json['description'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson({String? supplierId}) {
    final json = <String, dynamic>{
      'product_name': productName.trim(),
      'unit': unit.trim(),
      'price': price,
      'description': description.trim(),
    };
    final resolvedSupplierId = supplierId ?? this.supplierId;
    if (resolvedSupplierId != null) {
      json['supplier_id'] = resolvedSupplierId;
    }
    return json;
  }

  SupplierProduct copyWith({
    String? id,
    String? supplierId,
    String? productName,
    String? unit,
    double? price,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierProduct(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupplierProductRevision {
  final String id;
  final String supplierProductId;
  final double? oldPrice;
  final double? newPrice;
  final String? oldDescription;
  final String? newDescription;
  final DateTime updatedAt;

  const SupplierProductRevision({
    required this.id,
    required this.supplierProductId,
    this.oldPrice,
    this.newPrice,
    this.oldDescription,
    this.newDescription,
    required this.updatedAt,
  });

  factory SupplierProductRevision.fromJson(Map<String, dynamic> json) {
    return SupplierProductRevision(
      id: json['id'] as String,
      supplierProductId: json['supplier_product_id'] as String,
      oldPrice: _parseNullableDouble(json['old_price']),
      newPrice: _parseNullableDouble(json['new_price']),
      oldDescription: json['old_description'] as String?,
      newDescription: json['new_description'] as String?,
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

double _parseDouble(Object? value) => _parseNullableDouble(value) ?? 0;

double? _parseNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
