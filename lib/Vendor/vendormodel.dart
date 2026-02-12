import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VendorModel {
  String? docId;
  final String name;
  final String contact;
  final double
  totalDue; // Positive = We owe them, Negative = They owe us (Advance)
  final DateTime? createdAt;

  VendorModel({
    this.docId,
    required this.name,
    required this.contact,
    required this.totalDue,
    this.createdAt,
  });

  factory VendorModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorModel(
      docId: doc.id,
      name: data['name'] ?? 'Unknown Vendor',
      contact: data['contact'] ?? '',
      totalDue: (data['totalDue'] ?? 0.0).toDouble(),
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  // --- ERP Helpers ---

  // 1. Full Number Format (e.g., 12,500)
  String get formattedDue {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(totalDue.abs());
  }

  // 2. Status Indicator Logic
  // Returns: 'Payable', 'Advance', or 'Settled'
  String get status {
    if (totalDue > 0) return 'Payable'; // We owe money
    if (totalDue < 0) return 'Advance'; // We paid extra / They owe us
    return 'Settled';
  }

  // 3. Status Color Suggestion (Used in UI)
  // 0 = Green (Settled), 1 = Red (Payable), 2 = Blue (Advance)
  int get statusColorCode {
    if (totalDue > 0) return 1; // Red
    if (totalDue < 0) return 2; // Blue/Orange
    return 0; // Green
  }
}

class VendorTransaction {
  String? id;
  final String type; // 'CREDIT' or 'DEBIT'
  final double amount;
  final DateTime date;
  final String? paymentMethod;
  final String? shipmentName;
  final String? cartons;
  final String? notes;
  final bool isIncomingCash;

  VendorTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.paymentMethod,
    this.shipmentName,
    this.cartons,
    this.notes,
    this.isIncomingCash = false,
  });

  factory VendorTransaction.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorTransaction(
      id: doc.id,
      type: data['type'] ?? 'UNKNOWN',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date:
          data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
      paymentMethod: data['paymentMethod'],
      shipmentName: data['shipmentName'],
      cartons: data['cartons'],
      notes: data['notes'],
      isIncomingCash: data['isIncomingCash'] ?? false,
    );
  }

  // Helper for UI Table
  String get formattedAmount {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(date);
  }
}