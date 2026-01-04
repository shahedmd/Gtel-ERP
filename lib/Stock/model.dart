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
  final double agent;
  final double wholesale;
  final double shipmentTax; // Maps to 'shipmenttax' in DB
  final int shipmentNo;
  final double currency;
  final int stockQty; // Total Stock

  // --- Inventory Breakdown Fields ---
  final double avgPurchasePrice;
  final int seaStockQty;
  final int airStockQty;
  final int localQty; // Added Local Qty

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
      // DB column is lowercase 'shipmenttax', handling both cases just in case
      shipmentTax: parseDouble(json['shipmenttax'] ?? json['shipmentTax']),
      shipmentNo: parseInt(json['shipmentno'] ?? json['shipmentNo']),
      currency: parseDouble(json['currency']),
      stockQty: parseInt(json['stock_qty']),

      // --- New Inventory Fields ---
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
      'avg_purchase_price': avgPurchasePrice,
      'sea_stock_qty': seaStockQty,
      'air_stock_qty': airStockQty,
      'local_qty': localQty,
    };
  }
}
