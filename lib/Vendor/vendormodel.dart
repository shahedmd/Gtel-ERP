import 'package:cloud_firestore/cloud_firestore.dart';

class VendorModel {
  String? docId;
  final String name;
  final String contact;
  final double totalDue; // Positive = We owe them, Negative = They owe us
  final DateTime? createdAt;

  VendorModel({
    this.docId,
    required this.name,
    required this.contact,
    required this.totalDue,
    this.createdAt,
  });

  // Factory to safely parse from Firestore
  factory VendorModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorModel(
      docId: doc.id,
      name: data['name'] ?? 'Unknown Vendor',
      contact: data['contact'] ?? '',
      // Safe double conversion (handles int stored as double in DB)
      totalDue: (data['totalDue'] ?? 0.0).toDouble(),
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  // Helper to get formatted Due Amount
  String get formattedDue => "BDT ${totalDue.toStringAsFixed(0)}";
}

class VendorTransaction {
  String? id;
  final String
  type; // 'CREDIT' (Bill/Purchase/Received Advance) or 'DEBIT' (Payment)
  final double amount;
  final DateTime date;

  // Optional Fields
  final String? paymentMethod; // Cash, Bank, Check
  final String? shipmentName; // LINKED SHIPMENT NAME (For Auto-Entry)
  final String? cartons; // Carton details if manual entry
  final String? notes;
  final DateTime? shipmentDate;
  final DateTime? receiveDate;
  final bool isIncomingCash; // NEW: True if money came IN (Advance from Vendor)

  VendorTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.paymentMethod,
    this.shipmentName,
    this.cartons,
    this.notes,
    this.shipmentDate,
    this.receiveDate,
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

      // Nullable fields
      paymentMethod: data['paymentMethod'],
      shipmentName: data['shipmentName'],
      cartons: data['cartons'],
      notes: data['notes'],
      isIncomingCash: data['isIncomingCash'] ?? false,

      // Date handling
      shipmentDate:
          data['shipmentDate'] is Timestamp
              ? (data['shipmentDate'] as Timestamp).toDate()
              : null,
      receiveDate:
          data['receiveDate'] is Timestamp
              ? (data['receiveDate'] as Timestamp).toDate()
              : null,
    );
  }

  // Helpers for UI
  bool get isCredit => type == 'CREDIT';
  bool get isDebit => type == 'DEBIT';
}
