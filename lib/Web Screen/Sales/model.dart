import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final String name;
  final double amount;
  final double paid;
  final String customerType;
  final DateTime timestamp;

  // Stores the LATEST or Primary payment method details
  final Map<String, dynamic>? paymentMethod;

  // NEW: Stores the list of all payment transactions for this sale
  final List<Map<String, dynamic>> paymentHistory;

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
    this.paymentHistory = const [], // Default to empty list
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

      // 3. Payment Method Casting (The map containing details like bkashNumber)
      paymentMethod: d['paymentMethod'] as Map<String, dynamic>?,

      // 4. Payment History Parsing (NEW)
      paymentHistory:
          (d['paymentHistory'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],

      appliedDebits: d['appliedDebits'] ?? [],

      // 5. CRITICAL: Fallback logic to find the Link ID
      transactionId: d['transactionId'] ?? d['invoiceId'],

      source: d['source'] ?? 'direct',
    );
  }

  double get pending => amount - paid;
}
