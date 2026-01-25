import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class DebtorModel {
  final String id;
  final String name;
  final String des;
  final String nid;
  final String phone;
  final String address;
  final List<Map<String, dynamic>> payments;
  final DateTime? createdAt;
  final DateTime? lastTransactionDate;
  final double balance;

  DebtorModel({
    required this.id,
    required this.name,
    required this.des,
    required this.nid,
    required this.phone,
    required this.address,
    required this.payments,
    this.createdAt,
    this.lastTransactionDate,
    this.balance = 0.0,
  });

  factory DebtorModel.fromFirestore(DocumentSnapshot doc) {
    // 1. Get data safely. If document is empty, use empty map.
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DebtorModel(
      id: doc.id,

      // 2. FORCE STRING: Handles nulls, numbers, or boolean values gracefully
      name: (data['name'] ?? '').toString(),
      des: (data['des'] ?? '').toString(),
      nid: (data['nid'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),

      // 3. FORCE DOUBLE: Handles Int (48270), Double (48270.5), String ("48270"), or Null
      balance: _parseSafeDouble(data['balance']),

      // 4. SAFE LIST: Ensures the list doesn't contain nulls
      payments:
          (data['payments'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>? ?? <String, dynamic>{})
              .toList(),

      // 5. TIMESTAMP: Safely convert timestamps
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastTransactionDate:
          (data['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
  }

  // Helper to prevent balance crashes
  static double _parseSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class TransactionModel {
  final String id;
  final String transactionId;
  final double amount;
  final String note;
  final String type;
  final DateTime date;
  final Map<String, dynamic>? paymentMethod;

  TransactionModel({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.note,
    required this.type,
    required this.date,
    this.paymentMethod,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      transactionId: data['transactionId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      note: data['note'] ?? '',
      type: data['type'] ?? 'credit',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: data['paymentMethod'],
    );
  }
}
