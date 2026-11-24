import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseAllocationPlan {
  final List<Map<String, dynamic>> allocations;
  final double unallocatedAmount;

  const PurchaseAllocationPlan({
    required this.allocations,
    required this.unallocatedAmount,
  });
}

class PurchaseAllocation {
  static const int _version = 1;
  static final Map<String, Future<void>> _migrations = {};

  static double amountFor(Map<String, dynamic> data) {
    final value = data['totalAmount'] ?? data['amount'] ?? 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double settledAmountFor(Map<String, dynamic> data) {
    final value = data['settledAmount'] ?? 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double dueFor(Map<String, dynamic> data) {
    final due = amountFor(data) - settledAmountFor(data);
    return due > 0.01 ? due : 0;
  }

  static PurchaseAllocationPlan allocate({
    required Iterable<Map<String, dynamic>> invoices,
    required double amount,
  }) {
    final ordered =
        invoices.toList()..sort((a, b) {
          final dateCompare = _dateFor(
            a['date'],
          ).compareTo(_dateFor(b['date']));
          if (dateCompare != 0) return dateCompare;
          return (a['id'] ?? '').toString().compareTo(
            (b['id'] ?? '').toString(),
          );
        });

    var remaining = amount > 0 ? amount : 0.0;
    final allocations = <Map<String, dynamic>>[];

    for (final invoice in ordered) {
      if (remaining <= 0.01) break;
      final due = dueFor(invoice);
      if (due <= 0.01) continue;

      final applied = remaining < due ? remaining : due;
      allocations.add({
        'invoiceId': (invoice['id'] ?? '').toString(),
        'amount': applied,
      });
      remaining -= applied;
    }

    return PurchaseAllocationPlan(
      allocations: allocations,
      unallocatedAmount: remaining > 0.01 ? remaining : 0,
    );
  }

  static Future<PurchaseAllocationPlan> planForSettlement({
    required FirebaseFirestore db,
    required String debtorId,
    required double amount,
  }) async {
    await ensureMigrated(db: db, debtorId: debtorId);
    final snapshot =
        await db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('purchases')
            .where('type', isEqualTo: 'invoice')
            .get();

    final invoices =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return <String, dynamic>{...data, 'id': doc.id};
        }).toList();

    return allocate(invoices: invoices, amount: amount);
  }

  static Future<void> ensureMigrated({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final lockKey = '${db.app.name}/$debtorId';
    final inProgress = _migrations[lockKey];
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final migration = _migrate(db: db, debtorId: debtorId);
    _migrations[lockKey] = migration;
    try {
      await migration;
    } finally {
      if (identical(_migrations[lockKey], migration)) {
        _migrations.remove(lockKey);
      }
    }
  }

  static Future<void> _migrate({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final debtorSnapshot = await debtorRef.get();
    if (debtorSnapshot.data()?['purchaseAllocationVersion'] == _version) {
      return;
    }

    final purchasesRef = debtorRef.collection('purchases');
    final snapshot = await purchasesRef.get();
    final docs =
        snapshot.docs.toList()..sort((a, b) {
          final dateCompare = _dateFor(
            a.data()['date'],
          ).compareTo(_dateFor(b.data()['date']));
          if (dateCompare != 0) return dateCompare;

          final typeA = (a.data()['type'] ?? '').toString().toLowerCase();
          final typeB = (b.data()['type'] ?? '').toString().toLowerCase();
          if (typeA == 'invoice' && typeB != 'invoice') return -1;
          if (typeB == 'invoice' && typeA != 'invoice') return 1;
          return a.id.compareTo(b.id);
        });

    final invoiceBalances = <_InvoiceBalance>[];
    final writes = <void Function(WriteBatch)>[];

    for (final doc in docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      if (type == 'invoice') {
        invoiceBalances.add(
          _InvoiceBalance(
            id: doc.id,
            ref: doc.reference,
            amount: amountFor(data),
          ),
        );
        continue;
      }

      if (type != 'payment' && type != 'adjustment') continue;

      var remaining = amountFor(data);
      final allocations = <Map<String, dynamic>>[];
      for (final invoice in invoiceBalances) {
        if (remaining <= 0.01) break;
        if (invoice.due <= 0.01) continue;

        final applied = remaining < invoice.due ? remaining : invoice.due;
        invoice.settled += applied;
        remaining -= applied;
        allocations.add({'invoiceId': invoice.id, 'amount': applied});
      }

      writes.add(
        (batch) => batch.update(doc.reference, {
          'allocations': allocations,
          'unallocatedAmount': remaining > 0.01 ? remaining : 0,
          'allocationVersion': _version,
        }),
      );
    }

    for (final invoice in invoiceBalances) {
      writes.add(
        (batch) =>
            batch.update(invoice.ref, {'settledAmount': invoice.settled}),
      );
    }

    for (var start = 0; start < writes.length; start += 450) {
      final batch = db.batch();
      final end = start + 450 < writes.length ? start + 450 : writes.length;
      for (final write in writes.sublist(start, end)) {
        write(batch);
      }
      await batch.commit();
    }

    await debtorRef.set({
      'purchaseAllocationVersion': _version,
    }, SetOptions(merge: true));
  }

  static DateTime _dateFor(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _InvoiceBalance {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final double amount;
  double settled = 0;

  _InvoiceBalance({required this.id, required this.ref, required this.amount});

  double get due {
    final remaining = amount - settled;
    return remaining > 0.01 ? remaining : 0;
  }
}
