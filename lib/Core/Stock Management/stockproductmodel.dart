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
  final double shipmentTax;
  final int shipmentNo;
  final double currency;
  int stockQty; // Kept non-final to support your existing direct modifications

  // --- Logistics & Alerts ---
  final double shipmentTaxAir;
  final DateTime? shipmentDate;
  final int alertQty;

  // --- Inventory Breakdown ---
  final double avgPurchasePrice;
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
    this.shipmentTaxAir = 0.0,
    this.shipmentDate,
    this.alertQty = 5,
    required this.avgPurchasePrice,
    required this.seaStockQty,
    required this.airStockQty,
    required this.localQty,
  });


  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString() == '0' || value.toString() == 'null') {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _parseInt(json['id']),
      name: json['name']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? '',
      brand: json['brand']?.toString().trim() ?? '',
      model: json['model']?.toString().trim() ?? '',
      weight: _parseDouble(json['weight']),
      yuan: _parseDouble(json['yuan']),
      air: _parseDouble(json['air']),
      sea: _parseDouble(json['sea']),
      agent: _parseDouble(json['agent']),
      wholesale: _parseDouble(json['wholesale']),
      shipmentTax: _parseDouble(json['shipmenttax'] ?? json['shipmentTax']),
      shipmentNo: _parseInt(json['shipmentno'] ?? json['shipmentNo']),
      currency: _parseDouble(json['currency']),
      stockQty: _parseInt(json['stock_qty']),
      shipmentTaxAir: _parseDouble(
        json['shipmenttaxair'] ?? json['shipmentTaxAir'],
      ),
      shipmentDate: _parseDate(json['shipmentdate'] ?? json['shipmentDate']),
      alertQty: json['alert_qty'] != null ? _parseInt(json['alert_qty']) : 5,
      avgPurchasePrice: _parseDouble(json['avg_purchase_price']),
      seaStockQty: _parseInt(json['sea_stock_qty']),
      airStockQty: _parseInt(json['air_stock_qty']),
      localQty: _parseInt(json['local_qty']),
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

  Product copyWith({
    int? id,
    String? name,
    String? category,
    String? brand,
    String? model,
    double? weight,
    double? yuan,
    double? air,
    double? sea,
    double? agent,
    double? wholesale,
    double? shipmentTax,
    int? shipmentNo,
    double? currency,
    int? stockQty,
    double? shipmentTaxAir,
    DateTime? shipmentDate,
    int? alertQty,
    double? avgPurchasePrice,
    int? seaStockQty,
    int? airStockQty,
    int? localQty,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      weight: weight ?? this.weight,
      yuan: yuan ?? this.yuan,
      air: air ?? this.air,
      sea: sea ?? this.sea,
      agent: agent ?? this.agent,
      wholesale: wholesale ?? this.wholesale,
      shipmentTax: shipmentTax ?? this.shipmentTax,
      shipmentNo: shipmentNo ?? this.shipmentNo,
      currency: currency ?? this.currency,
      stockQty: stockQty ?? this.stockQty,
      shipmentTaxAir: shipmentTaxAir ?? this.shipmentTaxAir,
      shipmentDate: shipmentDate ?? this.shipmentDate,
      alertQty: alertQty ?? this.alertQty,
      avgPurchasePrice: avgPurchasePrice ?? this.avgPurchasePrice,
      seaStockQty: seaStockQty ?? this.seaStockQty,
      airStockQty: airStockQty ?? this.airStockQty,
      localQty: localQty ?? this.localQty,
    );
  }

  bool get isLowStock => stockQty <= alertQty;
  double get profitAgent => agent - avgPurchasePrice;
  double get profitWholesale => wholesale - avgPurchasePrice;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}