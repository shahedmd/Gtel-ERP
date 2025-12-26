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
      final snap = await db.collection('debatorbody').orderBy('createdAt', descending: true).get();
      bodies.value = snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();
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
      bodies.where((d) => 
        d.name.toLowerCase().contains(q) || 
        d.phone.contains(q) || 
        d.nid.contains(q) || 
        d.address.toLowerCase().contains(q)
      ).toList()
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
      Get.snackbar("Success", "Debtor profile created successfully");
    } finally {
      isAddingBody.value = false;
    }
  }

  /// UPDATED: Edit Debtor with Atomic Name Sync
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
      
      // 1. Update the Debtor Profile
      DocumentReference debtorRef = db.collection('debatorbody').doc(id);
      batch.update(debtorRef, {
        "name": newName,
        "des": des,
        "nid": nid,
        "phone": phone,
        "address": address,
        "payments": payments,
      });

      // 2. IMPORTANT: If name changed, sync with Daily Sales
      // This ensures that your 'delete' logic (which uses Name) doesn't break
      if (oldName != newName) {
        final salesSnap = await db.collection('daily_sales')
            .where('customerType', isEqualTo: 'debtor')
            .where('name', isEqualTo: oldName)
            .get();

        for (var doc in salesSnap.docs) {
          batch.update(doc.reference, {"name": newName});
        }
      }

      await batch.commit();
      await loadBodies();
      Get.snackbar("Updated", "Debtor information synchronized");
    } catch (e) {
      Get.snackbar("Update Error", e.toString());
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
}) async {
  gbIsLoading.value = true;
  try {
    // 1. Check if DailySalesController is actually there
    if (!Get.isRegistered<DailySalesController>()) {
      Get.put(DailySalesController()); // Initialize it if missing
    }
    final daily = Get.find<DailySalesController>();

    final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
    if (!debtorSnap.exists) throw "Debtor not found";
    
    final debtorData = debtorSnap.data()!;
    final debtorName = debtorData['name'] ?? 'Unknown';
    final typeLower = type.toLowerCase();
    Map<String, dynamic>? paymentMethod = selectedPaymentMethod;

    if (typeLower == 'credit') {
      final txRef = await db.collection('debatorbody').doc(debtorId).collection('transactions').add({
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
        transactionId: txRef.id,
      );
    } else {
      if (paymentMethod == null) {
        final payments = (debtorData['payments'] as List? ?? []);
        if (payments.isNotEmpty) paymentMethod = Map<String, dynamic>.from(payments.first);
      }

      final txRef = await db.collection('debatorbody').doc(debtorId).collection('transactions').add({
        'amount': amount,
        'note': note,
        'type': 'debit',
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await daily.applyDebtorPayment(
        debtorName,
        amount,
        paymentMethod ?? {},
        date: date,
        transactionId: txRef.id,
      );
    }

    // --- KEY FIX START ---
    
    // 1. Close the dialog FIRST
    if (Get.isDialogOpen ?? false) {
      Get.back(); 
    }

    // 2. Then show the success message
    Get.snackbar(
      "Success", 
      "Transaction recorded",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
    
    // --- KEY FIX END ---

  } catch (e) {
    print("AddTransaction Error: $e");
    Get.snackbar("Transaction Error", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
  } finally {
    gbIsLoading.value = false;
  }
}

  // ------------------------------------------------------------------
  // 4. ADD TRANSACTION (PURCHASE ONLY)
  // ------------------------------------------------------------------
  Future<void> addTransactionFORpurchase(
    String debtorId,
    double amount,
    String note,
    DateTime date, {
    Map<String, dynamic>? selectedPaymentMethod,
  }) async {
    gbIsLoading.value = true;
    try {
      final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
      if (!debtorSnap.exists) return;

      Map<String, dynamic>? paymentMethod = selectedPaymentMethod;
      if (paymentMethod == null) {
        final payments = (debtorSnap.data()?['payments'] as List? ?? []);
        if (payments.isNotEmpty) paymentMethod = Map<String, dynamic>.from(payments.first);
      }

      await db.collection('debatorbody').doc(debtorId).collection('transactions').add({
        'amount': amount,
        'note': note,
        'type': 'debit',
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar("Success", "Purchase transaction added to ledger");
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 5. DATA STREAMS
  // ------------------------------------------------------------------
  Stream<QuerySnapshot> loadTransactions(String id) {
    return db.collection('debatorbody').doc(id).collection('transactions').orderBy('date', descending: true).snapshots();
  }

  Stream<Map<String, dynamic>> summary(String id) {
    return loadTransactions(id).map((snap) {
      double credit = 0;
      double debit = 0;
      for (var doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['type'] == 'credit') credit += (d['amount'] as num?)?.toDouble() ?? 0;
        if (d['type'] == 'debit') debit += (d['amount'] as num?)?.toDouble() ?? 0;
      }
      return {'credit': credit, 'debit': debit, 'balance': credit - debit};
    });
  }

  // ------------------------------------------------------------------
  // 6. DELETE TRANSACTION (ATOMIC REVERSAL)
  // ------------------------------------------------------------------
  Future<void> deleteTransaction(String debtorId, String transactionId) async {
    final daily = Get.find<DailySalesController>();
    gbIsLoading.value = true;

    try {
      final txRef = db.collection('debatorbody').doc(debtorId).collection('transactions').doc(transactionId);
      final txSnap = await txRef.get();
      if (!txSnap.exists) return;

      final txType = txSnap.data()?['type'];
      final debtorSnap = await db.collection('debatorbody').doc(debtorId).get();
      final debtorName = debtorSnap['name'];

      final salesSnap = await db.collection('daily_sales')
          .where('customerType', isEqualTo: 'debtor')
          .where('name', isEqualTo: debtorName)
          .get();

      final WriteBatch batch = db.batch();

      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final double paidAmount = (data['paid'] as num?)?.toDouble() ?? 0;
        final List applied = List.from(data['appliedDebits'] ?? []);

        if (data['transactionId'] == transactionId) {
          batch.delete(doc.reference);
        } 
        else if (applied.any((e) => e['id'] == transactionId)) {
          final entry = applied.firstWhere((e) => e['id'] == transactionId);
          final double usedAmt = (entry['amount'] as num?)?.toDouble() ?? 0;
          
          applied.removeWhere((e) => e['id'] == transactionId);
          
          batch.update(doc.reference, {
            'paid': (paidAmount - usedAmt).clamp(0, double.infinity),
            'appliedDebits': applied,
            'isPaid': false,
            'paymentMethod': null, // As requested: clear payment method on reversal
          });
        }
      }

      await batch.commit();
      await txRef.delete();
      
      if (txType == 'credit') {
        await _normalizeDebits(debtorId, debtorName);
      }

      await daily.loadDailySales();
      Get.snackbar("Transaction Deleted", "Daily sales and ledger have been adjusted");
    } catch (e) {
      Get.snackbar("Deletion Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  /// Internal logic to re-process payments if an old bill is deleted
  Future<void> _normalizeDebits(String debtorId, String debtorName) async {
    final daily = Get.find<DailySalesController>();
    final debits = await db.collection('debatorbody').doc(debtorId).collection('transactions')
        .where('type', isEqualTo: 'debit').get();

    for (var doc in debits.docs) {
      final d = doc.data();
      final stale = await db.collection('daily_sales').where('transactionId', isEqualTo: doc.id).get();
      final b = db.batch();
      for (var s in stale.docs) b.delete(s.reference);
      await b.commit();

      await daily.addSale(
        name: debtorName,
        amount: (d['amount'] as num).toDouble(),
        customerType: 'debtor',
        isPaid: true,
        date: (d['date'] as Timestamp).toDate(),
        paymentMethod: d['paymentMethod'],
        source: 'debit',
        transactionId: doc.id,
      );
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

  Future<Uint8List> generatePDF(String debtorName, List<Map<String, dynamic>> transactions) async {
    final pdf = pw.Document();
    
    double credit = transactions.where((t) => t['type'] == 'credit').fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    double debit = transactions.where((t) => t['type'] == 'debit').fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("G-TEL ERP SYSTEM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
        ]),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
      ]),
      build: (context) => [
        pw.Text("Statement of Account: $debtorName", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _pdfStat("Total Purchased", credit, PdfColors.black),
          _pdfStat("Total Paid", debit, PdfColors.green900),
          _pdfStat("Outstanding", credit - debit, PdfColors.red900),
        ]),
        pw.SizedBox(height: 25),
        pw.Table.fromTextArray(
          headers: ["Date", "Type", "Notes", "Amount (Tk)"],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          cellHeight: 25,
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight},
          data: transactions.map((t) => [
            DateFormat('dd/MM/yy').format((t['date'] as Timestamp).toDate()),
            t['type'].toString().toUpperCase(),
            t['note'] ?? "",
            (t['amount'] as num).toStringAsFixed(2),
          ]).toList(),
        ),
      ]
    ));
    return pdf.save();
  }

  pw.Widget _pdfStat(String label, double val, PdfColor col) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.Text("Tk ${val.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: col)),
    ]);
  }
}