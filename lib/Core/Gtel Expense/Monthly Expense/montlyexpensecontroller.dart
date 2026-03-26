// ignore_for_file: deprecated_member_use, avoid_types_as_parameter_names, unnecessary_cast

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ==========================================
// 1. DATA MODELS (Upgraded to Double for Financials)
// ==========================================
class DailySummary {
  final String date;
  double total; // Upgraded to double

  DailySummary({required this.date, required this.total});

  factory DailySummary.fromMap(Map<String, dynamic> map) => DailySummary(
    date: map['date']?.toString() ?? '',
    total: double.tryParse(map['total'].toString()) ?? 0.0,
  );

  Map<String, dynamic> toMap() => {'date': date, 'total': total};
}

class MonthlyExpenseModel {
  final String monthKey;
  final double total; // Upgraded to double
  final List<DailySummary> items;

  MonthlyExpenseModel({
    required this.monthKey,
    required this.total,
    required this.items,
  });

  factory MonthlyExpenseModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return MonthlyExpenseModel(
      monthKey: id,
      total: double.tryParse(data['total'].toString()) ?? 0.0,
      items:
          (data['items'] as List? ?? [])
              .map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
    );
  }
}

// ==========================================
// 2. MAIN CONTROLLER
// ==========================================
class MonthlyExpensesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<MonthlyExpenseModel> monthlyList = <MonthlyExpenseModel>[].obs;
  final RxDouble grandTotalAllMonths = 0.0.obs; // Upgraded to double
  final RxBool isLoading = false.obs;

  StreamSubscription? _monthlySubscription;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  @override
  void onInit() {
    super.onInit();
    fetchMonthlyExpenses();
  }

  @override
  void onClose() {
    _monthlySubscription?.cancel();
    super.onClose();
  }

  // ------------------------------------------------------------------
  // REAL-TIME LISTENER
  // ------------------------------------------------------------------
  void fetchMonthlyExpenses() {
    _monthlySubscription = _db
        .collection('monthly_expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final months =
              snapshot.docs
                  .map(
                    (doc) =>
                        MonthlyExpenseModel.fromFirestore(doc.id, doc.data()),
                  )
                  .toList();

          monthlyList.assignAll(months);
          grandTotalAllMonths.value = months.fold(
            0.0,
            (sum, m) => sum + m.total,
          );
        });
  }

  // ------------------------------------------------------------------
  // ADD TO MONTHLY (ATOMIC TRANSACTION)
  // ------------------------------------------------------------------
  Future<void> addToMonthly({
    required double amount,
    required DateTime date,
  }) async {
    final monthKey = "${DateFormat('MMM').format(date)}-${date.year}";
    final dayKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db.collection('monthly_expenses').doc(monthKey);

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'total': amount,
          'items': [
            {'date': dayKey, 'total': amount},
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        double currentTotal = double.tryParse(data['total'].toString()) ?? 0.0;
        List<dynamic> itemsRaw = List.from(data['items'] ?? []);

        List<DailySummary> items =
            itemsRaw
                .map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e)))
                .toList();

        int index = items.indexWhere((e) => e.date == dayKey);
        if (index >= 0) {
          items[index].total += amount;
        } else {
          items.add(DailySummary(date: dayKey, total: amount));
        }

        // Sort items so they appear in chronological order inside the document
        items.sort((a, b) => b.date.compareTo(a.date));

        transaction.update(docRef, {
          'total': currentTotal + amount,
          'items': items.map((e) => e.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ------------------------------------------------------------------
  // REMOVE FROM MONTHLY (ATOMIC TRANSACTION)
  // ------------------------------------------------------------------
  Future<void> removeFromMonthly({
    required double amount,
    required DateTime date,
  }) async {
    final monthKey = "${DateFormat('MMM').format(date)}-${date.year}";
    final dayKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db.collection('monthly_expenses').doc(monthKey);

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      double currentTotal = double.tryParse(data['total'].toString()) ?? 0.0;
      List<dynamic> itemsRaw = List.from(data['items'] ?? []);
      List<DailySummary> items =
          itemsRaw
              .map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e)))
              .toList();

      int index = items.indexWhere((e) => e.date == dayKey);
      if (index >= 0) {
        items[index].total -= amount;

        // If daily total becomes 0 or less, remove the date entry entirely to save space
        if (items[index].total <= 0.01) {
          items.removeAt(index);
        }

        double newTotal = currentTotal - amount;
        if (newTotal < 0) newTotal = 0.0;

        transaction.update(docRef, {
          'total': newTotal,
          'items': items.map((e) => e.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ------------------------------------------------------------------
  // PROFESSIONAL ERP PDF REPORT
  // ------------------------------------------------------------------
  Future<void> generateMonthlyPDF(String monthKey) async {
    try {
      isLoading.value = true;
      final monthData = monthlyList.firstWhere((m) => m.monthKey == monthKey);

      final pdf = pw.Document();
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
                      "MONTHLY EXPENSE SUMMARY",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 20,
                        color: PdfColors.blue900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.Text(
                      "Month: $monthKey",
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

                // --- TABLE ---
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
                  headers: ['Date', 'Day', 'Total Expenditure (BDT)'],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                  },
                  data:
                      monthData.items.map((e) {
                        final dateObj = DateTime.parse(e.date);
                        return [
                          DateFormat('dd MMM yyyy').format(dateObj),
                          DateFormat('EEEE').format(dateObj),
                          _currencyFormat.format(e.total),
                        ];
                      }).toList(),
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
                            "MONTH TOTAL:",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            "BDT ${_currencyFormat.format(monthData.total)}",
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
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}",
                      style: pw.TextStyle(
                        font: fontReg,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
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
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Monthly_Expenses_$monthKey.pdf',
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Could not generate PDF: $e",
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
      );
    } finally {
      isLoading.value = false;
    }
  }
}