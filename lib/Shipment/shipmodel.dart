import 'package:cloud_firestore/cloud_firestore.dart';


class ShipmentItem {
  final int productId;
  final String productName;
  final String productModel;
  final String productBrand;
  final String productCategory;
  final double unitWeightSnapshot;

  // FINANCIAL (Ordered)
  final int seaQty;
  final int airQty;

  // PHYSICAL (Received)
  final int receivedSeaQty;
  final int receivedAirQty;

  final String cartonNo;

  final double seaPriceSnapshot;
  final double airPriceSnapshot;

  final bool ignoreMissing;

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
    this.ignoreMissing = false,
  });

  int get lossQty => (seaQty + airQty) - (receivedSeaQty + receivedAirQty);

  // Cost based on ORDERED (Billable)
  double get totalItemCost =>
      (seaQty * seaPriceSnapshot) + (airQty * airPriceSnapshot);

  // Cost based on RECEIVED (Actual Value)
  double get receivedItemValue =>
      (receivedSeaQty * seaPriceSnapshot) + (receivedAirQty * airPriceSnapshot);

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
      'ignoreMissing': ignoreMissing,
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
      receivedSeaQty: map['receivedSeaQty'] ?? map['seaQty'] ?? 0,
      receivedAirQty: map['receivedAirQty'] ?? map['airQty'] ?? 0,
      cartonNo: map['cartonNo'] ?? '',
      seaPriceSnapshot: (map['seaPriceSnapshot'] ?? 0.0).toDouble(),
      airPriceSnapshot: (map['airPriceSnapshot'] ?? 0.0).toDouble(),
      ignoreMissing: map['ignoreMissing'] ?? false,
    );
  }
}

class ShipmentModel {
  String? docId;
  final String shipmentName;
  final DateTime purchaseDate;
  final DateTime? arrivalDate;

  final String? vendorId;
  final String vendorName;
  final String carrier;
  final double exchangeRate;
  final String? carrierReport;

  final int totalCartons;
  final double totalWeight;
  final double totalAmount; // Original Bill
  final bool isReceived;

  // NEW: Store the calculated loss/difference from vendor swaps
  final double vendorLossAmount;

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
    this.vendorLossAmount = 0.0,
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
      'vendorLossAmount': vendorLossAmount,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory ShipmentModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShipmentModel(
      docId: doc.id,
      shipmentName: data['shipmentName'] ?? 'Unknown',
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
      vendorLossAmount: (data['vendorLossAmount'] ?? 0.0).toDouble(),
      items:
          (data['items'] as List<dynamic>?)
              ?.map((e) => ShipmentItem.fromMap(e))
              .toList() ??
          [],
    );
  }
}
