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
  final int stockQty;

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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Product(
      id: parseInt(json['id']),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      weight: parseDouble(json['weight']),
      yuan: parseDouble(json['yuan']),
      air: parseDouble(json['air']),
      sea: parseDouble(json['sea']),
      agent: parseDouble(json['agent']),
      wholesale: parseDouble(json['wholesale']),
      shipmentTax: parseDouble(json['shipmenttax']),
      shipmentNo: parseInt(json['shipmentno']),
      currency: parseDouble(json['currency']),
      stockQty: parseInt(json['stock_qty']),
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
    };
  }
}
