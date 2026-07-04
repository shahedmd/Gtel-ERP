import 'package:cloud_firestore/cloud_firestore.dart';

double _parseSafeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0.0;
  return 0.0;
}

DateTime? _parseSafeDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

// ==========================================
// SOURCE TYPE (Agent Debtor vs Regular Customer Due)
// ==========================================
class DebtorSourceType {
  static const String agent = 'AGENT';
  static const String regular = 'REGULAR';
}

class DebtorModel {
  final String id;
  final String name;
  final String des;
  final String nid;
  final String phone;
  final String address;
  final List<Map<String, dynamic>> payments;
  final DateTime? createdAt;
  final DateTime? lastTransactionDate;
  final double balance; // Receivable (Sales Due)
  final double purchaseDue; // Payable

  // --- NEW: Unified List Support (Agent vs Regular Customer) ---
  // 'AGENT'   -> comes from `debatorbody` collection, has full transaction ledger
  // 'REGULAR' -> comes from `customers` collection (WHOLESALE/VIP), invoice-wise due only
  final String sourceType;
  // For REGULAR: 'WHOLESALE' / 'VIP' / 'CONDITION' (from customers.type). Null for AGENT.
  final String? customerCategory;

  DebtorModel({
    required this.id,
    required this.name,
    required this.des,
    required this.nid,
    required this.phone,
    required this.address,
    required this.payments,
    this.createdAt,
    this.lastTransactionDate,
    this.balance = 0.0,
    this.purchaseDue = 0.0,
    this.sourceType = DebtorSourceType.agent,
    this.customerCategory,
  });

  bool get isAgent => sourceType == DebtorSourceType.agent;
  bool get isRegularCustomer => sourceType == DebtorSourceType.regular;

  factory DebtorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DebtorModel(
      id: doc.id,
      name: (data['name'] ?? '').toString().trim(),
      des: (data['des'] ?? '').toString().trim(),
      nid: (data['nid'] ?? '').toString().trim(),
      phone: (data['phone'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      balance: _parseSafeDouble(data['balance']),
      purchaseDue: _parseSafeDouble(data['purchaseDue']),
      payments:
          (data['payments'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>? ?? <String, dynamic>{})
              .toList(),
      createdAt: _parseSafeDate(data['createdAt']),
      lastTransactionDate: _parseSafeDate(data['lastTransactionDate']),
      sourceType: DebtorSourceType.agent,
    );
  }

  // --- NEW: Maps a `customers` collection doc (WHOLESALE/VIP) into the
  // same shape used by the Debtor list/detail UI. `balance` here means
  // the customer's outstanding sales due (`currentDue` field).
  factory DebtorModel.fromRegularCustomer(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DebtorModel(
      id: doc.id, // phone is used as doc id in `customers`
      name: (data['name'] ?? '').toString().trim(),
      des: (data['shop'] ?? '').toString().trim(),
      nid: '',
      phone: (data['phone'] ?? doc.id).toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      balance: _parseSafeDouble(data['currentDue']),
      purchaseDue: 0.0,
      payments: const [],
      createdAt: null,
      lastTransactionDate: _parseSafeDate(data['lastShopDate']),
      sourceType: DebtorSourceType.regular,
      customerCategory: (data['type'] ?? 'WHOLESALE').toString().trim(),
    );
  }

  // --- COPY WITH (Professional Standard) ---
  DebtorModel copyWith({
    String? id,
    String? name,
    String? des,
    String? nid,
    String? phone,
    String? address,
    List<Map<String, dynamic>>? payments,
    DateTime? createdAt,
    DateTime? lastTransactionDate,
    double? balance,
    double? purchaseDue,
    String? sourceType,
    String? customerCategory,
  }) {
    return DebtorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      des: des ?? this.des,
      nid: nid ?? this.nid,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
      balance: balance ?? this.balance,
      purchaseDue: purchaseDue ?? this.purchaseDue,
      sourceType: sourceType ?? this.sourceType,
      customerCategory: customerCategory ?? this.customerCategory,
    );
  }

  // --- VALUE EQUALITY ---
  // NOTE: id alone is compared. Agent ids come from `debatorbody` auto-ids,
  // Regular customer ids are phone numbers from `customers` — these two
  // spaces don't collide, so plain id equality remains safe.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DebtorModel &&
        other.id == id &&
        other.sourceType == sourceType;
  }

  @override
  int get hashCode => Object.hash(id, sourceType);
}

// ==========================================
// 3. TRANSACTION MODEL
// ==========================================
class TransactionModel {
  final String id;
  final String transactionId;
  final double amount;
  final String note;
  final String type;
  final DateTime date;
  final Map<String, dynamic>? paymentMethod;

  TransactionModel({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.note,
    required this.type,
    required this.date,
    this.paymentMethod,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return TransactionModel(
      id: doc.id,
      transactionId: (data['transactionId'] ?? '').toString().trim(),
      amount: _parseSafeDouble(data['amount']),
      note: (data['note'] ?? '').toString().trim(),
      type: (data['type'] ?? 'credit').toString().trim(),
      date: _parseSafeDate(data['date']) ?? DateTime.now(),
      paymentMethod: data['paymentMethod'] as Map<String, dynamic>?,
    );
  }

  // --- COPY WITH (Professional Standard) ---
  TransactionModel copyWith({
    String? id,
    String? transactionId,
    double? amount,
    String? note,
    String? type,
    DateTime? date,
    Map<String, dynamic>? paymentMethod,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      type: type ?? this.type,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  // --- VALUE EQUALITY ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
