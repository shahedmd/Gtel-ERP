import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/invoice_payment_reconciliation_plan.dart';

void main() {
  group('InvoicePaymentReconciliationPlanner', () {
    test(
      'reconciles verified ledger allocations without changing cash fields',
      () {
        final plan = InvoicePaymentReconciliationPlanner.build(
          invoices: [
            _invoice(
              orderPaid: 0,
              orderDue: 100,
              dailyPaid: 0,
              ledgerPaid: 0,
              pending: 100,
              history: [
                {'amount': 20, 'type': 'cash', 'note': 'Initial Payment'},
                {
                  'amount': 80,
                  'type': 'cash',
                  'sourceTxId': 'collection-1',
                  'invoiceId': 'INV-1',
                },
              ],
            ),
          ],
          transactions: [
            ReconciliationLedgerTransaction(
              documentId: 'collection-1',
              data: {
                'transactionId': 'collection-1',
                'type': 'debit',
                'amount': 80,
              },
            ),
          ],
        );

        expect(plan.changes, hasLength(1));
        final change = plan.changes.single;
        expect(change.paid, 100);
        expect(change.ledgerPaid, 80);
        expect(change.due, 0);
        expect(plan.ledgerPaidToAdd, 80);
        expect(change.oldDailyValues, isNot(contains('paymentMethod.cash')));
      },
    );

    test('does not classify the invoice-time debit as ledgerPaid', () {
      final plan = InvoicePaymentReconciliationPlanner.build(
        invoices: [
          _invoice(
            orderPaid: 0,
            orderDue: 100,
            dailyPaid: 0,
            ledgerPaid: 0,
            pending: 100,
            history: [
              {
                'amount': 20,
                'type': 'cash',
                'sourceTxId': 'INV-1_pay',
                'note': 'Initial Payment',
              },
              {'amount': 80, 'type': 'cash', 'sourceTxId': 'collection-1'},
            ],
          ),
        ],
        transactions: [
          ReconciliationLedgerTransaction(
            documentId: 'INV-1_pay',
            data: {
              'transactionId': 'INV-1_pay',
              'type': 'debit',
              'amount': 20,
              'note': 'Payment for Inv INV-1',
            },
          ),
          ReconciliationLedgerTransaction(
            documentId: 'collection-1',
            data: {
              'transactionId': 'collection-1',
              'type': 'debit',
              'amount': 80,
              'note': 'Late Due Collection',
            },
          ),
        ],
      );

      expect(plan.changes.single.paid, 100);
      expect(plan.changes.single.ledgerPaid, 80);
    });

    test(
      'skips an invoice when a payment source has no matching ledger record',
      () {
        final plan = InvoicePaymentReconciliationPlanner.build(
          invoices: [
            _invoice(
              orderPaid: 0,
              orderDue: 100,
              dailyPaid: 0,
              ledgerPaid: 0,
              pending: 100,
              history: [
                {'amount': 100, 'sourceTxId': 'missing-tx'},
              ],
            ),
          ],
          transactions: const [],
        );

        expect(plan.changes, isEmpty);
        expect(plan.skipped, hasLength(1));
        expect(plan.skipped.single.reason, contains('missing, ambiguous'));
      },
    );

    test(
      'skips payment allocations exceeding the source transaction amount',
      () {
        final plan = InvoicePaymentReconciliationPlanner.build(
          invoices: [
            _invoice(
              orderPaid: 0,
              orderDue: 100,
              dailyPaid: 0,
              ledgerPaid: 0,
              pending: 100,
              history: [
                {'amount': 100, 'sourceTxId': 'collection-1'},
              ],
            ),
          ],
          transactions: [
            ReconciliationLedgerTransaction(
              documentId: 'collection-1',
              data: {'type': 'debit', 'amount': 50},
            ),
          ],
        );

        expect(plan.changes, isEmpty);
        expect(plan.skipped, hasLength(1));
      },
    );

    test('subtracts sale-return refunds from payment history', () {
      final plan = InvoicePaymentReconciliationPlanner.build(
        invoices: [
          _invoice(
            orderPaid: 500,
            orderDue: 0,
            dailyPaid: 500,
            ledgerPaid: 0,
            pending: 0,
            invoiceTotal: 500,
            history: [
              {'amount': 750, 'note': 'Initial Payment'},
              {
                'amount': 250,
                'collectionMode': 'sale_return_refund',
                'type': 'refund',
                'sourceTxId': 'RETURN-INV-1',
              },
            ],
          ),
        ],
        transactions: const [],
      );

      expect(plan.changes, hasLength(1));
      expect(plan.changes.single.paid, 500);
      expect(plan.skipped, isEmpty);
    });

    test('does not lower paid totals when payment history is incomplete', () {
      final plan = InvoicePaymentReconciliationPlanner.build(
        invoices: [
          _invoice(
            orderPaid: 80,
            orderDue: 20,
            dailyPaid: 80,
            ledgerPaid: 20,
            pending: 20,
            history: [
              {'amount': 50, 'note': 'Initial Payment'},
            ],
          ),
        ],
        transactions: const [],
      );

      expect(plan.changes, isEmpty);
      expect(plan.skipped.single.reason, contains('exceeds verified'));
    });
  });
}

ReconciliationInvoiceRecord _invoice({
  required double orderPaid,
  required double orderDue,
  required double dailyPaid,
  required double ledgerPaid,
  required double pending,
  double invoiceTotal = 100,
  required List<Map<String, dynamic>> history,
}) => ReconciliationInvoiceRecord(
  orderDocumentId: 'INV-1',
  orderData: {
    'invoiceId': 'INV-1',
    'grandTotal': invoiceTotal,
    'paid': orderPaid,
    'isCondition': false,
    'isFullyPaid': false,
    'status': 'partial',
    'paymentDetails': {'due': orderDue, 'paidForInvoice': orderPaid},
  },
  dailySalesDocumentId: 'daily-1',
  dailySalesData: {
    'invoiceId': 'INV-1',
    'transactionId': 'INV-1',
    'amount': invoiceTotal,
    'customerType': 'agent',
    'paid': dailyPaid,
    'ledgerPaid': ledgerPaid,
    'pending': pending,
    'status': 'partial',
    'paymentHistory': history,
    'paymentMethod': {'cash': 20, 'pending': pending},
  },
);
