import 'package:cloud_firestore/cloud_firestore.dart';

class ConditionOrderModel {
  final String invoiceId;
  final String customerName;
  final String customerPhone;
  final String courierName;
  final String challanNo;
  final int cartons;
  final double grandTotal;
  final double advance;
  final double courierDue; // The amount remaining to be collected
  final DateTime date;
  final String status; // 'on_delivery', 'completed', 'returned'
  final List<dynamic> items;

  ConditionOrderModel({
    required this.invoiceId,
    required this.customerName,
    required this.customerPhone,
    required this.courierName,
    required this.challanNo,
    required this.cartons,
    required this.grandTotal,
    required this.advance,
    required this.courierDue,
    required this.date,
    required this.status,
    required this.items,
  });

  factory ConditionOrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ConditionOrderModel(
      invoiceId: data['invoiceId'] ?? '',
      customerName: data['customerName'] ?? 'Unknown',
      customerPhone: data['customerPhone'] ?? '',
      courierName: data['courierName'] ?? 'General',
      challanNo: data['challanNo'] ?? '',
      cartons: int.tryParse(data['cartons'].toString()) ?? 0,
      grandTotal: double.tryParse(data['grandTotal'].toString()) ?? 0.0,
      advance:
          double.tryParse(
            (data['paymentDetails']?['totalPaidInput'] ?? 0).toString(),
          ) ??
          0.0,
      courierDue: double.tryParse(data['courierDue'].toString()) ?? 0.0,
      date: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      items: data['items'] ?? [],
    );
  }
}
