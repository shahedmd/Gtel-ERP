// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Profit&loss/controller.dart';
import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Cash/controller.dart';
import '../Sales/controller.dart';
import 'model.dart';

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // --- DATA LISTS ---
  var bodies = <DebtorModel>[].obs; // The list displayed on screen

  // --- LOADING STATES ---
  RxBool isBodiesLoading = false.obs;
  RxBool isSearching = false.obs;

  // --- PAGINATION STATE ---
  final int _limit = 20; // Items per page

  // This list keeps track of the 'startAfter' document for every page.
  // Index 0 = Page 1 (starts after null), Index 1 = Page 2 (starts after Doc A), etc.
  List<DocumentSnapshot?> pageCursors = [null];

  RxInt currentPage = 1.obs;
  RxBool hasMore = true.obs; // Can we go forward?

  // --- MARKET TOTALS ---
  var totalMarketOutstanding = 0.0.obs;
  var totalMarketPayable = 0.0.obs;

  // --- OBSERVABLES ---
  var filteredBodies = <DebtorModel>[].obs;

  // Global Market Debt (Receivable)
  // Global Market Payable (We owe them)

  RxBool gbIsLoading = false.obs;
  RxBool isAddingBody = false.obs;

  // --- PAGINATION STATE ---
  DocumentSnapshot? _lastDocument;
  final RxBool isMoreLoading = false.obs;

  // --- TRANSACTIONS STATE ---
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  DocumentSnapshot? _lastTxDoc;
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20;

  // --- FILTERS ---
  Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void onInit() {
    super.onInit();
    _silentAutoRepair();
    loadPage(1); // Load Page 1 initially
    loadBodies();
    calculateTotalOutstanding();
  }

  void nextPage() {
    if (!hasMore.value) return;
    loadPage(currentPage.value + 1);
  }

  void prevPage() {
    if (currentPage.value <= 1) return;
    loadPage(currentPage.value - 1);
  }

  // =========================================================
  // 2. SERVER-SIDE SEARCH LOGIC
  // =========================================================

  Future<void> runServerSearch(String queryText) async {
    if (queryText.trim().isEmpty) {
      // If search is cleared, reload the current page of the main list
      loadPage(currentPage.value);
      return;
    }

    isBodiesLoading.value = true;
    isSearching.value =
        true; // Mark as search mode (disables pagination buttons)

    try {
      // NOTE: Firestore text search is case-sensitive and prefix-based.
      // "Rahim" matches "Rah", but "rahim" does not match "Rah".
      // Searching by multiple fields (Phone OR Name) requires multiple queries in Firestore.

      String term = queryText.trim();

      // 1. Try finding by Name (Prefix search)
      // This looks for names starting with the query term
      QuerySnapshot nameSnap =
          await db
              .collection('debatorbody')
              .where('name', isGreaterThanOrEqualTo: term)
              .where('name', isLessThan: '$term\uf8ff')
              .limit(20)
              .get();

      // 2. Try finding by Phone (Exact match usually, or prefix)
      // Note: If you want prefix search on phone, use the same logic as name
      QuerySnapshot phoneSnap =
          await db
              .collection('debatorbody')
              .where('phone', isEqualTo: term)
              .get();

      // Merge results (removing duplicates based on ID)
      Map<String, DebtorModel> results = {};

      for (var doc in nameSnap.docs) {
        var m = DebtorModel.fromFirestore(doc);
        results[m.id] = m;
      }
      for (var doc in phoneSnap.docs) {
        var m = DebtorModel.fromFirestore(doc);
        results[m.id] = m;
      }

      bodies.value = results.values.toList();

      // In search mode, pagination doesn't apply the same way
      hasMore.value = false;
    } catch (e) {
      Get.snackbar("Search Error", e.toString());
      bodies.clear();
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> calculateTotalOutstanding() async {
    try {
      // Note: This still requires reading all docs if you want an exact market total.
      // If you have thousands of debtors, consider running this via a Cloud Function
      // or maintaining a separate aggregation document.
      final snap = await db.collection('debatorbody').get();
      double totalRec = 0;
      double totalPay = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        totalRec += (data['balance'] as num?)?.toDouble() ?? 0.0;
        totalPay += (data['purchaseDue'] as num?)?.toDouble() ?? 0.0;
      }
      totalMarketOutstanding.value = totalRec;
      totalMarketPayable.value = totalPay;
    } catch (e) {
      print("Calc Error: $e");
    }
  }

  Stream<double> getLiveBalance(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  Future<void> loadPage(int pageIndex) async {
    // Safety check
    if (pageIndex < 1) return;
    if (pageIndex > pageCursors.length) return;

    isBodiesLoading.value = true;
    isSearching.value = false; // Disable search mode

    try {
      Query query = db
          .collection('debatorbody')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      // Get the cursor for this page.
      // Page 1 cursor is at index 0 (null).
      // Page 2 cursor is at index 1 (the last doc of page 1).
      DocumentSnapshot? startAfterDoc = pageCursors[pageIndex - 1];

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      if (snap.docs.isNotEmpty) {
        bodies.value =
            snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();

        // Determine if we have more data for a NEXT page
        if (snap.docs.length < _limit) {
          hasMore.value = false;
        } else {
          hasMore.value = true;
          // If we are on the furthest page reached so far, save the cursor for the next page
          if (pageCursors.length <= pageIndex) {
            pageCursors.add(snap.docs.last);
          } else {
            // Update existing cursor just in case
            pageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentPage.value = pageIndex;
      } else {
        // No data found for this page (shouldn't happen via buttons, but safe to handle)
        if (pageIndex == 1) bodies.clear();
        hasMore.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load page: $e");
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> loadBodies({bool loadMore = false}) async {
    if (loadMore) {
      if (isMoreLoading.value || !hasMore.value) return;
      isMoreLoading.value = true;
    } else {
      isBodiesLoading.value = true;
      _lastDocument = null;
      hasMore.value = true;
    }

    try {
      Query query = db
          .collection('debatorbody')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();

      if (snap.docs.length < _limit) hasMore.value = false;

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
        List<DebtorModel> newBodies =
            snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();

        if (loadMore) {
          bodies.addAll(newBodies);
        } else {
          bodies.value = newBodies;
        }
      } else {
        if (!loadMore) bodies.clear();
      }

      calculateTotalOutstanding();
      searchDebtors('');
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
      print(e);
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  // --- UPDATED: PRECISE BREAKDOWN LOGIC ---
  Future<Map<String, double>> getInstantDebtorBreakdown(String debtorId) async {
    try {
      final snap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();

      double oldDueTotal = 0.0; // From 'previous_due'
      double oldDuePaid = 0.0; // From 'loan_payment'

      double runningSales = 0.0; // From 'credit' (Invoices)
      double runningPaid = 0.0; // From 'debit' (Invoice Payments)

      for (var doc in snap.docs) {
        final data = doc.data();
        String type = (data['type'] ?? '').toString();
        double amount = (data['amount'] as num).toDouble();

        if (type == 'previous_due') {
          oldDueTotal += amount;
        } else if (type == 'loan_payment') {
          oldDuePaid += amount;
        } else if (type == 'credit' || type == 'advance_given') {
          runningSales += amount;
        } else if (type == 'debit' || type == 'advance_received') {
          runningPaid += amount;
        }
      }

      // Logic: Loan payments strictly reduce Old Due.
      // If Loan Paid > Loan Total, the excess helps cover running sales (safeguard)
      double currentLoan = oldDueTotal - oldDuePaid;
      if (currentLoan < 0) {
        runningPaid += currentLoan.abs();
        currentLoan = 0;
      }

      double runningDue = runningSales - runningPaid;

      return {
        'loan': currentLoan, // Strict Old Due
        'running': runningDue, // Strict Running Due
        'total': currentLoan + runningDue,
      };
    } catch (e) {
      print("Breakdown Error: $e");
      return {'loan': 0.0, 'running': 0.0, 'total': 0.0};
    }
  }

  // --- STREAM BREAKDOWN ---
  Stream<Map<String, double>> getDebtorBreakdown(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .collection('transactions')
        .snapshots()
        .map((snap) {
          double oldDueTotal = 0.0;
          double oldDuePaid = 0.0;
          double runningSales = 0.0;
          double runningPaid = 0.0;

          for (var doc in snap.docs) {
            final data = doc.data();
            String type = (data['type'] ?? '').toString();
            double amount = (data['amount'] as num).toDouble();

            if (type == 'previous_due') {
              oldDueTotal += amount;
            } else if (type == 'loan_payment') {
              oldDuePaid += amount;
            } else if (type == 'credit' || type == 'advance_given') {
              runningSales += amount;
            } else if (type == 'debit' || type == 'advance_received') {
              runningPaid += amount;
            }
          }
          double currentLoan = oldDueTotal - oldDuePaid;
          if (currentLoan < 0) {
            runningPaid += currentLoan.abs();
            currentLoan = 0;
          }
          return {
            'loan': currentLoan,
            'running': runningSales - runningPaid,
            'total': currentLoan + (runningSales - runningPaid),
          };
        });
  }

  // ------------------------------------------------------------------
  // 2. TRANSACTION LOGIC
  // ------------------------------------------------------------------

  void clearTransactionState() {
    currentTransactions.clear();
    _lastTxDoc = null;
    hasMoreTx.value = true;
    isTxLoading.value = false;
    selectedDateRange.value = null;
  }

  void setDateFilter(DateTimeRange? range, String debtorId) {
    selectedDateRange.value = range;
    _lastTxDoc = null;
    hasMoreTx.value = true;
    loadDebtorTransactions(debtorId, loadMore: false);
  }

  Future<void> loadDebtorTransactions(
    String debtorId, {
    bool loadMore = false,
  }) async {
    if (!loadMore) {
      _recalculateSingleDebtorBalance(debtorId);
    }

    if (loadMore) {
      if (isTxLoading.value || !hasMoreTx.value) return;
    } else {
      if (!loadMore) {
        currentTransactions.clear();
        _lastTxDoc = null;
        hasMoreTx.value = true;
      }
      isTxLoading.value = true;
    }

    try {
      Query query = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .orderBy('date', descending: true);

      if (selectedDateRange.value != null) {
        query = query
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                selectedDateRange.value!.start,
              ),
            )
            .where(
              'date',
              isLessThanOrEqualTo: Timestamp.fromDate(
                selectedDateRange.value!.end,
              ),
            );
      }

      query = query.limit(_txLimit);

      if (loadMore && _lastTxDoc != null) {
        query = query.startAfterDocument(_lastTxDoc!);
      }

      final snap = await query.get();

      if (snap.docs.length < _txLimit) hasMoreTx.value = false;

      if (snap.docs.isNotEmpty) {
        _lastTxDoc = snap.docs.last;
        final newTx =
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
        if (loadMore) {
          currentTransactions.addAll(newTx);
        } else {
          currentTransactions.assignAll(newTx);
        }
      } else {
        if (!loadMore) hasMoreTx.value = false;
      }
    } catch (e) {
      print("Error loading transactions: $e");
    } finally {
      isTxLoading.value = false;
    }
  }

  Future<void> _recalculateSingleDebtorBalance(String debtorId) async {
    try {
      // Use the strict breakdown logic for the main balance update
      final breakdown = await getInstantDebtorBreakdown(debtorId);

      await db.collection('debatorbody').doc(debtorId).update({
        'balance': breakdown['total'],
        'lastTransactionDate': FieldValue.serverTimestamp(),
      });
      calculateTotalOutstanding();
    } catch (e) {
      print("Auto-Fix Error: $e");
    }
  }

  Future<void> addTransaction({
    required String debtorId,
    required double amount,
    required String note,
    required String type,
    required DateTime date, // <--- Ensure this is FEB 7 (Collection Date)
    required Map<String, dynamic> paymentMethodData,
    String? txid,
  }) async {
    gbIsLoading.value = true;
    try {
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      DocumentReference newTxRef = debtorRef.collection('transactions').doc();
      if (txid != null && txid.isNotEmpty) {
        newTxRef = debtorRef.collection('transactions').doc(txid);
      }
      String finalTxId = newTxRef.id;

      // 1. Save Transaction (History)
      await newTxRef.set({
        'transactionId': finalTxId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date), // FEB 7
        'paymentMethod': paymentMethodData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to CASH LEDGER (This makes it show up on FEB 7)
      if (type == 'debit' ||
          type == 'loan_payment' ||
          type == 'advance_received') {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': paymentMethodData['type'] ?? 'cash',
          'details': paymentMethodData,
          'description': "Collection from $debtorName",
          'timestamp': Timestamp.fromDate(date), // FEB 7
          'linkedDebtorId': debtorId,
          'linkedTxId': finalTxId,
          'source': 'debtor_collection',
        });
      } else if (type == 'advance_given') {
        await db.collection('cash_ledger').add({
          'type': 'withdraw',
          'amount': amount,
          'method': 'cash',
          'description': "Given to $debtorName",
          'timestamp': Timestamp.fromDate(date),
          'linkedDebtorId': debtorId,
          'source': 'debtor_payment',
        });
      }

      // 3. Update Old Bills (Prevents Double Entry on FEB 6)
      if (type == 'debit') {
        double remaining = amount;

        // Find unpaid bills
        QuerySnapshot pendingSnap =
            await db
                .collection('daily_sales')
                .where('customerType', isEqualTo: 'debtor')
                .where('name', isEqualTo: debtorName)
                .where('pending', isGreaterThan: 0)
                .orderBy('pending')
                .get();

        List<DocumentSnapshot> sortedDocs = pendingSnap.docs.toList();
        sortedDocs.sort(
          (a, b) => (a['timestamp'] as Timestamp).compareTo(
            b['timestamp'] as Timestamp,
          ),
        );

        WriteBatch batch = db.batch();

        for (var doc in sortedDocs) {
          if (remaining <= 0) break;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          double currentPending =
              double.tryParse(data['pending'].toString()) ?? 0.0;
          double currentPaid = double.tryParse(data['paid'].toString()) ?? 0.0;
          double currentLedgerPaid =
              double.tryParse(data['ledgerPaid']?.toString() ?? '0') ?? 0.0;

          double take =
              (remaining >= currentPending) ? currentPending : remaining;

          // Update FEB 6 Document
          batch.update(doc.reference, {
            "paid": currentPaid + take,
            "pending": currentPending - take,
            "ledgerPaid": currentLedgerPaid + take, // <--- CRITICAL
            "status": (currentPending - take) <= 0.5 ? "paid" : "partial",
          });

          // Update Master Sales Order
          String saleTxId = data['transactionId'] ?? '';
          if (saleTxId.isNotEmpty) {
            QuerySnapshot orderSnap =
                await db
                    .collection('sales_orders')
                    .where('transactionId', isEqualTo: saleTxId)
                    .limit(1)
                    .get();
            if (orderSnap.docs.isNotEmpty) {
              double oPaid =
                  double.tryParse(orderSnap.docs.first['paid'].toString()) ??
                  0.0;
              batch.update(orderSnap.docs.first.reference, {
                "paid": oPaid + take,
                "due": (currentPending - take),
                "status":
                    (currentPending - take) <= 0.5 ? "completed" : "pending",
              });
            }
          }
          remaining -= take;
        }
        await batch.commit();
      }

      // 4. *** FORCE REFRESH ALL CONTROLLERS ***
      // This is why you were stuck. The other controllers didn't know data changed.

      await _recalculateSingleDebtorBalance(debtorId);
      await loadBodies(loadMore: false);

      if (Get.isRegistered<DailySalesController>()) {
        await Get.find<DailySalesController>()
            .loadDailySales(); // RELOAD SALES LIST
      }

      if (Get.isRegistered<CashDrawerController>()) {
        Get.find<CashDrawerController>().fetchData();
      }

      if (Get.isRegistered<OverviewController>()) {
        Get.find<OverviewController>().refreshData(); // RELOAD OVERVIEW
      }

      if (Get.isRegistered<ProfitController>()) {
        Get.find<ProfitController>().refreshData();
      }

      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Success", "Transaction Recorded & Controllers Refreshed");
    } catch (e) {
      Get.snackbar("Error", e.toString());
      print(e);
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // DELETE & EDIT
  // ------------------------------------------------------------------

  Future<void> deleteTransaction(String debtorId, String transactionId) async {
    gbIsLoading.value = true;
    try {
      DocumentSnapshot txSnap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc(transactionId)
              .get();
      if (!txSnap.exists) {
        gbIsLoading.value = false;
        return;
      }
      String type = txSnap['type'];

      await db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId)
          .delete();

      // Cleanup Ledger
      if (type == 'loan_payment' || type.contains('advance')) {
        QuerySnapshot lSnap =
            await db
                .collection('cash_ledger')
                .where('linkedTxId', isEqualTo: transactionId)
                .get();
        for (var doc in lSnap.docs) {
          await doc.reference.delete();
        }
      }

      // Cleanup Sales
      if (type == 'credit' || type == 'debit') {
        if (!Get.isRegistered<DailySalesController>()) {
          Get.put(DailySalesController());
        }
        final daily = Get.find<DailySalesController>();
        final debtorSnap =
            await db.collection('debatorbody').doc(debtorId).get();
        final debtorName = debtorSnap.data()?['name'] ?? "";
        final salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();
        final batch = db.batch();

        for (final doc in salesSnap.docs) {
          final data = doc.data();
          if (data['transactionId'] == transactionId) {
            batch.delete(doc.reference);
          } else {
            List applied = List.from(data['appliedDebits'] ?? []);
            if (applied.any((e) => e['id'] == transactionId)) {
              final entry = applied.firstWhere((e) => e['id'] == transactionId);
              double used = (entry['amount'] as num).toDouble();
              double paid = (data['paid'] as num).toDouble();
              applied.removeWhere((e) => e['id'] == transactionId);
              batch.update(doc.reference, {
                'paid': (paid - used).clamp(0, double.infinity),
                'appliedDebits': applied,
              });
            }
          }
        }
        await batch.commit();
        await daily.loadDailySales();
      }

      await _recalculateSingleDebtorBalance(debtorId);
      loadDebtorTransactions(debtorId);
      loadBodies();

      Get.snackbar("Deleted", "Transaction removed & Balance corrected");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> editTransaction({
    required String debtorId,
    required String transactionId,
    required double oldAmount,
    required double newAmount,
    required String oldType,
    required String newType,
    required String note,
    required DateTime date,
    required Map<String, dynamic> paymentMethod,
  }) async {
    gbIsLoading.value = true;
    try {
      await db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId)
          .update({
            'amount': newAmount,
            'type': newType,
            'note': note,
            'date': Timestamp.fromDate(date),
            'paymentMethod': paymentMethod,
          });

      await _recalculateSingleDebtorBalance(debtorId);

      if (oldType == 'loan_payment' || oldType.contains('advance')) {
        QuerySnapshot lSnap =
            await db
                .collection('cash_ledger')
                .where('linkedTxId', isEqualTo: transactionId)
                .get();
        for (var d in lSnap.docs) {
          await d.reference.update({
            'amount': newAmount,
            'details': paymentMethod,
            'method': paymentMethod['type'],
          });
        }
      }

      loadDebtorTransactions(debtorId);
      loadBodies();
      Get.back();
      Get.snackbar("Success", "Updated successfully");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }



  Future<void> addBody({
    required String name,
    required String des,
    required String nid,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> payments,
  }) async {
    isAddingBody.value = true;
    try {
      await db.collection('debatorbody').add({
        "name": name.trim(),
        "des": des,
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
        "payments": payments,
        "balance": 0.0,
        "purchaseDue": 0.0,
        "createdAt": FieldValue.serverTimestamp(),
        "lastTransactionDate": FieldValue.serverTimestamp(),
      });
      await loadBodies(loadMore: false);
      Get.back();
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isAddingBody.value = false;
    }
  }

  Future<void> editDebtor({
    required String id,
    required String oldName,
    required String newName,
    required String des,
    required String nid,
    required String phone,
    required String address,
    List<Map<String, dynamic>>? payments,
  }) async {
    gbIsLoading.value = true;
    try {
      Map<String, dynamic> updateData = {
        "name": newName.trim(),
        "des": des,
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
      };

      if (payments != null) {
        updateData["payments"] = payments;
      }

      await db.collection('debatorbody').doc(id).update(updateData);

      if (oldName != newName) {
        final snap =
            await db
                .collection('daily_sales')
                .where('customerType', isEqualTo: 'debtor')
                .where('name', isEqualTo: oldName)
                .get();
        final batch = db.batch();
        for (var doc in snap.docs) {
          batch.update(doc.reference, {"name": newName.trim()});
        }
        await batch.commit();
      }

      await loadBodies(loadMore: false);
      Get.back();
      Get.snackbar("Success", "Debtor profile updated");
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 4. HELPER & PDF
  // ------------------------------------------------------------------

  Future<void> _silentAutoRepair() async {
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      bool needsUpdate = false;
      for (var doc in snap.docs) {
        if (!doc.data().containsKey('balance') ||
            !doc.data().containsKey('purchaseDue')) {
          needsUpdate = true;
          batch.update(doc.reference, {
            if (!doc.data().containsKey('balance')) 'balance': 0.0,
            if (!doc.data().containsKey('purchaseDue')) 'purchaseDue': 0.0,
          });
        }
      }
      if (needsUpdate) await batch.commit();
    } catch (e) {
      print(e);
    }
  }


  void searchDebtors(String query) {
    if (query.trim().isEmpty) {
      filteredBodies.assignAll(bodies);
      return;
    }
    final q = query.toLowerCase();
    filteredBodies.assignAll(
      bodies
          .where(
            (d) =>
                d.name.toLowerCase().contains(q) ||
                d.phone.contains(q) ||
                d.nid.contains(q) ||
                d.address.toLowerCase().contains(q),
          )
          .toList(),
    );
  }



  Future<Uint8List> generatePDF(
    String debtorName,
    List<Map<String, dynamic>> transactions,
  ) async {
    final pdf = pw.Document();

    double totalDebt = transactions
        .where(
          (t) =>
              t['type'] == 'credit' ||
              t['type'] == 'advance_given' ||
              t['type'] == 'previous_due',
        )
        .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    double totalPaid = transactions
        .where(
          (t) =>
              t['type'] == 'debit' ||
              t['type'] == 'advance_received' ||
              t['type'] == 'loan_payment',
        )
        .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "STATEMENT OF ACCOUNT",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Debtor: $debtorName",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStat("Total Debt Taken", totalDebt, PdfColors.black),
                  _pdfStat("Total Paid / Adv", totalPaid, PdfColors.green900),
                  _pdfStat(
                    "Net Balance",
                    totalDebt - totalPaid,
                    PdfColors.red900,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ["Date", "Type", "Note", "Method", "Amount"],
                data:
                    transactions.map((t) {
                      String method = "Cash";
                      if (t['paymentMethod'] != null &&
                          t['paymentMethod'] is Map) {
                        method =
                            (t['paymentMethod']['type'] ?? 'Cash')
                                .toString()
                                .toUpperCase();
                      }
                      return [
                        DateFormat('dd/MM/yy').format(
                          (t['date'] is DateTime
                              ? t['date']
                              : (t['date'] as Timestamp).toDate()),
                        ),
                        t['type'].toString().toUpperCase().replaceAll('_', ' '),
                        t['note'] ?? "",
                        method,
                        bdCurrency.format((t['amount'] as num)),
                      ];
                    }).toList(),
              ),
            ],
      ),
    );
    return pdf.save();
  }

  Future<void> downloadAllDebtorsReport() async {
    await _generateGeneralReport(title: "MARKET DUE REPORT", isPayable: false);
  }

  Future<void> downloadAllPayablesReport() async {
    await _generateGeneralReport(
      title: "MARKET PAYABLE REPORT",
      isPayable: true,
    );
  }

  Future<void> _generateGeneralReport({
    required String title,
    required bool isPayable,
  }) async {
    try {
      gbIsLoading.value = true;
      Get.snackbar("Preparing", "Generating report...");

      final snap = await db.collection('debatorbody').get();
      final allDebtors =
          snap.docs
              .map((d) {
                try {
                  return DebtorModel.fromFirestore(d);
                } catch (e) {
                  return null;
                }
              })
              .whereType<DebtorModel>()
              .toList();

      final targetDebtors =
          allDebtors
              .where((d) => isPayable ? (d.purchaseDue > 0) : (d.balance > 0))
              .toList();

      if (targetDebtors.isEmpty) {
        gbIsLoading.value = false;
        Get.snackbar("Info", "No data to print.");
        return;
      }

      targetDebtors.sort(
        (a, b) =>
            isPayable
                ? b.purchaseDue.compareTo(a.purchaseDue)
                : b.balance.compareTo(a.balance),
      );

      double grandTotal = 0.0;
      for (var d in targetDebtors) {
        grandTotal += isPayable ? d.purchaseDue : d.balance;
      }

      final pdf = pw.Document();
      const int rowsPerPage = 20;
      final int totalPages = (targetDebtors.length / rowsPerPage).ceil();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header:
              (context) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                    ],
                  ),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              ),
          build: (context) {
            List<pw.Widget> widgets = [];
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TOTAL AMOUNT",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "${bdCurrency.format(grandTotal)} BDT",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 15));

            for (int i = 0; i < totalPages; i++) {
              int start = i * rowsPerPage;
              int end =
                  (start + rowsPerPage < targetDebtors.length)
                      ? start + rowsPerPage
                      : targetDebtors.length;
              var chunk = targetDebtors.sublist(start, end);

              widgets.add(
                pw.Table.fromTextArray(
                  context: context,
                  border: null,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  headerHeight: 25,
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                  },
                  headers: ["SL", "Name", "Phone", "Amount"],
                  data: List<List<String>>.generate(chunk.length, (idx) {
                    final d = chunk[idx];
                    double val = isPayable ? d.purchaseDue : d.balance;
                    return [
                      "${start + idx + 1}",
                      d.name,
                      d.phone,
                      bdCurrency.format(val),
                    ];
                  }),
                ),
              );
              if (i < totalPages - 1) widgets.add(pw.NewPage());
            }
            return widgets;
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Error generating PDF: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  pw.Widget _pdfStat(String label, double val, PdfColor col) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          bdCurrency.format(val),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: col,
          ),
        ),
      ],
    );
  }
}
