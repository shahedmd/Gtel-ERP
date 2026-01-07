import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentModel {
  String? docId;
  final int productId;
  final String productName;
  final String productModel;
  final String productBrand; // Added for better UI context
  final int seaQty;
  final int airQty;
  final DateTime createdDate; // The "Shipment Date"
  final DateTime? arrivalDate; // The "Stock Entry Date"
  final bool isReceived;

  ShipmentModel({
    this.docId,
    required this.productId,
    required this.productName,
    required this.productModel,
    required this.productBrand,
    required this.seaQty,
    required this.airQty,
    required this.createdDate,
    this.arrivalDate,
    this.isReceived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productModel': productModel,
      'productBrand': productBrand,
      'seaQty': seaQty,
      'airQty': airQty,
      'createdDate': Timestamp.fromDate(createdDate),
      'arrivalDate':
          arrivalDate != null ? Timestamp.fromDate(arrivalDate!) : null,
      'isReceived': isReceived,
    };
  }

  factory ShipmentModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShipmentModel(
      docId: doc.id,
      productId: data['productId'],
      productName: data['productName'] ?? '',
      productModel: data['productModel'] ?? '',
      productBrand: data['productBrand'] ?? '',
      seaQty: data['seaQty'] ?? 0,
      airQty: data['airQty'] ?? 0,
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      arrivalDate:
          data['arrivalDate'] != null
              ? (data['arrivalDate'] as Timestamp).toDate()
              : null,
      isReceived: data['isReceived'] ?? false,
    );
  }
}
