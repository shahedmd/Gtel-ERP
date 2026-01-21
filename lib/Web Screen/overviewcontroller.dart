import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'Expenses/dailycontroller.dart';
import 'Sales/controller.dart';

class OverviewController extends GetxController {
  final DailySalesController salesCtrl = Get.find<DailySalesController>();
  final DailyExpensesController expenseCtrl =
      Get.find<DailyExpensesController>();

  var selectedDate = DateTime.now().obs;

  // Observables
  RxDouble grossSales = 0.0.obs;
  RxDouble totalCollected = 0.0.obs;
  RxDouble totalExpenses = 0.0.obs;
  RxDouble netProfit = 0.0.obs; // Fixed typo from netProfiit
  RxDouble outstandingDebt = 0.0.obs;

  RxMap<String, double> paymentMethods =
      <String, double>{
        "cash": 0.0,
        "bkash": 0.0,
        "nagad": 0.0,
        "bank": 0.0,
      }.obs;

  @override
  void onInit() {
    super.onInit();
    _syncDateAndFetch();

    // Listeners
    ever(salesCtrl.salesList, (_) => _recalculate());
    ever(expenseCtrl.dailyList, (_) => _recalculate());
    ever(salesCtrl.totalSales, (_) => _recalculate());
    ever(expenseCtrl.dailyTotal, (_) => _recalculate());

    _recalculate();
  }

  void _syncDateAndFetch() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  // inside OverviewController

  void refreshData() {
    // 1. Re-trigger the fetch in sub-controllers
    _syncDateAndFetch();

    // 2. Recalculate local totals immediately
    _recalculate();

    // 3. Show a small snackbar to confirm
    Get.snackbar(
      "Refreshed",
      "Dashboard data updated",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _recalculate() {
    // 1. Fetch Totals
    grossSales.value = salesCtrl.totalSales.value;
    totalCollected.value = salesCtrl.paidAmount.value;
    outstandingDebt.value = salesCtrl.debtorPending.value;
    totalExpenses.value = expenseCtrl.dailyTotal.value.toDouble();

    // Net Calculation
    netProfit.value = totalCollected.value - totalExpenses.value;

    // 2. Calculate Payment Method Breakdown
    double cash = 0, bkash = 0, nagad = 0, bank = 0;

    for (var sale in salesCtrl.salesList) {
      var pm = sale.paymentMethod;

      if (pm != null) {
        String type = (pm['type'] ?? 'cash').toString().toLowerCase();

        if (type == 'multi') {
          cash += (double.tryParse(pm['cash'].toString()) ?? 0.0);
          bkash += (double.tryParse(pm['bkash'].toString()) ?? 0.0);
          nagad += (double.tryParse(pm['nagad'].toString()) ?? 0.0);
          bank += (double.tryParse(pm['bank'].toString()) ?? 0.0);
        } else {
          double amount = double.tryParse(sale.paid.toString()) ?? 0.0;
          if (type == 'bkash') {
            bkash += amount;
          }
          if (type == 'nagad') {
            nagad += amount;
          }
          if (type == 'bank') {
            bank += amount;
          } else {
            cash += amount;
          }
        }
      } else {
        cash += double.tryParse(sale.paid.toString()) ?? 0.0;
      }
    }

    paymentMethods["cash"] = cash;
    paymentMethods["bkash"] = bkash;
    paymentMethods["nagad"] = nagad;
    paymentMethods["bank"] = bank;
    paymentMethods.refresh();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate.value = date;
    _syncDateAndFetch();
    _recalculate();
  }

  // --- PDF GENERATION LOGIC ---
  Future<void> generateAndPrintPdf() async {
    final doc = pw.Document();

    // Formatting helpers
    final dateStr = DateFormat('dd MMMM yyyy').format(selectedDate.value);
    final currency = NumberFormat("#,##0", "en_US");

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Daily Cash & Expense Report",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfStatItem(
                      "Total Collected",
                      totalCollected.value,
                      PdfColors.green,
                    ),
                    _pdfStatItem(
                      "Total Expenses",
                      totalExpenses.value,
                      PdfColors.red,
                    ),
                    _pdfStatItem(
                      "Net Cash Balance",
                      netProfit.value,
                      PdfColors.blue,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Breakdown Table
              pw.Text(
                "Cash Distribution Breakdown",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              // ignore: deprecated_member_use
              pw.Table.fromTextArray(
                headers: ['Source', 'Amount'],
                data: [
                  ['Cash (Hand)', currency.format(paymentMethods['cash'])],
                  ['bKash', currency.format(paymentMethods['bkash'])],
                  ['Nagad', currency.format(paymentMethods['nagad'])],
                  ['Bank Transfer', currency.format(paymentMethods['bank'])],
                  ['TOTAL', currency.format(totalCollected.value)],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                "Generated from ERP System",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  pw.Widget _pdfStatItem(String title, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.Text(
          amount.toStringAsFixed(0),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
