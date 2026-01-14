import 'package:cloud_firestore/cloud_firestore.dart';

class VendorModel {
  String? docId;
  final String name;
  final String contact;
  final double totalDue; // Positive means you owe them (Payable)

  VendorModel({
    this.docId,
    required this.name,
    required this.contact,
    required this.totalDue,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'contact': contact,
    'totalDue': totalDue,
  };

  factory VendorModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorModel(
      docId: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      totalDue: (data['totalDue'] ?? 0.0).toDouble(),
    );
  }
}

class VendorTransaction {
  String? docId;
  final String type; // 'CREDIT' (Bill) or 'DEBIT' (Payment)
  final double amount;
  final DateTime date;
  
  // Payment Details
  final String? paymentMethod; // Cash, Bank, USDT
  
  // Shipment Context (For linking bills to imports)
  final String? shipmentName;
  final String? cartons;
  final DateTime? shipmentDate;
  final DateTime? receiveDate;
  final String? notes;

  VendorTransaction({
    this.docId,
    required this.type,
    required this.amount,
    required this.date,
    this.paymentMethod,
    this.shipmentName,
    this.cartons,
    this.shipmentDate,
    this.receiveDate,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'paymentMethod': paymentMethod,
    'shipmentName': shipmentName,
    'cartons': cartons,
    'shipmentDate': shipmentDate != null ? Timestamp.fromDate(shipmentDate!) : null,
    'receiveDate': receiveDate != null ? Timestamp.fromDate(receiveDate!) : null,
    'notes': notes,
  };

  factory VendorTransaction.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorTransaction(
      docId: doc.id,
      type: data['type'] ?? 'CREDIT',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'],
      shipmentName: data['shipmentName'],
      cartons: data['cartons'],
      shipmentDate: data['shipmentDate'] != null ? (data['shipmentDate'] as Timestamp).toDate() : null,
      receiveDate: data['receiveDate'] != null ? (data['receiveDate'] as Timestamp).toDate() : null,
      notes: data['notes'],
    );
  }
}