import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentItem {
  final int productId;
  final String productName;
  final String productModel;
  final String productBrand;
  final int seaQty;
  final int airQty;
  final String cartonNo;
  // Snapshot prices to calculate accurate shipment cost
  final double seaPriceSnapshot;
  final double airPriceSnapshot;

  ShipmentItem({
    required this.productId,
    required this.productName,
    required this.productModel,
    required this.productBrand,
    required this.seaQty,
    required this.airQty,
    required this.cartonNo,
    required this.seaPriceSnapshot,
    required this.airPriceSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productModel': productModel,
      'productBrand': productBrand,
      'seaQty': seaQty,
      'airQty': airQty,
      'cartonNo': cartonNo,
      'seaPriceSnapshot': seaPriceSnapshot,
      'airPriceSnapshot': airPriceSnapshot,
    };
  }

  factory ShipmentItem.fromMap(Map<String, dynamic> map) {
    return ShipmentItem(
      productId: map['productId'],
      productName: map['productName'] ?? '',
      productModel: map['productModel'] ?? '',
      productBrand: map['productBrand'] ?? '',
      seaQty: map['seaQty'] ?? 0,
      airQty: map['airQty'] ?? 0,
      cartonNo: map['cartonNo'] ?? '',
      seaPriceSnapshot: (map['seaPriceSnapshot'] ?? 0.0).toDouble(),
      airPriceSnapshot: (map['airPriceSnapshot'] ?? 0.0).toDouble(),
    );
  }

  // Helper to get total cost of this specific item line
  double get totalItemCost =>
      (seaQty * seaPriceSnapshot) + (airQty * airPriceSnapshot);
}

class ShipmentModel {
  String? docId;
  final String shipmentName;
  final DateTime createdDate; // Departure Date
  final DateTime? arrivalDate; // Entry Date
  final int totalCartons;
  final double totalWeight;
  final double totalAmount; // TOTAL SHIPMENT COST (Calculated)
  final bool isReceived;
  final List<ShipmentItem> items;

  ShipmentModel({
    this.docId,
    required this.shipmentName,
    required this.createdDate,
    this.arrivalDate,
    required this.totalCartons,
    required this.totalWeight,
    required this.totalAmount,
    this.isReceived = false,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'shipmentName': shipmentName,
      'createdDate': Timestamp.fromDate(createdDate),
      'arrivalDate':
          arrivalDate != null ? Timestamp.fromDate(arrivalDate!) : null,
      'totalCartons': totalCartons,
      'totalWeight': totalWeight,
      'totalAmount': totalAmount,
      'isReceived': isReceived,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory ShipmentModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShipmentModel(
      docId: doc.id,
      shipmentName: data['shipmentName'] ?? 'Unknown',
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      arrivalDate:
          data['arrivalDate'] != null
              ? (data['arrivalDate'] as Timestamp).toDate()
              : null,
      totalCartons: data['totalCartons'] ?? 0,
      totalWeight: (data['totalWeight'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      isReceived: data['isReceived'] ?? false,
      items:
          (data['items'] as List<dynamic>)
              .map((e) => ShipmentItem.fromMap(e))
              .toList(),
    );
  }
}
