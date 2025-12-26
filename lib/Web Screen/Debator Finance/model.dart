import 'package:cloud_firestore/cloud_firestore.dart';

class DebtorModel {
  final String id;
  final String name;
  final String phone;
  final String nid;
  final String address;
  final String des;
  final List<Map<String, dynamic>> payments;
  final DateTime? createdAt;

  DebtorModel({
    required this.id, required this.name, required this.phone, 
    required this.nid, required this.address, required this.des, 
    required this.payments, this.createdAt
  });

  factory DebtorModel.fromFirestore(DocumentSnapshot doc) {
    Map d = doc.data() as Map;
    return DebtorModel(
      id: doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      nid: d['nid'] ?? '',
      address: d['address'] ?? '',
      des: d['des'] ?? '',
      payments: (d['payments'] as List? ?? []).cast<Map<String, dynamic>>(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String note;
  final DateTime date;
  final Map<String, dynamic>? paymentMethod;

  TransactionModel({
    required this.id, required this.amount, required this.type, 
    required this.note, required this.date, this.paymentMethod
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map d = doc.data() as Map;
    return TransactionModel(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      type: d['type'] ?? 'credit',
      note: d['note'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      paymentMethod: d['paymentMethod'],
    );
  }
}