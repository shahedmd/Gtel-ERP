// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---

  // 1. Vendor List State (Stream + Client-Side Pagination)
  final RxList<VendorModel> _allVendors =
      <VendorModel>[].obs; // Stores ALL data from stream
  final RxList<VendorModel> vendors =
      <VendorModel>[].obs; // Stores only CURRENT PAGE data
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
  final RxString currentTransFilter = 'All'.obs; // 'All', 'CREDIT', 'DEBIT'

  // History Pagination Helpers
  DocumentSnapshot? _lastTransDoc;
  final List<DocumentSnapshot> _transPageStartDocs = [];
  final RxInt currentTransPage = 1.obs;
  final RxBool hasMoreTrans = true.obs;
  String? _activeVendorId; // To track which vendor is open

  StreamSubscription? _vendorSub;

  @override
  void onInit() {
    super.onInit();
    bindVendors(); // Restored your original stream
  }

  @override
  void onClose() {
    _vendorSub?.cancel();
    super.onClose();
  }

  // ===========================================================================
  // 1. VENDOR LOGIC (Restored Stream + Added Pagination)
  // ===========================================================================

  void bindVendors() {
    isLoading.value = true;
    _vendorSub = _firestore
        .collection('vendors')
        .orderBy('name')
        .snapshots()
        .listen(
          (event) {
            // 1. Save ALL data to internal list
            _allVendors.value =
                event.docs.map((e) => VendorModel.fromSnapshot(e)).toList();

            // 2. Refresh the visible page
            _refreshVendorPage();

            isLoading.value = false;
          },
          onError: (e) {
            isLoading.value = false;
            debugPrint("Vendor Stream Error: $e");
          },
        );
  }

  // Search Logic
  void searchVendors(String query) {
    searchQuery.value = query;
    currentVendorPage.value = 1; // Reset to page 1 on search
    _refreshVendorPage();
  }

  // Pagination Logic (Client Side - Instant)
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

  // Core function to slice the list based on page & search
  void _refreshVendorPage() {
    // A. Filter by Search
    List<VendorModel> filtered =
        _allVendors.where((v) {
          return v.name.toLowerCase().contains(searchQuery.value.toLowerCase());
        }).toList();

    // B. Calculate Pagination Indices
    int totalItems = filtered.length;
    int startIndex = (currentVendorPage.value - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    // C. Safety Check
    if (startIndex >= totalItems) {
      startIndex = 0;
      currentVendorPage.value = 1; // Reset if out of bounds
    }
    if (endIndex > totalItems) endIndex = totalItems;

    // D. Update Visible List
    vendors.value = filtered.sublist(startIndex, endIndex);

    // E. Update "Has More" Flag
    hasMoreVendors.value = endIndex < totalItems;
  }

  // ===========================================================================
  // 2. TRANSACTION HISTORY LOGIC (Server-Side Pagination)
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
      _transPageStartDocs.removeLast(); // Remove current
      DocumentSnapshot targetStartDoc =
          _transPageStartDocs.last; // Get previous

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
  // 3. WRITES (Add Vendor / Add Transaction)
  // ===========================================================================

  Future<void> addVendor(String name, String contact) async {
    try {
      await _firestore.collection('vendors').add({
        'name': name,
        'contact': contact,
        'totalDue': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Note: No need to manually refresh list, the bindVendors stream handles it!
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
      // Logic: Stream updates vendor balance automatically.
      // Logic: If user is on details page, we might want to refresh history
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);
    } catch (e) {
      throw "Vendor Credit Failed: $e";
    }
  }

  Future<void> addTransaction({
    required String vendorId,
    required String vendorName,
    required String type,
    required double amount,
    required DateTime date,
    String? paymentMethod,
    String? shipmentName,
    String? cartons,
    String? notes,
    bool isIncomingCash = false,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();
      WriteBatch batch = _firestore.batch();

      double amountChange = 0.0;
      if (isIncomingCash) {
        amountChange = amount; // Increases Liability (Due)
      } else if (type == 'CREDIT') {
        amountChange = amount; // Increases Liability (Due)
      } else {
        amountChange = -amount; // Decreases Liability (Paid)
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

      // Integration Hooks
      if (isIncomingCash) {
        await _ensureCashLedgerEntry(
          amount: amount,
          method: paymentMethod ?? 'cash',
          desc: "Advance/Refund from Vendor: $vendorName",
        );
      } else if (type == 'DEBIT') {
        _logToDailyExpenses(
          vendorName,
          amount,
          date,
          notes ?? "Vendor Payment",
        );
      }

      if (Get.isDialogOpen ?? false) Get.back();

      // Refresh History Table (Balance updates automatically via stream)
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

  // --- HELPERS ---
  Future<void> _ensureCashLedgerEntry({
    required double amount,
    required String method,
    required String desc,
  }) async {
    try {
      if (Get.isRegistered<CashDrawerController>()) {
        await Get.find<CashDrawerController>().addManualCash(
          amount: amount,
          method: method,
          desc: desc,
        );
      } else {
        await _firestore.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': method,
          'description': desc,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Cash Ledger Error: $e");
    }
  }

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