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
  final String? transactionId; // Links to sales_orders
  final String source;

  SaleModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.paid,
    required this.customerType,
    required this.timestamp,
    this.paymentMethod,
    required this.appliedDebits,
    this.transactionId,
    required this.source,
  });

  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    // 1. Safe Data Map Casting
    Map<String, dynamic> d = doc.data() as Map<String, dynamic>;

    return SaleModel(
      id: doc.id,
      name: d['name'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paid: (d['paid'] as num?)?.toDouble() ?? 0.0,
      customerType: d['customerType'] ?? 'regular',

      // 2. Timestamp Safety
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // 3. Payment Method Casting
      paymentMethod: d['paymentMethod'] as Map<String, dynamic>?,

      appliedDebits: d['appliedDebits'] ?? [],

      // 4. CRITICAL: Fallback logic to find the Link ID
      // If 'transactionId' is missing, check 'invoiceId'
      transactionId: d['transactionId'] ?? d['invoiceId'],

      source: d['source'] ?? 'direct',
    );
  }

  double get pending => amount - paid;
}
