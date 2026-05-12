class ProductWarehouseStock {
  final int warehouseId;
  final String warehouseName;
  final int qty;
  final String location;

  const ProductWarehouseStock({
    required this.warehouseId,
    required this.warehouseName,
    required this.qty,
    required this.location,
  });

  factory ProductWarehouseStock.fromJson(Map<String, dynamic> json) {
    return ProductWarehouseStock(
      warehouseId: Product.parseInt(json['warehouse_id']),
      warehouseName: (json['warehouse_name'] ?? '').toString(),
      qty: Product.parseInt(json['qty']),
      location: (json['location'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'qty': qty,
      'location': location,
    };
  }
}

class Product {
  final int id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final double weight;
  final double yuan;
  final double sea;
  final double air;
  final double agent;
  final double wholesale;
  final double shipmentTax;
  final double shipmentTaxAir;
  final DateTime? shipmentDate;
  final int shipmentNo;
  final double currency;
  final int stockQty;
  final double avgPurchasePrice;
  final int seaStockQty;
  final int airStockQty;
  final int localQty;
  final int alertQty;
  final List<ProductWarehouseStock> warehouseStocks;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.weight,
    required this.yuan,
    required this.sea,
    required this.air,
    required this.agent,
    required this.wholesale,
    required this.shipmentTax,
    required this.shipmentTaxAir,
    required this.shipmentDate,
    required this.shipmentNo,
    required this.currency,
    required this.stockQty,
    required this.avgPurchasePrice,
    required this.seaStockQty,
    required this.airStockQty,
    required this.localQty,
    required this.alertQty,
    this.warehouseStocks = const [],
  });

  static int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawWarehouses = json['warehouse_stocks'];
    final List<ProductWarehouseStock> parsedWarehouses =
        rawWarehouses is List
            ? rawWarehouses
                .whereType<Map>()
                .map(
                  (item) => ProductWarehouseStock.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
            : <ProductWarehouseStock>[];

    return Product(
      id: parseInt(json['id']),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      weight: parseDouble(json['weight']),
      yuan: parseDouble(json['yuan']),
      sea: parseDouble(json['sea']),
      air: parseDouble(json['air']),
      agent: parseDouble(json['agent']),
      wholesale: parseDouble(json['wholesale']),
      shipmentTax: parseDouble(json['shipmenttax']),
      shipmentTaxAir: parseDouble(json['shipmenttaxair']),
      shipmentDate: parseDate(json['shipmentdate']),
      shipmentNo: parseInt(json['shipmentno']),
      currency: parseDouble(json['currency']),
      stockQty: parseInt(json['stock_qty']),
      avgPurchasePrice: parseDouble(json['avg_purchase_price']),
      seaStockQty: parseInt(json['sea_stock_qty']),
      airStockQty: parseInt(json['air_stock_qty']),
      localQty: parseInt(json['local_qty']),
      alertQty: parseInt(json['alert_qty'] ?? 5),
      warehouseStocks: parsedWarehouses,
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
      'sea': sea,
      'air': air,
      'agent': agent,
      'wholesale': wholesale,
      'shipmenttax': shipmentTax,
      'shipmenttaxair': shipmentTaxAir,
      'shipmentdate': shipmentDate?.toIso8601String(),
      'shipmentno': shipmentNo,
      'currency': currency,
      'stock_qty': stockQty,
      'avg_purchase_price': avgPurchasePrice,
      'sea_stock_qty': seaStockQty,
      'air_stock_qty': airStockQty,
      'local_qty': localQty,
      'alert_qty': alertQty,
      'warehouse_stocks': warehouseStocks.map((item) => item.toJson()).toList(),
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
    double? sea,
    double? air,
    double? agent,
    double? wholesale,
    double? shipmentTax,
    double? shipmentTaxAir,
    DateTime? shipmentDate,
    int? shipmentNo,
    double? currency,
    int? stockQty,
    double? avgPurchasePrice,
    int? seaStockQty,
    int? airStockQty,
    int? localQty,
    int? alertQty,
    List<ProductWarehouseStock>? warehouseStocks,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      weight: weight ?? this.weight,
      yuan: yuan ?? this.yuan,
      sea: sea ?? this.sea,
      air: air ?? this.air,
      agent: agent ?? this.agent,
      wholesale: wholesale ?? this.wholesale,
      shipmentTax: shipmentTax ?? this.shipmentTax,
      shipmentTaxAir: shipmentTaxAir ?? this.shipmentTaxAir,
      shipmentDate: shipmentDate ?? this.shipmentDate,
      shipmentNo: shipmentNo ?? this.shipmentNo,
      currency: currency ?? this.currency,
      stockQty: stockQty ?? this.stockQty,
      avgPurchasePrice: avgPurchasePrice ?? this.avgPurchasePrice,
      seaStockQty: seaStockQty ?? this.seaStockQty,
      airStockQty: airStockQty ?? this.airStockQty,
      localQty: localQty ?? this.localQty,
      alertQty: alertQty ?? this.alertQty,
      warehouseStocks: warehouseStocks ?? this.warehouseStocks,
    );
  }

  bool get isLowStock => stockQty <= alertQty;

  bool get hasWarehouseStock => warehouseStocks.isNotEmpty;

  int get warehouseTotalQty {
    return warehouseStocks.fold<int>(0, (total, item) => total + item.qty);
  }

  double get totalStockValue {
    return stockQty * avgPurchasePrice;
  }

  double get warehouseStockValue {
    final qty = hasWarehouseStock ? warehouseTotalQty : stockQty;
    return qty * avgPurchasePrice;
  }

  double get profitAgent {
    return agent - avgPurchasePrice;
  }

  double get profitWholesale {
    return wholesale - avgPurchasePrice;
  }

  String get displayName {
    if (name.trim().isEmpty) return model;
    return name;
  }

  String get displayModel {
    if (model.trim().isEmpty) return 'No model';
    return model;
  }

  ProductWarehouseStock? warehouseById(int warehouseId) {
    for (final stock in warehouseStocks) {
      if (stock.warehouseId == warehouseId) return stock;
    }
    return null;
  }
}
