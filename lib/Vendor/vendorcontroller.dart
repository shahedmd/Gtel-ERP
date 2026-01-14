// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
// ASSUMPTION: Adjust this import path to where your DailyExpensesController is located

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  final RxList<VendorModel> vendors = <VendorModel>[].obs;
  final RxList<VendorTransaction> currentTransactions =
      <VendorTransaction>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    bindVendors();
  }

  // 1. LISTEN TO VENDORS
  void bindVendors() {
    _firestore.collection('vendors').orderBy('name').snapshots().listen((
      event,
    ) {
      vendors.value =
          event.docs.map((e) => VendorModel.fromSnapshot(e)).toList();
    });
  }

  // 2. FETCH HISTORY FOR SPECIFIC VENDOR
  void fetchHistory(String vendorId) {
    currentTransactions.clear(); // Clear old data first
    _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('history')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((event) {
          currentTransactions.value =
              event.docs.map((e) => VendorTransaction.fromSnapshot(e)).toList();
        });
  }

  // 3. CREATE NEW VENDOR
  Future<void> addVendor(String name, String contact) async {
    try {
      await _firestore.collection('vendors').add({
        'name': name,
        'contact': contact,
        'totalDue': 0.0, // Starts at 0
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.back();
      Get.snackbar("Success", "Vendor Added");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  // 4. ADD TRANSACTION (CREDIT OR DEBIT)
  // UPDATED: Now requires 'vendorName' to create a clean Expense entry.
  // UPDATED: Automatically triggers DailyExpensesController on DEBIT.
  Future<void> addTransaction({
    required String vendorId,
    required String vendorName, // Pass this for the Expense Title
    required String type, // 'CREDIT' or 'DEBIT'
    required double amount,
    required DateTime date,
    String? paymentMethod,
    String? shipmentName,
    String? cartons,
    DateTime? shipmentDate,
    DateTime? receiveDate,
    String? notes,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();

      // STEP A: Run Firestore Transaction for Vendor Balance & History
      // This ensures the vendor balance is always accurate.
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot vendorSnapshot = await transaction.get(vendorRef);

        if (!vendorSnapshot.exists) throw "Vendor does not exist!";

        double currentDue = (vendorSnapshot.data() as Map)['totalDue'] ?? 0.0;

        double newDue =
            type == 'CREDIT'
                ? currentDue +
                    amount // Bill increases debt
                : currentDue - amount; // Payment decreases debt

        // 1. Update Balance
        transaction.update(vendorRef, {'totalDue': newDue});

        // 2. Add History Log
        transaction.set(historyRef, {
          'type': type,
          'amount': amount,
          'date': Timestamp.fromDate(date),
          'paymentMethod': paymentMethod,
          'shipmentName': shipmentName,
          'cartons': cartons,
          'shipmentDate':
              shipmentDate != null ? Timestamp.fromDate(shipmentDate) : null,
          'receiveDate':
              receiveDate != null ? Timestamp.fromDate(receiveDate) : null,
          'notes': notes,
        });
      });

      // STEP B: Integrate with Daily Expenses (ONLY for DEBIT)
      // Since DailyExpensesController handles the Monthly logic, we just call it.
      if (type == 'DEBIT') {
        try {
          if (Get.isRegistered<DailyExpensesController>()) {
            final dailyController = Get.find<DailyExpensesController>();

            // Add to Daily Expenses (which internally adds to Monthly)
            await dailyController.addDailyExpense(
              "Payment to $vendorName", // Name: e.g., "Payment to ABC Corp"
              amount.toInt(), // Convert double to int
              note: notes ?? "Paid via ${paymentMethod ?? 'Cash'}",
              date: date,
            );

            // Note: addDailyExpense might show a snackbar/Get.back().
            // If the UI behaves oddly (closing twice), check the back() calls.
          } else {
            debugPrint(
              "DailyExpensesController not initialized. Expense entry skipped.",
            );
          }
        } catch (e) {
          debugPrint("Failed to add to Daily Expenses: $e");
          // We do not throw here, because the Vendor transaction succeeded.
        }
      }

      // Check if dialog is open before closing (to prevent closing the wrong screen)
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        "Success",
        "Transaction Recorded Successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Transaction Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
