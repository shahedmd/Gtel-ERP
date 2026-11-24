import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_snapshot_ledger_replay.dart';

class InvoiceSnapshotRepairResult {
  final String operationId;
  final int invoiceCount;

  const InvoiceSnapshotRepairResult({
    required this.operationId,
    required this.invoiceCount,
  });
}

class InvoiceSnapshotRepair {
  static const String _runsCollection = 'invoice_snapshot_repair_runs';
  static const String _stateDocument = 'invoice_snapshot_repair_state';
  static const String _latestDocument = 'latest';
  static const int _batchSize = 400;

  static Future<InvoiceSnapshotRepairResult> repairDebtor({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final debtorSnapshot = await debtorRef.get();
    if (!debtorSnapshot.exists) {
      throw StateError('Debtor account was not found.');
    }

    final latestRef = debtorRef.collection(_stateDocument).doc(_latestDocument);
    final latest = await latestRef.get();
    final latestStatus = latest.data()?['status'];
    if (latestStatus != null && latestStatus != 'undone') {
      throw StateError(
        'Undo or finish the latest invoice snapshot repair before starting '
        'another repair.',
      );
    }

    final ordersSnapshot =
        await db
            .collection('sales_orders')
            .where('debtorId', isEqualTo: debtorId)
            .get();
    if (ordersSnapshot.docs.isEmpty) {
      throw StateError('No sales invoices were found for this debtor.');
    }

    final transactionsSnapshot =
        await debtorRef.collection('transactions').get();
    final orders = ordersSnapshot.docs.toList();
    final transactions = transactionsSnapshot.docs.toList();
    final initialInvoicePayments = await _loadInitialInvoicePayments(
      db: db,
      orders: orders,
    );
    final repairedSnapshots = _calculateSnapshots(
      orders: orders,
      transactions: transactions,
      initialInvoicePayments: initialInvoicePayments,
    );

    final operationId = debtorRef.collection(_runsCollection).doc().id;
    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    await runRef.set({
      'debtorId': debtorId,
      'operationId': operationId,
      'status': 'backing_up',
      'createdAt': FieldValue.serverTimestamp(),
      'invoiceCount': orders.length,
    });

    final backups = <Map<String, dynamic>>[];
    for (final order in orders) {
      final data = order.data();
      final repaired = repairedSnapshots[order.id];
      if (repaired == null) {
        throw StateError('Could not calculate invoice ${order.id}.');
      }

      backups.add({
        'orderId': order.id,
        'hadSnapshotOldDue': data.containsKey('snapshotOldDue'),
        'snapshotOldDue': data['snapshotOldDue'],
        'hadSnapshotRunningDue': data.containsKey('snapshotRunningDue'),
        'snapshotRunningDue': data['snapshotRunningDue'],
        'repairedSnapshotOldDue': repaired.oldDue,
        'repairedSnapshotRunningDue': repaired.runningDue,
      });
    }

    for (var start = 0; start < backups.length; start += _batchSize) {
      final batch = db.batch();
      final end =
          start + _batchSize < backups.length
              ? start + _batchSize
              : backups.length;
      for (final backup in backups.sublist(start, end)) {
        batch.set(runRef.collection('invoices').doc(backup['orderId']), backup);
      }
      await batch.commit();
    }

    await runRef.update({
      'status': 'repairing',
      'backedUpAt': FieldValue.serverTimestamp(),
    });
    await latestRef.set({
      'operationId': operationId,
      'status': 'repairing',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var start = 0; start < orders.length; start += _batchSize) {
      final batch = db.batch();
      final end =
          start + _batchSize < orders.length
              ? start + _batchSize
              : orders.length;
      for (final order in orders.sublist(start, end)) {
        final repaired = repairedSnapshots[order.id]!;
        batch.update(order.reference, {
          'snapshotOldDue': repaired.oldDue,
          'snapshotRunningDue': repaired.runningDue,
        });
      }
      await batch.commit();
    }

    await runRef.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    await latestRef.set({
      'operationId': operationId,
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return InvoiceSnapshotRepairResult(
      operationId: operationId,
      invoiceCount: orders.length,
    );
  }

  static Future<int> undoLastRepair({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final latestRef = debtorRef.collection(_stateDocument).doc(_latestDocument);
    final latest = await latestRef.get();
    final operationId = latest.data()?['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw StateError('There is no invoice snapshot repair to undo.');
    }
    if (latest.data()?['status'] == 'undone') {
      throw StateError('The latest invoice snapshot repair is already undone.');
    }

    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    final run = await runRef.get();
    if (!run.exists) {
      throw StateError('The saved repair backup could not be found.');
    }
    final backupsSnapshot = await runRef.collection('invoices').get();
    if (backupsSnapshot.docs.isEmpty) {
      throw StateError('The saved invoice snapshot backup is empty.');
    }

    final ordersRef = db.collection('sales_orders');
    final restores = <_InvoiceSnapshotRestore>[];
    for (final backupDoc in backupsSnapshot.docs) {
      final backup = backupDoc.data();
      final orderId = (backup['orderId'] ?? backupDoc.id).toString();
      final orderRef = ordersRef.doc(orderId);
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw StateError(
          'Invoice $orderId no longer exists; no snapshots were restored.',
        );
      }

      final current = orderSnapshot.data() ?? <String, dynamic>{};
      final restore = _InvoiceSnapshotRestore(
        ref: orderRef,
        orderId: orderId,
        beforeOldDue: backup['snapshotOldDue'],
        beforeRunningDue: backup['snapshotRunningDue'],
        hadOldDue: backup['hadSnapshotOldDue'] == true,
        hadRunningDue: backup['hadSnapshotRunningDue'] == true,
        repairedOldDue: _number(backup['repairedSnapshotOldDue']),
        repairedRunningDue: _number(backup['repairedSnapshotRunningDue']),
      );

      final oldDueIsExpected =
          _sameValue(current['snapshotOldDue'], restore.repairedOldDue) ||
          _samePresenceAndValue(
            current,
            'snapshotOldDue',
            restore.hadOldDue,
            restore.beforeOldDue,
          );
      final runningDueIsExpected =
          _sameValue(
            current['snapshotRunningDue'],
            restore.repairedRunningDue,
          ) ||
          _samePresenceAndValue(
            current,
            'snapshotRunningDue',
            restore.hadRunningDue,
            restore.beforeRunningDue,
          );
      if (!oldDueIsExpected || !runningDueIsExpected) {
        throw StateError(
          'Invoice $orderId changed after repair; undo stopped to avoid '
          'overwriting newer invoice data.',
        );
      }
      restores.add(restore);
    }

    await runRef.update({'status': 'undoing'});
    await latestRef.update({
      'status': 'undoing',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var start = 0; start < restores.length; start += _batchSize) {
      final batch = db.batch();
      final end =
          start + _batchSize < restores.length
              ? start + _batchSize
              : restores.length;
      for (final restore in restores.sublist(start, end)) {
        batch.update(restore.ref, {
          'snapshotOldDue':
              restore.hadOldDue ? restore.beforeOldDue : FieldValue.delete(),
          'snapshotRunningDue':
              restore.hadRunningDue
                  ? restore.beforeRunningDue
                  : FieldValue.delete(),
        });
      }
      await batch.commit();
    }

    await runRef.update({
      'status': 'undone',
      'undoneAt': FieldValue.serverTimestamp(),
    });
    await latestRef.set({
      'operationId': operationId,
      'status': 'undone',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return restores.length;
  }

  static Future<Map<String, double>> _loadInitialInvoicePayments({
    required FirebaseFirestore db,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  }) async {
    final ids = <String>{};
    for (final order in orders) {
      final data = order.data();
      for (final key in ['invoiceId', 'transactionId']) {
        final id = (data[key] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
      ids.add(order.id);
    }

    final sales = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final allIds = ids.toList();
    for (var start = 0; start < allIds.length; start += 30) {
      final end = start + 30 < allIds.length ? start + 30 : allIds.length;
      final chunk = allIds.sublist(start, end);
      final result =
          await db
              .collection('daily_sales')
              .where('transactionId', whereIn: chunk)
              .get();
      sales.addAll(result.docs);
    }

    final payments = <String, double>{};
    for (final sale in sales) {
      final data = sale.data();
      final invoiceId =
          (data['transactionId'] ?? data['invoiceId'] ?? '').toString();
      final history = data['paymentHistory'] as List<dynamic>? ?? [];
      var initialPaid = 0.0;
      for (final item in history) {
        if (item is! Map) continue;
        if ((item['sourceTxId'] ?? '').toString().trim().isNotEmpty) continue;
        initialPaid += _number(item['amount']);
      }
      payments[invoiceId] = initialPaid;
    }
    return payments;
  }

  static Map<String, InvoiceSnapshotValues> _calculateSnapshots({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
    required Map<String, double> initialInvoicePayments,
  }) {
    final orderAliases = <String, String>{};
    for (final order in orders) {
      orderAliases[order.id] = order.id;
      final data = order.data();
      for (final key in ['invoiceId', 'transactionId']) {
        final alias = (data[key] ?? '').toString().trim();
        if (alias.isNotEmpty) orderAliases[alias] = order.id;
      }
    }

    final orderEvents = <InvoiceSnapshotLedgerEvent>[];
    for (final order in orders) {
      final data = order.data();
      final paymentDetails =
          data['paymentDetails'] is Map
              ? Map<String, dynamic>.from(data['paymentDetails'] as Map)
              : <String, dynamic>{};
      final invoiceId =
          (data['invoiceId'] ?? data['transactionId'] ?? order.id).toString();
      final paidForOldDue = _number(paymentDetails['paidForOldDue']);
      final paidForPreviousRunning = _number(
        paymentDetails['paidForPrevRunning'],
      );
      final paidForInvoice = initialInvoicePayments[invoiceId];
      if (paidForInvoice == null) {
        throw StateError(
          'Invoice $invoiceId has no initial payment history in daily_sales. '
          'The repair stopped without changing invoice snapshots.',
        );
      }

      final grandTotal = _number(
        data['grandTotal'],
        fallback: _number(data['subtotal']) - _number(data['discount']),
      );
      orderEvents.add(
        InvoiceSnapshotLedgerEvent(
          date: _date(data['date'] ?? data['timestamp']),
          tieBreaker: _date(data['timestamp'] ?? data['date']),
          orderId: order.id,
          oldDuePaid: paidForOldDue,
          runningDuePaid: paidForPreviousRunning,
          invoiceDue: (grandTotal - paidForInvoice).clamp(0, double.infinity),
        ),
      );
    }

    final standaloneEvents = <InvoiceSnapshotLedgerEvent>[];
    for (final transaction in transactions) {
      final data = transaction.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final transactionId = (data['transactionId'] ?? '').toString().trim();
      final linkedOrderId = orderAliases[transactionId];
      final note = (data['note'] ?? '').toString().toLowerCase();
      final isInvoiceSale = type == 'credit' && linkedOrderId != null;
      final isInvoicePayment =
          (type == 'debit' &&
              (orderAliases.keys.any(
                    (alias) =>
                        transactionId == '${alias}_pay' ||
                        transactionId == '${alias}_surplus',
                  ) ||
                  note.startsWith('payment for inv ') ||
                  note.startsWith('surplus pay from inv '))) ||
          (type == 'loan_payment' && note.startsWith('payment via inv '));
      if (isInvoiceSale || isInvoicePayment) continue;

      if (!{
        'previous_due',
        'loan_payment',
        'eid_bonus',
        'discount',
        'credit',
        'debit',
        'advance_given',
        'advance_received',
      }.contains(type)) {
        continue;
      }
      standaloneEvents.add(
        InvoiceSnapshotLedgerEvent(
          date: _date(data['date']),
          tieBreaker: _date(data['createdAt'] ?? data['date']),
          transactionType: type,
          amount: _number(data['amount']),
          transactionId: transaction.id,
        ),
      );
    }

    return InvoiceSnapshotLedgerReplay.calculate([
      ...orderEvents,
      ...standaloneEvents,
    ]);
  }

  static double _number(dynamic value, {double? fallback}) {
    if (value is num) return value.toDouble();
    if (value != null) {
      return double.tryParse(value.toString()) ?? fallback ?? 0;
    }
    return fallback ?? 0;
  }

  static DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  static bool _sameValue(dynamic current, double expected) {
    final currentNumber =
        current is num ? current.toDouble() : double.tryParse('$current');
    return currentNumber != null && (currentNumber - expected).abs() < 0.005;
  }

  static bool _samePresenceAndValue(
    Map<String, dynamic> current,
    String key,
    bool hadValue,
    dynamic oldValue,
  ) {
    if (hadValue != current.containsKey(key)) return false;
    if (!hadValue) return true;
    if (oldValue is num && current[key] is num) {
      return (oldValue.toDouble() - (current[key] as num).toDouble()).abs() <
          0.005;
    }
    return current[key] == oldValue;
  }
}

class _InvoiceSnapshotRestore {
  final DocumentReference<Map<String, dynamic>> ref;
  final String orderId;
  final dynamic beforeOldDue;
  final dynamic beforeRunningDue;
  final bool hadOldDue;
  final bool hadRunningDue;
  final double repairedOldDue;
  final double repairedRunningDue;

  const _InvoiceSnapshotRestore({
    required this.ref,
    required this.orderId,
    required this.beforeOldDue,
    required this.beforeRunningDue,
    required this.hadOldDue,
    required this.hadRunningDue,
    required this.repairedOldDue,
    required this.repairedRunningDue,
  });
}
