class RegularCustomerDiscountInvoice {
  final String dailySalesDocumentId;
  final String invoiceId;
  final double amount;
  final double pending;
  final double paid;
  final double ledgerPaid;
  final double discount;

  const RegularCustomerDiscountInvoice({
    required this.dailySalesDocumentId,
    required this.invoiceId,
    required this.amount,
    required this.pending,
    required this.paid,
    required this.ledgerPaid,
    required this.discount,
  });
}

class RegularCustomerDiscountAllocation {
  final RegularCustomerDiscountInvoice invoice;
  final double amount;

  const RegularCustomerDiscountAllocation({
    required this.invoice,
    required this.amount,
  });

  double get newPaid => invoice.paid + amount;
  double get newLedgerPaid => invoice.ledgerPaid + amount;
  double get newPending =>
      (invoice.pending - amount).clamp(0, double.infinity).toDouble();
  double get newDiscount => invoice.discount + amount;
  bool get isFullyPaid => newPending <= 0.5;
}

class RegularCustomerDiscountPlan {
  final List<RegularCustomerDiscountAllocation> allocations;
  final double unappliedAmount;

  const RegularCustomerDiscountPlan({
    required this.allocations,
    required this.unappliedAmount,
  });

  double get appliedAmount =>
      allocations.fold(0, (total, allocation) => total + allocation.amount);

  static RegularCustomerDiscountPlan build({
    required List<RegularCustomerDiscountInvoice> invoices,
    required double amount,
  }) {
    if (!amount.isFinite || amount <= 0) {
      return RegularCustomerDiscountPlan(
        allocations: const [],
        unappliedAmount: amount,
      );
    }

    var remaining = amount;
    final allocations = <RegularCustomerDiscountAllocation>[];
    for (final invoice in invoices) {
      if (remaining <= 0.01) break;
      if (invoice.pending <= 0.5 ||
          !invoice.pending.isFinite ||
          invoice.invoiceId.isEmpty) {
        continue;
      }

      final applied = remaining < invoice.pending ? remaining : invoice.pending;
      allocations.add(
        RegularCustomerDiscountAllocation(invoice: invoice, amount: applied),
      );
      remaining -= applied;
    }

    return RegularCustomerDiscountPlan(
      allocations: allocations,
      unappliedAmount: remaining > 0.01 ? remaining : 0,
    );
  }
}
