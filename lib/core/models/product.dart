class Product {
  final String id;
  final String name;
  final String unit;
  final int minimumStockLevel;
  final String? category;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.minimumStockLevel,
    this.category,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String? ?? 'pcs',
      minimumStockLevel: json['minimum_stock_level'] as int? ?? 0,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'minimum_stock_level': minimumStockLevel,
        'category': category,
      };
}

class InventoryItem {
  final String id;
  final String productId;
  final int quantityAvailable;
  final Product? product;
  final DateTime? lastRestockedAt;

  const InventoryItem({
    required this.id,
    required this.productId,
    required this.quantityAvailable,
    this.product,
    this.lastRestockedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    Product? prod;
    if (json['products'] != null && json['products'] is Map) {
      prod = Product.fromJson(json['products'] as Map<String, dynamic>);
    }
    return InventoryItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      quantityAvailable: json['quantity_available'] as int? ?? 0,
      product: prod,
      lastRestockedAt: json['last_restocked_at'] != null
          ? DateTime.parse(json['last_restocked_at'] as String)
          : null,
    );
  }

  bool get isLowStock =>
      product != null && quantityAvailable <= product!.minimumStockLevel;

  bool get isOutOfStock => quantityAvailable <= 0;
}
