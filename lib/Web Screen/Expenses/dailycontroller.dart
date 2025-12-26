// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'expensemodel.dart';
import 'monthlycontroller.dart';

class DailyExpensesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  final RxList<ExpenseModel> dailyList = <ExpenseModel>[].obs;
  final RxInt dailyTotal = 0.obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  StreamSubscription? _expenseSubscription;
  late final MonthlyExpensesController monthlyController;

  // Formatting Key
  String get selectedKey => DateFormat('yyyy-MM-dd').format(selectedDate.value);

  @override
  void onInit() {
    super.onInit();
    monthlyController = Get.find<MonthlyExpensesController>();
    _listenToDailyExpenses();
  }

  @override
  void onClose() {
    _expenseSubscription?.cancel(); // Essential for long-term performance
    super.onClose();
  }

  void _listenToDailyExpenses() {
    // Cancel existing listener if date changes
    _expenseSubscription?.cancel();

    _expenseSubscription = _db
        .collection('daily_expenses')
        .doc(selectedKey)
        .collection('items')
        .orderBy('time', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final items =
                snapshot.docs
                    .map(
                      (doc) => ExpenseModel.fromFirestore(doc.id, doc.data()),
                    )
                    .toList();

            dailyList.assignAll(items);
            dailyTotal.value = items.fold(
              0,
              (sumvalue, e) => sumvalue + e.amount,
            );
          },
          onError: (error) {
            debugPrint("Error listening to expenses: $error");
          },
        );
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    _listenToDailyExpenses();
  }

  // --- ADD EXPENSE ---
  Future<void> addDailyExpense(
    String name,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    try {
      isLoading.value = true;
      final expenseDate = date ?? DateTime.now();
      final docKey = DateFormat('yyyy-MM-dd').format(expenseDate);

      final parentDoc = _db.collection('daily_expenses').doc(docKey);

      // Using a batch/transaction style logic (Manually)
      await parentDoc.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await parentDoc.collection('items').add({
        'name': name,
        'amount': amount,
        'note': note,
        'time': Timestamp.fromDate(expenseDate),
      });

      // Update Monthly Controller
      await monthlyController.addToMonthly(amount: amount, date: expenseDate);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        "Success",
        "Expense added successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to add expense: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- DELETE EXPENSE ---
  Future<void> deleteDaily(String docId) async {
    try {
      isLoading.value = true;

      // 1. Get a reference to the specific daily item
      final docRef = _db
          .collection('daily_expenses')
          .doc(selectedKey)
          .collection('items')
          .doc(docId);

      // 2. Fetch the data before deleting so we know the amount and date
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final expense = ExpenseModel.fromFirestore(snapshot.id, snapshot.data()!);

      // 3. Delete from Daily Expenses
      await docRef.delete();

      // 4. Update the Monthly Total (Subtracting the amount)
      await monthlyController.removeFromMonthly(
        amount: expense.amount,
        date: expense.time,
      );

      Get.snackbar("Success", "Entry removed and monthly total updated.");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- PROFESSIONAL POS PDF GENERATION ---
  Future<void> generateDailyPDF() async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMMM yyyy').format(selectedDate.value);

    // Style Constants
    final primaryColor = PdfColors.blue900;
    final secondaryColor = PdfColors.grey800;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "G-TEL ERP SYSTEM",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        "Daily Transaction Report",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Date: $formattedDate",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "Generated: ${DateFormat('hh:mm a').format(DateTime.now())}",
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.SizedBox(height: 20),

              // Data Table
              pw.Table.fromTextArray(
                headers: ['Time', 'Description', 'Note', 'Amount (BDT)'],
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                ),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
                data:
                    dailyList
                        .map(
                          (e) => [
                            DateFormat('hh:mm a').format(e.time),
                            e.name,
                            e.note,
                            e.amount.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),

              // Total Summary
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "GRAND TOTAL:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          "BDT ${dailyTotal.value.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Footer
              pw.SizedBox(height: 50),
              pw.Center(
                child: pw.Text(
                  "This is a computer-generated report. No signature required.",
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
