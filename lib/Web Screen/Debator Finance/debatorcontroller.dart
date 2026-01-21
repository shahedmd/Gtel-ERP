// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// EXTERNAL CONTROLLERS
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import '../Sales/controller.dart';
import 'model.dart';

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // --- OBSERVABLES ---
  var bodies = <DebtorModel>[].obs;
  var filteredBodies = <DebtorModel>[].obs;

  // Total Outstanding (Global Market Debt)
  var totalMarketOutstanding = 0.0.obs;

  RxBool isBodiesLoading = false.obs;
  RxBool gbIsLoading = false.obs;
  RxBool isAddingBody = false.obs; // Restored

  // --- PAGINATION STATE ---
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  final RxBool hasMore = true.obs;
  final RxBool isMoreLoading = false.obs;

  // --- TRANSACTIONS STATE ---
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  DocumentSnapshot? _lastTxDoc;
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20;

  // --- FILTERS ---
  Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);

  @override
  void onInit() {
    super.onInit();
    loadBodies();
    calculateTotalOutstanding();
    _silentAutoRepair();
  }

  // ------------------------------------------------------------------
  // 1. DATA LOADING & BREAKDOWN
  // ------------------------------------------------------------------

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

      searchDebtors('');
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
      print(e);
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  // --- NEW FEATURE: BREAKDOWN STREAM ---
  Stream<Map<String, double>> getDebtorBreakdown(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .collection('transactions')
        .snapshots()
        .map((snap) {
          double previousDueTotal = 0.0;
          double previousPaid = 0.0;
          double runningDue = 0.0;

          for (var doc in snap.docs) {
            final data = doc.data();
            String type = (data['type'] ?? '').toString();
            double amount = (data['amount'] as num).toDouble();

            // 1. LOAN / PREVIOUS SECTION
            if (type == 'previous_due') {
              previousDueTotal += amount;
            } else if (type == 'loan_payment') {
              previousPaid += amount;
            }
            // 2. RUNNING / NORMAL SECTION (Includes advances as running debt)
            else if (type == 'credit' || type == 'advance_given') {
              runningDue += amount;
            } else if (type == 'debit' || type == 'advance_received') {
              runningDue -= amount;
            }
          }

          double currentLoan = previousDueTotal - previousPaid;

          return {
            'loan': currentLoan,
            'running': runningDue,
            'total': currentLoan + runningDue,
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

  // --- CORE RECALCULATION (UPDATED FOR NEW TYPES) ---
  Future<void> _recalculateSingleDebtorBalance(String debtorId) async {
    try {
      final txs =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();
      double realBalance = 0.0;

      for (var doc in txs.docs) {
        final data = doc.data();
        String type = (data['type'] ?? 'credit').toString();
        double amount = (data['amount'] as num).toDouble();

        // ADD to Debt: Credit, Advance Given, Previous Due
        if (type == 'credit' ||
            type == 'advance_given' ||
            type == 'previous_due') {
          realBalance += amount;
        }
        // REDUCE Debt: Debit, Advance Recv, Loan Payment
        else {
          realBalance -= amount;
        }
      }

      await db.collection('debatorbody').doc(debtorId).update({
        'balance': realBalance,
        'lastTransactionDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Auto-Fix Error: $e");
    }
  }

  // ------------------------------------------------------------------
  // 3. ADD TRANSACTION (UPDATED WITH NEW LOGIC)
  // ------------------------------------------------------------------

  Future<void> addTransaction({
    required String debtorId,
    required double amount,
    required String note,
    required String type,
    required DateTime date,
    Map<String, dynamic>? selectedPaymentMethod,
    String? txid,
  }) async {
    gbIsLoading.value = true;
    try {
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      DocumentReference newTxRef;
      if (txid != null && txid.isNotEmpty) {
        newTxRef = debtorRef.collection('transactions').doc(txid);
      } else {
        newTxRef = debtorRef.collection('transactions').doc();
        txid = newTxRef.id;
      }

      Map<String, dynamic>? paymentData = selectedPaymentMethod;
      if (paymentData == null &&
          (type == 'debit' ||
              type == 'advance_received' ||
              type == 'loan_payment')) {
        List pm = debtorSnap.data()?['payments'] ?? [];
        if (pm.isNotEmpty) paymentData = pm.first;
      }

      await newTxRef.set({
        'transactionId': txid,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // --- LOGIC SPLIT START ---

      // A. Previous Due Setup (Just Internal Record)
      if (type == 'previous_due') {
        // No external sync
      }
      // B. Loan Payment (Goes to Cash Ledger Only)
      else if (type == 'loan_payment') {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': paymentData?['type'] ?? 'cash',
          'description': "Previous Due Collected: $debtorName",
          'timestamp': FieldValue.serverTimestamp(),
          'linkedDebtorId': debtorId,
          'linkedTxId': txid,
        });
      }
      // C. Advances
      else if (type == 'advance_given') {
        await db.collection('cash_ledger').add({
          'type': 'expense',
          'amount': amount,
          'method': 'cash',
          'description': "Advance Given to $debtorName",
          'timestamp': FieldValue.serverTimestamp(),
          'linkedDebtorId': debtorId,
          'linkedTxId': txid,
        });
        if (!Get.isRegistered<DailyExpensesController>())
          Get.put(DailyExpensesController());
        try {
          await Get.find<DailyExpensesController>().addDailyExpense(
            "Loan to $debtorName",
            amount.toInt(),
            note: "Debtor Advance - $note",
            date: date,
          );
        } catch (e) {
          print("Expense Sync Error: $e");
        }
      } else if (type == 'advance_received') {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': paymentData?['type'] ?? 'cash',
          'description': "Advance Received from $debtorName",
          'timestamp': FieldValue.serverTimestamp(),
          'linkedDebtorId': debtorId,
          'linkedTxId': txid,
        });
      }
      // D. Sales Logic (Credit/Debit)
      else if (type == 'credit' || type == 'debit') {
        if (!Get.isRegistered<DailySalesController>())
          Get.put(DailySalesController());
        final daily = Get.find<DailySalesController>();

        if (type == 'credit') {
          await daily.addSale(
            name: debtorName,
            amount: amount,
            customerType: 'debtor',
            isPaid: false,
            date: date,
            paymentMethod: null,
            source: "credit",
            transactionId: txid,
          );
        } else if (type == 'debit') {
          await daily.applyDebtorPayment(
            debtorName,
            amount,
            paymentData ?? {},
            date: date,
            transactionId: txid,
          );
        }
      }
      // --- LOGIC SPLIT END ---

      await _recalculateSingleDebtorBalance(debtorId);

      loadDebtorTransactions(debtorId);
      loadBodies();
      calculateTotalOutstanding();
      if (Get.isRegistered<CashDrawerController>()) {
        Get.find<CashDrawerController>().fetchData();
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
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print(e);
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 4. DELETE & EDIT (Restored)
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

      // Cleanup
      if (type == 'loan_payment' || type.contains('advance')) {
        QuerySnapshot lSnap =
            await db
                .collection('cash_ledger')
                .where('linkedTxId', isEqualTo: transactionId)
                .get();
        for (var doc in lSnap.docs) await doc.reference.delete();
      }

      if (type == 'credit' || type == 'debit') {
        // Keeping your legacy sales cleanup logic
        if (!Get.isRegistered<DailySalesController>())
          Get.put(DailySalesController());
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
      calculateTotalOutstanding();
      if (Get.isRegistered<CashDrawerController>())
        Get.find<CashDrawerController>().fetchData();
      if (Get.isRegistered<DailyExpensesController>())
        Get.find<DailyExpensesController>().onInit();

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
    Map<String, dynamic>? paymentMethod,
  }) async {
    gbIsLoading.value = true;
    try {
      // 1. Update Tx
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

      // 2. Force Recalculate
      await _recalculateSingleDebtorBalance(debtorId);

      // 3. Update External (Simplified update - complex type changes might require delete/re-add)
      if (oldType == 'loan_payment' || oldType.contains('advance')) {
        QuerySnapshot lSnap =
            await db
                .collection('cash_ledger')
                .where('linkedTxId', isEqualTo: transactionId)
                .get();
        for (var d in lSnap.docs) {
          await d.reference.update({
            'amount': newAmount,
            // Simple type switch, doesn't handle deep logic change
          });
        }
      }

      // Legacy Sales update
      if (newType == 'credit' || newType == 'debit') {
        final salesSnap =
            await db
                .collection('daily_sales')
                .where('transactionId', isEqualTo: transactionId)
                .get();
        for (var doc in salesSnap.docs) {
          if (newType == 'credit') {
            await doc.reference.update({'amount': newAmount});
          } else {
            await doc.reference.update({
              'amount': newAmount,
              'paid': newAmount,
              'paymentMethod': paymentMethod,
            });
          }
        }
      }

      loadDebtorTransactions(debtorId);
      loadBodies();
      calculateTotalOutstanding();
      Get.back();
      Get.snackbar("Success", "Updated successfully");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 5. DEBTOR PROFILE CRUD (Restored)
  // ------------------------------------------------------------------

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
    required List<Map<String, dynamic>> payments,
  }) async {
    gbIsLoading.value = true;
    try {
      await db.collection('debatorbody').doc(id).update({
        "name": newName.trim(),
        "des": des,
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
        "payments": payments,
      });
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
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 6. HELPERS
  // ------------------------------------------------------------------

  Future<void> _silentAutoRepair() async {
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      bool needsUpdate = false;
      for (var doc in snap.docs) {
        if (!doc.data().containsKey('balance')) {
          needsUpdate = true;
          batch.update(doc.reference, {
            'balance': 0.0,
            'lastTransactionDate':
                doc['createdAt'] ?? FieldValue.serverTimestamp(),
          });
        }
      }
      if (needsUpdate) await batch.commit();
    } catch (e) {
      print(e);
    }
  }

  Future<void> calculateTotalOutstanding() async {
    try {
      final snap = await db.collection('debatorbody').get();
      double total = 0;
      for (var doc in snap.docs) {
        total += (doc.data()['balance'] as num?)?.toDouble() ?? 0.0;
      }
      totalMarketOutstanding.value = total;
    } catch (e) {}
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

  Stream<double> getLiveBalance(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  // --- PDF GENERATION ---
  Future<Uint8List> generatePDF(
    String debtorName,
    List<Map<String, dynamic>> transactions,
  ) async {
    final pdf = pw.Document();

    // Calculate totals for PDF
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
                headers: ["Date", "Type", "Note", "Amount"],
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
                        (t['amount'] as num).toStringAsFixed(2),
                      ];
                    }).toList(),
              ),
            ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfStat(String label, double val, PdfColor col) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          val.toStringAsFixed(2),
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
