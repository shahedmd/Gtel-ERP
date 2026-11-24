class CashDrawerSaleReceipt {
  static const _methods = ['cash', 'bank', 'bkash', 'nagad'];

  static Map<String, double> byMethod(Map<String, dynamic> sale) {
    final paid = _number(sale['paid']);
    final ledgerPaid = _number(sale['ledgerPaid']);
    final actualReceived =
        (paid - ledgerPaid).clamp(0, double.infinity).toDouble();
    final customerType = (sale['customerType'] ?? '').toString().toLowerCase();
    if (customerType != 'wholesale' && customerType != 'vip') {
      return _legacyByMethod(sale['paymentMethod'], actualReceived);
    }

    final result = {for (final method in _methods) method: 0.0};
    final paymentMethod = sale['paymentMethod'];

    if (paymentMethod is Map) {
      for (final method in _methods) {
        result[method] = _number(paymentMethod[method]);
      }

      if (result.values.fold<double>(0, (sum, value) => sum + value) <= 0.01) {
        final bankName = (paymentMethod['bankName'] ?? '').toString();
        final bkashNumber = (paymentMethod['bkashNumber'] ?? '').toString();
        final nagadNumber = (paymentMethod['nagadNumber'] ?? '').toString();
        final method =
            bankName.isNotEmpty
                ? 'bank'
                : bkashNumber.isNotEmpty
                ? 'bkash'
                : nagadNumber.isNotEmpty
                ? 'nagad'
                : 'cash';
        result[method] = actualReceived;
      } else {
        final ledgerByMethod = _oldDueCollectionsByMethod(
          sale['paymentHistory'],
        );
        for (final method in _methods) {
          result[method] = (result[method]! - ledgerByMethod[method]!).clamp(
            0,
            double.infinity,
          );
        }
      }
    } else {
      final methodString = paymentMethod.toString().toLowerCase();
      final method =
          methodString.contains('bank')
              ? 'bank'
              : methodString.contains('bkash')
              ? 'bkash'
              : methodString.contains('nagad')
              ? 'nagad'
              : 'cash';
      result[method] = actualReceived;
    }

    _reconcileTotal(result, actualReceived);
    return result;
  }

  static Map<String, double> _legacyByMethod(
    dynamic paymentMethod,
    double actualReceived,
  ) {
    final result = {for (final method in _methods) method: 0.0};
    if (paymentMethod is Map) {
      for (final method in _methods) {
        result[method] = _number(paymentMethod[method]);
      }

      if (result.values.fold<double>(0, (sum, value) => sum + value) <= 0.01) {
        final bankName = (paymentMethod['bankName'] ?? '').toString();
        final bkashNumber = (paymentMethod['bkashNumber'] ?? '').toString();
        final nagadNumber = (paymentMethod['nagadNumber'] ?? '').toString();
        final method =
            bankName.isNotEmpty
                ? 'bank'
                : bkashNumber.isNotEmpty
                ? 'bkash'
                : nagadNumber.isNotEmpty
                ? 'nagad'
                : 'cash';
        result[method] = actualReceived;
      }
    } else {
      final methodString = paymentMethod.toString().toLowerCase();
      final method =
          methodString.contains('bank')
              ? 'bank'
              : methodString.contains('bkash')
              ? 'bkash'
              : methodString.contains('nagad')
              ? 'nagad'
              : 'cash';
      result[method] = actualReceived;
    }
    return result;
  }

  static Map<String, double> _oldDueCollectionsByMethod(dynamic history) {
    final totals = {for (final method in _methods) method: 0.0};
    if (history is! Iterable) return totals;

    for (final entry in history) {
      if (entry is! Map || entry['collectionMode'] != 'old_due_ledger') {
        continue;
      }
      final method = (entry['type'] ?? 'cash').toString().toLowerCase();
      if (totals.containsKey(method)) {
        totals[method] = totals[method]! + _number(entry['amount']);
      }
    }
    return totals;
  }

  static void _reconcileTotal(Map<String, double> amounts, double target) {
    final total = amounts.values.fold<double>(0, (sum, value) => sum + value);
    if (total > target && total > 0) {
      final scale = target / total;
      for (final method in _methods) {
        amounts[method] = amounts[method]! * scale;
      }
    } else if (total < target) {
      amounts['cash'] = amounts['cash']! + target - total;
    }
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
