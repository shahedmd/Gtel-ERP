import 'package:cloud_firestore/cloud_firestore.dart';

class PaidInvoiceRunningDueSnapshot {
  static const _hasOriginalField = 'snapshotRunningDueBeforePaidExists';
  static const _originalValue = 'snapshotRunningDueBeforePaid';

  static Map<String, dynamic> markPaid(Map<String, dynamic> order) {
    // Paying this invoice alone does not prove that earlier dues were settled.
    return const {};
  }

  static Map<String, dynamic> clearForRepair(Map<String, dynamic> order) {
    final update = <String, dynamic>{'snapshotRunningDue': 0.0};
    if (!order.containsKey(_hasOriginalField)) {
      update[_hasOriginalField] = order.containsKey('snapshotRunningDue');
      if (order.containsKey('snapshotRunningDue')) {
        update[_originalValue] = order['snapshotRunningDue'];
      }
    }
    return update;
  }

  static Map<String, dynamic> restoreIfUnpaid(Map<String, dynamic> order) {
    if (!order.containsKey(_hasOriginalField)) return const {};
    return {
      'snapshotRunningDue':
          order[_hasOriginalField] == true && order.containsKey(_originalValue)
              ? order[_originalValue]
              : FieldValue.delete(),
    };
  }

  static bool shouldClearRunningDue({required Map<String, dynamic> order}) {
    final orderType = (order['customerType'] ?? '').toString().toLowerCase();
    if (orderType != 'agent' || order['isFullyPaid'] != true) return false;

    final paymentDetails =
        order['paymentDetails'] is Map
            ? Map<String, dynamic>.from(order['paymentDetails'] as Map)
            : const <String, dynamic>{};
    final due = double.tryParse(paymentDetails['due']?.toString() ?? '');
    if (due != null) return due <= 0.5;

    final grandTotal = double.tryParse(order['grandTotal']?.toString() ?? '');
    final paid = double.tryParse(order['paid']?.toString() ?? '');
    return grandTotal != null && paid != null && grandTotal - paid <= 0.5;
  }
}
