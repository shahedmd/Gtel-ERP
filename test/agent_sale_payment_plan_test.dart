import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Live%20order/agent_sale_payment_plan.dart';

void main() {
  test(
    'applies payment to invoice and old due, then keeps surplus as advance',
    () {
      final plan = AgentSalePaymentPlan.build(
        invoiceTotal: 1000,
        cashReceived: 1500,
        oldDue: 100,
        runningDue: 0,
      );

      expect(plan.invoiceCash, 1000);
      expect(plan.oldDueCash, 100);
      expect(plan.runningDueCash, 0);
      expect(plan.advanceApplied, 0);
      expect(plan.advanceReceived, 400);
      expect(plan.invoicePaid, 1000);
      expect(plan.invoiceDue, 0);
      expect(
        calculatePostSaleAccountBalance(
          previousBalance: 100,
          invoiceTotal: 1000,
          cashReceived: 1500,
        ),
        -400,
      );
      expect(
        calculateInvoicePresentDue(
          previousBalance: 100,
          paidForOldDue: 100,
          paidForRunningDue: 0,
          invoiceDue: 0,
          advanceApplied: 0,
          advanceReceived: 400,
        ),
        -400,
      );
    },
  );

  test('keeps overpayment as advance when there is no previous due', () {
    final plan = AgentSalePaymentPlan.build(
      invoiceTotal: 1000,
      cashReceived: 1500,
      oldDue: 0,
      runningDue: 0,
    );

    expect(plan.advanceReceived, 500);
    expect(plan.invoiceDue, 0);
  });

  test('applies existing Agent advance to invoice paid and due fields', () {
    final plan = AgentSalePaymentPlan.build(
      invoiceTotal: 50,
      cashReceived: 0,
      oldDue: 0,
      runningDue: -30,
    );

    expect(plan.invoiceCash, 0);
    expect(plan.advanceApplied, 30);
    expect(plan.invoicePaid, 30);
    expect(plan.invoiceDue, 20);
    expect(
      calculateAgentInvoicePresentDue(
        snapshotOldDue: 0,
        snapshotRunningDue: -30,
        paidForOldDue: 0,
        paidForRunningDue: 0,
        invoiceDue: plan.invoiceDue,
        advanceApplied: plan.advanceApplied,
        advanceReceived: plan.advanceReceived,
      ),
      20,
    );
  });

  test('preview includes existing credit in the resulting account balance', () {
    expect(
      calculatePostSaleAccountBalance(
        previousBalance: -500,
        invoiceTotal: 1000,
        cashReceived: 400,
      ),
      100,
    );
  });

  test(
    'reprint uses the adjusted running-due snapshot after FIFO collection',
    () {
      expect(
        calculateAgentInvoicePreviousBalance(
          snapshotOldDue: 0,
          snapshotRunningDue: 0,
          paidForOldDue: 0,
          paidForRunningDue: 0,
        ),
        0,
      );
      expect(
        calculateAgentInvoicePresentDue(
          snapshotOldDue: 0,
          snapshotRunningDue: 0,
          paidForOldDue: 0,
          paidForRunningDue: 0,
          invoiceDue: 50,
          advanceApplied: 0,
          advanceReceived: 0,
        ),
        50,
      );
    },
  );

  test('a paid invoice can still show its unpaid previous running due', () {
    expect(
      calculateAgentInvoicePreviousBalance(
        snapshotOldDue: 0,
        snapshotRunningDue: 10,
        paidForOldDue: 0,
        paidForRunningDue: 0,
      ),
      10,
    );
    expect(
      calculateAgentInvoicePresentDue(
        snapshotOldDue: 0,
        snapshotRunningDue: 10,
        paidForOldDue: 0,
        paidForRunningDue: 0,
        invoiceDue: 0,
        advanceApplied: 0,
        advanceReceived: 0,
      ),
      10,
    );
  });

  test('keeps new excess separately when existing credit is unused', () {
    final plan = AgentSalePaymentPlan.build(
      invoiceTotal: 1000,
      cashReceived: 1500,
      oldDue: 0,
      runningDue: -500,
    );

    expect(plan.advanceApplied, 0);
    expect(plan.advanceReceived, 500);
    expect(plan.invoiceDue, 0);
  });

  test(
    'leaves invoice due when combined cash and prior credit are insufficient',
    () {
      final plan = AgentSalePaymentPlan.build(
        invoiceTotal: 1000,
        cashReceived: 400,
        oldDue: 0,
        runningDue: -300,
      );

      expect(plan.invoiceCash, 400);
      expect(plan.advanceApplied, 300);
      expect(plan.advanceReceived, 0);
      expect(plan.invoiceDue, 300);
    },
  );
}
