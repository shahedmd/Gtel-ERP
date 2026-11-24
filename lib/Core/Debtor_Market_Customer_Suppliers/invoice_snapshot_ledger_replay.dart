class InvoiceSnapshotLedgerEvent {
  final DateTime date;
  final DateTime tieBreaker;
  final String? orderId;
  final String? transactionId;
  final String? transactionType;
  final double amount;
  final double oldDuePaid;
  final double runningDuePaid;
  final double invoiceDue;

  const InvoiceSnapshotLedgerEvent({
    required this.date,
    required this.tieBreaker,
    this.orderId,
    this.transactionId,
    this.transactionType,
    this.amount = 0,
    this.oldDuePaid = 0,
    this.runningDuePaid = 0,
    this.invoiceDue = 0,
  });
}

class InvoiceSnapshotValues {
  final double oldDue;
  final double runningDue;

  const InvoiceSnapshotValues({required this.oldDue, required this.runningDue});
}

class InvoiceSnapshotLedgerReplay {
  static Map<String, InvoiceSnapshotValues> calculate(
    List<InvoiceSnapshotLedgerEvent> events,
  ) {
    final orderedEvents = [...events]..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      final tieCompare = a.tieBreaker.compareTo(b.tieBreaker);
      if (tieCompare != 0) return tieCompare;
      if (a.orderId == null && b.orderId != null) return -1;
      if (a.orderId != null && b.orderId == null) return 1;
      return (a.orderId ?? a.transactionId ?? '').compareTo(
        b.orderId ?? b.transactionId ?? '',
      );
    });

    var oldDue = 0.0;
    var runningDue = 0.0;
    final snapshots = <String, InvoiceSnapshotValues>{};
    for (final event in orderedEvents) {
      if (event.orderId != null) {
        snapshots[event.orderId!] = InvoiceSnapshotValues(
          oldDue: oldDue,
          runningDue: runningDue,
        );
        final oldDueBeforePayment = oldDue;
        oldDue = _applyOldDuePayment(oldDue, event.oldDuePaid);
        runningDue -= (event.oldDuePaid - oldDueBeforePayment).clamp(
          0,
          double.infinity,
        );
        runningDue -= event.runningDuePaid;
        runningDue += event.invoiceDue;
        continue;
      }

      switch (event.transactionType) {
        case 'previous_due':
          oldDue += event.amount;
          break;
        case 'loan_payment':
          final oldDueBeforePayment = oldDue;
          oldDue = _applyOldDuePayment(oldDue, event.amount);
          runningDue -= (event.amount - oldDueBeforePayment).clamp(
            0,
            double.infinity,
          );
          break;
        case 'discount':
        case 'eid_bonus':
          final oldDueBeforePayment = oldDue;
          oldDue = _applyOldDuePayment(oldDue, event.amount);
          runningDue -= (event.amount - oldDueBeforePayment).clamp(
            0,
            double.infinity,
          );
          break;
        case 'credit':
        case 'advance_given':
          runningDue += event.amount;
          break;
        case 'debit':
        case 'advance_received':
          runningDue -= event.amount;
          break;
      }
    }
    return snapshots;
  }

  static double _applyOldDuePayment(double oldDue, double payment) {
    final oldRemaining = oldDue - payment;
    return oldRemaining >= 0 ? oldRemaining : 0;
  }
}
