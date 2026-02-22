// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---

  // 1. Vendor List State (Stream + Client-Side Pagination)
  final RxList<VendorModel> _allVendors = <VendorModel>[].obs;
  final RxList<VendorModel> vendors = <VendorModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  // Vendor Pagination
  final int _itemsPerPage = 10;
  final RxInt currentVendorPage = 1.obs;
  final RxBool hasMoreVendors = false.obs;

  // 2. Transaction History State (Server-Side Pagination)
  final RxList<VendorTransaction> currentTransactions =
      <VendorTransaction>[].obs;
  final RxBool isHistoryLoading = false.obs;
  final RxString currentTransFilter = 'All'.obs; 

  // History Pagination Helpers
  DocumentSnapshot? _lastTransDoc;
  final List<DocumentSnapshot> _transPageStartDocs = [];
  final RxInt currentTransPage = 1.obs;
  final RxBool hasMoreTrans = true.obs;
  String? _activeVendorId;

  StreamSubscription? _vendorSub;

  @override
  void onInit() {
    super.onInit();
    bindVendors();
  }

  @override
  void onClose() {
    _vendorSub?.cancel();
    super.onClose();
  }

  // ===========================================================================
  // 1. VENDOR LOGIC
  // ===========================================================================

  void bindVendors() {
    isLoading.value = true;
    _vendorSub = _firestore
        .collection('vendors')
        .orderBy('name')
        .snapshots()
        .listen(
          (event) {
            _allVendors.value =
                event.docs.map((e) => VendorModel.fromSnapshot(e)).toList();
            _refreshVendorPage();
            isLoading.value = false;
          },
          onError: (e) {
            isLoading.value = false;
            debugPrint("Vendor Stream Error: $e");
          },
        );
  }

  void searchVendors(String query) {
    searchQuery.value = query;
    currentVendorPage.value = 1;
    _refreshVendorPage();
  }

  void nextVendorPage() {
    if (hasMoreVendors.value) {
      currentVendorPage.value++;
      _refreshVendorPage();
    }
  }

  void previousVendorPage() {
    if (currentVendorPage.value > 1) {
      currentVendorPage.value--;
      _refreshVendorPage();
    }
  }

  void _refreshVendorPage() {
    List<VendorModel> filtered =
        _allVendors.where((v) {
          return v.name.toLowerCase().contains(searchQuery.value.toLowerCase());
        }).toList();

    int totalItems = filtered.length;
    int startIndex = (currentVendorPage.value - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= totalItems) {
      startIndex = 0;
      currentVendorPage.value = 1;
    }
    if (endIndex > totalItems) endIndex = totalItems;

    vendors.value = filtered.sublist(startIndex, endIndex);
    hasMoreVendors.value = endIndex < totalItems;
  }

  // ===========================================================================
  // 2. TRANSACTION HISTORY LOGIC
  // ===========================================================================

  void setTransactionFilter(String filter) {
    if (currentTransFilter.value == filter) return;
    currentTransFilter.value = filter;
    if (_activeVendorId != null) {
      loadHistoryInitial(_activeVendorId!);
    }
  }

  Future<void> loadHistoryInitial(String vendorId) async {
    _activeVendorId = vendorId;
    isHistoryLoading.value = true;
    currentTransPage.value = 1;
    _transPageStartDocs.clear();
    _lastTransDoc = null;
    currentTransactions.clear();

    try {
      Query query = _buildHistoryQuery(vendorId);
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastTransDoc = snapshot.docs.last;
        _transPageStartDocs.add(snapshot.docs.first);
        currentTransactions.value =
            snapshot.docs
                .map((e) => VendorTransaction.fromSnapshot(e))
                .toList();
        hasMoreTrans.value = snapshot.docs.length == _itemsPerPage;
      } else {
        hasMoreTrans.value = false;
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> nextHistoryPage() async {
    if (!hasMoreTrans.value ||
        isHistoryLoading.value ||
        _activeVendorId == null) {
      return;
    }
    isHistoryLoading.value = true;
    try {
      Query query = _buildHistoryQuery(
        _activeVendorId!,
      ).startAfterDocument(_lastTransDoc!);
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastTransDoc = snapshot.docs.last;
        _transPageStartDocs.add(snapshot.docs.first);
        currentTransactions.value =
            snapshot.docs
                .map((e) => VendorTransaction.fromSnapshot(e))
                .toList();
        currentTransPage.value++;
        hasMoreTrans.value = snapshot.docs.length == _itemsPerPage;
      } else {
        hasMoreTrans.value = false;
      }
    } catch (e) {
      debugPrint("Error next history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> previousHistoryPage() async {
    if (currentTransPage.value <= 1 ||
        isHistoryLoading.value ||
        _activeVendorId == null) {
      return;
    }
    isHistoryLoading.value = true;
    try {
      _transPageStartDocs.removeLast();
      DocumentSnapshot targetStartDoc = _transPageStartDocs.last;

      Query query = _buildHistoryQuery(
        _activeVendorId!,
      ).startAtDocument(targetStartDoc);
      QuerySnapshot snapshot = await query.get();

      _lastTransDoc = snapshot.docs.last;
      currentTransactions.value =
          snapshot.docs.map((e) => VendorTransaction.fromSnapshot(e)).toList();
      currentTransPage.value--;
      hasMoreTrans.value = true;
    } catch (e) {
      debugPrint("Error prev history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Query _buildHistoryQuery(String vendorId) {
    Query query = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('history')
        .orderBy('date', descending: true);

    if (currentTransFilter.value == 'CREDIT') {
      query = query.where('type', isEqualTo: 'CREDIT');
    } else if (currentTransFilter.value == 'DEBIT') {
      query = query.where('type', isEqualTo: 'DEBIT');
    }

    return query.limit(_itemsPerPage);
  }

  // ===========================================================================
  // 3. WRITES (Add Vendor, Add/Edit/Delete Transaction)
  // ===========================================================================

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

  // Used by ShipmentController
  Future<void> addAutomatedShipmentCredit({
    required String vendorId,
    required double amount,
    required String shipmentName,
    required DateTime date,
  }) async {
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();
      WriteBatch batch = _firestore.batch();

      batch.update(vendorRef, {'totalDue': FieldValue.increment(amount)});
      batch.set(historyRef, {
        'type': 'CREDIT',
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'paymentMethod': 'Stock Receive',
        'shipmentName': shipmentName,
        'cartons': 'N/A',
        'notes': 'Auto-entry from Shipment: $shipmentName',
        'isIncomingCash': false,
      });

      await batch.commit();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);
    } catch (e) {
      throw "Vendor Credit Failed: $e";
    }
  }

  // 1. UPDATED: Add Transaction (Now handles specific withdrawals)
  Future<void> addTransaction({
    required String vendorId,
    required String vendorName,
    required String type, // 'CREDIT' (Bill) or 'DEBIT' (Payment)
    required double amount,
    required DateTime date,
    String? paymentMethod, // 'Cash', 'Bank', 'Bkash', 'Nagad'
    String? shipmentName,
    String? cartons,
    String? notes,
    bool isIncomingCash = false, // True if vendor refunds us (Advance)
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();
      WriteBatch batch = _firestore.batch();

      // --- 1. Calculate Vendor Balance Impact ---
      // CREDIT (Purchase) -> Positive Impact (We owe more)
      // DEBIT (Payment) -> Negative Impact (We owe less)
      // Incoming Cash -> Positive Impact (We owe more/They owe less)
      double amountChange = 0.0;
      if (isIncomingCash) {
        amountChange = amount;
      } else if (type == 'CREDIT') {
        amountChange = amount;
      } else {
        amountChange = -amount;
      }

      batch.update(vendorRef, {'totalDue': FieldValue.increment(amountChange)});
      batch.set(historyRef, {
        'type': isIncomingCash ? 'CREDIT' : type,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
        'shipmentName': shipmentName,
        'cartons': cartons,
        'notes': notes,
        'isIncomingCash': isIncomingCash,
      });

      await batch.commit();

      // --- 2. Side Effects (Cash/Bank Ledger Integration) ---

      // CASE A: Vendor gives us money (Refund/Advance) -> DEPOSIT
      if (isIncomingCash) {
        await _ensureCashLedgerEntry(
          type: 'deposit',
          amount: amount,
          method: paymentMethod ?? 'Cash',
          desc: "Advance/Refund from Vendor: $vendorName",
          date: date,
        );
      }
      // CASE B: We pay the Vendor (DEBIT) -> WITHDRAWAL
      // This fixes the issue: We specify the method so it deducts from Bank/Bkash directly
      else if (type == 'DEBIT') {
        await _ensureCashLedgerEntry(
          type: 'withdraw',
          amount: amount,
          method: paymentMethod ?? 'Cash',
          desc: "Payment to $vendorName ($notes)",
          date: date,
        );
      }
      // CASE C: We receive a Bill (CREDIT) -> No Cash Movement, just liability increase.

      if (Get.isDialogOpen ?? false) Get.back();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);

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

  // 2. UPDATED: Helper to write to cash_ledger
  // Now accepts 'type' (deposit/withdraw) and 'date' for back-dating consistency
  Future<void> _ensureCashLedgerEntry({
    required String type, // 'deposit' or 'withdraw'
    required double amount,
    required String method,
    required String desc,
    required DateTime date,
  }) async {
    try {
      await _firestore.collection('cash_ledger').add({
        'type': type,
        'amount': amount,
        'method': method,
        'description': desc,
        // Use the actual transaction date so reports match the back-dated entry
        'timestamp': Timestamp.fromDate(date),
        'source': 'vendor_transaction',
      });
    } catch (e) {
      debugPrint("Cash Ledger Error: $e");
    }
  }

  // --- NEW: DELETE TRANSACTION ---
  // Reverses the financial impact and removes the record
  Future<void> deleteTransaction(
    String vendorId,
    VendorTransaction trans,
  ) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc(trans.id);

      WriteBatch batch = _firestore.batch();

      // Calculate Reverse Amount
      // If we deleted a CREDIT (Purchase 100) -> We owe 100 less. (increment -100)
      // If we deleted a DEBIT (Payment 100) -> We owe 100 more. (increment +100)
      double reverseAmount = 0.0;

      if (trans.type == 'CREDIT') {
        reverseAmount = -trans.amount;
      } else {
        // Debit
        reverseAmount = trans.amount;
      }

      batch.delete(historyRef);
      batch.update(vendorRef, {
        'totalDue': FieldValue.increment(reverseAmount),
      });

      await batch.commit();

      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);
      Get.back(); // Close dialog if open
      Get.snackbar(
        "Success",
        "Transaction Deleted",
        backgroundColor: Colors.grey,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Delete Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- NEW: EDIT TRANSACTION ---
  // Updates amount/date/notes and adjusts balance based on amount difference
  Future<void> updateTransaction({
    required String vendorId,
    required VendorTransaction oldTrans,
    required double newAmount,
    required DateTime newDate,
    required String newNotes,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc(oldTrans.id);

      WriteBatch batch = _firestore.batch();

      // Calculate Balance Adjustment
      double balanceAdjustment = 0.0;

      if (oldTrans.type == 'CREDIT') {
        // Credit: Positive Impact on Due.
        // New 120 - Old 100 = +20. (We owe 20 more)
        // New 80 - Old 100 = -20. (We owe 20 less)
        balanceAdjustment = newAmount - oldTrans.amount;
      } else {
        // Debit: Negative Impact on Due.
        // New 120 (Paid More) - Old 100 = +20 diff in payment.
        // Since payment reduces due, we subtract the difference.
        // -(120 - 100) = -20. (We owe 20 less because we paid more)
        balanceAdjustment = -(newAmount - oldTrans.amount);
      }

      batch.update(historyRef, {
        'amount': newAmount,
        'date': Timestamp.fromDate(newDate),
        'notes': newNotes,
      });

      // Only touch main balance if amount actually changed
      if (balanceAdjustment != 0.0) {
        batch.update(vendorRef, {
          'totalDue': FieldValue.increment(balanceAdjustment),
        });
      }

      await batch.commit();

      if (Get.isDialogOpen ?? false) Get.back();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);

      Get.snackbar(
        "Success",
        "Transaction Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Update Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
