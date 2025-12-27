// ignore_for_file: deprecated_member_use

import 'dart:collection';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gtel_erp/Web%20Screen/Sales/model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class MonthlySalesController extends GetxController {
  final isLoading = false.obs;

  // SplayTreeMap keeps keys sorted automatically (e.g., 2025-01, 2025-02)
  final monthlyData = SplayTreeMap<String, MonthlySummary>().obs;

  @override
  void onInit() {
    super.onInit();
    fetchSales();
  }

  Future<void> fetchSales() async {
    try {
      isLoading.value = true;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('daily_sales')
              .orderBy('timestamp', descending: true)
              .get();

      // 1. Create your temporary sorted map
      final tempMap = SplayTreeMap<String, MonthlySummary>(
        (a, b) => b.compareTo(a),
      );

      for (var doc in snapshot.docs) {
        final sale = SaleModel.fromFirestore(doc);

        final monthKey = DateFormat('yyyy-MM').format(sale.timestamp);
        final dayKey = DateFormat('yyyy-MM-dd').format(sale.timestamp);

        tempMap.putIfAbsent(monthKey, () => MonthlySummary());

        final month = tempMap[monthKey]!;
        month.total += sale.amount;
        month.paid += sale.paid;

        month.daily.putIfAbsent(dayKey, () => DailySummary());
        month.daily[dayKey]!.total += sale.amount;
        month.daily[dayKey]!.paid += sale.paid;
      }

      // 2. Assign the whole map to the observable .value
      monthlyData.value = tempMap;
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch sales: $e");
    } finally {
      isLoading.value = false;
    }
  }
}

class MonthlySummary {
  double total = 0;
  double paid = 0;
  // Nested map for daily breakdown within the month
  Map<String, DailySummary> daily = SplayTreeMap<String, DailySummary>(
    (a, b) => b.compareTo(a),
  );

  double get pending => total - paid;
}

class DailySummary {
  double total = 0;
  double paid = 0;
  double get pending => total - paid;
}

Future<void> generateMonthlyPdf(String monthKey, MonthlySummary summary) async {
  final pdf = pw.Document();
  final primaryColor = PdfColors.blue900;
  final secondaryColor = PdfColors.blueGrey800;

  pdf.addPage(
    pw.MultiPage(
      // MultiPage is essential for long lists
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header:
          (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "G-TEL ERP: MONTHLY SALES",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    "Month: $monthKey",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, color: primaryColor),
            ],
          ),
      build: (context) {
        return [
          pw.SizedBox(height: 20),

          // SUMMARY SECTION
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatItem("Total Revenue", summary.total, PdfColors.black),
                _pdfStatItem(
                  "Total Collected",
                  summary.paid,
                  PdfColors.green800,
                ),
                _pdfStatItem(
                  "Total Pending",
                  summary.pending,
                  PdfColors.red800,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // TABLE BREAKDOWN
          pw.Table.fromTextArray(
            headers: ["Transaction Date", "Daily Sales (BDT)", "Status"],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: secondaryColor),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.center,
            },
            data:
                summary.daily.entries.map((e) {
                  final d = e.value;
                  return [
                    DateFormat(
                      'dd MMM yyyy (EEEE)',
                    ).format(DateTime.parse(e.key)),
                    d.total.toStringAsFixed(2),
                    d.pending <= 0 ? "CLEARED" : "DUE",
                  ];
                }).toList(),
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
            child: pw.Text(
              "End of Monthly Statement",
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

pw.Widget _pdfStatItem(String label, double value, PdfColor color) {
  return pw.Column(
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Text(
        "Tk ${value.toStringAsFixed(2)}",
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}
