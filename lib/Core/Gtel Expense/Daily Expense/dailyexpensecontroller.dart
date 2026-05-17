// ignore_for_file: deprecated_member_use, empty_catches

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../expensedatamodel.dart';
import '../Monthly Expense/montlyexpensecontroller.dart';

class DailyExpensesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final MonthlyExpensesController monthlyController;

  // --- STATE ---
  final RxList<ExpenseModel> dailyList = <ExpenseModel>[].obs;
  final RxDouble dailyTotal = 0.0.obs;
  final RxBool isLoading = false.obs;

  final Rx<DateTime> selectedDate =
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).obs;

  StreamSubscription? _expenseSubscription;

  // Document Key Format (e.g., "2026-03-27")
  String get selectedKey => DateFormat('yyyy-MM-dd').format(selectedDate.value);
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  // --- PAYMENT METHOD OPTIONS ---
  // Used by the UI to populate the method selector
  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'label': 'Cash',
      'icon': Icons.money_rounded,
      'color': Color(0xFF2E7D32), // Green
    },
    {
      'label': 'Bank',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF1565C0), // Blue
    },
    {
      'label': 'Bkash',
      'icon': Icons.phone_android_rounded,
      'color': Color(0xFFDF146E), // bKash Pink
    },
    {
      'label': 'Nagad',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFFF7931E), // Nagad Orange
    },
  ];

  @override
  void onInit() {
    super.onInit();
    monthlyController = Get.find<MonthlyExpensesController>();
    listenToDailyExpenses();
  }

  @override
  void onClose() {
    _expenseSubscription?.cancel();
    super.onClose();
  }

  // ==========================================
  // 1. REAL-TIME LISTENER
  // ==========================================
  void listenToDailyExpenses() {
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
            dailyTotal.value = items.fold(0.0, (sumv, e) => sumv + e.amount);
          },
          onError: (error) {
            debugPrint("Error listening to expenses: $error");
            Get.snackbar(
              "Sync Error",
              "Failed to sync live expenses.",
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          },
        );
  }

  void changeDate(DateTime date) {
    selectedDate.value = DateTime(date.year, date.month, date.day);
    listenToDailyExpenses();
  }

  // ==========================================
  // 2. ADD EXPENSE (WITH METHOD SUPPORT)
  // ==========================================
  Future<void> addDailyExpense(
    String name,
    double amount, {
    String note = '',
    DateTime? date,
    String method = 'Cash', // NEW: 'Cash' | 'Bank' | 'Bkash' | 'Nagad'
  }) async {
    try {
      isLoading.value = true;

      // 1. Determine exact time
      final now = DateTime.now();
      DateTime expenseDate = now;

      if (date != null) {
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          expenseDate = DateTime(
            date.year,
            date.month,
            date.day,
            now.hour,
            now.minute,
            now.second,
          );
        } else {
          expenseDate = date;
        }
      }

      // 2. Create the Model
      final newExpense = ExpenseModel(
        id: '',
        name: name,
        amount: amount,
        note: note,
        time: expenseDate,
      );

      final docKey = DateFormat('yyyy-MM-dd').format(expenseDate);
      final parentRef = _db.collection('daily_expenses').doc(docKey);
      final itemRef = parentRef.collection('items').doc();

      // 3. Build Firestore data with method field included
      final Map<String, dynamic> firestoreData = newExpense.toFirestore(
        isNewEntry: true,
      );
      firestoreData['method'] =
          method; // Persists 'Cash', 'Bank', 'Bkash', 'Nagad'

      // 4. SECURE WRITE BATCH
      WriteBatch batch = _db.batch();
      batch.set(parentRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(itemRef, firestoreData);

      await batch.commit();

      // 5. Update Monthly Controller
      await monthlyController.addToMonthly(amount: amount, date: expenseDate);

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Success",
        "Expense added via $method.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to add expense: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 3. DELETE EXPENSE
  // ==========================================
  Future<void> deleteDaily(String docId) async {
    try {
      isLoading.value = true;

      final docRef = _db
          .collection('daily_expenses')
          .doc(selectedKey)
          .collection('items')
          .doc(docId);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      final expense = ExpenseModel.fromFirestore(snapshot.id, snapshot.data()!);

      await docRef.delete();
      await monthlyController.removeFromMonthly(
        amount: expense.amount,
        date: expense.time,
      );

      Get.snackbar(
        "Deleted",
        "Expense record removed permanently.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to delete: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 4. ENTERPRISE PDF GENERATOR (WITH METHOD COLUMN)
  // ==========================================
  Future<void> generateDailyPDF() async {
    if (dailyList.isEmpty) {
      Get.snackbar(
        "Notice",
        "No expenses to generate a report for.",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMMM yyyy').format(selectedDate.value);

    final fontReg = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // --- HEADER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "DAILY EXPENSE REPORT",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 20,
                      color: PdfColors.blue900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    formattedDate,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 15),

              // --- TABLE (now includes Payment Method column) ---
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                headers: [
                  'Time',
                  'Expense Description',
                  'Notes / Details',
                  'Method', // NEW COLUMN
                  'Amount (BDT)',
                ],
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(1.5), // Method
                  4: const pw.FlexColumnWidth(2),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                },
                data:
                    dailyList
                        .map(
                          (e) => [
                            DateFormat('hh:mm a').format(e.time),
                            e.name,
                            e.note.isEmpty ? "-" : e.note,
                            // Read method from model; fallback gracefully
                            (e as dynamic).method ?? 'Cash',
                            _currencyFormat.format(e.amount),
                          ],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 15),

              // --- TOTAL SUMMARY ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL EXPENSES:",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          "BDT ${_currencyFormat.format(dailyTotal.value)}",
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

              // --- SIGNATURE BLOCK ---
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
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
              pw.SizedBox(height: 20),
              pw.Text(
                "System Generated Report - Strictly Confidential",
                style: pw.TextStyle(
                  font: fontReg,
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'Daily_Expenses_${DateFormat('dd_MMM_yyyy').format(selectedDate.value)}.pdf',
    );
  }
}