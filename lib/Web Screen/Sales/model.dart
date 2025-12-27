import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final String name;
  final double amount;
  final double paid;
  final String customerType;
  final DateTime timestamp;
  final Map<String, dynamic>? paymentMethod;
  final List<dynamic> appliedDebits;
  final String? transactionId;
  final String source;

  SaleModel({
    required this.id, required this.name, required this.amount,
    required this.paid, required this.customerType, required this.timestamp,
    this.paymentMethod, required this.appliedDebits, this.transactionId,
    required this.source,
  });

  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    Map d = doc.data() as Map;
    return SaleModel(
      id: doc.id,
      name: d['name'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paid: (d['paid'] as num?)?.toDouble() ?? 0.0,
      customerType: d['customerType'] ?? 'regular',
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      paymentMethod: d['paymentMethod'],
      appliedDebits: d['appliedDebits'] ?? [],
      transactionId: d['transactionId'],
      source: d['source'] ?? 'direct',
    );
  }

  double get pending => amount - paid;
}