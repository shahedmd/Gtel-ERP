import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';
import '../Permission/permission_controller.dart';

class ActivityLogger {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  ActivityLogger._();

  static Future<void> log({
    required String action,
    required String module,
    required String details,
  }) async {
    try {
      String userEmail = 'unknown';
      String userName = 'unknown';
      if (Get.isRegistered<PermissionController>()) {
        final permCtrl = Get.find<PermissionController>();
        userEmail = permCtrl.userEmail;
        userName = permCtrl.userName;
      }
      await _db.collection('activity_logs').add({
        'userEmail': userEmail,
        'userName': userName,
        'action': action,
        'module': module,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('ActivityLogger error: $e');
    }
  }

  static Future<void> saleCreated(String details) =>
      log(action: 'CREATE_SALE', module: 'Sales', details: details);

  static Future<void> saleDeleted(String details) =>
      log(action: 'DELETE_SALE', module: 'Sales', details: details);

  static Future<void> saleEdited(String details) =>
      log(action: 'EDIT_SALE', module: 'Sales', details: details);

  // Stock
  static Future<void> stockUpdated(String details) =>
      log(action: 'UPDATE_STOCK', module: 'Stock', details: details);

  static Future<void> stockDeleted(String details) =>
      log(action: 'DELETE_STOCK', module: 'Stock', details: details);

  // Staff
  static Future<void> staffCreated(String details) =>
      log(action: 'CREATE_STAFF', module: 'Staff', details: details);

  static Future<void> staffEdited(String details) =>
      log(action: 'EDIT_STAFF', module: 'Staff', details: details);

  static Future<void> staffDeleted(String details) =>
      log(action: 'DELETE_STAFF', module: 'Staff', details: details);

  static Future<void> salaryEdited(String details) =>
      log(action: 'EDIT_SALARY', module: 'Staff', details: details);

  // Expenses
  static Future<void> expenseCreated(String details) =>
      log(action: 'CREATE_EXPENSE', module: 'Expenses', details: details);

  static Future<void> expenseDeleted(String details) =>
      log(action: 'DELETE_EXPENSE', module: 'Expenses', details: details);

  // Debtor
  static Future<void> debtorEdited(String details) =>
      log(action: 'EDIT_DEBTOR', module: 'Debtor', details: details);

  static Future<void> debtorPayment(String details) =>
      log(action: 'DEBTOR_PAYMENT', module: 'Debtor', details: details);

  // Cash Drawer
  static Future<void> cashTransaction(String details) =>
      log(action: 'CASH_TRANSACTION', module: 'Cash Drawer', details: details);

  // Sale Return
  static Future<void> saleReturned(String details) =>
      log(action: 'SALE_RETURN', module: 'Sale Return', details: details);

  // Shipment
  static Future<void> shipmentUpdated(String details) =>
      log(action: 'UPDATE_SHIPMENT', module: 'Shipment', details: details);
}