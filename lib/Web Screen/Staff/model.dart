import 'package:cloud_firestore/cloud_firestore.dart';

class StaffModel {
  final String id;
  final String name;
  final String phone;
  final String nid;
  final String des; // Designation
  final int salary; // Base Salary
  final double currentDebt; // NEW: Track how much they owe
  final DateTime joiningDate;

  StaffModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.nid,
    required this.des,
    required this.salary,
    this.currentDebt = 0.0,
    required this.joiningDate,
  });

  factory StaffModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return StaffModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      nid: data['nid'] ?? '',
      des: data['des'] ?? '',
      salary: data['salary'] ?? 0,
      currentDebt: (data['currentDebt'] as num?)?.toDouble() ?? 0.0,
      joiningDate: (data['joiningDate'] as Timestamp).toDate(),
    );
  }
}

class SalaryModel {
  final String id;
  final double amount;
  final String note;
  final String month;
  final String? type; // 'SALARY', 'ADVANCE', 'REPAYMENT'
  final DateTime date;

  SalaryModel({
    required this.id,
    required this.amount,
    required this.note,
    required this.month,
    this.type,
    required this.date,
  });

  factory SalaryModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return SalaryModel(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      note: data['note'] ?? '',
      month: data['month'] ?? '',
      type: data['type'] as String? ?? 'SALARY',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}
