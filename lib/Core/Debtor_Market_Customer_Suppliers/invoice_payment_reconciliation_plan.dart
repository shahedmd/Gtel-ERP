class ReconciliationInvoiceRecord {
  final String orderDocumentId;
  final Map<String, dynamic> orderData;
  final String dailySalesDocumentId;
  final Map<String, dynamic> dailySalesData;

  const ReconciliationInvoiceRecord({
    required this.orderDocumentId,
    required this.orderData,
    required this.dailySalesDocumentId,
    required this.dailySalesData,
  });
}

class ReconciliationLedgerTransaction {
  final String documentId;
  final Map<String, dynamic> data;

  const ReconciliationLedgerTransaction({
    required this.documentId,
    required this.data,
  });
}

class InvoicePaymentReconciliationChange {
  final String invoiceId;
  final String orderDocumentId;
  final String dailySalesDocumentId;
  final double paid;
  final double ledgerPaid;
  final double due;
  final Map<String, dynamic> oldDailyValues;
  final Map<String, bool> oldDailyValuePresence;
  final Map<String, dynamic> oldOrderValues;
  final Map<String, bool> oldOrderValuePresence;

  const InvoicePaymentReconciliationChange({
    required this.invoiceId,
    required this.orderDocumentId,
    required this.dailySalesDocumentId,
    required this.paid,
    required this.ledgerPaid,
    required this.due,
    required this.oldDailyValues,
    required this.oldDailyValuePresence,
    required this.oldOrderValues,
    required this.oldOrderValuePresence,
  });
}

class InvoicePaymentReconciliationSkip {
  final String invoiceId;
  final String reason;

  const InvoicePaymentReconciliationSkip({
    required this.invoiceId,
    required this.reason,
  });
}

class InvoicePaymentReconciliationPlan {
  final List<InvoicePaymentReconciliationChange> changes;
  final List<InvoicePaymentReconciliationSkip> skipped;

  const InvoicePaymentReconciliationPlan({
    required this.changes,
    required this.skipped,
  });

  double get ledgerPaidToAdd => changes.fold(0, (total, change) {
    final oldValue = change.oldDailyValues['ledgerPaid'];
    final oldLedgerPaid = oldValue is num ? oldValue.toDouble() : 0.0;
    return total +
        (change.ledgerPaid - oldLedgerPaid)
            .clamp(0, double.infinity)
            .toDouble();
  });
}

class InvoicePaymentReconciliationPlanner {
  static const double _tolerance = 0.5;
  static const Set<String> _validLedgerPaymentTypes = {
    'debit',
    'loan_payment',
    'discount',
    'eid_bonus',
    'collection',
    'payment',
    'received',
  };

  static InvoicePaymentReconciliationPlan build({
    required List<ReconciliationInvoiceRecord> invoices,
    required List<ReconciliationLedgerTransaction> transactions,
  }) {
    final transactionsById = <String, ReconciliationLedgerTransaction>{};
    final ambiguousTransactionIds = <String>{};
    for (final transaction in transactions) {
      final aliases = {
        transaction.documentId,
        (transaction.data['transactionId'] ?? '').toString().trim(),
      }..remove('');
      for (final alias in aliases) {
        if (transactionsById.containsKey(alias) &&
            transactionsById[alias]!.documentId != transaction.documentId) {
          ambiguousTransactionIds.add(alias);
        } else {
          transactionsById[alias] = transaction;
        }
      }
    }

    final sourceAllocations = <String, double>{};
    for (final invoice in invoices) {
      for (final entry in _paymentHistory(invoice.dailySalesData) ?? const []) {
        final sourceTxId = (entry['sourceTxId'] ?? '').toString().trim();
        if (sourceTxId.isEmpty ||
            _isAdvanceCredit(entry) ||
            _isSaleReturnRefund(entry)) {
          continue;
        }
        sourceAllocations[sourceTxId] =
            (sourceAllocations[sourceTxId] ?? 0) + _number(entry['amount']);
      }
    }

    final invalidSourceIds = <String>{};
    for (final entry in sourceAllocations.entries) {
      final transaction = transactionsById[entry.key];
      if (transaction == null || ambiguousTransactionIds.contains(entry.key)) {
        invalidSourceIds.add(entry.key);
        continue;
      }
      final type = (transaction.data['type'] ?? '').toString().toLowerCase();
      final amount = _number(transaction.data['amount']);
      if (!_validLedgerPaymentTypes.contains(type) ||
          amount <= 0 ||
          entry.value > amount + _tolerance) {
        invalidSourceIds.add(entry.key);
      }
    }

    final changes = <InvoicePaymentReconciliationChange>[];
    final skipped = <InvoicePaymentReconciliationSkip>[];
    for (final invoice in invoices) {
      final invoiceId = _invoiceId(invoice);
      final order = invoice.orderData;
      final sale = invoice.dailySalesData;
      final orderTotal = _invoiceTotal(order, 'grandTotal');
      final saleTotal = _invoiceTotal(sale, 'amount');
      if (_isConditionInvoice(order, sale)) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Condition invoices are outside this repair.',
          ),
        );
        continue;
      }
      if (orderTotal <= 0 || saleTotal <= 0) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Invoice total is missing or invalid.',
          ),
        );
        continue;
      }
      if ((orderTotal - saleTotal).abs() > _tolerance) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Daily sales and sales order totals do not match.',
          ),
        );
        continue;
      }

      final history = _paymentHistory(sale);
      if (history == null || history.isEmpty) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason:
                'Payment history is missing or malformed, so this invoice '
                'cannot be verified.',
          ),
        );
        continue;
      }

      var historyPaid = 0.0;
      var verifiedLedgerPaid = 0.0;
      String? invalidSource;
      var invalidHistory = false;
      for (final entry in history) {
        final amount = _number(entry['amount'], fallback: double.nan);
        if (!amount.isFinite || amount < 0) {
          invalidHistory = true;
          break;
        }
        if (_isSaleReturnRefund(entry)) {
          historyPaid -= amount;
          continue;
        }
        historyPaid += amount;
        if (_isAdvanceCredit(entry)) {
          verifiedLedgerPaid += amount;
          continue;
        }

        final sourceTxId = (entry['sourceTxId'] ?? '').toString().trim();
        if (sourceTxId.isEmpty) continue;
        if (invalidSourceIds.contains(sourceTxId)) {
          invalidSource = sourceTxId;
          break;
        }
        final sourceTransaction = transactionsById[sourceTxId];
        if (sourceTransaction == null) {
          invalidSource = sourceTxId;
          break;
        }
        if (!_isInitialInvoicePayment(
          invoiceId,
          sourceTxId,
          sourceTransaction,
        )) {
          verifiedLedgerPaid += amount;
        }
      }
      if (invalidHistory) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Payment history contains an invalid amount.',
          ),
        );
        continue;
      }
      if (historyPaid < -_tolerance) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Refund history exceeds recorded payments.',
          ),
        );
        continue;
      }
      if (invalidSource != null) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason:
                'Ledger transaction $invalidSource is missing, ambiguous, '
                'or does not support the recorded allocation.',
          ),
        );
        continue;
      }
      if (historyPaid > orderTotal + _tolerance ||
          verifiedLedgerPaid > historyPaid + _tolerance) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason: 'Recorded payments exceed the invoice total.',
          ),
        );
        continue;
      }

      final dailyPaid = _number(sale['paid']);
      final orderPaid = _number(order['paid']);
      final currentLedgerPaid = _number(sale['ledgerPaid']);
      if (historyPaid + 0.01 < dailyPaid || historyPaid + 0.01 < orderPaid) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason:
                'Saved paid amount exceeds verified payment history; '
                'automatic reduction is unsafe.',
          ),
        );
        continue;
      }
      if (verifiedLedgerPaid + 0.01 < currentLedgerPaid) {
        skipped.add(
          InvoicePaymentReconciliationSkip(
            invoiceId: invoiceId,
            reason:
                'Saved ledgerPaid exceeds ledger payments verified from '
                'history; automatic reduction is unsafe.',
          ),
        );
        continue;
      }

      final paid = historyPaid;
      final due = (orderTotal - paid).clamp(0, double.infinity).toDouble();
      final fullyPaid = due <= _tolerance;
      final dailyNeedsUpdate =
          !_close(dailyPaid, paid) ||
          !_close(currentLedgerPaid, verifiedLedgerPaid) ||
          !_close(_number(sale['pending']), due) ||
          sale['status'] != (fullyPaid ? 'paid' : 'partial') ||
          !_close(_number(_nested(sale, 'paymentMethod', 'pending')), due);
      final orderPaymentDetails =
          order['paymentDetails'] is Map
              ? Map<String, dynamic>.from(order['paymentDetails'] as Map)
              : <String, dynamic>{};
      final orderNeedsUpdate =
          !_close(orderPaid, paid) ||
          !_close(_number(orderPaymentDetails['due']), due) ||
          !_close(_number(orderPaymentDetails['paidForInvoice']), paid) ||
          order['isFullyPaid'] != fullyPaid ||
          order['status'] != (fullyPaid ? 'completed' : 'partial');
      if (!dailyNeedsUpdate && !orderNeedsUpdate) continue;

      changes.add(
        InvoicePaymentReconciliationChange(
          invoiceId: invoiceId,
          orderDocumentId: invoice.orderDocumentId,
          dailySalesDocumentId: invoice.dailySalesDocumentId,
          paid: paid,
          ledgerPaid: verifiedLedgerPaid,
          due: due,
          oldDailyValues: {
            'paid': sale['paid'],
            'ledgerPaid': sale['ledgerPaid'],
            'pending': sale['pending'],
            'status': sale['status'],
            'paymentMethod.pending': _nested(sale, 'paymentMethod', 'pending'),
          },
          oldDailyValuePresence: {
            for (final field in [
              'paid',
              'ledgerPaid',
              'pending',
              'status',
              'paymentMethod.pending',
            ])
              field: _hasPath(sale, field),
          },
          oldOrderValues: {
            'paid': order['paid'],
            'paymentDetails.due': orderPaymentDetails['due'],
            'paymentDetails.paidForInvoice':
                orderPaymentDetails['paidForInvoice'],
            'isFullyPaid': order['isFullyPaid'],
            'status': order['status'],
          },
          oldOrderValuePresence: {
            for (final field in [
              'paid',
              'paymentDetails.due',
              'paymentDetails.paidForInvoice',
              'isFullyPaid',
              'status',
            ])
              field: _hasPath(order, field),
          },
        ),
      );
    }
    return InvoicePaymentReconciliationPlan(changes: changes, skipped: skipped);
  }

  static String _invoiceId(ReconciliationInvoiceRecord invoice) {
    final sale = invoice.dailySalesData;
    final order = invoice.orderData;
    return (sale['transactionId'] ??
            sale['invoiceId'] ??
            order['invoiceId'] ??
            invoice.orderDocumentId)
        .toString();
  }

  static List<Map<String, dynamic>>? _paymentHistory(
    Map<String, dynamic> data,
  ) {
    final values = data['paymentHistory'];
    if (values is! List || values.any((entry) => entry is! Map)) return null;
    return values
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static bool _isAdvanceCredit(Map<String, dynamic> entry) =>
      (entry['collectionMode'] ?? '').toString() == 'advance_credit' ||
      (entry['type'] ?? '').toString().toLowerCase() == 'advance';

  static bool _isSaleReturnRefund(Map<String, dynamic> entry) =>
      (entry['collectionMode'] ?? '').toString() == 'sale_return_refund';

  static bool _isInitialInvoicePayment(
    String invoiceId,
    String sourceTxId,
    ReconciliationLedgerTransaction transaction,
  ) {
    final note = (transaction.data['note'] ?? '').toString().toLowerCase();
    return sourceTxId == '${invoiceId}_pay' ||
        note.trim() == 'payment for inv $invoiceId'.toLowerCase();
  }

  static bool _isConditionInvoice(
    Map<String, dynamic> order,
    Map<String, dynamic> sale,
  ) =>
      order['isCondition'] == true ||
      (sale['customerType'] ?? '').toString().toLowerCase() ==
          'condition_advance';

  static double _invoiceTotal(Map<String, dynamic> data, String key) {
    final direct = _number(data[key]);
    if (direct > 0) return direct;
    return _number(data['subtotal']) - _number(data['discount']);
  }

  static dynamic _nested(
    Map<String, dynamic> data,
    String parent,
    String child,
  ) {
    final value = data[parent];
    return value is Map ? value[child] : null;
  }

  static bool _hasPath(Map<String, dynamic> data, String path) {
    dynamic current = data;
    for (final key in path.split('.')) {
      if (current is! Map || !current.containsKey(key)) return false;
      current = current[key];
    }
    return true;
  }

  static double _number(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value != null) return double.tryParse(value.toString()) ?? fallback;
    return fallback;
  }

  static bool _close(double a, double b) => (a - b).abs() <= 0.01;
}
