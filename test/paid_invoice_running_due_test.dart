import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/paid_invoice_running_due.dart';

void main() {
  Map<String, dynamic> order({
    String customerType = 'AGENT',
    double total = 1000,
    double paid = 1000,
    double due = 0,
    double snapshotRunningDue = 500,
    bool isFullyPaid = true,
  }) => {
    'customerType': customerType,
    'grandTotal': total,
    'paid': paid,
    'paymentDetails': {'due': due},
    'snapshotRunningDue': snapshotRunningDue,
    'isFullyPaid': isFullyPaid,
  };

  test('repair targets only fully paid Agent invoices', () {
    expect(
      PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(order: order()),
      isTrue,
    );
    expect(
      PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(
        order: order(paid: 0, due: 100, isFullyPaid: false),
      ),
      isFalse,
    );
    expect(
      PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(
        order: order(paid: 0, due: 100),
      ),
      isFalse,
    );
    expect(
      PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(
        order: order(customerType: 'WHOLESALE'),
      ),
      isFalse,
    );
    expect(
      PaidInvoiceRunningDueSnapshot.shouldClearRunningDue(
        order: order(isFullyPaid: false),
      ),
      isFalse,
    );
  });

  test('normal payment does not automatically clear previous balance', () {
    expect(PaidInvoiceRunningDueSnapshot.markPaid(order()), isEmpty);
  });

  test(
    'repair clears snapshot while preserving the original value for undo',
    () {
      final update = PaidInvoiceRunningDueSnapshot.clearForRepair(order());
      expect(update['snapshotRunningDue'], 0);
      expect(update['snapshotRunningDueBeforePaid'], 500);
      expect(update['snapshotRunningDueBeforePaidExists'], isTrue);
    },
  );

  test('legacy paid-invoice snapshots can still be restored', () {
    final reopenedUpdate = PaidInvoiceRunningDueSnapshot.restoreIfUnpaid({
      ...order(snapshotRunningDue: 0),
      'snapshotRunningDueBeforePaidExists': true,
      'snapshotRunningDueBeforePaid': 250,
    });
    expect(reopenedUpdate['snapshotRunningDue'], 250);
  });

  test(
    'reopening an invoice without a running snapshot deletes the zero field',
    () {
      final reopenedUpdate = PaidInvoiceRunningDueSnapshot.restoreIfUnpaid({
        'snapshotRunningDueBeforePaidExists': false,
      });
      expect(reopenedUpdate['snapshotRunningDue'], isA<FieldValue>());
    },
  );
}
