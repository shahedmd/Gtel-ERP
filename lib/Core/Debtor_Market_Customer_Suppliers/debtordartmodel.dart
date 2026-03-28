// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 1. HIGH-PERFORMANCE PARSERS
// ==========================================
double _parseSafeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0.0;
  return 0.0;
}

DateTime? _parseSafeDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

// ==========================================
// 2. DEBTOR MODEL
// ==========================================
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
  final double balance; // Receivable (Sales Due)
  final double purchaseDue; // Payable

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
    this.purchaseDue = 0.0,
  });

  factory DebtorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DebtorModel(
      id: doc.id,
      name: (data['name'] ?? '').toString().trim(),
      des: (data['des'] ?? '').toString().trim(),
      nid: (data['nid'] ?? '').toString().trim(),
      phone: (data['phone'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      balance: _parseSafeDouble(data['balance']),
      purchaseDue: _parseSafeDouble(data['purchaseDue']),
      payments:
          (data['payments'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>? ?? <String, dynamic>{})
              .toList(),
      createdAt: _parseSafeDate(data['createdAt']),
      lastTransactionDate: _parseSafeDate(data['lastTransactionDate']),
    );
  }

  // --- COPY WITH (Professional Standard) ---
  DebtorModel copyWith({
    String? id,
    String? name,
    String? des,
    String? nid,
    String? phone,
    String? address,
    List<Map<String, dynamic>>? payments,
    DateTime? createdAt,
    DateTime? lastTransactionDate,
    double? balance,
    double? purchaseDue,
  }) {
    return DebtorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      des: des ?? this.des,
      nid: nid ?? this.nid,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
      balance: balance ?? this.balance,
      purchaseDue: purchaseDue ?? this.purchaseDue,
    );
  }

  // --- VALUE EQUALITY ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DebtorModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ==========================================
// 3. TRANSACTION MODEL
// ==========================================
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
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return TransactionModel(
      id: doc.id,
      transactionId: (data['transactionId'] ?? '').toString().trim(),
      amount: _parseSafeDouble(data['amount']),
      note: (data['note'] ?? '').toString().trim(),
      type: (data['type'] ?? 'credit').toString().trim(),
      date: _parseSafeDate(data['date']) ?? DateTime.now(),
      paymentMethod: data['paymentMethod'] as Map<String, dynamic>?,
    );
  }

  // --- COPY WITH (Professional Standard) ---
  TransactionModel copyWith({
    String? id,
    String? transactionId,
    double? amount,
    String? note,
    String? type,
    DateTime? date,
    Map<String, dynamic>? paymentMethod,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      type: type ?? this.type,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  // --- VALUE EQUALITY ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}