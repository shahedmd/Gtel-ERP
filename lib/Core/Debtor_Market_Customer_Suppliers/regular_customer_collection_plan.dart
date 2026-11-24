class RegularCustomerCollectionInvoice {
  const RegularCustomerCollectionInvoice({
    required this.documentId,
    required this.pending,
    required this.paid,
    required this.ledgerPaid,
    required this.invoiceDate,
  });

  final String documentId;
  final double pending;
  final double paid;
  final double ledgerPaid;
  final DateTime invoiceDate;
}

class RegularCustomerCollectionAllocation {
  const RegularCustomerCollectionAllocation({
    required this.invoice,
    required this.amount,
    required this.isPreviousDateInvoice,
  });

  final RegularCustomerCollectionInvoice invoice;
  final double amount;
  final bool isPreviousDateInvoice;

  double get newPaid => invoice.paid + amount;
  double get newLedgerPaid =>
      invoice.ledgerPaid + (isPreviousDateInvoice ? amount : 0);
  double get newPending => invoice.pending - amount;
  bool get isFullyPaid => newPending <= 0.5;
}

class RegularCustomerCollectionPlan {
  const RegularCustomerCollectionPlan({
    required this.allocations,
    required this.appliedAmount,
    required this.advanceAmount,
    required this.cashLedgerAmount,
  });

  final List<RegularCustomerCollectionAllocation> allocations;
  final double appliedAmount;
  final double advanceAmount;
  final double cashLedgerAmount;

  factory RegularCustomerCollectionPlan.build({
    required List<RegularCustomerCollectionInvoice> invoices,
    required double amount,
    required DateTime collectionDate,
  }) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be a positive amount.');
    }

    final orderedInvoices = [...invoices]..sort((a, b) {
      final dateCompare = DateTime(
        a.invoiceDate.year,
        a.invoiceDate.month,
        a.invoiceDate.day,
      ).compareTo(
        DateTime(b.invoiceDate.year, b.invoiceDate.month, b.invoiceDate.day),
      );
      return dateCompare != 0
          ? dateCompare
          : a.documentId.compareTo(b.documentId);
    });

    final eligibleInvoices =
        orderedInvoices.where((invoice) => invoice.pending > 0.5).toList();
    final totalPending = eligibleInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.pending,
    );
    final appliedAmount = amount < totalPending ? amount : totalPending;
    final advanceAmount = amount - appliedAmount;
    final collectionDay = DateTime(
      collectionDate.year,
      collectionDate.month,
      collectionDate.day,
    );

    var remaining = appliedAmount;
    var cashLedgerAmount = advanceAmount;
    final allocations = <RegularCustomerCollectionAllocation>[];
    for (final invoice in eligibleInvoices) {
      if (remaining <= 0.01) break;

      final take = remaining < invoice.pending ? remaining : invoice.pending;
      final invoiceDay = DateTime(
        invoice.invoiceDate.year,
        invoice.invoiceDate.month,
        invoice.invoiceDate.day,
      );
      final isPreviousDateInvoice = invoiceDay.isBefore(collectionDay);
      allocations.add(
        RegularCustomerCollectionAllocation(
          invoice: invoice,
          amount: take,
          isPreviousDateInvoice: isPreviousDateInvoice,
        ),
      );
      if (isPreviousDateInvoice) cashLedgerAmount += take;
      remaining -= take;
    }

    return RegularCustomerCollectionPlan(
      allocations: allocations,
      appliedAmount: appliedAmount,
      advanceAmount: advanceAmount,
      cashLedgerAmount: cashLedgerAmount,
    );
  }
}
