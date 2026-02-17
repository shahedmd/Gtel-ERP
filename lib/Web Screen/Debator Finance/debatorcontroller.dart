// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  var bodies = <DebtorModel>[].obs;

  // --- LOADING STATES ---
  RxBool isBodiesLoading = false.obs;
  RxBool isSearching = false.obs;

  // --- PAGINATION STATE ---
  final int _limit = 20;
  List<DocumentSnapshot?> pageCursors = [null];
  RxInt currentPage = 1.obs;
  RxBool hasMore = true.obs;

  // --- MARKET TOTALS ---
  var totalMarketOutstanding = 0.0.obs;
  var totalMarketPayable = 0.0.obs;

  // --- OBSERVABLES ---
  var filteredBodies = <DebtorModel>[].obs;
  RxBool gbIsLoading = false.obs;
  RxBool isAddingBody = false.obs;

  // --- PAGINATION STATE (INTERNAL) ---
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
    loadPage(1);
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
  // 1. SEARCH & LOAD LOGIC
  // =========================================================

  Future<void> runServerSearch(String queryText) async {
    if (queryText.trim().isEmpty) {
      loadPage(currentPage.value);
      return;
    }

    isBodiesLoading.value = true;
    isSearching.value = true;

    try {
      String term = queryText.trim();

      QuerySnapshot nameSnap =
          await db
              .collection('debatorbody')
              .where('name', isGreaterThanOrEqualTo: term)
              .where('name', isLessThan: '$term\uf8ff')
              .limit(20)
              .get();

      QuerySnapshot phoneSnap =
          await db
              .collection('debatorbody')
              .where('phone', isEqualTo: term)
              .get();

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
    if (pageIndex < 1) return;
    if (pageIndex > pageCursors.length) return;

    isBodiesLoading.value = true;
    isSearching.value = false;

    try {
      Query query = db
          .collection('debatorbody')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      DocumentSnapshot? startAfterDoc = pageCursors[pageIndex - 1];

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      if (snap.docs.isNotEmpty) {
        bodies.value =
            snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();

        if (snap.docs.length < _limit) {
          hasMore.value = false;
        } else {
          hasMore.value = true;
          if (pageCursors.length <= pageIndex) {
            pageCursors.add(snap.docs.last);
          } else {
            pageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentPage.value = pageIndex;
      } else {
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
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  // --- BREAKDOWN LOGIC ---
  Future<Map<String, double>> getInstantDebtorBreakdown(String debtorId) async {
    try {
      final snap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();

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

      double runningDue = runningSales - runningPaid;

      return {
        'loan': currentLoan,
        'running': runningDue,
        'total': currentLoan + runningDue,
      };
    } catch (e) {
      print("Breakdown Error: $e");
      return {'loan': 0.0, 'running': 0.0, 'total': 0.0};
    }
  }

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

  // =========================================================
  // 2. TRANSACTION LOGIC
  // =========================================================

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
    required DateTime date,
    required Map<String, dynamic> paymentMethodData,
    String? txid,
  }) async {
    gbIsLoading.value = true;
    try {
      // 1. GET DEBTOR INFO
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      // 2. SAVE TRANSACTION (History)
      DocumentReference newTxRef =
          (txid != null && txid.isNotEmpty)
              ? debtorRef.collection('transactions').doc(txid)
              : debtorRef.collection('transactions').doc();
      String finalTxId = newTxRef.id;

      await newTxRef.set({
        'transactionId': finalTxId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethodData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. CASH LEDGER ENTRY
      bool isCollection = [
        'debit',
        'loan_payment',
        'advance_received',
        'collection',
        'payment',
        'received',
      ].contains(type.toLowerCase());

      if (isCollection) {
        String method = (paymentMethodData['type'] ?? 'cash').toString();
        if (method.toLowerCase() == 'cash' &&
            paymentMethodData.containsKey('bankName')) {
          method = 'Bank';
        } else if (method.toLowerCase() == 'cash' &&
            paymentMethodData.containsKey('bkashNumber')) {
          method = 'Bkash';
        }

        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': method,
          'details': paymentMethodData,
          'description': "Collection from $debtorName",
          'timestamp': Timestamp.fromDate(date),
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

      // =================================================================
      // 4. FIX: UPDATE BILLS (WORKS FOR AGENT OR DEBTOR)
      // =================================================================
      if (isCollection) {
        double remainingToAllocate = amount;

        // QUERY BY NAME ONLY.
        // This ensures it catches "agent", "debtor", or any other type.
        QuerySnapshot salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();

        // Filter for UNPAID bills in Memory (Dart)
        // We check if pending is greater than 0.5 to avoid tiny decimal errors
        List<DocumentSnapshot> pendingBills =
            salesSnap.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double p = double.tryParse(data['pending'].toString()) ?? 0.0;
              return p > 0.5;
            }).toList();

        // Sort: OLDEST FIRST (FIFO) - Pay the oldest bill first
        pendingBills.sort((a, b) {
          Timestamp t1 = a['timestamp'] as Timestamp;
          Timestamp t2 = b['timestamp'] as Timestamp;
          return t1.compareTo(t2);
        });

        if (pendingBills.isNotEmpty) {
          WriteBatch batch = db.batch();
          bool hasUpdates = false;

          for (var doc in pendingBills) {
            if (remainingToAllocate <= 0.01) break;

            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            double currentPending =
                double.tryParse(data['pending'].toString()) ?? 0.0;
            double currentPaid =
                double.tryParse(data['paid'].toString()) ?? 0.0;
            double currentLedgerPaid =
                double.tryParse(data['ledgerPaid']?.toString() ?? '0') ?? 0.0;

            // Calculate payment for this bill
            double take =
                (remainingToAllocate >= currentPending)
                    ? currentPending
                    : remainingToAllocate;

            // Create History Entry
            final newHistoryEntry = {
              'type': paymentMethodData['type'] ?? 'cash',
              'amount': take,
              'paidAt': Timestamp.now(),
              'sourceTxId': finalTxId,
            };

            // Update the bill
            batch.update(doc.reference, {
              "paid": currentPaid + take,
              "pending": currentPending - take,
              "ledgerPaid": currentLedgerPaid + take,
              "status": (currentPending - take) <= 0.5 ? "paid" : "partial",
              "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
            });
            hasUpdates = true;

            // Update Master Sales Order (if linked)
            String saleTxId = data['transactionId'] ?? '';
            if (saleTxId.isNotEmpty) {
              db
                  .collection('sales_orders')
                  .where('transactionId', isEqualTo: saleTxId)
                  .limit(1)
                  .get()
                  .then((orderSnap) {
                    if (orderSnap.docs.isNotEmpty) {
                      var oDoc = orderSnap.docs.first;
                      double oPaid =
                          double.tryParse(oDoc['paid'].toString()) ?? 0.0;
                      oDoc.reference.update({
                        "paid": oPaid + take,
                        "due": (currentPending - take),
                        "status":
                            (currentPending - take) <= 0.5
                                ? "completed"
                                : "pending",
                      });
                    }
                  });
            }

            remainingToAllocate -= take;
          }

          if (hasUpdates) {
            await batch.commit();
          }
        }
      }

      // 5. REFRESH CONTROLLERS
      await _recalculateSingleDebtorBalance(debtorId);
      await loadBodies(loadMore: false);

      if (Get.isRegistered<DailySalesController>()) {
        await Get.find<DailySalesController>().loadDailySales();
      }
      if (Get.isRegistered<OverviewController>()) {
        Get.find<OverviewController>().refreshData();
      }
      if (Get.isRegistered<CashDrawerController>()) {
        Get.find<CashDrawerController>().fetchData();
      }

      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Success", "Collection Recorded & Bills Updated");
    } catch (e) {
      Get.snackbar("Error", e.toString());
      print("Error: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  // --- DELETE TRANSACTION ---
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
      QuerySnapshot lSnap =
          await db
              .collection('cash_ledger')
              .where('linkedTxId', isEqualTo: transactionId)
              .get();
      for (var doc in lSnap.docs) {
        await doc.reference.delete();
      }

      // Cleanup Sales (Reverse payments)
      if (type == 'credit' ||
          type == 'debit' ||
          type == 'collection' ||
          type == 'payment') {
        if (!Get.isRegistered<DailySalesController>()) {
          Get.put(DailySalesController());
        }
        final daily = Get.find<DailySalesController>();
        final debtorSnap =
            await db.collection('debatorbody').doc(debtorId).get();
        final debtorName = debtorSnap.data()?['name'] ?? "";

        // Find sales paid by this transaction
        final salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();
        final batch = db.batch();

        for (final doc in salesSnap.docs) {
          final data = doc.data();
          // If this sales entry ITSELF was the transaction (unlikely here but possible)
          if (data['transactionId'] == transactionId) {
            batch.delete(doc.reference);
          } else {
            // Check payment history for this transaction ID linkage
            List history = List.from(data['paymentHistory'] ?? []);
            bool changed = false;
            double amountReversed = 0.0;

            history.removeWhere((h) {
              if (h['sourceTxId'] == transactionId) {
                amountReversed += (h['amount'] as num).toDouble();
                changed = true;
                return true;
              }
              return false;
            });

            if (changed) {
              double currentPaid = (data['paid'] as num).toDouble();
              double currentPending = (data['pending'] as num).toDouble();
              double newPaid = (currentPaid - amountReversed).clamp(
                0,
                double.infinity,
              );

              batch.update(doc.reference, {
                'paid': newPaid,
                'pending': currentPending + amountReversed,
                'paymentHistory': history,
                'status': 'partial', // Revert to partial/unpaid
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

      // Update Ledger
      QuerySnapshot lSnap =
          await db
              .collection('cash_ledger')
              .where('linkedTxId', isEqualTo: transactionId)
              .get();
      for (var d in lSnap.docs) {
        String method = (paymentMethod['type'] ?? 'cash').toString();
        if (method == 'cash' && paymentMethod.containsKey('bankName')) {
          method = 'Bank';
        }
        await d.reference.update({
          'amount': newAmount,
          'details': paymentMethod,
          'method': method,
          'bankName': paymentMethod['bankName'],
          'accountNo': paymentMethod['accountNumber'],
        });
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

  // Helper for PDF Payment Method Display
  String _formatMethodForPdf(dynamic pm) {
    if (pm == null) return "Cash";
    if (pm is String) return pm;
    if (pm is Map) {
      String type = (pm['type'] ?? 'Cash').toString();
      if (type.toLowerCase() == 'cash' && pm.containsKey('bankName')) {
        return "Bank: ${pm['bankName']}";
      }
      if (type.toLowerCase() == 'bank') return "Bank: ${pm['bankName'] ?? ''}";
      if (type.toLowerCase().contains('bkash')) return "Bkash";
      if (type.toLowerCase().contains('nagad')) return "Nagad";
      return type.toUpperCase();
    }
    return "Cash";
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
              t['type'] == 'loan_payment' ||
              t['type'] == 'collection',
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
                      return [
                        DateFormat('dd/MM/yy').format(
                          (t['date'] is DateTime
                              ? t['date']
                              : (t['date'] as Timestamp).toDate()),
                        ),
                        t['type'].toString().toUpperCase().replaceAll('_', ' '),
                        t['note'] ?? "",
                        _formatMethodForPdf(
                          t['paymentMethod'],
                        ), // Robust helper
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
