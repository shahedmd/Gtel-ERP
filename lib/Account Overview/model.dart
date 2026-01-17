import 'package:cloud_firestore/cloud_firestore.dart';

// Model for Fixed Assets (Laptops, Decoration, Shop Advance)
class FixedAssetModel {
  String? id;
  final String name;
  final double value;
  final String category; // e.g., 'Equipment', 'Security Deposit', 'Furniture'
  final DateTime date;

  FixedAssetModel({
    this.id,
    required this.name,
    required this.value,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'category': category,
      'date': Timestamp.fromDate(date),
    };
  }

  factory FixedAssetModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FixedAssetModel(
      id: doc.id,
      name: data['name'] ?? '',
      value: (data['value'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'General',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}

// Model for Recurring Payroll/Expenses (Rent, Salaries)
class PayrollItemModel {
  String? id;
  final String title;
  final double monthlyAmount;
  final String type; // 'Salary', 'Rent', 'Maintenance'

  PayrollItemModel({
    this.id,
    required this.title,
    required this.monthlyAmount,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {'title': title, 'monthlyAmount': monthlyAmount, 'type': type};
  }

  factory PayrollItemModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayrollItemModel(
      id: doc.id,
      title: data['title'] ?? '',
      monthlyAmount: (data['monthlyAmount'] ?? 0.0).toDouble(),
      type: data['type'] ?? 'General',
    );
  }
}
