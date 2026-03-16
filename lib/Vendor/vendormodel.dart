import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VendorModel {
  String? docId;
  final String name;
  final String contact;
  final double totalDue;
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

  String get formattedDue {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(totalDue.abs());
  }

  String get status {
    if (totalDue > 0) return 'Payable';
    if (totalDue < 0) return 'Advance';
    return 'Settled';
  }

  int get statusColorCode {
    if (totalDue > 0) return 1;
    if (totalDue < 0) return 2;
    return 0;
  }
}

class VendorTransaction {
  String? id;
  final String type;
  final double amount;
  final DateTime date;
  final String? paymentMethod;
  final String? shipmentName;
  final String? cartons;
  final String? notes;
  final bool isIncomingCash;
  final String?
  cashLedgerId; // NEW: To easily update/delete cash_ledger entries

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
    this.cashLedgerId,
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
      cashLedgerId: data['cashLedgerId'],
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }

  String get formattedDate {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(date); // Format to show exact time
  }
}