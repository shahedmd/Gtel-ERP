// ignore_for_file: empty_catches, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';
import 'package:gtel_erp/Cash/controller.dart';
import '../../Web Screen/Sales/controller.dart';
import 'debtordartmodel.dart';

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ==========================================
  // 1. STATE & VARIABLES
  // ==========================================
  final RxList<DebtorModel> bodies = <DebtorModel>[].obs;
  final RxList<DebtorModel> filteredBodies = <DebtorModel>[].obs;

  // Loading States
  final RxBool isBodiesLoading = false.obs;
  final RxBool isSearching = false.obs;
  final RxBool gbIsLoading = false.obs;
  final RxBool isAddingBody = false.obs;
  final RxBool isMoreLoading = false.obs;

  // Debtor Pagination
  final int _limit = 30;
  List<DocumentSnapshot?> pageCursors = [null];
  final RxInt currentPage = 1.obs;
  final RxBool hasMore = true.obs;
  DocumentSnapshot? _lastDocument;

  // Market Totals
  final RxDouble totalMarketOutstanding = 0.0.obs;
  final RxDouble totalMarketPayable = 0.0.obs;

  // Transaction States
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20;
  List<DocumentSnapshot?> txPageCursors = [null];
  final RxInt currentTxPage = 1.obs;
  final Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);

  Timer? _searchDebounce;

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

  // ==========================================
  // 2. SEARCH & PAGINATION
  // ==========================================
  void nextPage() {
    if (isSearching.value || !hasMore.value) return;
    loadPage(currentPage.value + 1);
  }

  void prevPage() {
    if (isSearching.value || currentPage.value <= 1) return;
    loadPage(currentPage.value - 1);
  }

  void searchDebtors(String queryText) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (queryText.trim().isEmpty) {
      isSearching.value = false;
      filteredBodies.assignAll(bodies);
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _performGlobalSearch(queryText),
    );
  }

  // ==========================================
  // 3. CORE FINANCIAL CALCULATIONS
  // ==========================================
  Future<void> calculateTotalOutstanding() async {
    try {
      final snap = await db.collection('debatorbody').get();
      double totalRec = 0;
      double totalPay = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        double bal = (data['balance'] as num?)?.toDouble() ?? 0.0;
        double pDue = (data['purchaseDue'] as num?)?.toDouble() ?? 0.0;

        // STRICT FIX: Only sum positive numbers. Ignore negative (advance) balances.
        if (bal > 0) totalRec += bal;
        if (pDue > 0) totalPay += pDue;
      }

      totalMarketOutstanding.value = totalRec;
      totalMarketPayable.value = totalPay;
    } catch (e) {
      AppLogger.i(e.toString());
    }
  }

  Future<void> syncAllBalances() async {
    gbIsLoading.value = true;
    Get.snackbar(
      "Syncing...",
      "Recalculating all debtor balances (Receivables & Payables). Please wait...",
      duration: const Duration(seconds: 4),
    );

    try {
      final snap = await db.collection('debatorbody').get();
      WriteBatch batch = db.batch();
      int count = 0;

      double newMarketDue = 0.0;
      double newMarketPayable = 0.0;

      for (var doc in snap.docs) {
        String debtorId = doc.id;

        // ========================================================
        // 1. RECALCULATE RECEIVABLES (From 'transactions' collection)
        // ========================================================
        final txSnap =
            await db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('transactions')
                .get();

        double oldDueTotal = 0.0,
            oldDuePaid = 0.0,
            runningSales = 0.0,
            runningPaid = 0.0;

        for (var txDoc in txSnap.docs) {
          final data = txDoc.data();
          String type = (data['type'] ?? '').toString().toLowerCase();
          double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

          if (type == 'previous_due') {
            oldDueTotal += amount;
          } else if (type == 'loan_payment' || type == 'eid_bonus') {
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
        double accurateBalance = currentLoan + (runningSales - runningPaid);

        // ========================================================
        // 2. RECALCULATE PAYABLES (From 'purchases' collection)
        // ========================================================
        final purchaseSnap =
            await db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('purchases')
                .get();

        double accuratePayable = 0.0;

        for (var pDoc in purchaseSnap.docs) {
          final pData = pDoc.data();
          String pType = (pData['type'] ?? '').toString().toLowerCase();
          double pAmount =
              double.tryParse(
                (pData['totalAmount'] ?? pData['amount']).toString(),
              ) ??
              0.0;

          if (pType == 'invoice') {
            accuratePayable += pAmount;
          } else if (pType == 'payment' || pType == 'adjustment') {
            accuratePayable -= pAmount;
          }
        }

        // ========================================================
        // 3. UPDATE THE DEBTOR DOCUMENT WITH BOTH CORRECTED VALUES
        // ========================================================
        batch.update(doc.reference, {
          'balance': accurateBalance,
          'purchaseDue': accuratePayable, // NOW THIS IS FIXED TOO!
        });

        // Add to Market Totals only if positive
        if (accurateBalance > 0) newMarketDue += accurateBalance;
        if (accuratePayable > 0) newMarketPayable += accuratePayable;

        count++;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      totalMarketOutstanding.value = newMarketDue;
      totalMarketPayable.value = newMarketPayable;
      await loadBodies(loadMore: false);

      Get.snackbar(
        "Success",
        "All Receivables & Payables synchronized perfectly!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Sync failed: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> _performGlobalSearch(String queryText) async {
    isSearching.value = true;
    isBodiesLoading.value = true;

    try {
      String qLower = queryText.trim().toLowerCase();
      Map<String, DebtorModel> results = {};
      List<String> searchTerms = qLower.split(RegExp(r'\s+'));
      String primaryTerm = searchTerms.first;

      if (primaryTerm.isNotEmpty) {
        var kwSnap =
            await db
                .collection('debatorbody')
                .where('searchKeywords', arrayContains: primaryTerm)
                .limit(50)
                .get();
        for (var doc in kwSnap.docs) {
          results[doc.id] = DebtorModel.fromFirestore(doc);
        }
      }

      for (var m in bodies) {
        results[m.id] = m;
      }

      List<DebtorModel> finalMatches =
          results.values.where((d) {
            String combinedString =
                "${d.name} ${d.phone} ${d.nid} ${d.address}".toLowerCase();
            try {
              combinedString += " ${(d as dynamic).des}".toLowerCase();
            } catch (_) {}
            for (String term in searchTerms) {
              if (!combinedString.contains(term)) return false;
            }
            return true;
          }).toList();

      filteredBodies.value = finalMatches;
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> runServerSearch(String queryText) async =>
      searchDebtors(queryText);

  List<String> _generateSearchKeywords(String name, String phone, String des) {
    Set<String> keywords = {};
    void addAllSubstrings(String text) {
      if (text.isEmpty) return;
      if (text.length > 50) {
        List<String> words = text.split(RegExp(r'\s+'));
        for (String w in words) {
          for (int i = 1; i <= w.length; i++) {
            keywords.add(w.substring(0, i));
          }
        }
        for (int i = 1; i <= 50; i++) {
          keywords.add(text.substring(0, i));
        }
        return;
      }
      for (int i = 0; i < text.length; i++) {
        for (int j = i + 1; j <= text.length; j++) {
          keywords.add(text.substring(i, j));
        }
      }
    }

    addAllSubstrings(name.trim().toLowerCase());
    addAllSubstrings(phone.trim().toLowerCase());
    addAllSubstrings(des.trim().toLowerCase());
    return keywords.toList();
  }

  Future<void> repairSearchKeywords() async {
    gbIsLoading.value = true;
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      for (var doc in snap.docs) {
        final data = doc.data();
        batch.update(doc.reference, {
          'searchKeywords': _generateSearchKeywords(
            data['name'] ?? '',
            data['phone'] ?? '',
            data['des'] ?? '',
          ),
        });
      }
      await batch.commit();
      Get.snackbar("Success", "All Search Keywords Updated Successfully!");
    } catch (e) {
      Get.snackbar("Error", "Failed to fix search data: $e");
    } finally {
      gbIsLoading.value = false;
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
    if (pageIndex < 1 || pageIndex > pageCursors.length) return;
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
        filteredBodies.assignAll(bodies);
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
      if (!isSearching.value) filteredBodies.assignAll(bodies);
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  Future<Map<String, double>> getInstantDebtorBreakdown(String debtorId) async {
    try {
      final snap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();
      double oldDueTotal = 0.0,
          oldDuePaid = 0.0,
          runningSales = 0.0,
          runningPaid = 0.0;

      for (var doc in snap.docs) {
        final data = doc.data();
        String type = (data['type'] ?? '').toString();
        double amount = (data['amount'] as num).toDouble();

        if (type == 'previous_due') {
          oldDueTotal += amount;
        } else if (type == 'loan_payment' || type == 'eid_bonus') {
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
          double oldDueTotal = 0.0,
              oldDuePaid = 0.0,
              runningSales = 0.0,
              runningPaid = 0.0;

          for (var doc in snap.docs) {
            final data = doc.data();
            String type = (data['type'] ?? '').toString();
            double amount = (data['amount'] as num).toDouble();

            if (type == 'previous_due') {
              oldDueTotal += amount;
            } else if (type == 'loan_payment' || type == 'eid_bonus') {
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
  // 4. TRANSACTION OPERATIONS
  // =========================================================
  void clearTransactionState() {
    currentTransactions.clear();
    txPageCursors = [null];
    currentTxPage.value = 1;
    hasMoreTx.value = true;
    isTxLoading.value = false;
    selectedDateRange.value = null;
  }

  void setDateFilter(DateTimeRange? range, String debtorId) {
    selectedDateRange.value = range;
    txPageCursors = [null];
    currentTxPage.value = 1;
    hasMoreTx.value = true;
    loadTxPage(debtorId, 1);
  }

  void nextTxPage(String debtorId) {
    if (!hasMoreTx.value) return;
    loadTxPage(debtorId, currentTxPage.value + 1);
  }

  void prevTxPage(String debtorId) {
    if (currentTxPage.value <= 1) return;
    loadTxPage(debtorId, currentTxPage.value - 1);
  }

  Future<void> loadTxPage(String debtorId, int pageIndex) async {
    if (pageIndex < 1 || pageIndex > txPageCursors.length) return;
    isTxLoading.value = true;

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

      DocumentSnapshot? startAfterDoc = txPageCursors[pageIndex - 1];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      if (snap.docs.isNotEmpty) {
        currentTransactions.value =
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
        if (snap.docs.length < _txLimit) {
          hasMoreTx.value = false;
        } else {
          hasMoreTx.value = true;
          if (txPageCursors.length <= pageIndex) {
            txPageCursors.add(snap.docs.last);
          } else {
            txPageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentTxPage.value = pageIndex;
      } else {
        if (pageIndex == 1) currentTransactions.clear();
        hasMoreTx.value = false;
      }
    } catch (e) {
      AppLogger.i(e.toString());
    } finally {
      isTxLoading.value = false;
    }
  }

  Future<void> _recalculateSingleDebtorBalance(String debtorId) async {
    try {
      final breakdown = await getInstantDebtorBreakdown(debtorId);
      await db.collection('debatorbody').doc(debtorId).update({
        'balance': breakdown['total'],
        'lastTransactionDate': Timestamp.now(),
      });
      calculateTotalOutstanding();
    } catch (e) {
      AppLogger.i(e.toString());
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
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      double amountForRunningBills = 0.0;
      if (type.toLowerCase() == 'eid_bonus') {
        Map<String, double> breakdown = await getInstantDebtorBreakdown(
          debtorId,
        );
        double currentLoan = breakdown['loan'] ?? 0.0;
        if (amount > currentLoan) amountForRunningBills = amount - currentLoan;
      }

      DocumentReference newTxRef =
          (txid != null && txid.isNotEmpty)
              ? debtorRef.collection('transactions').doc(txid)
              : debtorRef.collection('transactions').doc();
      String finalTxId = newTxRef.id;

      Map<String, dynamic>? finalPaymentMethod = paymentMethodData;
      if (['credit', 'previous_due'].contains(type.toLowerCase())) {
        finalPaymentMethod = null;
      }

      await newTxRef.set({
        'transactionId': finalTxId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date),
        'paymentMethod': finalPaymentMethod,
        'createdAt': Timestamp.now(),
      });

      String parsedMethod = (paymentMethodData['type'] ?? 'cash').toString();
      if (type.toLowerCase() == 'eid_bonus') parsedMethod = 'eid_bonus';

      if (parsedMethod.toLowerCase() == 'cash' &&
          paymentMethodData.containsKey('bankName') &&
          paymentMethodData['bankName'].toString().trim().isNotEmpty) {
        parsedMethod = 'Bank';
      } else if (parsedMethod.toLowerCase() == 'cash' &&
          paymentMethodData.containsKey('bkashNumber') &&
          paymentMethodData['bkashNumber'].toString().trim().isNotEmpty) {
        parsedMethod = 'Bkash';
      }

      bool isCollection = [
        'debit',
        'loan_payment',
        'advance_received',
        'collection',
        'payment',
        'received',
      ].contains(type.toLowerCase());

      if (isCollection) {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': parsedMethod,
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
          'method': parsedMethod,
          'details': paymentMethodData,
          'description': "Advance Given to $debtorName",
          'timestamp': Timestamp.fromDate(date),
          'linkedDebtorId': debtorId,
          'linkedTxId': finalTxId,
          'source': 'debtor_payment',
        });
      }

      bool isRunningBillPayment = [
        'debit',
        'collection',
        'payment',
        'received',
      ].contains(type.toLowerCase());
      double remainingToAllocate = amount;

      if (type.toLowerCase() == 'eid_bonus' && amountForRunningBills > 0.01) {
        isRunningBillPayment = true;
        remainingToAllocate = amountForRunningBills;
      }

      if (isRunningBillPayment) {
        String pType = parsedMethod.toLowerCase();
        String bNum = paymentMethodData['bkashNumber'] ?? '';
        String nNum = paymentMethodData['nagadNumber'] ?? '';
        String bankName = paymentMethodData['bankName'] ?? '';
        String accNum =
            paymentMethodData['accountNo'] ??
            paymentMethodData['accountNumber'] ??
            '';

        QuerySnapshot ordersSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();
        List<DocumentSnapshot> allOrders = ordersSnap.docs.toList();

        allOrders.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp t1 =
              dataA['timestamp'] is Timestamp
                  ? dataA['timestamp']
                  : Timestamp.now();
          Timestamp t2 =
              dataB['timestamp'] is Timestamp
                  ? dataB['timestamp']
                  : Timestamp.now();
          return t1.compareTo(t2);
        });

        List<DocumentSnapshot> pendingOrders =
            allOrders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double pending = 0.0;
              if (data['paymentDetails'] != null &&
                  data['paymentDetails']['due'] != null) {
                pending =
                    double.tryParse(data['paymentDetails']['due'].toString()) ??
                    0.0;
              } else {
                pending =
                    (double.tryParse(data['grandTotal']?.toString() ?? '0') ??
                        0.0) -
                    (double.tryParse(data['paid']?.toString() ?? '0') ?? 0.0);
              }
              return pending > 0.5;
            }).toList();

        if (pendingOrders.isNotEmpty) {
          WriteBatch batch = db.batch();
          bool hasUpdates = false;
          Map<String, double> middleInvoiceReductions = {};

          for (var orderDoc in pendingOrders) {
            if (remainingToAllocate <= 0.01) break;

            Map<String, dynamic> oData =
                orderDoc.data() as Map<String, dynamic>;
            String invoiceId = oData['invoiceId'] ?? orderDoc.id;

            QuerySnapshot dailySnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', isEqualTo: invoiceId)
                    .limit(1)
                    .get();

            double currentPendingD = 0.0;
            double currentPaidD = 0.0;
            double currentLedgerPaidD = 0.0;
            DocumentSnapshot? dailyDoc;

            if (dailySnap.docs.isNotEmpty) {
              dailyDoc = dailySnap.docs.first;
              Map<String, dynamic> dData =
                  dailyDoc.data() as Map<String, dynamic>;
              currentPendingD =
                  double.tryParse(dData['pending'].toString()) ?? 0.0;
              currentPaidD = double.tryParse(dData['paid'].toString()) ?? 0.0;
              currentLedgerPaidD =
                  double.tryParse(dData['ledgerPaid']?.toString() ?? '0') ??
                  0.0;
            }

            double salesOrderPending =
                oData['paymentDetails'] != null &&
                        oData['paymentDetails']['due'] != null
                    ? (double.tryParse(
                          oData['paymentDetails']['due'].toString(),
                        ) ??
                        0.0)
                    : ((double.tryParse(
                              oData['grandTotal']?.toString() ?? '0',
                            ) ??
                            0.0) -
                        (double.tryParse(oData['paid']?.toString() ?? '0') ??
                            0.0));

            double actualPending =
                dailyDoc != null ? currentPendingD : salesOrderPending;

            if (actualPending <= 0.5) {
              if (salesOrderPending > 0.5) {
                batch.update(orderDoc.reference, {
                  "paid":
                      double.tryParse(oData['grandTotal']?.toString() ?? '0') ??
                      0.0,
                  "paymentDetails.due": 0.0,
                  "isFullyPaid": true,
                  "status": "completed",
                });
                hasUpdates = true;
              }
              continue;
            }

            double take =
                (remainingToAllocate >= actualPending)
                    ? actualPending
                    : remainingToAllocate;
            bool isNowFullyPaid = (actualPending - take) <= 0.5;

            Map<String, dynamic> orderUpdate = {
              "paid": FieldValue.increment(take),
              "paymentDetails.due": FieldValue.increment(-take),
              "paymentDetails.$pType": FieldValue.increment(take),
            };

            if (oData['customerName'] != debtorName) {
              orderUpdate['customerName'] = debtorName;
            }
            if (pType == 'bkash' && bNum.isNotEmpty) {
              orderUpdate["paymentDetails.bkashNumber"] = bNum;
            } else if (pType == 'nagad' && nNum.isNotEmpty) {
              orderUpdate["paymentDetails.nagadNumber"] = nNum;
            } else if (pType == 'bank') {
              if (bankName.isNotEmpty) {
                orderUpdate["paymentDetails.bankName"] = bankName;
              }
              if (accNum.isNotEmpty) {
                orderUpdate["paymentDetails.accountNumber"] = accNum;
              }
            }

            if (isNowFullyPaid) {
              orderUpdate["isFullyPaid"] = true;
              orderUpdate["status"] = "completed";
            }
            batch.update(orderDoc.reference, orderUpdate);

            int currentIndex = allOrders.indexWhere(
              (doc) => doc.id == orderDoc.id,
            );
            if (currentIndex != -1 && currentIndex < allOrders.length - 1) {
              for (int i = currentIndex + 1; i < allOrders.length; i++) {
                String newerDocId = allOrders[i].id;
                middleInvoiceReductions[newerDocId] =
                    (middleInvoiceReductions[newerDocId] ?? 0.0) + take;
              }
            }

            if (dailyDoc != null) {
              Map<String, dynamic> dData =
                  dailyDoc.data() as Map<String, dynamic>;
              final newHistoryEntry = {
                'amount': take,
                'note':
                    note.isNotEmpty
                        ? note
                        : (type.toLowerCase() == 'eid_bonus'
                            ? "Eid Bonus Applied"
                            : "Late Due Collection"),
                'timestamp': Timestamp.fromDate(date),
                'type': pType,
                'bkashNumber': bNum,
                'nagadNumber': nNum,
                'bankName': bankName,
                'accountNumber': accNum,
                'sourceTxId': finalTxId,
              };
              Map<String, dynamic> dailyUpdate = {
                "paid": currentPaidD + take,
                "pending": currentPendingD - take,
                "ledgerPaid": currentLedgerPaidD + take,
                "status": (currentPendingD - take) <= 0.5 ? "paid" : "partial",
                "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
                "paymentMethod.$pType": FieldValue.increment(take),
              };

              if (dData['name'] != debtorName) dailyUpdate['name'] = debtorName;
              if (pType == 'bkash' && bNum.isNotEmpty) {
                dailyUpdate["paymentMethod.bkashNumber"] = bNum;
              } else if (pType == 'nagad' && nNum.isNotEmpty) {
                dailyUpdate["paymentMethod.nagadNumber"] = nNum;
              } else if (pType == 'bank') {
                if (bankName.isNotEmpty) {
                  dailyUpdate["paymentMethod.bankName"] = bankName;
                }
                if (accNum.isNotEmpty) {
                  dailyUpdate["paymentMethod.accountNumber"] = accNum;
                }
              }
              batch.update(dailyDoc.reference, dailyUpdate);
            }
            hasUpdates = true;
            remainingToAllocate -= take;
          }

          if (middleInvoiceReductions.isNotEmpty) {
            middleInvoiceReductions.forEach((docId, totalTake) {
              batch.update(db.collection('sales_orders').doc(docId), {
                "snapshotRunningDue": FieldValue.increment(-totalTake),
              });
            });
            hasUpdates = true;
          }
          if (hasUpdates) await batch.commit();
        }
      }

      await _recalculateSingleDebtorBalance(debtorId);
      await loadBodies(loadMore: false);

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);

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
      Get.snackbar(
        "Success",
        type.toLowerCase() == 'eid_bonus'
            ? "Eid Bonus Recorded Perfectly!"
            : "Collection Recorded & Bills Updated",
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

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

      QuerySnapshot lSnap =
          await db
              .collection('cash_ledger')
              .where('linkedTxId', isEqualTo: transactionId)
              .get();
      for (var doc in lSnap.docs) {
        await doc.reference.delete();
      }

      if (type == 'credit' ||
          type == 'debit' ||
          type == 'collection' ||
          type == 'payment' ||
          type == 'eid_bonus') {
        if (!Get.isRegistered<DailySalesController>()) {
          Get.put(DailySalesController());
        }
        final daily = Get.find<DailySalesController>();
        final debtorSnap =
            await db.collection('debatorbody').doc(debtorId).get();
        final debtorName = debtorSnap.data()?['name'] ?? "";

        Map<String, DocumentSnapshot> dailyDocsToProcess = {};

        final salesByNameSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();
        for (var doc in salesByNameSnap.docs) {
          dailyDocsToProcess[doc.id] = doc;
        }

        final ordersByIdSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();
        List<String> orderTxIds = [];
        for (var doc in ordersByIdSnap.docs) {
          orderTxIds.add((doc.data() as Map)['invoiceId'] ?? doc.id);
        }

        for (int i = 0; i < orderTxIds.length; i += 10) {
          int end = i + 10 > orderTxIds.length ? orderTxIds.length : i + 10;
          List<String> chunk = orderTxIds.sublist(i, end);
          if (chunk.isNotEmpty) {
            final chunkSnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', whereIn: chunk)
                    .get();
            for (var doc in chunkSnap.docs) {
              dailyDocsToProcess[doc.id] = doc;
            }
          }
        }

        final batch = db.batch();

        for (final doc in dailyDocsToProcess.values) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['transactionId'] == transactionId) {
            batch.delete(doc.reference);
          } else {
            List history = List.from(data['paymentHistory'] ?? []);
            bool changed = false;
            double amountReversed = 0.0;
            String reversedType = 'cash';

            history.removeWhere((h) {
              if (h['sourceTxId'] == transactionId) {
                amountReversed += (h['amount'] as num).toDouble();
                reversedType = (h['type'] ?? 'cash').toString().toLowerCase();
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
                'status': 'partial',
                'paymentMethod.$reversedType': FieldValue.increment(
                  -amountReversed,
                ),
              });

              String saleTxId = data['transactionId'] ?? '';
              if (saleTxId.isNotEmpty) {
                DocumentReference orderRef = db
                    .collection('sales_orders')
                    .doc(saleTxId);
                batch.update(orderRef, {
                  "paid": FieldValue.increment(-amountReversed),
                  "paymentDetails.due": FieldValue.increment(amountReversed),
                  "paymentDetails.$reversedType": FieldValue.increment(
                    -amountReversed,
                  ),
                  "isFullyPaid": false,
                  "status": "completed",
                });
              }
            }
          }
        }
        await batch.commit();
        await daily.loadDailySales();
      }

      await _recalculateSingleDebtorBalance(debtorId);

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);
      await loadBodies();

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
      Map<String, dynamic>? finalPaymentMethod = paymentMethod;
      if (['credit', 'previous_due'].contains(newType.toLowerCase())) {
        finalPaymentMethod = null;
      }

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
            'paymentMethod': finalPaymentMethod,
          });

      await _recalculateSingleDebtorBalance(debtorId);

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

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);
      await loadBodies();

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
        "des": des.trim(),
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
        "payments": payments,
        "balance": 0.0,
        "purchaseDue": 0.0,
        "searchKeywords": _generateSearchKeywords(
          name.trim(),
          phone.trim(),
          des.trim(),
        ),
        "createdAt": Timestamp.now(),
        "lastTransactionDate": Timestamp.now(),
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
        "des": des.trim(),
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
        "searchKeywords": _generateSearchKeywords(
          newName.trim(),
          phone.trim(),
          des.trim(),
        ),
      };
      if (payments != null) updateData["payments"] = payments;

      await db.collection('debatorbody').doc(id).update(updateData);

      if (oldName != newName) {
        final batch = db.batch();
        final orderSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: id)
                .get();
        List<String> linkedInvoiceIds = [];
        for (var doc in orderSnap.docs) {
          batch.update(doc.reference, {"customerName": newName.trim()});
          linkedInvoiceIds.add((doc.data() as Map)['invoiceId'] ?? doc.id);
        }

        final salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: oldName)
                .get();
        for (var doc in salesSnap.docs) {
          batch.update(doc.reference, {"name": newName.trim()});
        }

        for (int i = 0; i < linkedInvoiceIds.length; i += 10) {
          int end =
              i + 10 > linkedInvoiceIds.length
                  ? linkedInvoiceIds.length
                  : i + 10;
          List<String> chunk = linkedInvoiceIds.sublist(i, end);
          if (chunk.isNotEmpty) {
            final chunkSnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', whereIn: chunk)
                    .get();
            for (var doc in chunkSnap.docs) {
              batch.update(doc.reference, {"name": newName.trim()});
            }
          }
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

  Future<void> deleteDebtor(String id) async {
    gbIsLoading.value = true;
    try {
      final txSnap =
          await db
              .collection('debatorbody')
              .doc(id)
              .collection('transactions')
              .get();
      WriteBatch batch = db.batch();
      int count = 0;
      for (var doc in txSnap.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 490) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      batch.delete(db.collection('debatorbody').doc(id));
      await batch.commit();

      bodies.removeWhere((element) => element.id == id);
      filteredBodies.removeWhere((element) => element.id == id);

      calculateTotalOutstanding();
      Get.snackbar("Success", "Debtor account deleted successfully.");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete debtor: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> _generateGeneralReport({
    required String title,
    required bool isPayable,
  }) async {
    gbIsLoading.value = true;
    try {
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

      // MASSIVE FIX: Removed the `.abs()`. It will now strictly ignore negative (advance) rows!
      final targetDebtors =
          allDebtors.where((d) {
            double val = isPayable ? d.purchaseDue : d.balance;
            return val > 0.01;
          }).toList();

      if (targetDebtors.isEmpty) {
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
      final fontReg = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header:
              (context) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                        style: pw.TextStyle(font: fontReg, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                ],
              ),
          build:
              (context) => [
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: ["SL", "Name", "Phone", "Amount"],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                  },
                  data: List<List<String>>.generate(targetDebtors.length, (
                    idx,
                  ) {
                    final d = targetDebtors[idx];
                    return [
                      "${idx + 1}",
                      d.name,
                      d.phone,
                      bdCurrency.format(isPayable ? d.purchaseDue : d.balance),
                    ];
                  }),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue300),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            "GRAND TOTAL:",
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            "${bdCurrency.format(grandTotal)} BDT",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  // =========================================================
  // 5. ENTERPRISE PDF GENERATORS (Upgraded)
  // =========================================================
  void _silentAutoRepair() async {
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      bool needsUpdate = false;
      for (var doc in snap.docs) {
        if (!(doc.data() as Map).containsKey('balance') ||
            !(doc.data() as Map).containsKey('purchaseDue')) {
          needsUpdate = true;
          batch.update(doc.reference, {
            if (!(doc.data() as Map).containsKey('balance')) 'balance': 0.0,
            if (!(doc.data() as Map).containsKey('purchaseDue'))
              'purchaseDue': 0.0,
          });
        }
      }
      if (needsUpdate) await batch.commit();
    } catch (e) {
      AppLogger.i(e.toString());
    }
  }

  String _formatMethodForPdf(dynamic pm, [String? txType]) {
    if (txType != null &&
        ['credit', 'previous_due'].contains(txType.toLowerCase())) {
      return "-";
    }
    if (pm == null) return "Cash";
    if (pm is String) return pm;
    if (pm is Map) {
      String type = (pm['type'] ?? 'Cash').toString();
      String lowerType = type.toLowerCase();
      if (lowerType == 'eid_bonus') return "Eid Bonus";
      bool hasBank =
          pm.containsKey('bankName') &&
          pm['bankName'].toString().trim().isNotEmpty;
      if (lowerType == 'cash' && hasBank) return "Bank: ${pm['bankName']}";
      if (lowerType == 'bank') {
        return hasBank ? "Bank: ${pm['bankName']}" : "Bank";
      }
      if (lowerType.contains('bkash')) return "Bkash";
      if (lowerType.contains('nagad')) return "Nagad";
      if (lowerType.contains('rocket')) return "Rocket";
      return type.toUpperCase();
    }
    return "Cash";
  }

  // --- INDIVIDUAL DEBTOR STATEMENT (FIXED LIFETIME TOTALS) ---
  Future<void> downloadFullDebtorStatement(
    String debtorId,
    String debtorName,
  ) async {
    gbIsLoading.value = true;
    try {
      // 1. FETCH ALL TRANSACTIONS (To calculate accurate All-Time Totals)
      final allSnap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();

      if (allSnap.docs.isEmpty) {
        Get.snackbar("Info", "No transactions found to print.");
        return;
      }

      double allTimeDebit = 0.0;
      double allTimeCredit = 0.0;
      List<Map<String, dynamic>> allTransactions = [];

      for (var doc in allSnap.docs) {
        final data = doc.data();
        allTransactions.add(data);

        String type = (data['type'] ?? '').toString().toLowerCase();
        bool isDebit = [
          'credit',
          'previous_due',
          'advance_given',
        ].contains(type);
        double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (isDebit) {
          allTimeDebit += amount;
        } else {
          allTimeCredit += amount;
        }
      }

      // 2. FILTER FOR PDF ROWS (Based on selected Date Range)
      List<Map<String, dynamic>> pdfTransactions = List.from(allTransactions);

      if (selectedDateRange.value != null) {
        DateTime start = selectedDateRange.value!.start;
        DateTime end = selectedDateRange.value!.end;

        DateTime normalizedStart = DateTime(
          start.year,
          start.month,
          start.day,
          0,
          0,
          0,
        );
        DateTime normalizedEnd = DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
        );

        pdfTransactions =
            allTransactions.where((t) {
              DateTime tDate =
                  (t['date'] is Timestamp)
                      ? (t['date'] as Timestamp).toDate()
                      : t['date'];
              return tDate.isAfter(
                    normalizedStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  tDate.isBefore(normalizedEnd.add(const Duration(seconds: 1)));
            }).toList();
      }

      // 3. GENERATE PDF (Pass both the filtered rows AND the all-time totals)
      final pdfBytes = await generatePDF(
        debtorName,
        pdfTransactions,
        allTimeDebit,
        allTimeCredit,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${debtorName.replaceAll(' ', '_')}_Statement.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate full PDF: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  // --- PDF GENERATOR (Accepts lifetime totals as parameters) ---
  Future<Uint8List> generatePDF(
    String debtorName,
    List<Map<String, dynamic>> transactions,
    double totalDebit, // NEW PARAM: Lifetime Debit
    double totalCredit, // NEW PARAM: Lifetime Credit
  ) async {
    final pdf = pw.Document();
    final fontReg = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    // Sort Chronologically for PDF rows
    transactions.sort((a, b) {
      DateTime dA =
          (a['date'] is Timestamp)
              ? (a['date'] as Timestamp).toDate()
              : (a['date'] as DateTime);
      DateTime dB =
          (b['date'] is Timestamp)
              ? (b['date'] as Timestamp).toDate()
              : (b['date'] as DateTime);
      return dA.compareTo(dB);
    });

    // Calculate Net Balance from Lifetime Totals
    double netBalance = totalDebit - totalCredit;
    String balanceLabel =
        netBalance > 0
            ? "Due Balance"
            : (netBalance < 0 ? "Advance Balance" : "Net Balance");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "STATEMENT OF ACCOUNT",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Account Name: $debtorName",
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                          style: pw.TextStyle(font: fontReg, fontSize: 10),
                        ),
                        pw.Text(
                          "Page ${context.pageNumber} of ${context.pagesCount}",
                          style: pw.TextStyle(font: fontReg, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 15),
              ],
            ),
        build:
            (context) => [
              if (transactions.isEmpty)
                pw.Center(
                  child: pw.Text(
                    "No transactions found in this date range.",
                    style: pw.TextStyle(font: fontReg, fontSize: 12),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: [
                    "Date",
                    "Description",
                    "Payment Method",
                    "Debit",
                    "Credit",
                  ],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                  },
                  data:
                      transactions.map((t) {
                        DateTime date =
                            (t['date'] is Timestamp)
                                ? (t['date'] as Timestamp).toDate()
                                : t['date'];
                        String type =
                            (t['type'] ?? '').toString().toLowerCase();
                        bool isDebit = [
                          'credit',
                          'previous_due',
                          'advance_given',
                        ].contains(type);
                        double amount =
                            (t['amount'] as num?)?.toDouble() ?? 0.0;
                        String method = _formatMethodForPdf(
                          t['paymentMethod'],
                          type,
                        );

                        String desc =
                            isDebit
                                ? "DEBIT"
                                : (type == 'eid_bonus'
                                    ? "EID BONUS"
                                    : "CREDIT");
                        if (t['note'] != null &&
                            t['note'].toString().trim().isNotEmpty) {
                          desc += "\nNote: ${t['note']}";
                        }

                        return [
                          DateFormat('dd/MM/yyyy').format(date),
                          desc,
                          method,
                          isDebit ? bdCurrency.format(amount) : "-",
                          !isDebit ? bdCurrency.format(amount) : "-",
                        ];
                      }).toList(),
                ),

              pw.SizedBox(height: 20),

              // Summary Block (Uses Lifetime Totals!)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue400),
                  color: PdfColors.blue50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfStat(
                      "All-Time Debit",
                      totalDebit,
                      PdfColors.red900,
                      fontReg,
                      fontBold,
                    ),
                    _pdfStat(
                      "All-Time Credit",
                      totalCredit,
                      PdfColors.green900,
                      fontReg,
                      fontBold,
                    ),
                    _pdfStat(
                      balanceLabel,
                      netBalance.abs(),
                      PdfColors.blue900,
                      fontReg,
                      fontBold,
                    ),
                  ],
                ),
              ),

              // Signatures
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Prepared By",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Authorized Signature",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
      ),
    );

    return pdf.save();
  }

  // --- EID BONUS REPORT (UPGRADED) ---
  Future<void> downloadYearlyEidBonusReport() async {
    gbIsLoading.value = true;
    try {
      DateTime now = DateTime.now();
      DateTime startOfYear = DateTime(now.year, 1, 1);
      DateTime endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

      QuerySnapshot debtorSnap = await db.collection('debatorbody').get();
      Map<String, Map<String, dynamic>> debtorDataMap = {};
      for (var d in debtorSnap.docs) {
        debtorDataMap[d.id] = d.data() as Map<String, dynamic>;
      }

      List<Map<String, dynamic>> yearlyBonuses = [];
      double totalBonus = 0.0;

      QuerySnapshot txSnap =
          await db
              .collectionGroup('transactions')
              .where('type', isEqualTo: 'eid_bonus')
              .get();

      for (var doc in txSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime date =
            (data['date'] is Timestamp)
                ? (data['date'] as Timestamp).toDate()
                : (data['date'] as DateTime);
        if (date.isAfter(startOfYear) && date.isBefore(endOfYear)) {
          String debtorId = doc.reference.parent.parent!.id;
          double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          yearlyBonuses.add({
            'date': date,
            'amount': amount,
            'note': data['note'] ?? '',
            'debtorName': debtorDataMap[debtorId]?['name'] ?? 'Unknown',
            'debtorPhone': debtorDataMap[debtorId]?['phone'] ?? 'Unknown',
          });
          totalBonus += amount;
        }
      }

      if (yearlyBonuses.isEmpty) {
        Get.snackbar("Info", "No Eid Bonus given in ${now.year}.");
        return;
      }
      yearlyBonuses.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      final pdf = pw.Document();
      final fontReg = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header:
              (context) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "EID BONUS REPORT - ${now.year}",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.Text(
                        "Generated: ${DateFormat('dd MMM yyyy').format(now)}",
                        style: pw.TextStyle(font: fontReg, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                ],
              ),
          build:
              (context) => [
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.green800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: [
                    "SL",
                    "Date",
                    "Debtor Name",
                    "Phone",
                    "Bonus Amount",
                  ],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  data: List<List<String>>.generate(yearlyBonuses.length, (
                    idx,
                  ) {
                    final b = yearlyBonuses[idx];
                    return [
                      "${idx + 1}",
                      DateFormat('dd/MM/yyyy').format(b['date'] as DateTime),
                      b['debtorName'],
                      b['debtorPhone'],
                      bdCurrency.format(b['amount']),
                    ];
                  }),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green300),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            "TOTAL BONUS GIVEN:",
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            "${bdCurrency.format(totalBonus)} BDT",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColors.green900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Eid_Bonus_Report_${now.year}.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate report: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  // --- MARKET REPORT (UPGRADED) ---
  Future<void> downloadAllDebtorsReport() async => await _generateGeneralReport(
    title: "MARKET DUE REPORT",
    isPayable: false,
  );
  Future<void> downloadAllPayablesReport() async =>
      await _generateGeneralReport(
        title: "MARKET PAYABLE REPORT",
        isPayable: true,
      );

  pw.Widget _pdfStat(
    String label,
    double val,
    PdfColor col,
    pw.Font fontReg,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontReg,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          bdCurrency.format(val),
          style: pw.TextStyle(font: fontBold, fontSize: 14, color: col),
        ),
      ],
    );
  }
}
