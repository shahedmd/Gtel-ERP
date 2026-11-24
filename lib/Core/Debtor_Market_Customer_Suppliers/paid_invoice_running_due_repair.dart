import 'package:cloud_firestore/cloud_firestore.dart';

import 'paid_invoice_running_due.dart';

class PaidInvoiceRunningDueRepairResult {
  const PaidInvoiceRunningDueRepairResult({
    required this.operationId,
    required this.clearedInvoiceCount,
    required this.skippedInvoiceCount,
  });

  final String operationId;
  final int clearedInvoiceCount;
  final int skippedInvoiceCount;
}

class PaidInvoiceRunningDueRepair {
  static const _runsCollection = 'paid_invoice_running_due_repair_runs';
  static const _stateCollection = 'paid_invoice_running_due_repair_state';
  static const _latestDocument = 'latest';
  static const _batchSize = 400;

  static Future<PaidInvoiceRunningDueRepairResult> repairDebtor({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final debtorSnapshot = await debtorRef.get();
    if (!debtorSnapshot.exists) {
      throw StateError('Debtor account was not found.');
    }

    final latestRef = debtorRef
        .collection(_stateCollection)
        .doc(_latestDocument);
    final latest = await latestRef.get();
    final latestStatus = latest.data()?['status'];
    if (latestStatus != null && latestStatus != 'undone') {
      throw StateError(
        'Undo the latest running-due repair before starting another.',
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

    final orders = ordersSnapshot.docs;
    final candidates = <_RunningDueRepairCandidate>[];
    var skippedInvoiceCount = 0;
    for (final order in orders) {
      final data = order.data();
      final snapshotRunningDue = data['snapshotRunningDue'];
      if (!_hasRunningDue(snapshotRunningDue) ||
          (data['customerType'] ?? '').toString().toLowerCase() != 'agent') {
        continue;
      }
      if (!PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(order: data)) {
        skippedInvoiceCount++;
        continue;
      }
      candidates.add(
        _RunningDueRepairCandidate(orderId: order.id, order: order, data: data),
      );
    }

    if (candidates.isEmpty) {
      return PaidInvoiceRunningDueRepairResult(
        operationId: '',
        clearedInvoiceCount: 0,
        skippedInvoiceCount: skippedInvoiceCount,
      );
    }

    final operationId = debtorRef.collection(_runsCollection).doc().id;
    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    await runRef.set({
      'debtorId': debtorId,
      'operationId': operationId,
      'status': 'backing_up',
      'createdAt': FieldValue.serverTimestamp(),
      'invoiceCount': candidates.length,
    });

    for (var start = 0; start < candidates.length; start += _batchSize) {
      final end =
          start + _batchSize < candidates.length
              ? start + _batchSize
              : candidates.length;
      final batch = db.batch();
      for (final candidate in candidates.sublist(start, end)) {
        final order = candidate.data;
        final paymentDetails =
            order['paymentDetails'] is Map
                ? Map<String, dynamic>.from(order['paymentDetails'] as Map)
                : const <String, dynamic>{};
        batch.set(runRef.collection('invoices').doc(candidate.orderId), {
          'orderId': candidate.orderId,
          'hadSnapshotRunningDue': order.containsKey('snapshotRunningDue'),
          'snapshotRunningDue': order['snapshotRunningDue'],
          'hadRunningDueBackup': order.containsKey(
            'snapshotRunningDueBeforePaidExists',
          ),
          'snapshotRunningDueBeforePaidExists':
              order['snapshotRunningDueBeforePaidExists'],
          'hadRunningDueValueBackup': order.containsKey(
            'snapshotRunningDueBeforePaid',
          ),
          'snapshotRunningDueBeforePaid': order['snapshotRunningDueBeforePaid'],
          'grandTotal': order['grandTotal'],
          'orderPaid': order['paid'],
          'orderDue': paymentDetails['due'],
          'orderIsFullyPaid': order['isFullyPaid'],
        });
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

    for (var start = 0; start < candidates.length; start += _batchSize) {
      final end =
          start + _batchSize < candidates.length
              ? start + _batchSize
              : candidates.length;
      final batch = db.batch();
      for (final candidate in candidates.sublist(start, end)) {
        batch.update(
          candidate.order.reference,
          PaidInvoiceRunningDueSnapshot.clearForRepair(candidate.data),
        );
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

    return PaidInvoiceRunningDueRepairResult(
      operationId: operationId,
      clearedInvoiceCount: candidates.length,
      skippedInvoiceCount: skippedInvoiceCount,
    );
  }

  static Future<int> undoLastRepair({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final latestRef = debtorRef
        .collection(_stateCollection)
        .doc(_latestDocument);
    final latest = await latestRef.get();
    final operationId = latest.data()?['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw StateError('There is no paid-invoice running-due repair to undo.');
    }
    if (latest.data()?['status'] == 'undone') {
      throw StateError('The latest running-due repair is already undone.');
    }

    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    final run = await runRef.get();
    if (!run.exists) throw StateError('The saved repair backup was not found.');
    final backups = await runRef.collection('invoices').get();
    if (backups.docs.isEmpty) {
      throw StateError('The saved running-due backup is empty.');
    }

    final restores = <_RunningDueRestore>[];
    for (final backupDoc in backups.docs) {
      final backup = backupDoc.data();
      final orderId = (backup['orderId'] ?? backupDoc.id).toString();
      final orderRef = db.collection('sales_orders').doc(orderId);
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw StateError('Invoice $orderId no longer exists; undo stopped.');
      }
      final current = orderSnapshot.data() ?? <String, dynamic>{};
      final paymentDetails =
          current['paymentDetails'] is Map
              ? Map<String, dynamic>.from(current['paymentDetails'] as Map)
              : const <String, dynamic>{};
      if ((!_isZero(current['snapshotRunningDue']) &&
              !_matchesOriginalSnapshot(current, backup)) ||
          !_sameNumber(current['grandTotal'], backup['grandTotal']) ||
          !_sameNumber(current['paid'], backup['orderPaid']) ||
          !_sameNumber(paymentDetails['due'], backup['orderDue']) ||
          current['isFullyPaid'] != backup['orderIsFullyPaid']) {
        throw StateError(
          'Invoice $orderId changed after repair; undo stopped to avoid '
          'overwriting newer invoice data.',
        );
      }
      restores.add(
        _RunningDueRestore(ref: orderRef, orderId: orderId, backup: backup),
      );
    }

    await runRef.update({'status': 'undoing'});
    await latestRef.update({
      'status': 'undoing',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var start = 0; start < restores.length; start += _batchSize) {
      final end =
          start + _batchSize < restores.length
              ? start + _batchSize
              : restores.length;
      final batch = db.batch();
      for (final restore in restores.sublist(start, end)) {
        final backup = restore.backup;
        final update = <String, dynamic>{
          'snapshotRunningDue':
              backup['hadSnapshotRunningDue'] == true
                  ? backup['snapshotRunningDue']
                  : FieldValue.delete(),
          'snapshotRunningDueBeforePaidExists':
              backup['hadRunningDueBackup'] == true
                  ? backup['snapshotRunningDueBeforePaidExists']
                  : FieldValue.delete(),
          'snapshotRunningDueBeforePaid':
              backup['hadRunningDueValueBackup'] == true
                  ? backup['snapshotRunningDueBeforePaid']
                  : FieldValue.delete(),
        };
        batch.update(restore.ref, update);
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

  static Future<int> undoLastPreviousDueRepair({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    final latestRef = debtorRef
        .collection('paid_invoice_previous_due_repair_state')
        .doc('latest');
    final latest = await latestRef.get();
    final operationId = latest.data()?['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw StateError('There is no earlier Previous Due repair to undo.');
    }
    if (latest.data()?['status'] == 'undone') {
      throw StateError('The earlier Previous Due repair is already undone.');
    }

    final runRef = debtorRef
        .collection('paid_invoice_previous_due_repair_runs')
        .doc(operationId);
    final run = await runRef.get();
    if (!run.exists) {
      throw StateError('The earlier repair backup was not found.');
    }
    final backups = await runRef.collection('invoices').get();
    if (backups.docs.isEmpty) {
      throw StateError('The earlier Previous Due backup is empty.');
    }

    final restores = <_LegacyPreviousDueRestore>[];
    for (final backupDoc in backups.docs) {
      final backup = backupDoc.data();
      final orderId = (backup['orderId'] ?? backupDoc.id).toString();
      final orderRef = db.collection('sales_orders').doc(orderId);
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw StateError('Invoice $orderId no longer exists; undo stopped.');
      }
      final current = orderSnapshot.data() ?? <String, dynamic>{};
      final paymentDetails =
          current['paymentDetails'] is Map
              ? Map<String, dynamic>.from(current['paymentDetails'] as Map)
              : const <String, dynamic>{};
      final dailySalesDocId = (backup['dailySalesDocId'] ?? '').toString();
      final dailySnapshot =
          dailySalesDocId.isEmpty
              ? null
              : await db.collection('daily_sales').doc(dailySalesDocId).get();
      final dailyCurrent = dailySnapshot?.data() ?? <String, dynamic>{};
      if ((!_isZero(current['snapshotOldDue']) &&
              !_matchesLegacyOriginalSnapshot(current, backup)) ||
          !_sameNumber(current['grandTotal'], backup['grandTotal']) ||
          !_sameNumber(current['paid'], backup['orderPaid']) ||
          !_sameNumber(paymentDetails['due'], backup['orderDue']) ||
          current['isFullyPaid'] != backup['orderIsFullyPaid'] ||
          dailySnapshot == null ||
          !dailySnapshot.exists ||
          !_sameNumber(dailyCurrent['amount'], backup['dailyAmount']) ||
          !_sameNumber(dailyCurrent['paid'], backup['dailyPaid']) ||
          !_sameNumber(dailyCurrent['pending'], backup['dailyPending'])) {
        throw StateError(
          'Invoice $orderId changed after the earlier repair; undo stopped '
          'to avoid overwriting newer invoice data.',
        );
      }
      restores.add(_LegacyPreviousDueRestore(ref: orderRef, backup: backup));
    }

    await runRef.update({'status': 'undoing'});
    await latestRef.update({
      'status': 'undoing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (var start = 0; start < restores.length; start += _batchSize) {
      final end =
          start + _batchSize < restores.length
              ? start + _batchSize
              : restores.length;
      final batch = db.batch();
      for (final restore in restores.sublist(start, end)) {
        final backup = restore.backup;
        batch.update(restore.ref, {
          'snapshotOldDue':
              backup['hadSnapshotOldDue'] == true
                  ? backup['snapshotOldDue']
                  : FieldValue.delete(),
          'snapshotOldDueBeforePaidExists':
              backup['hadPreviousDueBackup'] == true
                  ? backup['snapshotOldDueBeforePaidExists']
                  : FieldValue.delete(),
          'snapshotOldDueBeforePaid':
              backup['hadPreviousDueValueBackup'] == true
                  ? backup['snapshotOldDueBeforePaid']
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

  static bool _isZero(dynamic value) =>
      value is num && value.toDouble().abs() <= 0.005;

  static bool _hasRunningDue(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    return amount != null && amount.abs() > 0.005;
  }

  static bool _matchesOriginalSnapshot(
    Map<String, dynamic> current,
    Map<String, dynamic> backup,
  ) {
    if (backup['hadSnapshotRunningDue'] != true) {
      return !current.containsKey('snapshotRunningDue');
    }
    return _sameNumber(
      current['snapshotRunningDue'],
      backup['snapshotRunningDue'],
    );
  }

  static bool _matchesLegacyOriginalSnapshot(
    Map<String, dynamic> current,
    Map<String, dynamic> backup,
  ) {
    if (backup['hadSnapshotOldDue'] != true) {
      return !current.containsKey('snapshotOldDue');
    }
    return _sameNumber(current['snapshotOldDue'], backup['snapshotOldDue']);
  }

  static bool _sameNumber(dynamic a, dynamic b) {
    if (a == null || b == null) return a == b;
    final first = a is num ? a.toDouble() : double.tryParse(a.toString());
    final second = b is num ? b.toDouble() : double.tryParse(b.toString());
    return first != null && second != null && (first - second).abs() <= 0.005;
  }
}

class _RunningDueRepairCandidate {
  const _RunningDueRepairCandidate({
    required this.orderId,
    required this.order,
    required this.data,
  });

  final String orderId;
  final QueryDocumentSnapshot<Map<String, dynamic>> order;
  final Map<String, dynamic> data;
}

class _RunningDueRestore {
  const _RunningDueRestore({
    required this.ref,
    required this.orderId,
    required this.backup,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String orderId;
  final Map<String, dynamic> backup;
}

class _LegacyPreviousDueRestore {
  const _LegacyPreviousDueRestore({required this.ref, required this.backup});

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> backup;
}
