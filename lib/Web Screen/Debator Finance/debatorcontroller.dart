// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'dart:async';
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
  final int _limit = 30;
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

  // --- SEARCH DEBOUNCE ---
  Timer? _searchDebounce;

  DocumentSnapshot? _lastDocument;
  final RxBool isMoreLoading = false.obs;

  // ==========================================
  // TRANSACTION PAGINATION STATES (UPDATED)
  // ==========================================
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20; // 20 Rows Per Page
  List<DocumentSnapshot?> txPageCursors = [null];
  RxInt currentTxPage = 1.obs;

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
    if (isSearching.value) return;
    if (!hasMore.value) return;
    loadPage(currentPage.value + 1);
  }

  void prevPage() {
    if (isSearching.value) return;
    if (currentPage.value <= 1) return;
    loadPage(currentPage.value - 1);
  }

  // =========================================================
  // 1. ADVANCED GLOBAL SEARCH LOGIC
  // =========================================================

  void searchDebtors(String queryText) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (queryText.trim().isEmpty) {
      isSearching.value = false;
      filteredBodies.assignAll(bodies);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performGlobalSearch(queryText);
    });
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
    } catch (e) {
      print("Global Search Error: $e");
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> runServerSearch(String queryText) async {
    searchDebtors(queryText);
  }

  List<String> _generateSearchKeywords(String name, String phone, String des) {
    Set<String> keywords = {};

    String lowerName = name.trim().toLowerCase();
    String lowerPhone = phone.trim().toLowerCase();
    String lowerDes = des.trim().toLowerCase();

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

    addAllSubstrings(lowerName);
    addAllSubstrings(lowerPhone);
    addAllSubstrings(lowerDes);

    return keywords.toList();
  }

  Future<void> repairSearchKeywords() async {
    gbIsLoading.value = true;
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();

      for (var doc in snap.docs) {
        final data = doc.data();
        String name = data['name'] ?? '';
        String phone = data['phone'] ?? '';
        String des = data['des'] ?? '';

        batch.update(doc.reference, {
          'searchKeywords': _generateSearchKeywords(name, phone, des),
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

  // =========================================================
  // CALCULATIONS & LOADING
  // =========================================================

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

      if (!isSearching.value) {
        filteredBodies.assignAll(bodies);
      }
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
  // 2. TRANSACTION PAGINATION LOGIC (NEW)
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
    if (pageIndex < 1) return;
    if (pageIndex > txPageCursors.length) return;

    isTxLoading.value = true;
    _recalculateSingleDebtorBalance(debtorId);

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
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      DocumentReference newTxRef =
          (txid != null && txid.isNotEmpty)
              ? debtorRef.collection('transactions').doc(txid)
              : debtorRef.collection('transactions').doc();
      String finalTxId = newTxRef.id;

      // ==========================================
      // NULLIFY PAYMENT METHOD FOR BILLS/DEBT
      // ==========================================
      Map<String, dynamic>? finalPaymentMethod = paymentMethodData;
      if ([
        'credit',
        'previous_due',
        'advance_given',
      ].contains(type.toLowerCase())) {
        finalPaymentMethod = null; // Don't save payment method for debts/bills
      }

      await newTxRef.set({
        'transactionId': finalTxId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date),
        'paymentMethod': finalPaymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

      if (isCollection) {
        double remainingToAllocate = amount;

        QuerySnapshot salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();

        List<DocumentSnapshot> pendingBills =
            salesSnap.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double p = double.tryParse(data['pending'].toString()) ?? 0.0;
              return p > 0.5;
            }).toList();

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

            double take =
                (remainingToAllocate >= currentPending)
                    ? currentPending
                    : remainingToAllocate;

            final newHistoryEntry = {
              'type': paymentMethodData['type'] ?? 'cash',
              'amount': take,
              'paidAt': Timestamp.now(),
              'sourceTxId': finalTxId,
            };

            batch.update(doc.reference, {
              "paid": currentPaid + take,
              "pending": currentPending - take,
              "ledgerPaid": currentLedgerPaid + take,
              "status": (currentPending - take) <= 0.5 ? "paid" : "partial",
              "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
            });
            hasUpdates = true;

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

      await _recalculateSingleDebtorBalance(debtorId);
      await loadBodies(loadMore: false);

      loadTxPage(debtorId, 1);

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
          type == 'payment') {
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
                'status': 'partial',
              });
            }
          }
        }
        await batch.commit();
        await daily.loadDailySales();
      }

      await _recalculateSingleDebtorBalance(debtorId);
      loadTxPage(debtorId, currentTxPage.value);
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
      // ==========================================
      // NULLIFY PAYMENT METHOD FOR BILLS/DEBT
      // ==========================================
      Map<String, dynamic>? finalPaymentMethod = paymentMethod;
      if ([
        'credit',
        'previous_due',
        'advance_given',
      ].contains(newType.toLowerCase())) {
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

      loadTxPage(debtorId, currentTxPage.value);
      loadBodies();
      Get.back();
      Get.snackbar("Success", "Updated successfully");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // --- ADD BODY ---
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

  // --- EDIT BODY ---
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

  // --- DELETE BODY ---
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

  // --- UPDATED PDF FORMATTER to handle no payment method logic ---
  String _formatMethodForPdf(dynamic pm, [String? txType]) {
    // Return empty dash if it's a bill type
    if (txType != null &&
        [
          'credit',
          'previous_due',
          'advance_given',
        ].contains(txType.toLowerCase())) {
      return "-";
    }

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
                          t['type'].toString(),
                        ), // PASSED TYPE HERE
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