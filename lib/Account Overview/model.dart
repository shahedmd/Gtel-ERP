import 'package:cloud_firestore/cloud_firestore.dart';

class FixedAssetModel {
  String? id;
  String name;
  double value;
  String category;
  DateTime date;

  FixedAssetModel({
    this.id,
    required this.name,
    required this.value,
    required this.category,
    required this.date,
  });

  factory FixedAssetModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FixedAssetModel(
      id: doc.id,
      name: data['name'] ?? '',
      value: double.tryParse(data['value'].toString()) ?? 0.0,
      category: data['category'] ?? 'General',
      date:
          data['date'] != null
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }
}

class RecurringExpenseModel {
  String? id;
  String title;
  double monthlyAmount;
  String type; // 'Salary', 'Rent', 'Bill'

  RecurringExpenseModel({
    this.id,
    required this.title,
    required this.monthlyAmount,
    required this.type,
  });

  factory RecurringExpenseModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringExpenseModel(
      id: doc.id,
      title: data['title'] ?? '',
      monthlyAmount: double.tryParse(data['monthlyAmount'].toString()) ?? 0.0,
      type: data['type'] ?? 'Expense',
    );
  }
}
