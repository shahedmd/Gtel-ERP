class InvoiceSnapshotOrder {
  final String id;
  final DateTime invoiceDate;
  final DateTime creationTime;
  final double? snapshotRunningDue;

  const InvoiceSnapshotOrder({
    required this.id,
    required this.invoiceDate,
    required this.creationTime,
    required this.snapshotRunningDue,
  });
}

class InvoiceSnapshotRunningDueChange {
  final String invoiceId;
  final double newSnapshotRunningDue;

  const InvoiceSnapshotRunningDueChange({
    required this.invoiceId,
    required this.newSnapshotRunningDue,
  });
}

class InvoiceSnapshotRunningDuePlan {
  final List<InvoiceSnapshotRunningDueChange> changes;
  final List<String> skippedInvoiceIds;

  const InvoiceSnapshotRunningDuePlan({
    required this.changes,
    required this.skippedInvoiceIds,
  });
}

class InvoiceSnapshotRunningDueAdjustment {
  static InvoiceSnapshotRunningDuePlan plan({
    required String editedInvoiceId,
    required List<InvoiceSnapshotOrder> debtorInvoices,
    required double dueDelta,
  }) {
    if (!dueDelta.isFinite || dueDelta.abs() <= 0.01) {
      return const InvoiceSnapshotRunningDuePlan(
        changes: [],
        skippedInvoiceIds: [],
      );
    }

    final orderedInvoices = [...debtorInvoices]..sort(_compare);
    final editedIndex = orderedInvoices.indexWhere(
      (invoice) => invoice.id == editedInvoiceId,
    );
    if (editedIndex < 0) {
      throw StateError(
        'The edited invoice is missing from its debtor invoices.',
      );
    }

    final changes = <InvoiceSnapshotRunningDueChange>[];
    final skipped = <String>[];
    for (final invoice in orderedInvoices.skip(editedIndex + 1)) {
      final currentSnapshot = invoice.snapshotRunningDue;
      if (currentSnapshot == null || !currentSnapshot.isFinite) {
        skipped.add(invoice.id);
        continue;
      }
      changes.add(
        InvoiceSnapshotRunningDueChange(
          invoiceId: invoice.id,
          newSnapshotRunningDue: currentSnapshot + dueDelta,
        ),
      );
    }
    return InvoiceSnapshotRunningDuePlan(
      changes: changes,
      skippedInvoiceIds: skipped,
    );
  }

  static int _compare(InvoiceSnapshotOrder a, InvoiceSnapshotOrder b) {
    final dateCompare = a.invoiceDate.compareTo(b.invoiceDate);
    if (dateCompare != 0) return dateCompare;
    final creationCompare = a.creationTime.compareTo(b.creationTime);
    if (creationCompare != 0) return creationCompare;
    return a.id.compareTo(b.id);
  }
}
