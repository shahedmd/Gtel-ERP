// ignore_for_file: deprecated_member_use, empty_catches
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../Sales/controller.dart';
import 'model.dart';

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // Observables
  var bodies = <DebtorModel>[].obs;
  var filteredBodies = <DebtorModel>[].obs;

  RxBool isBodiesLoading = false.obs;
  RxBool gbIsLoading = false.obs; // Global Transaction loading
  RxBool isAddingBody = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadBodies();
  }

  // ------------------------------------------------------------------
  // 1. DATA LOADING & SEARCH
  // ------------------------------------------------------------------
  Future<void> loadBodies() async {
    isBodiesLoading.value = true;
    try {
      final snap =
          await db
              .collection('debatorbody')
              .orderBy('createdAt', descending: true)
              .get();
      bodies.value =
          snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();
      filteredBodies.assignAll(bodies);
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
    } finally {
      isBodiesLoading.value = false;
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
  // 2. ADD & EDIT DEBTOR INFORMATION
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
        "name": name,
        "des": des,
        "nid": nid,
        "phone": phone,
        "address": address,
        "payments": payments,
        "createdAt": FieldValue.serverTimestamp(),
      });
      await loadBodies();

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
        "name": newName,
        "des": des,
        "nid": nid,
        "phone": phone,
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
          batch.update(doc.reference, {"name": newName});
        }
      }

      await batch.commit();
      await loadBodies();

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
  // 3. TRANSACTION LOGIC (SALES LINKED)
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
        // 1. Create a reference to a new document (this auto-generates the ID)
        final newTxRef =
            db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('transactions')
                .doc(txid);

        // 2. Use .set() to save data including the generated ID
        await newTxRef.set({
          'transactionId': txid, // <--- Storing the ID here
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

        // FIX: The daily controller now uses the 'date' provided to filter only THIS day
        await daily.applyDebtorPayment(
          debtorName,
          amount,
          paymentMethod ?? {},
          date: date,
          transactionId: txid,
        );
      }

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
  // 5. DATA STREAMS
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
  // 6. DELETE TRANSACTION (FIXED: NO GLOBAL RE-CALCULATION)
  // ------------------------------------------------------------------
Future<void> deleteTransaction(String debtorId, String transactionId) async {
    final daily = Get.find<DailySalesController>();
    gbIsLoading.value = true;

    try {
      // 1. Get references
      final txRef = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId);

      final salesOrderRef = db
          .collection('sales_orders')
          .doc(transactionId); // Reference to Sales Order

      // --- NEW: Reference to Debtor P&L ---
      final pnlRef = db
          .collection('debtor_transaction_history')
          .doc(transactionId); 

      final txSnap = await txRef.get();
      if (!txSnap.exists) {
        gbIsLoading.value = false;
        return;
      }

      final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
      final debtorName = debtorSnap['name'];

      // 2. Find associated Daily Sales
      // Note: This queries all entries for this debtor to check for payments/sales
      final salesSnap =
          await db
              .collection('daily_sales')
              .where('name', isEqualTo: debtorName)
              .get();

      final WriteBatch batch = db.batch();

      // 3. Handle Daily Sales updates
      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final List applied = List.from(data['appliedDebits'] ?? []);

        // Case A: This was the specific purchase entry linked to the transaction
        if (data['transactionId'] == transactionId) {
          batch.delete(doc.reference);
        }
        // Case B: This was a payment that was applied to a sale
        else if (applied.any((e) => e['id'] == transactionId)) {
          final entry = applied.firstWhere((e) => e['id'] == transactionId);
          final double usedAmt = (entry['amount'] as num?)?.toDouble() ?? 0;
          final double currentPaid = (data['paid'] as num?)?.toDouble() ?? 0;

          applied.removeWhere((e) => e['id'] == transactionId);

          batch.update(doc.reference, {
            'paid': (currentPaid - usedAmt).clamp(0, double.infinity),
            'appliedDebits': applied,
            // Only reset isPaid if it was fully paid before and now isn't
            // 'isPaid': false, 
            // 'paymentMethod': null, 
          });
        }
      }

      // 4. Delete the Sales Order
      batch.delete(salesOrderRef);

      // 5. Delete the Debtor Transaction
      batch.delete(txRef);
      
      // 6. Delete the Debtor Profit Loss Doc (NEW)
      // Even if this is a 'payment' transaction and the P&L doc doesn't exist, 
      // Firestore batch.delete is safe to call.
      batch.delete(pnlRef);

      // 7. Commit all changes at once
      await batch.commit();

      await daily.loadDailySales();
      Get.snackbar("Deleted", "Transaction, Invoice & P&L removed successfully");
    } catch (e) {
      Get.snackbar("Deletion Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 7. PDF GENERATOR & HELPERS
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
  // 8. EDIT TRANSACTION (SALES SYNC)
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

      await batch.commit();
      Get.back(closeOverlays: true);
      Get.snackbar(
        "Success",
        "Transaction updated",
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
