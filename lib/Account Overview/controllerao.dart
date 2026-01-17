import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/model.dart';
// import 'package:gtel_erp/models/financial_models.dart'; // Import your models here

class FinancialController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---

  // 1. Assets State
  RxList<FixedAssetModel> fixedAssets = <FixedAssetModel>[].obs;
  RxDouble totalFixedAssets = 0.0.obs;

  // 2. Liquid Cash State (Placeholders for your Cash Controller)
  RxDouble cashInHand = 0.0.obs;
  RxDouble cashInBank = 0.0.obs;
  RxDouble cashInBkash = 0.0.obs;
  RxDouble cashInNagad = 0.0.obs;

  // 3. Liabilities State (Placeholders for Vendor/Debtor Controllers)
  RxDouble totalVendorDue = 0.0.obs; // We owe them
  RxDouble totalDebtorReceivable = 0.0.obs; // They owe us (Asset)

  // 4. Payroll State
  RxList<PayrollItemModel> payrollItems = <PayrollItemModel>[].obs;
  RxDouble totalMonthlyPayroll = 0.0.obs;

  // --- SUMMARY CALCULATED VARS ---
  RxDouble get totalAssets =>
      (totalFixedAssets.value +
              cashInHand.value +
              cashInBank.value +
              cashInBkash.value +
              cashInNagad.value +
              totalDebtorReceivable.value)
          .obs;

  RxDouble get totalLiabilities =>
      (totalVendorDue.value + totalMonthlyPayroll.value).obs;
  // Payroll is technically an expense, but treated as liability for projection

  RxDouble get netWorth => (totalAssets.value - totalVendorDue.value).obs;
  // Net worth usually doesn't subtract future payroll, but subtracts actual debt.

  @override
  void onInit() {
    super.onInit();
    _bindFixedAssets();
    _bindPayroll();
    _fetchExternalControllerData();
  }

  // --- FIRESTORE LISTENERS ---

  void _bindFixedAssets() {
    _db.collection('company_assets').snapshots().listen((snapshot) {
      fixedAssets.value =
          snapshot.docs.map((e) => FixedAssetModel.fromSnapshot(e)).toList();
      totalFixedAssets.value = fixedAssets.fold(
        0,
        (sum, item) => sum + item.value,
      );
    });
  }

  void _bindPayroll() {
    _db.collection('company_payroll').snapshots().listen((snapshot) {
      payrollItems.value =
          snapshot.docs.map((e) => PayrollItemModel.fromSnapshot(e)).toList();
      totalMonthlyPayroll.value = payrollItems.fold(
        0,
        (sum, item) => sum + item.monthlyAmount,
      );
    });
  }

  // --- EXTERNAL DATA INTEGRATION (MOCK) ---
  // Call this method to update values from your other controllers
  void _fetchExternalControllerData() {
    // TODO: Connect your existing controllers here later
    // Example: cashInHand.value = Get.find<CashController>().balance.value;

    // Mock Data for UI visualization
    cashInHand.value = 50000;
    cashInBank.value = 120000;
    cashInBkash.value = 15000;
    cashInNagad.value = 8000;

    totalVendorDue.value = 45000; // Liability
    totalDebtorReceivable.value = 32000; // Asset
  }

  // --- CRUD OPERATIONS: ASSETS ---

  Future<void> addAsset(String name, double value, String category) async {
    await _db.collection('company_assets').add({
      'name': name,
      'value': value,
      'category': category,
      'date': Timestamp.now(),
    });
    Get.back();
    Get.snackbar(
      "Success",
      "Asset Added",
      backgroundColor: Colors.green.withOpacity(0.2),
    );
  }

  Future<void> deleteAsset(String id) async {
    await _db.collection('company_assets').doc(id).delete();
  }

  Future<void> updateAsset(String id, double newValue) async {
    await _db.collection('company_assets').doc(id).update({'value': newValue});
  }

  // --- CRUD OPERATIONS: PAYROLL ---

  Future<void> addPayrollItem(String title, double amount, String type) async {
    await _db.collection('company_payroll').add({
      'title': title,
      'monthlyAmount': amount,
      'type': type,
    });
    Get.back();
    Get.snackbar(
      "Success",
      "Payroll Item Added",
      backgroundColor: Colors.green.withOpacity(0.2),
    );
  }

  Future<void> deletePayroll(String id) async {
    await _db.collection('company_payroll').doc(id).delete();
  }
}
