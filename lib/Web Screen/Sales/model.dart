import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final String name;
  final double amount;
  final double paid;

  // CRITICAL FIELD: Tracks how much was paid via Ledger/Debtor collection later.
  // This allows OverviewController to subtract this from 'paid' to find 'Real Cash at Sale Time'.
  final double ledgerPaid;

  final String customerType;
  final DateTime timestamp;
  final Map<String, dynamic>? paymentMethod;
  final List<Map<String, dynamic>> paymentHistory;
  final List<dynamic> appliedDebits;
  final String? transactionId;
  final String source;

  SaleModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.paid,
    this.ledgerPaid = 0.0, // Default to 0
    required this.customerType,
    required this.timestamp,
    this.paymentMethod,
    this.paymentHistory = const [],
    required this.appliedDebits,
    this.transactionId,
    required this.source,
  });

  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    // 1. Safe Cast to Map
    Map<String, dynamic> d = doc.data() as Map<String, dynamic>;

    return SaleModel(
      id: doc.id,
      name: d['name'] ?? '',

      // 2. Safe Number Parsing (Handles int/double/null)
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paid: (d['paid'] as num?)?.toDouble() ?? 0.0,

      // 3. CRITICAL: Safe Read for ledgerPaid
      // If field is missing (old data), it returns 0.0
      ledgerPaid: (d['ledgerPaid'] as num?)?.toDouble() ?? 0.0,

      customerType: d['customerType'] ?? 'regular',

      // 4. Safe Timestamp
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),

      paymentMethod: d['paymentMethod'] as Map<String, dynamic>?,

      // 5. Safe List Parsing
      paymentHistory:
          (d['paymentHistory'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],

      appliedDebits: d['appliedDebits'] ?? [],

      // 6. Transaction/Invoice Link
      transactionId: d['transactionId'] ?? d['invoiceId'],
      source: d['source'] ?? 'direct',
    );
  }

  // Helper: Returns true if this sale was fully collected via Ledger (not cash)
  bool get isFullyLedgerPaid => ledgerPaid >= paid && paid > 0;

  double get pending => amount - paid;
}