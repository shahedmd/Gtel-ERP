import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String name;
  final int amount;
  final String note;
  final DateTime time;

  ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.note,
    required this.time,
  });

  factory ExpenseModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ExpenseModel(
      id: id,
      name: data['name'] ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      note: data['note'] ?? '',
      time: data['time'] is Timestamp 
          ? (data['time'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}