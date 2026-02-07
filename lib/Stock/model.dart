class Product {
  final int id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final double weight;
  final double yuan;
  final double air;
  final double sea;
  final double agent; // Selling Price (Agent)
  final double wholesale; // Selling Price (Wholesale)
  final double shipmentTax;
  final int shipmentNo;
  final double currency;
  int stockQty;

  // --- New Fields ---
  final double shipmentTaxAir;
  final DateTime? shipmentDate;
  final int alertQty;

  // --- Inventory Breakdown Fields ---
  final double avgPurchasePrice; // Cost Price
  final int seaStockQty;
  final int airStockQty;
  final int localQty;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.weight,
    required this.yuan,
    required this.air,
    required this.sea,
    required this.agent,
    required this.wholesale,
    required this.shipmentTax,
    required this.shipmentNo,
    required this.currency,
    required this.stockQty,

    // Updated Constructor Defaults
    this.shipmentTaxAir = 0.0,
    this.shipmentDate,
    this.alertQty = 5,

    required this.avgPurchasePrice,
    required this.seaStockQty,
    required this.airStockQty,
    required this.localQty,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper for safe integer parsing
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Helper for safe double parsing
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper for safe Date parsing
    DateTime? parseDate(dynamic value) {
      if (value == null ||
          value.toString() == '0' ||
          value.toString() == 'null') {
        return null;
      }
      return DateTime.tryParse(value.toString());
    }

    return Product(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      weight: parseDouble(json['weight']),
      yuan: parseDouble(json['yuan']),
      air: parseDouble(json['air']),
      sea: parseDouble(json['sea']),
      agent: parseDouble(json['agent']),
      wholesale: parseDouble(json['wholesale']),
      shipmentTax: parseDouble(json['shipmenttax'] ?? json['shipmentTax']),
      shipmentNo: parseInt(json['shipmentno'] ?? json['shipmentNo']),
      currency: parseDouble(json['currency']),
      stockQty: parseInt(json['stock_qty']),

      // --- New Fields Mapped ---
      shipmentTaxAir: parseDouble(
        json['shipmenttaxair'] ?? json['shipmentTaxAir'],
      ),
      shipmentDate: parseDate(json['shipmentdate'] ?? json['shipmentDate']),

      // If alert_qty is missing, default to 5
      alertQty: json['alert_qty'] != null ? parseInt(json['alert_qty']) : 5,

      // --- Inventory Breakdown ---
      avgPurchasePrice: parseDouble(json['avg_purchase_price']),
      seaStockQty: parseInt(json['sea_stock_qty']),
      airStockQty: parseInt(json['air_stock_qty']),
      localQty: parseInt(json['local_qty']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'model': model,
      'weight': weight,
      'yuan': yuan,
      'air': air,
      'sea': sea,
      'agent': agent,
      'wholesale': wholesale,
      'shipmenttax': shipmentTax,
      'shipmentno': shipmentNo,
      'currency': currency,
      'stock_qty': stockQty,
      'shipmenttaxair': shipmentTaxAir,
      'shipmentdate': shipmentDate?.toIso8601String(),
      'alert_qty': alertQty,
      'avg_purchase_price': avgPurchasePrice,
      'sea_stock_qty': seaStockQty,
      'air_stock_qty': airStockQty,
      'local_qty': localQty,
    };
  }

  // Optional Helper: Check if this specific product is low stock
  bool get isLowStock => stockQty <= alertQty;

  // ==========================================
  // PROFIT CALCULATIONS (Added)
  // ==========================================

  /// Calculate Profit for Agent Price
  /// (Selling Price - Average Purchase Price)
  double get profitAgent => agent - avgPurchasePrice;

  /// Calculate Profit for Wholesale Price
  /// (Selling Price - Average Purchase Price)
  double get profitWholesale => wholesale - avgPurchasePrice;
}
