// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE ---
  final RxList<VendorModel> vendors = <VendorModel>[].obs;
  final RxList<VendorTransaction> currentTransactions =
      <VendorTransaction>[].obs;
  final RxBool isLoading = false.obs;

  // --- SUBSCRIPTIONS (Memory Management) ---
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
    _historySub?.cancel(); // Cancel previous listener if switching vendors

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

  // 4. AUTOMATED SHIPMENT CREDIT (The New Feature)
  /// Called by ShipmentController when stock is received.
  /// Does NOT trigger DailyExpenses (because Credit is just a bill, not a cash outflow yet).
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
        double newDue = currentDue + amount; // Credit increases what we owe

        // Update Balance
        transaction.update(vendorRef, {'totalDue': newDue});

        // Add Log
        transaction.set(historyRef, {
          'type': 'CREDIT',
          'amount': amount,
          'date': Timestamp.fromDate(date),
          'paymentMethod': 'Stock Receive',
          'shipmentName': shipmentName,
          'cartons': 'N/A', // Can be updated if needed
          'notes': 'Auto-entry from Shipment: $shipmentName',
        });
      });

      // We don't show a snackbar here because ShipmentController will show the "Success" message.
    } catch (e) {
      // Re-throw so ShipmentController knows something went wrong
      throw "Vendor Credit Failed: $e";
    }
  }

  // 5. MANUAL TRANSACTION (UI Based)
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
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot vendorSnapshot = await transaction.get(vendorRef);
        if (!vendorSnapshot.exists) throw "Vendor does not exist!";

        double currentDue = (vendorSnapshot.data() as Map)['totalDue'] ?? 0.0;

        // CREDIT (Bill) = Increases Due
        // DEBIT (Payment) = Decreases Due
        double newDue =
            type == 'CREDIT' ? currentDue + amount : currentDue - amount;

        transaction.update(vendorRef, {'totalDue': newDue});

        transaction.set(historyRef, {
          'type': type,
          'amount': amount,
          'date': Timestamp.fromDate(date),
          'paymentMethod': paymentMethod,
          'shipmentName': shipmentName,
          'cartons': cartons,
          'notes': notes,
        });
      });

      // INTEGRATE WITH EXPENSES (ONLY FOR DEBIT/PAYMENT)
      if (type == 'DEBIT') {
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

  // Helper for Daily Expenses
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
    } catch (e) {
      debugPrint("Expense Log Error: $e");
    }
  }
}
