import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String name;
  final double amount; // Upgraded to double for financial accuracy
  final String note;
  final DateTime time;

  ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.note,
    required this.time,
  });

  // ==========================================
  // 1. SAFE DATA PARSING (Prevents Firestore Crashes)
  // ==========================================
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ==========================================
  // 2. FROM FIRESTORE FACTORY
  // ==========================================
  factory ExpenseModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ExpenseModel(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      amount: _parseDouble(data['amount']),
      note: data['note']?.toString().trim() ?? '',
      time:
          data['time'] is Timestamp
              ? (data['time'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

 
  Map<String, dynamic> toFirestore({bool isNewEntry = false}) {
    return {
      'name': name,
      'amount': amount,
      'note': note,
      // ERP Security Fix: If it's a new entry, force Firebase to stamp it with the exact Server Time.
      // If we are just updating an old entry, keep the original time.
      'time':
          isNewEntry ? FieldValue.serverTimestamp() : Timestamp.fromDate(time),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? name,
    double? amount,
    String? note,
    DateTime? time,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      time: time ?? this.time,
    );
  }


  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}