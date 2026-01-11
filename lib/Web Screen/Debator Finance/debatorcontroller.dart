// ignore_for_file: deprecated_member_use, empty_catches, avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../Sales/controller.dart';
import 'model.dart'; // Ensure TransactionModel is defined here

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // --- OBSERVABLES (DEBTOR LIST) ---
  var bodies = <DebtorModel>[].obs;
  var filteredBodies = <DebtorModel>[].obs;

  RxBool isBodiesLoading = false.obs;
  RxBool gbIsLoading = false.obs; // Global Transaction loading
  RxBool isAddingBody = false.obs;

  // --- PAGINATION STATE (DEBTOR LIST) ---
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  final RxBool hasMore = true.obs;
  final RxBool isMoreLoading = false.obs;

  // --- OBSERVABLES (TRANSACTION PAGINATION - NEW UPDATE) ---
  // Stores the list of transactions for the currently viewed debtor
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  DocumentSnapshot? _lastTxDoc; // Cursor for transactions
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20; // Load 20 transactions at a time

  @override
  void onInit() {
    super.onInit();
    loadBodies(); // Initial load
  }

  // ------------------------------------------------------------------
  // 1. DATA LOADING & SEARCH (DEBTORS)
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

      if (snap.docs.length < _limit) {
        hasMore.value = false;
      }

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

      if (filteredBodies.isEmpty || !loadMore) {
        filteredBodies.assignAll(bodies);
      } else {
        filteredBodies.assignAll(bodies);
      }
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
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

  // ------------------------------------------------------------------
  // 2. TRANSACTION PAGINATION LOGIC (NEW FUTURE PROOF UPDATE)
  // ------------------------------------------------------------------

  /// Resets state before opening a new debtor details page
  void clearTransactionState() {
    currentTransactions.clear();
    _lastTxDoc = null;
    hasMoreTx.value = true;
    isTxLoading.value = false;
  }

  /// Loads transactions for a specific debtor in chunks
  Future<void> loadDebtorTransactions(
    String debtorId, {
    bool loadMore = false,
  }) async {
    // Prevent duplicate calls
    if (loadMore) {
      if (isTxLoading.value || !hasMoreTx.value) return;
    } else {
      clearTransactionState();
      isTxLoading.value = true;
    }

    try {
      Query query = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(_txLimit);

      // Pagination cursor logic
      if (loadMore && _lastTxDoc != null) {
        query = query.startAfterDocument(_lastTxDoc!);
      }

      final snap = await query.get();

      // Check if end reached
      if (snap.docs.length < _txLimit) {
        hasMoreTx.value = false;
      }

      if (snap.docs.isNotEmpty) {
        _lastTxDoc = snap.docs.last;

        final newTx =
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();

        if (loadMore) {
          currentTransactions.addAll(newTx);
        } else {
          currentTransactions.value = newTx;
        }
      }
    } catch (e) {
      print("Error loading transactions: $e");
    } finally {
      isTxLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 3. ADD & EDIT DEBTOR INFORMATION
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
        "createdAt": FieldValue.serverTimestamp(),
      });

      await loadBodies(loadMore: false);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        "Success",
        "Debtor profile created successfully",
        snackPosition: SnackPosition.BOTTOM,
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
      final WriteBatch batch = db.batch();
      DocumentReference debtorRef = db.collection('debatorbody').doc(id);

      batch.update(debtorRef, {
        "name": newName.trim(),
        "des": des,
        "nid": nid,
        "phone": phone.trim(),
        "address": address,
        "payments": payments,
      });

      if (oldName != newName) {
        final salesSnap =
            await db
                .collection('daily_sales')
                .where('customerType', isEqualTo: 'debtor')
                .where('name', isEqualTo: oldName)
                .get();
        for (var doc in salesSnap.docs) {
          batch.update(doc.reference, {"name": newName.trim()});
        }
      }

      await batch.commit();
      await loadBodies(loadMore: false);

      Get.back(closeOverlays: true);
      Get.snackbar(
        "Success",
        "Profile updated",
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 4. TRANSACTION LOGIC (SALES LINKED & PROTECTED)
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
      if (!Get.isRegistered<DailySalesController>()) {
        Get.put(DailySalesController());
      }
      final daily = Get.find<DailySalesController>();

      final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
      if (!debtorSnap.exists) throw "Debtor not found";

      final debtorData = debtorSnap.data()!;
      final debtorName = debtorData['name'] ?? 'Unknown';
      final typeLower = type.toLowerCase();
      Map<String, dynamic>? paymentMethod = selectedPaymentMethod;

      if (typeLower == 'credit') {
        // PURCHASE (SALE)
        if (txid != null) {
          final existingTx =
              await db
                  .collection('debatorbody')
                  .doc(debtorId)
                  .collection('transactions')
                  .doc(txid)
                  .get();

          if (existingTx.exists) {
            throw "Transaction ID already exists. Please refresh.";
          }
        }

        DocumentReference newTxRef;
        if (txid != null && txid.isNotEmpty) {
          newTxRef = db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc(txid);
        } else {
          newTxRef =
              db
                  .collection('debatorbody')
                  .doc(debtorId)
                  .collection('transactions')
                  .doc();
          txid = newTxRef.id;
        }

        await newTxRef.set({
          'transactionId': txid,
          'amount': amount,
          'note': note,
          'type': 'credit',
          'date': Timestamp.fromDate(date),
          'paymentMethod': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

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
      } else {
        // PAYMENT (COLLECTION)
        if (paymentMethod == null) {
          final payments = (debtorData['payments'] as List? ?? []);
          if (payments.isNotEmpty) {
            paymentMethod = Map<String, dynamic>.from(payments.first);
          }
        }

        await db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .add({
              'amount': amount,
              'note': note,
              'type': 'debit',
              'date': Timestamp.fromDate(date),
              'paymentMethod': paymentMethod,
              'createdAt': FieldValue.serverTimestamp(),
              'transactionId': txid,
            });

        await daily.applyDebtorPayment(
          debtorName,
          amount,
          paymentMethod ?? {},
          date: date,
          transactionId: txid,
        );
      }

      // Update the local transaction list if we are currently viewing this debtor
      // This makes the UI update instantly without full reload
      loadDebtorTransactions(debtorId);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        "Success",
        "Transaction recorded",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Transaction Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 5. DATA STREAMS (KEPT FOR LEGACY/SUMMARY)
  // ------------------------------------------------------------------
  Stream<QuerySnapshot> loadTransactions(String id) {
    return db
        .collection('debatorbody')
        .doc(id)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Stream<Map<String, dynamic>> summary(String id) {
    return loadTransactions(id).map((snap) {
      double credit = 0;
      double debit = 0;
      for (var doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['type'] == 'credit') {
          credit += (d['amount'] as num?)?.toDouble() ?? 0;
        }
        if (d['type'] == 'debit') {
          debit += (d['amount'] as num?)?.toDouble() ?? 0;
        }
      }
      return {'credit': credit, 'debit': debit, 'balance': credit - debit};
    });
  }

  // ------------------------------------------------------------------
  // 6. DELETE TRANSACTION
  // ------------------------------------------------------------------
  Future<void> deleteTransaction(String debtorId, String transactionId) async {
    final daily = Get.find<DailySalesController>();
    gbIsLoading.value = true;

    try {
      final txRef = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId);

      final salesOrderRef = db.collection('sales_orders').doc(transactionId);
      final pnlRef = db
          .collection('debtor_transaction_history')
          .doc(transactionId);

      final txSnap = await txRef.get();
      if (!txSnap.exists) {
        gbIsLoading.value = false;
        return;
      }

      final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
      final debtorName = debtorSnap.data()?['name'] ?? "";

      final salesSnap =
          await db
              .collection('daily_sales')
              .where('name', isEqualTo: debtorName)
              .get();

      final WriteBatch batch = db.batch();

      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final List applied = List.from(data['appliedDebits'] ?? []);

        if (data['transactionId'] == transactionId) {
          batch.delete(doc.reference);
        } else if (applied.any((e) => e['id'] == transactionId)) {
          final entry = applied.firstWhere((e) => e['id'] == transactionId);
          final double usedAmt = (entry['amount'] as num?)?.toDouble() ?? 0;
          final double currentPaid = (data['paid'] as num?)?.toDouble() ?? 0;

          applied.removeWhere((e) => e['id'] == transactionId);

          batch.update(doc.reference, {
            'paid': (currentPaid - usedAmt).clamp(0, double.infinity),
            'appliedDebits': applied,
          });
        }
      }

      batch.delete(salesOrderRef);
      batch.delete(txRef);
      batch.delete(pnlRef);

      await batch.commit();

      await daily.loadDailySales();
      // Update local paginated list
      loadDebtorTransactions(debtorId);

      Get.snackbar(
        "Deleted",
        "Transaction, Invoice & P&L removed successfully",
      );
    } catch (e) {
      Get.snackbar("Deletion Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 7. PDF GENERATOR
  // ------------------------------------------------------------------
  String formatPaymentMethod(Map<String, dynamic>? method) {
    if (method == null) return "-";
    final type = method['type'] ?? "";
    final number = method['number'] ?? "";
    return "$type${number.isNotEmpty ? ": $number" : ""}";
  }

  Future<Uint8List> generatePDF(
    String debtorName,
    List<Map<String, dynamic>> transactions,
  ) async {
    final pdf = pw.Document();
    double credit = transactions
        .where((t) => t['type'] == 'credit')
        .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    double debit = transactions
        .where((t) => t['type'] == 'debit')
        .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

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
                      "G-TEL ERP SYSTEM",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
              ],
            ),
        build:
            (context) => [
              pw.Text(
                "Statement of Account: $debtorName",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStat("Total Purchased", credit, PdfColors.black),
                  _pdfStat("Total Paid", debit, PdfColors.green900),
                  _pdfStat("Outstanding", credit - debit, PdfColors.red900),
                ],
              ),
              pw.SizedBox(height: 25),
              pw.Table.fromTextArray(
                headers: ["Date", "Type", "Notes", "Amount (Tk)"],
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                ),
                cellHeight: 25,
                data:
                    transactions.map((t) {
                      final dynamic dateValue = t['date'];
                      DateTime tDate =
                          (dateValue is Timestamp)
                              ? dateValue.toDate()
                              : (dateValue is DateTime
                                  ? dateValue
                                  : DateTime.now());
                      return [
                        DateFormat('dd/MM/yy').format(tDate),
                        t['type'].toString().toUpperCase(),
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
          "Tk ${val.toStringAsFixed(2)}",
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: col,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 8. EDIT TRANSACTION
  // ------------------------------------------------------------------
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
      final txRef = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId);

      final WriteBatch batch = db.batch();

      batch.update(txRef, {
        'amount': newAmount,
        'type': newType,
        'note': note,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
      });

      final salesSnap =
          await db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: transactionId)
              .get();

      for (var doc in salesSnap.docs) {
        if (newType == 'credit') {
          batch.update(doc.reference, {'amount': newAmount});
        } else {
          batch.update(doc.reference, {
            'amount': newAmount,
            'paid': newAmount,
            'paymentMethod': paymentMethod,
          });
        }
      }

      if (newType == 'credit') {
        final analyticsRef = db
            .collection('debtor_transaction_history')
            .doc(transactionId);

        batch.set(analyticsRef, {
          'saleAmount': newAmount,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Update local paginated list
      loadDebtorTransactions(debtorId);

      Get.back(closeOverlays: true);
      Get.snackbar(
        "Success",
        "Transaction & Records updated",
        backgroundColor: const Color(0xFF3B82F6),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Update Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }
}
