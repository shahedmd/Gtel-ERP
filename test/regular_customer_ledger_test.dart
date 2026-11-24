import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';

void main() {
  test(
    'sale return refund reverses an earlier collection in the statement',
    () {
      final invoiceDate = DateTime(2026, 8, 23, 10);
      final paymentDate = DateTime(2026, 8, 24, 10);
      final returnDate = DateTime(2026, 11, 1, 10);

      final rows = DebatorController.buildRegularCustomerLedgerRows(
        invoices: [
          {
            'docId': 'INVOICE-750',
            'invoiceId': 'INVOICE-750',
            'amount': 0,
            'timestamp': Timestamp.fromDate(invoiceDate),
            'paymentHistory': [
              {
                'amount': 750,
                'timestamp': Timestamp.fromDate(paymentDate),
                'sourceTxId': 'COLLECT-750',
                'invoiceId': 'INVOICE-750',
                'collectionMode': 'old_due_ledger',
                'type': 'cash',
              },
              {
                'amount': 750,
                'timestamp': Timestamp.fromDate(returnDate),
                'sourceTxId': 'RETURN-INVOICE-750',
                'invoiceId': 'INVOICE-750',
                'collectionMode': 'sale_return_refund',
                'type': 'refund',
                'note': 'Refund for returned items in invoice INVOICE-750',
              },
            ],
          },
        ],
        advanceHistory: const [],
      );

      expect(rows.map((row) => row['label']).toList(), [
        'INVOICE',
        'PAYMENT',
        'REFUND',
      ]);
      expect(rows[1]['credit'], 750);
      expect(rows[2]['debit'], 750);
      expect(rows.last['due'], 0);
    },
  );

  test(
    'records an invoice discount as a ledger credit, not a cash receipt',
    () {
      final invoiceDate = DateTime(2026, 11, 1, 10);
      final discountDate = DateTime(2026, 11, 2, 11);

      final rows = DebatorController.buildRegularCustomerLedgerRows(
        invoices: [
          {
            'docId': 'INVOICE-DISCOUNT',
            'invoiceId': 'INVOICE-DISCOUNT',
            'amount': 3000,
            'timestamp': Timestamp.fromDate(invoiceDate),
            'paymentHistory': [
              {
                'amount': 500,
                'timestamp': Timestamp.fromDate(discountDate),
                'type': 'discount',
                'collectionMode': 'discount',
                'sourceTxId': 'DISCOUNT-1',
                'invoiceId': 'INVOICE-DISCOUNT',
              },
            ],
          },
        ],
        advanceHistory: const [],
      );

      expect(rows, hasLength(2));
      expect(rows[0]['label'], 'INVOICE');
      expect(rows[0]['debit'], 3000);
      expect(rows[0]['credit'], 0);
      expect(rows[0]['due'], 3000);
      expect(rows[1]['label'], 'DISCOUNT');
      expect(rows[1]['debit'], 0);
      expect(rows[1]['credit'], 500);
      expect(rows[1]['due'], 2500);
      expect(rows[1]['paymentMethod'], {'type': 'discount'});
    },
  );

  test('due ledger keeps the full receipt and excludes a returned invoice', () {
    final dueInvoiceDate = DateTime(2026, 10, 4, 10);
    final receiptDate = DateTime(2026, 11, 1, 10);

    final rows = DebatorController.buildRegularCustomerDueLedgerRows(
      invoices: [
        {
          'docId': 'DUE-1',
          'invoiceId': 'DUE-1',
          'amount': 2000,
          'paid': 1000,
          'pending': 1000,
          'timestamp': Timestamp.fromDate(dueInvoiceDate),
          'paymentHistory': [
            {
              'amount': 500,
              'timestamp': Timestamp.fromDate(dueInvoiceDate),
              'type': 'cash',
            },
            {
              'amount': 450,
              'timestamp': Timestamp.fromDate(receiptDate),
              'sourceTxId': 'RECEIPT-1',
              'invoiceId': 'DUE-1',
              'collectionMode': 'old_due_ledger',
              'type': 'cash',
            },
          ],
        },
        {
          'docId': 'PAID-1',
          'invoiceId': 'PAID-1',
          'amount': 0,
          'paid': 0,
          'pending': 750,
          'timestamp': Timestamp.fromDate(dueInvoiceDate),
          'paymentHistory': [
            {
              'amount': 50,
              'timestamp': Timestamp.fromDate(receiptDate),
              'sourceTxId': 'RECEIPT-1',
              'invoiceId': 'PAID-1',
              'collectionMode': 'old_due_ledger',
              'type': 'cash',
            },
          ],
        },
      ],
      advanceHistory: const [],
    );

    expect(rows.map((row) => row['label']).toList(), ['INVOICE', 'PAYMENT']);
    expect(rows.last['credit'], 500);
    expect(rows.last['note'], 'Payment received');
    expect(rows.last['due'], 1000);
    expect(
      DebatorController.effectiveRegularCustomerPending({
        'amount': 0,
        'paid': 0,
        'pending': 750,
      }),
      0,
    );
  });

  test('combines collection and excess advance without double counting', () {
    final invoiceDate = DateTime(2026, 10, 31, 10);
    final receiptDate = DateTime(2026, 10, 31, 11);
    final nextInvoiceDate = DateTime(2026, 10, 31, 12);
    const receiptId = 'COLLECT-123';
    const firstInvoiceId = 'INVOICE-1';

    final rows = DebatorController.buildRegularCustomerLedgerRows(
      invoices: [
        {
          'docId': firstInvoiceId,
          'invoiceId': firstInvoiceId,
          'amount': 105,
          'timestamp': Timestamp.fromDate(invoiceDate),
          'paymentHistory': [
            {
              'amount': 105,
              'timestamp': Timestamp.fromDate(receiptDate),
              'sourceTxId': receiptId,
              'invoiceId': firstInvoiceId,
              'collectionMode': 'old_due_ledger',
              'type': 'cash',
            },
          ],
        },
        {
          'docId': 'INVOICE-2',
          'invoiceId': 'INVOICE-2',
          'amount': 105,
          'timestamp': Timestamp.fromDate(nextInvoiceDate),
          'paymentHistory': [
            {
              'amount': 15,
              'timestamp': Timestamp.fromDate(nextInvoiceDate),
              'collectionMode': 'advance_credit',
              'type': 'advance',
            },
          ],
        },
      ],
      advanceHistory: [
        {
          'amount': 15,
          'timestamp': Timestamp.fromDate(receiptDate),
          'sourceTxId': receiptId,
          'type': 'cash',
        },
      ],
    );

    expect(rows, hasLength(3));
    expect(rows.map((row) => row['label']).toList(), [
      'INVOICE',
      'PAYMENT',
      'INVOICE',
    ]);
    expect(rows[0]['debit'], 105);
    expect(rows[0]['credit'], 0);
    expect(rows[0]['due'], 105);
    expect(rows[1]['debit'], 0);
    expect(rows[1]['credit'], 120);
    expect(rows[1]['due'], -15);
    expect(rows[1]['note'], contains('Extra advance ৳15'));
    expect(rows[2]['debit'], 105);
    expect(rows[2]['credit'], 0);
    expect(rows[2]['due'], 90);
    expect(rows[2]['note'], contains('Advance used ৳15'));
  });
}
