import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/regular_customer_discount_plan.dart';

void main() {
  RegularCustomerDiscountInvoice invoice({
    required String id,
    required double pending,
    double amount = 1000,
    double paid = 0,
    double ledgerPaid = 0,
    double discount = 0,
  }) => RegularCustomerDiscountInvoice(
    dailySalesDocumentId: 'daily-$id',
    invoiceId: id,
    amount: amount,
    pending: pending,
    paid: paid,
    ledgerPaid: ledgerPaid,
    discount: discount,
  );

  test('allocates discount oldest-first and updates settlement fields', () {
    final plan = RegularCustomerDiscountPlan.build(
      invoices: [
        invoice(
          id: 'invoice-1',
          pending: 300,
          paid: 700,
          ledgerPaid: 200,
          discount: 0,
        ),
        invoice(
          id: 'invoice-2',
          pending: 500,
          paid: 500,
          ledgerPaid: 0,
          discount: 0,
        ),
      ],
      amount: 600,
    );

    expect(plan.appliedAmount, 600);
    expect(plan.unappliedAmount, 0);
    expect(plan.allocations, hasLength(2));
    expect(plan.allocations[0].invoice.invoiceId, 'invoice-1');
    expect(plan.allocations[0].newPaid, 1000);
    expect(plan.allocations[0].newLedgerPaid, 500);
    expect(plan.allocations[0].newPending, 0);
    expect(plan.allocations[0].newDiscount, 300);
    expect(plan.allocations[0].isFullyPaid, isTrue);
    expect(plan.allocations[1].amount, 300);
    expect(plan.allocations[1].newPaid, 800);
    expect(plan.allocations[1].newLedgerPaid, 300);
    expect(plan.allocations[1].newPending, 200);
    expect(plan.allocations[1].newDiscount, 300);
    expect(plan.allocations[1].isFullyPaid, isFalse);
  });

  test('does not discount more than the open invoice due', () {
    final plan = RegularCustomerDiscountPlan.build(
      invoices: [invoice(id: 'invoice-1', pending: 250)],
      amount: 400,
    );

    expect(plan.appliedAmount, 250);
    expect(plan.unappliedAmount, 150);
    expect(plan.allocations.single.newPending, 0);
  });

  test('does not create allocations for invalid amounts', () {
    final plan = RegularCustomerDiscountPlan.build(
      invoices: [invoice(id: 'invoice-1', pending: 250)],
      amount: double.nan,
    );

    expect(plan.allocations, isEmpty);
    expect(plan.appliedAmount, 0);
  });
}
