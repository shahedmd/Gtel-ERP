// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart'; // Your Cash Controller Import
import 'package:gtel_erp/Vendor/vendormodel.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE ---
  final RxList<VendorModel> vendors = <VendorModel>[].obs;
  final RxList<VendorTransaction> currentTransactions =
      <VendorTransaction>[].obs;
  final RxBool isLoading = false.obs;

  StreamSubscription? _vendorSub;
  StreamSubscription? _historySub;

  @override
  void onInit() {
    super.onInit();
    bindVendors();
  }

  @override
  void onClose() {
    _vendorSub?.cancel();
    _historySub?.cancel();
    super.onClose();
  }

  // 1. LISTEN TO VENDORS
  void bindVendors() {
    _vendorSub = _firestore
        .collection('vendors')
        .orderBy('name')
        .snapshots()
        .listen(
          (event) {
            vendors.value =
                event.docs.map((e) => VendorModel.fromSnapshot(e)).toList();
          },
          onError: (e) {
            debugPrint("Vendor Stream Error: $e");
          },
        );
  }

  // 2. FETCH HISTORY
  void fetchHistory(String vendorId) {
    currentTransactions.clear();
    _historySub?.cancel();

    _historySub = _firestore
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

  // 3. CREATE VENDOR
  Future<void> addVendor(String name, String contact) async {
    try {
      await _firestore.collection('vendors').add({
        'name': name,
        'contact': contact,
        'totalDue': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.back();
      Get.snackbar(
        "Success",
        "Vendor Added Successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // 4. AUTOMATED SHIPMENT CREDIT
  Future<void> addAutomatedShipmentCredit({
    required String vendorId,
    required double amount,
    required String shipmentName,
    required DateTime date,
  }) async {
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot vendorSnapshot = await transaction.get(vendorRef);
        if (!vendorSnapshot.exists) throw "Vendor not found";

        double currentDue = (vendorSnapshot.data() as Map)['totalDue'] ?? 0.0;
        double newDue = currentDue + amount;

        transaction.update(vendorRef, {'totalDue': newDue});

        transaction.set(historyRef, {
          'type': 'CREDIT',
          'amount': amount,
          'date': Timestamp.fromDate(date),
          'paymentMethod': 'Stock Receive',
          'shipmentName': shipmentName,
          'cartons': 'N/A',
          'notes': 'Auto-entry from Shipment: $shipmentName',
          'isIncomingCash': false,
        });
      });
    } catch (e) {
      throw "Vendor Credit Failed: $e";
    }
  }

  // 5. MANUAL TRANSACTION (Updated & Fixed)
  Future<void> addTransaction({
    required String vendorId,
    required String vendorName,
    required String type, // 'CREDIT' or 'DEBIT'
    required double amount,
    required DateTime date,
    String? paymentMethod,
    String? shipmentName,
    String? cartons,
    String? notes,
    // New Parameter: Set this to true in your UI Switch/Checkbox
    bool isIncomingCash = false,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot vendorSnapshot = await transaction.get(vendorRef);
        if (!vendorSnapshot.exists) throw "Vendor does not exist!";

        double currentDue = (vendorSnapshot.data() as Map)['totalDue'] ?? 0.0;
        double newDue;

        // LOGIC FOR DUE AMOUNT:
        // 1. We Received Advance (isIncomingCash = true):
        //    We got money, so we owe the vendor MORE (Liability increases).
        //    Treat exactly like a Credit/Bill.
        if (isIncomingCash) {
          newDue = currentDue + amount;
        }
        // 2. Normal Bill (Credit): We owe more.
        else if (type == 'CREDIT') {
          newDue = currentDue + amount;
        }
        // 3. Normal Payment (Debit): We owe less.
        else {
          newDue = currentDue - amount;
        }

        transaction.update(vendorRef, {'totalDue': newDue});

        // If it's incoming cash, we force type to CREDIT (Liability) in history
        transaction.set(historyRef, {
          'type': isIncomingCash ? 'CREDIT' : type,
          'amount': amount,
          'date': Timestamp.fromDate(date),
          'paymentMethod': paymentMethod,
          'shipmentName': shipmentName,
          'cartons': cartons,
          'notes': notes,
          'isIncomingCash': isIncomingCash, // Save the flag
        });
      });

      // --- INTEGRATION: CONNECTING TO CASH & EXPENSES ---

      // SCENARIO 1: Vendor Paid Us (Incoming Advance)
      if (isIncomingCash) {
        // FIXED: Using helper method that handles "Fallback" if controller is missing
        await _ensureCashLedgerEntry(
          amount: amount,
          method: paymentMethod ?? 'cash',
          desc: "Advance/Refund from Vendor: $vendorName",
        );
      }
      // SCENARIO 2: We Paid Vendor (Outgoing Payment)
      else if (type == 'DEBIT') {
        _logToDailyExpenses(
          vendorName,
          amount,
          date,
          notes ?? "Vendor Payment",
        );
      }

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Success",
        "Transaction Recorded",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Transaction Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- HELPER METHODS ---

  // 1. Safe Cash Ledger Entry (Fallback Mechanism)
  Future<void> _ensureCashLedgerEntry({
    required double amount,
    required String method,
    required String desc,
  }) async {
    try {
      if (Get.isRegistered<CashDrawerController>()) {
        // CASE A: Controller is active (User visited Cash screen)
        // Update via controller to refresh UI immediately
        await Get.find<CashDrawerController>().addManualCash(
          amount: amount,
          method: method,
          desc: desc,
        );
      } else {
        // CASE B: Controller is NOT active (User hasn't visited Cash screen yet)
        // Write directly to Firestore so data is not lost
        await _firestore.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': method,
          'description': desc,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("CRITICAL ERROR: Could not save to Cash Ledger: $e");
    }
  }

  // 2. Helper for Daily Expenses
  void _logToDailyExpenses(
    String vendorName,
    double amount,
    DateTime date,
    String note,
  ) {
    try {
      if (Get.isRegistered<DailyExpensesController>()) {
        Get.find<DailyExpensesController>().addDailyExpense(
          "Payment to $vendorName",
          amount.toInt(),
          note: note,
          date: date,
        );
      }
      // Expenses are complex to add manually via fallback due to subcollections,
      // usually Expense controller is initialized early in the app.
    } catch (e) {
      debugPrint("Expense Log Error: $e");
    }
  }
}
