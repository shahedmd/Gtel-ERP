import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/purchaseallocation.dart';

void main() {
  test('allocates settlements to the oldest invoice first', () {
    final plan = PurchaseAllocation.allocate(
      invoices: [
        {
          'id': 'newer',
          'date': DateTime(2026, 1, 10),
          'totalAmount': 6000.0,
          'settledAmount': 0.0,
        },
        {
          'id': 'older',
          'date': DateTime(2026, 1, 1),
          'totalAmount': 10000.0,
          'settledAmount': 0.0,
        },
      ],
      amount: 12000,
    );

    expect(plan.allocations, [
      {'invoiceId': 'older', 'amount': 10000.0},
      {'invoiceId': 'newer', 'amount': 2000.0},
    ]);
    expect(plan.unallocatedAmount, 0);
  });

  test('preserves partial invoice balances and reports excess credit', () {
    final plan = PurchaseAllocation.allocate(
      invoices: [
        {
          'id': 'older',
          'date': DateTime(2026, 1, 1),
          'totalAmount': 10000.0,
          'settledAmount': 8000.0,
        },
        {
          'id': 'newer',
          'date': DateTime(2026, 1, 10),
          'totalAmount': 6000.0,
          'settledAmount': 0.0,
        },
      ],
      amount: 5000,
    );

    expect(plan.allocations, [
      {'invoiceId': 'older', 'amount': 2000.0},
      {'invoiceId': 'newer', 'amount': 3000.0},
    ]);
    expect(plan.unallocatedAmount, 0);
    expect(
      PurchaseAllocation.dueFor({
        'totalAmount': 6000.0,
        'settledAmount': 3000.0,
      }),
      3000,
    );
  });

  test('leaves settlement above outstanding invoices as supplier credit', () {
    final plan = PurchaseAllocation.allocate(
      invoices: [
        {
          'id': 'invoice',
          'date': DateTime(2026, 1, 1),
          'totalAmount': 1000.0,
          'settledAmount': 0.0,
        },
      ],
      amount: 1500,
    );

    expect(plan.allocations.single['amount'], 1000.0);
    expect(plan.unallocatedAmount, 500.0);
  });
}
