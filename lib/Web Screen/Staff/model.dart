import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffModel {
  final String id;
  final String name;
  final String phone;
  final String nid;
  final String des;
  final int salary;
  final double currentDebt;
  final DateTime joiningDate;
  final String status; // 'active', 'resigned', 'suspended'
  final DateTime? resignDate;
  final String? resignReason;

  StaffModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.nid,
    required this.des,
    required this.salary,
    this.currentDebt = 0.0,
    required this.joiningDate,
    this.status = 'active',
    this.resignDate,
    this.resignReason,
  });

  bool get isActive => status == 'active';
  bool get isResigned => status == 'resigned';
  bool get isSuspended => status == 'suspended';

  factory StaffModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      nid: data['nid'] ?? '',
      des: data['des'] ?? '',
      salary: data['salary'] ?? 0,
      currentDebt: (data['currentDebt'] as num?)?.toDouble() ?? 0.0,
      joiningDate: (data['joiningDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
      resignDate:
          data['resignDate'] != null
              ? (data['resignDate'] as Timestamp).toDate()
              : null,
      resignReason: data['resignReason'],
    );
  }
}

class SalaryModel {
  final String id;
  final double amount;
  final String note;
  final String month;
  final String? type; // 'SALARY', 'ADVANCE', 'REPAYMENT', 'BONUS'
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
    final data = doc.data() as Map<String, dynamic>;
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

class SuspensionModel {
  final String id;
  final String month;
  final int days;
  final String reason;
  final DateTime createdAt;

  SuspensionModel({
    required this.id,
    required this.month,
    required this.days,
    required this.reason,
    required this.createdAt,
  });

  factory SuspensionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SuspensionModel(
      id: doc.id,
      month: data['month'] ?? '',
      days: data['days'] ?? 0,
      reason: data['reason'] ?? '',
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// Returns the adjusted (deducted) salary based on suspension days
  double adjustedSalary(int baseSalary) {
    if (days <= 0) return baseSalary.toDouble();
    try {
      final monthDate = DateFormat('MMMM yyyy').parse(month);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
      final deduction = (baseSalary / daysInMonth) * days;
      return baseSalary - deduction;
    } catch (_) {
      return baseSalary.toDouble();
    }
  }

  /// Returns the amount deducted due to suspension
  double deductionAmount(int baseSalary) {
    return baseSalary - adjustedSalary(baseSalary);
  }
}