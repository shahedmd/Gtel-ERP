import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String name;
  final double amount;
  final String note;
  final DateTime time;
  final String method; // NEW: 'Cash' | 'Bank' | 'Bkash' | 'Nagad'

  ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.note,
    required this.time,
    this.method = 'Cash', // Defaults to Cash for backward compatibility
  });

  // ==========================================
  // 1. SAFE DATA PARSING
  // ==========================================
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Validates that the method string is one of the four known values.
  // Falls back to 'Cash' for any legacy records that pre-date this field.
  static const _validMethods = {'Cash', 'Bank', 'Bkash', 'Nagad'};

  static String _parseMethod(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return _validMethods.contains(s) ? s : 'Cash';
  }

  // ==========================================
  // 2. FROM FIRESTORE
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
      method: _parseMethod(data['method']), // NEW
    );
  }

  // ==========================================
  // 3. TO FIRESTORE
  // ==========================================
  Map<String, dynamic> toFirestore({bool isNewEntry = false}) {
    return {
      'name': name,
      'amount': amount,
      'note': note,
      'method': method, // NEW — now part of the model, not patched externally
      'time':
          isNewEntry ? FieldValue.serverTimestamp() : Timestamp.fromDate(time),
    };
  }

  // ==========================================
  // 4. COPY WITH
  // ==========================================
  ExpenseModel copyWith({
    String? id,
    String? name,
    double? amount,
    String? note,
    DateTime? time,
    String? method, // NEW
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      time: time ?? this.time,
      method: method ?? this.method, // NEW
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