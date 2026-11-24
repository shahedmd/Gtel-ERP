import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Sale%20Return/invoice_snapshot_running_due_adjustment.dart';

void main() {
  group('InvoiceSnapshotRunningDueAdjustment', () {
    final day = DateTime(2026, 9, 16);

    InvoiceSnapshotOrder order(String id, int minute, double? snapshot) =>
        InvoiceSnapshotOrder(
          id: id,
          invoiceDate: day,
          creationTime: day.add(Duration(minutes: minute)),
          snapshotRunningDue: snapshot,
        );

    test('adjusts only invoices created after the edited invoice', () {
      final invoices = [
        order('invoice-1', 1, 0),
        order('invoice-2', 2, 100),
        order('invoice-3', 3, 250),
        order('invoice-4', 4, 400),
      ];

      final plan = InvoiceSnapshotRunningDueAdjustment.plan(
        editedInvoiceId: 'invoice-3',
        debtorInvoices: invoices,
        dueDelta: 75,
      );

      expect(plan.changes, hasLength(1));
      expect(plan.changes.single.invoiceId, 'invoice-4');
      expect(plan.changes.single.newSnapshotRunningDue, 475);
      expect(plan.skippedInvoiceIds, isEmpty);
    });

    test(
      'subtracts reductions in the edited invoice due from later snapshots',
      () {
        final invoices = [
          order('older', 1, 0),
          order('edited', 2, 100),
          order('newer', 3, 350),
        ];

        final plan = InvoiceSnapshotRunningDueAdjustment.plan(
          editedInvoiceId: 'edited',
          debtorInvoices: invoices,
          dueDelta: -80,
        );

        expect(plan.changes.single.newSnapshotRunningDue, 270);
      },
    );

    test('skips later invoices without a saved running-due snapshot', () {
      final invoices = [
        order('edited', 1, 0),
        order('missing-snapshot', 2, null),
        order('valid-snapshot', 3, 200),
      ];

      final plan = InvoiceSnapshotRunningDueAdjustment.plan(
        editedInvoiceId: 'edited',
        debtorInvoices: invoices,
        dueDelta: 25,
      );

      expect(plan.changes.single.newSnapshotRunningDue, 225);
      expect(plan.skippedInvoiceIds, ['missing-snapshot']);
    });

    test('does not change snapshots when the invoice due is unchanged', () {
      final invoices = [order('edited', 1, 0), order('newer', 2, 100)];

      final plan = InvoiceSnapshotRunningDueAdjustment.plan(
        editedInvoiceId: 'edited',
        debtorInvoices: invoices,
        dueDelta: 0,
      );

      expect(plan.changes, isEmpty);
    });
  });
}
