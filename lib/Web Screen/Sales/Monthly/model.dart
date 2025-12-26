import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final double amount;
  final double paid;
  final DateTime timestamp;

  SaleModel({
    required this.amount,
    required this.paid,
    required this.timestamp,
  });

  factory SaleModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleModel(
      amount: (data['amount'] ?? 0).toDouble(),
      paid: (data['paid'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
