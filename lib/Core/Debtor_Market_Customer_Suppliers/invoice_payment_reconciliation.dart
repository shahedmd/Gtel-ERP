import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_payment_reconciliation_plan.dart';

class InvoicePaymentReconciliationPreview {
  final int eligibleInvoiceCount;
  final int skippedInvoiceCount;
  final double ledgerPaidToAdd;
  final List<InvoicePaymentReconciliationSkip> skipped;

  const InvoicePaymentReconciliationPreview({
    required this.eligibleInvoiceCount,
    required this.skippedInvoiceCount,
    required this.ledgerPaidToAdd,
    required this.skipped,
  });
}

class InvoicePaymentReconciliationResult {
  final String operationId;
  final int updatedInvoiceCount;
  final int skippedInvoiceCount;
  final double ledgerPaidAdded;

  const InvoicePaymentReconciliationResult({
    required this.operationId,
    required this.updatedInvoiceCount,
    required this.skippedInvoiceCount,
    required this.ledgerPaidAdded,
  });
}

class InvoicePaymentReconciliation {
  static const String _runsCollection = 'invoice_payment_reconciliation_runs';
  static const String _stateCollection = 'invoice_payment_reconciliation_state';
  static const String _latestDocument = 'latest';
  static const int _batchSize = 200;
  static const List<String> _dailyFields = [
    'paid',
    'ledgerPaid',
    'pending',
    'status',
    'paymentMethod.pending',
  ];
  static const List<String> _orderFields = [
    'paid',
    'paymentDetails.due',
    'paymentDetails.paidForInvoice',
    'isFullyPaid',
    'status',
  ];

  static Future<InvoicePaymentReconciliationPreview> previewDebtor({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final plan = await _buildPlan(db: db, debtorId: debtorId);
    return InvoicePaymentReconciliationPreview(
      eligibleInvoiceCount: plan.changes.length,
      skippedInvoiceCount: plan.skipped.length,
      ledgerPaidToAdd: plan.ledgerPaidToAdd,
      skipped: plan.skipped,
    );
  }

  static Future<InvoicePaymentReconciliationResult> repairDebtor({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final debtorRef = db.collection('debatorbody').doc(debtorId);
    if (!(await debtorRef.get()).exists) {
      throw StateError('Debtor account was not found.');
    }

    final latestRef = debtorRef
        .collection(_stateCollection)
        .doc(_latestDocument);
    final latest = await latestRef.get();
    final latestStatus = latest.data()?['status'];
    if (latestStatus != null && latestStatus != 'undone') {
      throw StateError(
        'Undo or finish the latest payment reconciliation before starting '
        'another one.',
      );
    }

    final plan = await _buildPlan(db: db, debtorId: debtorId);
    if (plan.changes.isEmpty) {
      if (plan.skipped.isEmpty) {
        throw StateError('No payment fields need reconciliation.');
      }
      throw StateError(
        'No invoices were safe to update. Review the skipped invoice reasons.',
      );
    }

    final operationId = debtorRef.collection(_runsCollection).doc().id;
    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    await runRef.set({
      'debtorId': debtorId,
      'operationId': operationId,
      'status': 'backing_up',
      'createdAt': FieldValue.serverTimestamp(),
      'invoiceCount': plan.changes.length,
      'skippedInvoiceCount': plan.skipped.length,
      'ledgerPaidToAdd': plan.ledgerPaidToAdd,
    });

    for (var start = 0; start < plan.changes.length; start += _batchSize) {
      final end =
          start + _batchSize < plan.changes.length
              ? start + _batchSize
              : plan.changes.length;
      final batch = db.batch();
      for (final change in plan.changes.sublist(start, end)) {
        batch.set(
          runRef.collection('invoices').doc(change.dailySalesDocumentId),
          _backupData(change),
        );
      }
      await batch.commit();
    }

    await runRef.update({
      'status': 'applying',
      'backedUpAt': FieldValue.serverTimestamp(),
    });
    await latestRef.set({
      'operationId': operationId,
      'status': 'applying',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var start = 0; start < plan.changes.length; start += _batchSize) {
      final end =
          start + _batchSize < plan.changes.length
              ? start + _batchSize
              : plan.changes.length;
      final changes = plan.changes.sublist(start, end);
      for (var checkStart = 0; checkStart < changes.length; checkStart += 20) {
        final checkEnd =
            checkStart + 20 < changes.length ? checkStart + 20 : changes.length;
        await Future.wait(
          changes
              .sublist(checkStart, checkEnd)
              .map((change) => _ensureUnchanged(db, change)),
        );
      }

      final batch = db.batch();
      for (final change in changes) {
        batch.update(
          db.collection('daily_sales').doc(change.dailySalesDocumentId),
          {
            'paid': change.paid,
            'ledgerPaid': change.ledgerPaid,
            'pending': change.due,
            'status': change.due <= 0.5 ? 'paid' : 'partial',
            'paymentMethod.pending': change.due,
          },
        );
        batch
            .update(db.collection('sales_orders').doc(change.orderDocumentId), {
              'paid': change.paid,
              'paymentDetails.due': change.due,
              'paymentDetails.paidForInvoice': change.paid,
              'isFullyPaid': change.due <= 0.5,
              'status': change.due <= 0.5 ? 'completed' : 'partial',
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

    return InvoicePaymentReconciliationResult(
      operationId: operationId,
      updatedInvoiceCount: plan.changes.length,
      skippedInvoiceCount: plan.skipped.length,
      ledgerPaidAdded: plan.ledgerPaidToAdd,
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
      throw StateError('There is no payment reconciliation to undo.');
    }
    if (latest.data()?['status'] == 'undone') {
      throw StateError('The latest payment reconciliation is already undone.');
    }

    final runRef = debtorRef.collection(_runsCollection).doc(operationId);
    final run = await runRef.get();
    if (!run.exists) {
      throw StateError('The saved reconciliation backup could not be found.');
    }
    final backups = await runRef.collection('invoices').get();
    if (backups.docs.isEmpty) {
      throw StateError('The saved reconciliation backup is empty.');
    }

    final restores = <_PaymentReconciliationRestore>[];
    for (final backupDoc in backups.docs) {
      final data = backupDoc.data();
      final dailyId = data['dailySalesDocumentId'].toString();
      final orderId = data['orderDocumentId'].toString();
      final dailyRef = db.collection('daily_sales').doc(dailyId);
      final orderRef = db.collection('sales_orders').doc(orderId);
      final dailySnapshot = await dailyRef.get();
      final orderSnapshot = await orderRef.get();
      if (!dailySnapshot.exists || !orderSnapshot.exists) {
        throw StateError(
          'Invoice ${data['invoiceId']} is missing from Firestore; no data '
          'was restored.',
        );
      }

      final beforeDaily = _decodeValues(data, 'daily', _dailyFields);
      final beforeOrder = _decodeValues(data, 'order', _orderFields);
      final expectedDaily = _decodeValues(data, 'expectedDaily', _dailyFields);
      final expectedOrder = _decodeValues(data, 'expectedOrder', _orderFields);
      final currentDaily = dailySnapshot.data() ?? <String, dynamic>{};
      final currentOrder = orderSnapshot.data() ?? <String, dynamic>{};
      if (!_matchesEither(currentDaily, beforeDaily, expectedDaily) ||
          !_matchesEither(currentOrder, beforeOrder, expectedOrder)) {
        throw StateError(
          'Invoice ${data['invoiceId']} changed after reconciliation; undo '
          'stopped to avoid overwriting newer payment data.',
        );
      }
      restores.add(
        _PaymentReconciliationRestore(
          dailyRef: dailyRef,
          orderRef: orderRef,
          beforeDaily: beforeDaily,
          beforeOrder: beforeOrder,
        ),
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
        batch.update(restore.dailyRef, _restoreUpdates(restore.beforeDaily));
        batch.update(restore.orderRef, _restoreUpdates(restore.beforeOrder));
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

  static Future<InvoicePaymentReconciliationPlan> _buildPlan({
    required FirebaseFirestore db,
    required String debtorId,
  }) async {
    final ordersSnapshot =
        await db
            .collection('sales_orders')
            .where('debtorId', isEqualTo: debtorId)
            .get();
    if (ordersSnapshot.docs.isEmpty) {
      throw StateError('No sales invoices were found for this debtor.');
    }

    final ordersByAlias = <String, Set<String>>{};
    for (final order in ordersSnapshot.docs) {
      final data = order.data();
      final aliases = {
        order.id,
        (data['invoiceId'] ?? '').toString().trim(),
        (data['transactionId'] ?? '').toString().trim(),
      }..remove('');
      for (final alias in aliases) {
        ordersByAlias.putIfAbsent(alias, () => <String>{}).add(order.id);
      }
    }

    final aliases = ordersByAlias.keys.toList();
    final dailyDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var start = 0; start < aliases.length; start += 30) {
      final end = start + 30 < aliases.length ? start + 30 : aliases.length;
      final chunk = aliases.sublist(start, end);
      for (final field in ['transactionId', 'invoiceId']) {
        final snapshot =
            await db
                .collection('daily_sales')
                .where(field, whereIn: chunk)
                .get();
        for (final doc in snapshot.docs) {
          dailyDocs[doc.id] = doc;
        }
      }
    }

    final dailyByOrder =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final daily in dailyDocs.values) {
      final data = daily.data();
      final saleAliases = {
        (data['transactionId'] ?? '').toString().trim(),
        (data['invoiceId'] ?? '').toString().trim(),
      }..remove('');
      final matchingOrders = <String>{};
      for (final alias in saleAliases) {
        matchingOrders.addAll(ordersByAlias[alias] ?? const <String>{});
      }
      if (matchingOrders.length != 1) {
        continue;
      }
      dailyByOrder
          .putIfAbsent(
            matchingOrders.single,
            () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
          .add(daily);
    }

    final records = <ReconciliationInvoiceRecord>[];
    final skipped = <InvoicePaymentReconciliationSkip>[];
    for (final order in ordersSnapshot.docs) {
      final invoiceId = (order.data()['invoiceId'] ?? order.id).toString();
      final matches = dailyByOrder[order.id] ?? const [];
      if (matches.length != 1) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason:
                matches.isEmpty
                    ? 'No unique daily_sales document matches this invoice.'
                    : 'Multiple daily_sales documents match this invoice.',
          ),
        );
        continue;
      }
      records.add(
        ReconciliationInvoiceRecord(
          orderDocumentId: order.id,
          orderData: order.data(),
          dailySalesDocumentId: matches.single.id,
          dailySalesData: matches.single.data(),
        ),
      );
    }

    final transactionSnapshot =
        await db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .get();
    final transactions =
        transactionSnapshot.docs
            .map(
              (doc) => ReconciliationLedgerTransaction(
                documentId: doc.id,
                data: doc.data(),
              ),
            )
            .toList();
    final planned = InvoicePaymentReconciliationPlanner.build(
      invoices: records,
      transactions: transactions,
    );
    return InvoicePaymentReconciliationPlan(
      changes: planned.changes,
      skipped: [...skipped, ...planned.skipped],
    );
  }

  static Map<String, dynamic> _backupData(
    InvoicePaymentReconciliationChange change,
  ) {
    final expectedDaily = <String, dynamic>{
      'paid': change.paid,
      'ledgerPaid': change.ledgerPaid,
      'pending': change.due,
      'status': change.due <= 0.5 ? 'paid' : 'partial',
      'paymentMethod.pending': change.due,
    };
    final expectedOrder = <String, dynamic>{
      'paid': change.paid,
      'paymentDetails.due': change.due,
      'paymentDetails.paidForInvoice': change.paid,
      'isFullyPaid': change.due <= 0.5,
      'status': change.due <= 0.5 ? 'completed' : 'partial',
    };
    return {
      'invoiceId': change.invoiceId,
      'dailySalesDocumentId': change.dailySalesDocumentId,
      'orderDocumentId': change.orderDocumentId,
      ..._encodeValues(
        'daily',
        change.oldDailyValues,
        presence: change.oldDailyValuePresence,
      ),
      ..._encodeValues(
        'order',
        change.oldOrderValues,
        presence: change.oldOrderValuePresence,
      ),
      ..._encodeValues('expectedDaily', expectedDaily),
      ..._encodeValues('expectedOrder', expectedOrder),
    };
  }

  static Map<String, dynamic> _encodeValues(
    String prefix,
    Map<String, dynamic> values, {
    Map<String, bool>? presence,
  }) {
    final encoded = <String, dynamic>{};
    for (final entry in values.entries) {
      final key = '${prefix}_${entry.key.replaceAll('.', '_')}';
      encoded['${key}_hadValue'] = presence?[entry.key] ?? true;
      encoded[key] = entry.value;
    }
    return encoded;
  }

  static Map<String, _SavedFieldValue> _decodeValues(
    Map<String, dynamic> data,
    String prefix,
    List<String> fields,
  ) {
    return {
      for (final field in fields)
        field: _SavedFieldValue(
          hadValue:
              data['${prefix}_${field.replaceAll('.', '_')}_hadValue'] == true,
          value: data['${prefix}_${field.replaceAll('.', '_')}'],
        ),
    };
  }

  static bool _matchesEither(
    Map<String, dynamic> current,
    Map<String, _SavedFieldValue> before,
    Map<String, _SavedFieldValue> expected,
  ) {
    for (final key in before.keys) {
      if (!_sameField(current, key, before[key]!) &&
          !_sameField(current, key, expected[key]!)) {
        return false;
      }
    }
    return true;
  }

  static Future<void> _ensureUnchanged(
    FirebaseFirestore db,
    InvoicePaymentReconciliationChange change,
  ) async {
    final dailySnapshot =
        await db
            .collection('daily_sales')
            .doc(change.dailySalesDocumentId)
            .get();
    final orderSnapshot =
        await db.collection('sales_orders').doc(change.orderDocumentId).get();
    if (!dailySnapshot.exists || !orderSnapshot.exists) {
      throw StateError(
        'Invoice ${change.invoiceId} changed after preview; no further '
        'reconciliation updates were applied.',
      );
    }
    if (!_matchesSavedValues(
          dailySnapshot.data() ?? <String, dynamic>{},
          change.oldDailyValues,
          change.oldDailyValuePresence,
        ) ||
        !_matchesSavedValues(
          orderSnapshot.data() ?? <String, dynamic>{},
          change.oldOrderValues,
          change.oldOrderValuePresence,
        )) {
      throw StateError(
        'Invoice ${change.invoiceId} changed after preview; no further '
        'reconciliation updates were applied.',
      );
    }
  }

  static bool _matchesSavedValues(
    Map<String, dynamic> current,
    Map<String, dynamic> values,
    Map<String, bool> presence,
  ) {
    for (final entry in values.entries) {
      final actual = _readPath(current, entry.key);
      if (actual.$1 != presence[entry.key]) return false;
      if (!actual.$1) continue;
      if (entry.value is num && actual.$2 is num) {
        if (((entry.value as num).toDouble() - (actual.$2 as num).toDouble())
                .abs() >=
            0.005) {
          return false;
        }
      } else if (entry.value != actual.$2) {
        return false;
      }
    }
    return true;
  }

  static bool _sameField(
    Map<String, dynamic> data,
    String path,
    _SavedFieldValue expected,
  ) {
    final value = _readPath(data, path);
    if (expected.hadValue != value.$1) return false;
    if (!expected.hadValue) return true;
    if (expected.value is num && value.$2 is num) {
      return ((expected.value as num).toDouble() - (value.$2 as num).toDouble())
              .abs() <
          0.005;
    }
    return expected.value == value.$2;
  }

  static (bool, dynamic) _readPath(Map<String, dynamic> data, String path) {
    final keys = path.split('.');
    dynamic current = data;
    for (final key in keys) {
      if (current is! Map || !current.containsKey(key)) return (false, null);
      current = current[key];
    }
    return (true, current);
  }

  static Map<String, dynamic> _restoreUpdates(
    Map<String, _SavedFieldValue> values,
  ) => {
    for (final entry in values.entries)
      entry.key: entry.value.hadValue ? entry.value.value : FieldValue.delete(),
  };
}

class _SavedFieldValue {
  final bool hadValue;
  final dynamic value;

  const _SavedFieldValue({required this.hadValue, required this.value});
}

class _PaymentReconciliationRestore {
  final DocumentReference<Map<String, dynamic>> dailyRef;
  final DocumentReference<Map<String, dynamic>> orderRef;
  final Map<String, _SavedFieldValue> beforeDaily;
  final Map<String, _SavedFieldValue> beforeOrder;

  const _PaymentReconciliationRestore({
    required this.dailyRef,
    required this.orderRef,
    required this.beforeDaily,
    required this.beforeOrder,
  });
}
