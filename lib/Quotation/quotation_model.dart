import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QuotationItem {
  final int productId;
  final String name;
  final String model;
  final String brand;
  final int quantity;
  final double unitPrice;
  final Map<String, dynamic> productSnapshot;

  const QuotationItem({
    required this.productId,
    required this.name,
    required this.model,
    required this.brand,
    required this.quantity,
    required this.unitPrice,
    required this.productSnapshot,
  });

  double get subtotal => quantity * unitPrice;

  factory QuotationItem.fromMap(Map<String, dynamic> data) {
    return QuotationItem(
      productId: (data['productId'] as num?)?.toInt() ?? 0,
      name: data['name']?.toString() ?? '',
      model: data['model']?.toString() ?? '',
      brand: data['brand']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      productSnapshot: Map<String, dynamic>.from(
        data['productSnapshot'] as Map? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'model': model,
    'brand': brand,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'subtotal': subtotal,
    'productSnapshot': productSnapshot,
  };
}

class Quotation {
  final String id;
  final String quotationNo;
  final String customerName;
  final String customerPhone;
  final String customerType;
  final String shopName;
  final String address;
  final List<QuotationItem> items;
  final double discount;
  final String discountNote;
  final String note;
  final int validityDays;
  final DateTime createdAt;
  final String createdBy;

  const Quotation({
    required this.id,
    required this.quotationNo,
    required this.customerName,
    required this.customerPhone,
    required this.customerType,
    required this.shopName,
    required this.address,
    required this.items,
    required this.discount,
    required this.discountNote,
    required this.note,
    required this.validityDays,
    required this.createdAt,
    required this.createdBy,
  });

  double get subtotal => items.fold(0, (total, item) => total + item.subtotal);
  double get grandTotal => (subtotal - discount).clamp(0, double.infinity);
  DateTime get validUntil => createdAt.add(Duration(days: validityDays));
  String get formattedDate => DateFormat('dd/MM/yyyy').format(createdAt);

  factory Quotation.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAtValue = data['createdAt'];
    final createdAt =
        createdAtValue is Timestamp
            ? createdAtValue.toDate()
            : DateTime.tryParse(createdAtValue?.toString() ?? '') ??
                DateTime.now();

    return Quotation(
      id: id,
      quotationNo: data['quotationNo']?.toString() ?? id,
      customerName: data['customerName']?.toString() ?? '',
      customerPhone: data['customerPhone']?.toString() ?? '',
      customerType: data['customerType']?.toString() ?? 'WHOLESALE',
      shopName: data['shopName']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      items:
          (data['items'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    QuotationItem.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      discountNote: data['discountNote']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 14,
      createdAt: createdAt,
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'quotationNo': quotationNo,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerType': customerType,
    'shopName': shopName,
    'address': address,
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'discount': discount,
    'discountNote': discountNote,
    'grandTotal': grandTotal,
    'note': note,
    'validityDays': validityDays,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toSaleDraft() => {
    'quotationId': id,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerType': customerType,
    'shopName': shopName,
    'address': address,
    'discount': discount,
    'discountNote': discountNote,
    'items': items.map((item) => item.toMap()).toList(),
  };
}
