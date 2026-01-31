import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentItem {
  final int productId;
  final String productName;
  final String productModel;
  final String productBrand;
  final String productCategory;
  final double unitWeightSnapshot;

  // FINANCIAL (What we pay for)
  final int seaQty;
  final int airQty;

  // PHYSICAL (What we receive - Default equals financial, but editable)
  final int receivedSeaQty;
  final int receivedAirQty;

  final String cartonNo;

  // Snapshot prices
  final double seaPriceSnapshot;
  final double airPriceSnapshot;

  ShipmentItem({
    required this.productId,
    required this.productName,
    required this.productModel,
    required this.productBrand,
    required this.productCategory,
    required this.unitWeightSnapshot,
    required this.seaQty,
    required this.airQty,
    required this.receivedSeaQty,
    required this.receivedAirQty,
    required this.cartonNo,
    required this.seaPriceSnapshot,
    required this.airPriceSnapshot,
  });

  // Helper to calculate Loss/On Hold
  int get lossQty => (seaQty + airQty) - (receivedSeaQty + receivedAirQty);

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productModel': productModel,
      'productBrand': productBrand,
      'productCategory': productCategory,
      'unitWeightSnapshot': unitWeightSnapshot,
      'seaQty': seaQty,
      'airQty': airQty,
      'receivedSeaQty': receivedSeaQty,
      'receivedAirQty': receivedAirQty,
      'cartonNo': cartonNo,
      'seaPriceSnapshot': seaPriceSnapshot,
      'airPriceSnapshot': airPriceSnapshot,
    };
  }

  factory ShipmentItem.fromMap(Map<String, dynamic> map) {
    return ShipmentItem(
      productId: map['productId'] ?? 0,
      productName: map['productName'] ?? '',
      productModel: map['productModel'] ?? '',
      productBrand: map['productBrand'] ?? '',
      productCategory: map['productCategory'] ?? '',
      unitWeightSnapshot: (map['unitWeightSnapshot'] ?? 0.0).toDouble(),
      seaQty: map['seaQty'] ?? 0,
      airQty: map['airQty'] ?? 0,
      // If received qty is missing (old data), default to ordered qty
      receivedSeaQty: map['receivedSeaQty'] ?? map['seaQty'] ?? 0,
      receivedAirQty: map['receivedAirQty'] ?? map['airQty'] ?? 0,
      cartonNo: map['cartonNo'] ?? '',
      seaPriceSnapshot: (map['seaPriceSnapshot'] ?? 0.0).toDouble(),
      airPriceSnapshot: (map['airPriceSnapshot'] ?? 0.0).toDouble(),
    );
  }

  // Cost is ALWAYS based on Ordered Qty (Vendor Contract)
  double get totalItemCost =>
      (seaQty * seaPriceSnapshot) + (airQty * airPriceSnapshot);

  double get totalLineWeight => (seaQty + airQty) * unitWeightSnapshot;
}

class ShipmentModel {
  String? docId;
  final String shipmentName;
  final DateTime purchaseDate; // Primary Date
  final DateTime? arrivalDate; // Entry Date

  final String? vendorId;
  final String vendorName;
  final String carrier;
  final double exchangeRate;

  // REPORTING
  final String? carrierReport;

  final int totalCartons;
  final double totalWeight;
  final double totalAmount;
  final bool isReceived;
  final List<ShipmentItem> items;

  ShipmentModel({
    this.docId,
    required this.shipmentName,
    required this.purchaseDate,
    this.arrivalDate,
    this.vendorId,
    required this.vendorName,
    required this.carrier,
    required this.exchangeRate,
    this.carrierReport,
    required this.totalCartons,
    required this.totalWeight,
    required this.totalAmount,
    this.isReceived = false,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'shipmentName': shipmentName,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'arrivalDate':
          arrivalDate != null ? Timestamp.fromDate(arrivalDate!) : null,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'carrier': carrier,
      'exchangeRate': exchangeRate,
      'carrierReport': carrierReport,
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
      // Removed createdDate, defaulting to purchaseDate if legacy data needs it
      purchaseDate:
          data['purchaseDate'] != null
              ? (data['purchaseDate'] as Timestamp).toDate()
              : DateTime.now(),
      arrivalDate:
          data['arrivalDate'] != null
              ? (data['arrivalDate'] as Timestamp).toDate()
              : null,
      vendorId: data['vendorId'],
      vendorName: data['vendorName'] ?? 'N/A',
      carrier: data['carrier'] ?? 'N/A',
      exchangeRate: (data['exchangeRate'] ?? 0.0).toDouble(),
      carrierReport: data['carrierReport'],
      totalCartons: data['totalCartons'] ?? 0,
      totalWeight: (data['totalWeight'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      isReceived: data['isReceived'] ?? false,
      items:
          (data['items'] as List<dynamic>?)
              ?.map((e) => ShipmentItem.fromMap(e))
              .toList() ??
          [],
    );
  }
}
