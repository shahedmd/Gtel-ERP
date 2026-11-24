class AgentSalePaymentPlan {
  const AgentSalePaymentPlan({
    required this.invoiceCash,
    required this.oldDueCash,
    required this.runningDueCash,
    required this.advanceApplied,
    required this.advanceReceived,
    required this.invoiceDue,
  });

  final double invoiceCash;
  final double oldDueCash;
  final double runningDueCash;
  final double advanceApplied;
  final double advanceReceived;
  final double invoiceDue;

  double get invoicePaid => _round(invoiceCash + advanceApplied);

  factory AgentSalePaymentPlan.build({
    required double invoiceTotal,
    required double cashReceived,
    required double oldDue,
    required double runningDue,
  }) {
    if (!invoiceTotal.isFinite ||
        invoiceTotal < 0 ||
        !cashReceived.isFinite ||
        cashReceived < 0 ||
        !oldDue.isFinite ||
        !runningDue.isFinite) {
      throw ArgumentError(
        'Invoice and cash amounts must be non-negative; all amounts must be finite.',
      );
    }

    var remainingCash = cashReceived;
    final invoiceCash = _round(
      remainingCash < invoiceTotal ? remainingCash : invoiceTotal,
    );
    remainingCash = _round(remainingCash - invoiceCash);

    final oldDueCash = _takeFromPositiveBalance(oldDue, remainingCash);
    remainingCash = _round(remainingCash - oldDueCash);
    final runningDueCash = _takeFromPositiveBalance(runningDue, remainingCash);
    remainingCash = _round(remainingCash - runningDueCash);

    final outstandingAfterCash =
        (oldDue - oldDueCash).clamp(0.0, double.infinity) +
        runningDue -
        runningDueCash;
    final advanceApplied = _round(
      _min(
        _max(0.0, -outstandingAfterCash),
        _max(0.0, invoiceTotal - invoiceCash),
      ),
    );
    final invoiceDue = _round(
      _max(0.0, invoiceTotal - invoiceCash - advanceApplied),
    );

    return AgentSalePaymentPlan(
      invoiceCash: invoiceCash,
      oldDueCash: oldDueCash,
      runningDueCash: runningDueCash,
      advanceApplied: advanceApplied,
      advanceReceived: remainingCash,
      invoiceDue: invoiceDue,
    );
  }

  static double _takeFromPositiveBalance(double balance, double cash) =>
      _round(_min(_max(0.0, balance), cash));

  static double _min(double a, double b) => a < b ? a : b;

  static double _max(double a, double b) => a > b ? a : b;

  static double _round(double value) => double.parse(value.toStringAsFixed(2));
}

double calculatePostSaleAccountBalance({
  required double previousBalance,
  required double invoiceTotal,
  required double cashReceived,
}) => double.parse(
  (previousBalance + invoiceTotal - cashReceived).toStringAsFixed(2),
);

double calculateInvoicePresentDue({
  required double previousBalance,
  required double paidForOldDue,
  required double paidForRunningDue,
  required double invoiceDue,
  required double advanceApplied,
  required double advanceReceived,
}) => double.parse(
  (previousBalance -
          paidForOldDue -
          paidForRunningDue +
          invoiceDue +
          advanceApplied -
          advanceReceived)
      .toStringAsFixed(2),
);

double calculateAgentInvoicePresentDue({
  required double snapshotOldDue,
  required double snapshotRunningDue,
  required double paidForOldDue,
  required double paidForRunningDue,
  required double invoiceDue,
  required double advanceApplied,
  required double advanceReceived,
}) {
  final previousBalance = calculateAgentInvoicePreviousBalance(
    snapshotOldDue: snapshotOldDue,
    snapshotRunningDue: snapshotRunningDue,
    paidForOldDue: paidForOldDue,
    paidForRunningDue: paidForRunningDue,
  );
  return double.parse(
    (previousBalance + invoiceDue + advanceApplied - advanceReceived)
        .toStringAsFixed(2),
  );
}

double calculateAgentInvoicePreviousBalance({
  required double snapshotOldDue,
  required double snapshotRunningDue,
  required double paidForOldDue,
  required double paidForRunningDue,
}) {
  final oldDueRemaining =
      snapshotOldDue > paidForOldDue ? snapshotOldDue - paidForOldDue : 0.0;
  final runningDueRemaining =
      snapshotRunningDue < 0
          ? snapshotRunningDue
          : snapshotRunningDue > paidForRunningDue
          ? snapshotRunningDue - paidForRunningDue
          : 0.0;
  return double.parse(
    (oldDueRemaining + runningDueRemaining).toStringAsFixed(2),
  );
}
