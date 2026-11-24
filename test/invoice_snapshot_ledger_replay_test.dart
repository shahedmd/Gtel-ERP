import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/invoice_snapshot_ledger_replay.dart';

void main() {
  group('InvoiceSnapshotLedgerReplay', () {
    test('replays old due, invoice due, and later payment allocations', () {
      final day1 = DateTime(2025, 1, 1);
      final day2 = DateTime(2025, 1, 2);
      final day3 = DateTime(2025, 1, 3);
      final events = [
        InvoiceSnapshotLedgerEvent(
          date: day1,
          tieBreaker: day1,
          transactionType: 'previous_due',
          amount: 1000,
        ),
        InvoiceSnapshotLedgerEvent(
          date: day2,
          tieBreaker: day2,
          orderId: 'invoice-1',
          oldDuePaid: 200,
          invoiceDue: 300,
        ),
        InvoiceSnapshotLedgerEvent(
          date: day3,
          tieBreaker: day3,
          orderId: 'invoice-2',
          oldDuePaid: 100,
          runningDuePaid: 50,
          invoiceDue: 250,
        ),
      ];

      final snapshots = InvoiceSnapshotLedgerReplay.calculate(events);

      expect(snapshots['invoice-1']?.oldDue, 1000);
      expect(snapshots['invoice-1']?.runningDue, 0);
      expect(snapshots['invoice-2']?.oldDue, 800);
      expect(snapshots['invoice-2']?.runningDue, 300);
    });

    test('applies excess old-due payment to running due', () {
      final day1 = DateTime(2025, 1, 1);
      final day2 = DateTime(2025, 1, 2);
      final day3 = DateTime(2025, 1, 3);
      final snapshots = InvoiceSnapshotLedgerReplay.calculate([
        InvoiceSnapshotLedgerEvent(
          date: day1,
          tieBreaker: day1,
          transactionType: 'previous_due',
          amount: 100,
        ),
        InvoiceSnapshotLedgerEvent(
          date: day2,
          tieBreaker: day2,
          orderId: 'invoice-1',
          invoiceDue: 50,
        ),
        InvoiceSnapshotLedgerEvent(
          date: day3,
          tieBreaker: day3,
          transactionType: 'loan_payment',
          amount: 120,
        ),
        InvoiceSnapshotLedgerEvent(
          date: day3.add(const Duration(days: 1)),
          tieBreaker: day3.add(const Duration(days: 1)),
          orderId: 'invoice-2',
        ),
      ]);

      expect(snapshots['invoice-2']?.oldDue, 0);
      expect(snapshots['invoice-2']?.runningDue, 30);
    });

    test('orders same-date events by their creation-time tie breaker', () {
      final date = DateTime(2025, 1, 1);
      final snapshots = InvoiceSnapshotLedgerReplay.calculate([
        InvoiceSnapshotLedgerEvent(
          date: date,
          tieBreaker: date,
          transactionType: 'previous_due',
          amount: 100,
        ),
        InvoiceSnapshotLedgerEvent(
          date: date,
          tieBreaker: date.add(const Duration(minutes: 2)),
          transactionType: 'loan_payment',
          amount: 40,
        ),
        InvoiceSnapshotLedgerEvent(
          date: date,
          tieBreaker: date.add(const Duration(minutes: 3)),
          orderId: 'invoice-1',
        ),
      ]);

      expect(snapshots['invoice-1']?.oldDue, 60);
    });
  });
}
