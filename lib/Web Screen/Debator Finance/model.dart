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
  final DateTime? lastTransactionDate; // New Field
  final double balance; // New Field

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
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return DebtorModel(
      id: doc.id,
      name: data['name'] ?? '',
      des: data['des'] ?? '',
      nid: data['nid'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      // Safely parse balance (handle int/double/string/null)
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      payments: List<Map<String, dynamic>>.from(data['payments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastTransactionDate:
          (data['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
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
