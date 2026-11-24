import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Live%20order/agent_sale_payment_plan.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/regular_customer_collection_plan.dart';

void main() {
  final today = DateTime(2026, 11, 9);
  final yesterday = DateTime(2026, 11, 8);

  RegularCustomerCollectionInvoice invoice({
    required String id,
    required DateTime date,
    required double pending,
    double paid = 0,
    double ledgerPaid = 0,
  }) => RegularCustomerCollectionInvoice(
    documentId: id,
    pending: pending,
    paid: paid,
    ledgerPaid: ledgerPaid,
    invoiceDate: date,
  );

  test('same-day collection updates paid without a cash-ledger allocation', () {
    final plan = RegularCustomerCollectionPlan.build(
      invoices: [invoice(id: 'today', date: today, pending: 1000, paid: 250)],
      amount: 1000,
      collectionDate: today,
    );

    expect(plan.appliedAmount, 1000);
    expect(plan.cashLedgerAmount, 0);
    expect(plan.allocations.single.newPaid, 1250);
    expect(plan.allocations.single.newLedgerPaid, 0);
    expect(plan.allocations.single.isFullyPaid, isTrue);
  });

  test('previous-date collection is fully represented in the cash ledger', () {
    final plan = RegularCustomerCollectionPlan.build(
      invoices: [
        invoice(
          id: 'yesterday',
          date: yesterday,
          pending: 1000,
          paid: 200,
          ledgerPaid: 50,
        ),
      ],
      amount: 1000,
      collectionDate: today,
    );

    expect(plan.cashLedgerAmount, 1000);
    expect(plan.allocations.single.newPaid, 1200);
    expect(plan.allocations.single.newLedgerPaid, 1050);
    expect(plan.allocations.single.isFullyPaid, isTrue);
  });

  test(
    'mixed FIFO collection separates previous-date and same-day amounts',
    () {
      final plan = RegularCustomerCollectionPlan.build(
        invoices: [
          invoice(id: 'today', date: today, pending: 400),
          invoice(id: 'yesterday', date: yesterday, pending: 600),
        ],
        amount: 1200,
        collectionDate: today,
      );

      expect(
        plan.allocations.map((allocation) => allocation.invoice.documentId),
        ['yesterday', 'today'],
      );
      expect(plan.allocations.map((allocation) => allocation.amount), [
        600,
        400,
      ]);
      expect(plan.allocations.map((allocation) => allocation.newLedgerPaid), [
        600,
        0,
      ]);
      expect(plan.appliedAmount, 1000);
      expect(plan.advanceAmount, 200);
      expect(plan.cashLedgerAmount, 800);
    },
  );

  test(
    'sale overpayment settles previous due and keeps only the excess as advance',
    () {
      final previousDuePlan = RegularCustomerCollectionPlan.build(
        invoices: [invoice(id: 'yesterday', date: yesterday, pending: 100)],
        amount: 1500 - 1000,
        collectionDate: today,
      );

      expect(previousDuePlan.appliedAmount, 100);
      expect(previousDuePlan.advanceAmount, 400);
      expect(previousDuePlan.cashLedgerAmount, 500);
      expect(previousDuePlan.allocations.single.isPreviousDateInvoice, isTrue);
      expect(
        calculatePostSaleAccountBalance(
          previousBalance: 100,
          invoiceTotal: 1000,
          cashReceived: 1500,
        ),
        -400,
      );
    },
  );

  test('sale cash pays earlier invoices before the current invoice', () {
    final previousDuePlan = RegularCustomerCollectionPlan.build(
      invoices: [invoice(id: 'previous', date: yesterday, pending: 100)],
      amount: 150,
      collectionDate: today,
    );
    final currentInvoicePaid =
        previousDuePlan.advanceAmount < 200
            ? previousDuePlan.advanceAmount
            : 200.0;

    expect(previousDuePlan.allocations.single.amount, 100);
    expect(currentInvoicePaid, 50);
    expect(previousDuePlan.advanceAmount - currentInvoicePaid, 0);
  });
}
