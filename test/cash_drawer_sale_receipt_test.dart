import 'package:flutter_test/flutter_test.dart';
import 'package:gtel_erp/Cash/cash_drawer_sale_receipt.dart';

void main() {
  test('same-day invoice payment remains in the sale receipt', () {
    final receipt = CashDrawerSaleReceipt.byMethod({
      'customerType': 'wholesale',
      'paid': 1000,
      'ledgerPaid': 0,
      'paymentMethod': {'cash': 1000},
      'paymentHistory': [
        {'amount': 1000, 'type': 'cash', 'collectionMode': 'same_day'},
      ],
    });

    expect(receipt['cash'], 1000);
  });

  test('previous-date ledger payment is excluded from the sale receipt', () {
    final receipt = CashDrawerSaleReceipt.byMethod({
      'customerType': 'vip',
      'paid': 1000,
      'ledgerPaid': 1000,
      'paymentMethod': {'cash': 1000},
      'paymentHistory': [
        {'amount': 1000, 'type': 'cash', 'collectionMode': 'old_due_ledger'},
      ],
    });

    expect(receipt['cash'], 0);
  });

  test('mixed old and same-day payments count each receipt once', () {
    final receipt = CashDrawerSaleReceipt.byMethod({
      'customerType': 'wholesale',
      'paid': 1000,
      'ledgerPaid': 600,
      'paymentMethod': {'cash': 1000},
      'paymentHistory': [
        {'amount': 600, 'type': 'cash', 'collectionMode': 'old_due_ledger'},
        {'amount': 400, 'type': 'cash', 'collectionMode': 'same_day'},
      ],
    });

    expect(receipt['cash'], 400);
    expect(receipt.values.fold<double>(0, (sum, amount) => sum + amount), 400);
    expect(receipt['cash']! + 600, 1000);
  });

  test('discount ledgerPaid does not subtract a real cash payment', () {
    final receipt = CashDrawerSaleReceipt.byMethod({
      'customerType': 'vip',
      'paid': 1000,
      'ledgerPaid': 500,
      'paymentMethod': {'cash': 500},
      'paymentHistory': [
        {'amount': 500, 'type': 'discount', 'collectionMode': 'discount'},
      ],
    });

    expect(receipt['cash'], 500);
  });

  test('non-Wholesale/VIP sale receipt calculation remains unchanged', () {
    final receipt = CashDrawerSaleReceipt.byMethod({
      'customerType': 'agent',
      'paid': 1000,
      'ledgerPaid': 400,
      'paymentMethod': {'cash': 1000},
    });

    expect(receipt['cash'], 1000);
  });
}
