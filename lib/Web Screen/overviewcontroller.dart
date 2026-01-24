import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Import your existing controllers
import 'Expenses/dailycontroller.dart';
import 'Sales/controller.dart';

/// Standard Model for the Ledger UI
class LedgerItem {
  final DateTime time;
  final String title; // e.g. "Customer Name" or "Loan from Boss"
  final String subtitle; // e.g. "Cash - Sale" or "Bank - Deposit"
  final double amount;
  final String type; // 'income' or 'expense'

  LedgerItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
  });
}

class OverviewController extends GetxController {
  final DailySalesController salesCtrl = Get.find<DailySalesController>();
  final DailyExpensesController expenseCtrl =
      Get.find<DailyExpensesController>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- STATE ---
  var selectedDate = DateTime.now().obs;

  // To handle the subscription for external cash (Loans/Advances)
  StreamSubscription? _ledgerSubscription;
  RxList<Map<String, dynamic>> externalLedgerData =
      <Map<String, dynamic>>[].obs;

  // Header Stats
  RxDouble totalCashIn = 0.0.obs;
  RxDouble totalCashOut = 0.0.obs;
  RxDouble netCashBalance = 0.0.obs;

  // Ledger Lists (UI Columns)
  RxList<LedgerItem> cashInList = <LedgerItem>[].obs;
  RxList<LedgerItem> cashOutList = <LedgerItem>[].obs;

  // Chart Data
  RxMap<String, double> methodBreakdown =
      <String, double>{
        "Cash": 0.0,
        "Bkash": 0.0,
        "Nagad": 0.0,
        "Bank": 0.0,
      }.obs;

  @override
  void onInit() {
    super.onInit();
    // 1. Initial Sync
    _syncDateToSubControllers();
    _listenToExternalLedger(); // Start listening to cash_ledger

    // 2. Listeners to trigger recalculation
    ever(salesCtrl.salesList, (_) => _processLedgerData());
    ever(expenseCtrl.dailyList, (_) => _processLedgerData());
    ever(
      externalLedgerData,
      (_) => _processLedgerData(),
    ); // Trigger when manual adds change

    // 3. Date Change Listener
    ever(selectedDate, (_) {
      _syncDateToSubControllers();
      _listenToExternalLedger(); // Re-bind listener for new date
    });
  }

  @override
  void onClose() {
    _ledgerSubscription?.cancel();
    super.onClose();
  }

  // --- ACTIONS ---

  void pickDate(DateTime date) {
    selectedDate.value = date;
  }

  void refreshData() {
    _syncDateToSubControllers();
    _listenToExternalLedger();
    Get.snackbar(
      "Refreshed",
      "Ledger synced.",
      duration: const Duration(seconds: 1),
    );
  }

  // --- LOGIC ---

  void _syncDateToSubControllers() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  // Listen to 'cash_ledger' for the specific selected date
  void _listenToExternalLedger() {
    _ledgerSubscription?.cancel();

    DateTime start = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      selectedDate.value.day,
    );
    DateTime end = start.add(const Duration(days: 1));

    _ledgerSubscription = _db
        .collection('cash_ledger')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) {
          externalLedgerData.assignAll(snap.docs.map((e) => e.data()).toList());
        });
  }

  void _processLedgerData() {
    double tIn = 0;
    double tOut = 0;

    // Reset Breakdown
    Map<String, double> tempBreakdown = {
      "Cash": 0.0,
      "Bkash": 0.0,
      "Nagad": 0.0,
      "Bank": 0.0,
    };

    List<LedgerItem> tempIn = [];
    List<LedgerItem> tempOut = [];

    // ==========================================
    // 1. PROCESS SALES (Cash In)
    // ==========================================
    for (var sale in salesCtrl.salesList) {
      double paid = double.tryParse(sale.paid.toString()) ?? 0.0;

      if (paid > 0) {
        tIn += paid;

        // Analyze Payment Method
        var pm = sale.paymentMethod;
        String methodStr = "Cash";

        if (pm != null) {
          String type = (pm['type'] ?? 'cash').toString().toLowerCase();

          if (type == 'multi') {
            double c = double.tryParse(pm['cash'].toString()) ?? 0;
            double b = double.tryParse(pm['bkash'].toString()) ?? 0;
            double n = double.tryParse(pm['nagad'].toString()) ?? 0;
            double bk = double.tryParse(pm['bank'].toString()) ?? 0;

            if (c > 0) tempBreakdown["Cash"] = (tempBreakdown["Cash"] ?? 0) + c;
            if (b > 0) {
              tempBreakdown["Bkash"] = (tempBreakdown["Bkash"] ?? 0) + b;
            }
            if (n > 0) {
              tempBreakdown["Nagad"] = (tempBreakdown["Nagad"] ?? 0) + n;
            }
            if (bk > 0) {
              tempBreakdown["Bank"] = (tempBreakdown["Bank"] ?? 0) + bk;
            }
            methodStr = "Multi-Pay";
          } else {
            if (type.contains('bkash')) {
              tempBreakdown["Bkash"] = (tempBreakdown["Bkash"] ?? 0) + paid;
              methodStr = "Bkash";
            } else if (type.contains('nagad')) {
              tempBreakdown["Nagad"] = (tempBreakdown["Nagad"] ?? 0) + paid;
              methodStr = "Nagad";
            } else if (type.contains('bank')) {
              tempBreakdown["Bank"] = (tempBreakdown["Bank"] ?? 0) + paid;
              methodStr = "Bank";
            } else {
              tempBreakdown["Cash"] = (tempBreakdown["Cash"] ?? 0) + paid;
              methodStr = "Cash";
            }
          }
        } else {
          tempBreakdown["Cash"] = (tempBreakdown["Cash"] ?? 0) + paid;
        }

        tempIn.add(
          LedgerItem(
            time: sale.timestamp,
            title: sale.name,
            subtitle: "$methodStr (Sale)",
            amount: paid,
            type: 'income',
          ),
        );
      }
    }

    // ==========================================
    // 2. PROCESS EXTERNAL LEDGER (Loans/Withdrawals)
    // ==========================================
    for (var item in externalLedgerData) {
      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      String type = item['type'] ?? 'deposit'; // 'deposit' or 'withdraw'
      String method = (item['method'] ?? 'cash').toString();
      String desc = item['description'] ?? 'Manual Entry';
      DateTime time = (item['timestamp'] as Timestamp).toDate();

      // Normalize Method Name for Chart
      String chartKey = "Cash";
      if (method.toLowerCase().contains('bkash')) {
        chartKey = "Bkash";
      }
      if (method.toLowerCase().contains('nagad')) {
        chartKey = "Nagad";
      }
      if (method.toLowerCase().contains('bank')) {
        chartKey = "Bank";
      }

      if (type == 'deposit') {
        // --- CASH IN ---
        tIn += amt;
        // Add to chart breakdown
        tempBreakdown[chartKey] = (tempBreakdown[chartKey] ?? 0) + amt;

        tempIn.add(
          LedgerItem(
            time: time,
            title: desc,
            subtitle: "$chartKey (Manual Add)",
            amount: amt,
            type: 'income',
          ),
        );
      } else {
        // --- CASH OUT ---
        tOut += amt;
        // Note: We don't usually deduct from 'Collection Breakdown' chart
        // because that chart shows source of funds. Withdrawals are just outflows.

        tempOut.add(
          LedgerItem(
            time: time,
            title: desc,
            subtitle: "$chartKey (Withdrawal)",
            amount: amt,
            type: 'expense',
          ),
        );
      }
    }

    // ==========================================
    // 3. PROCESS EXPENSES (Cash Out)
    // ==========================================
    for (var expense in expenseCtrl.dailyList) {
      double amt = expense.amount.toDouble();
      tOut += amt;

      tempOut.add(
        LedgerItem(
          time: expense.time,
          title: expense.name,
          subtitle: expense.note.isNotEmpty ? expense.note : "General Expense",
          amount: amt,
          type: 'expense',
        ),
      );
    }

    // Sort Lists Chronologically
    tempIn.sort((a, b) => a.time.compareTo(b.time));
    tempOut.sort((a, b) => a.time.compareTo(b.time));

    // Update Observables
    totalCashIn.value = tIn;
    totalCashOut.value = tOut;
    netCashBalance.value = tIn - tOut;

    cashInList.assignAll(tempIn);
    cashOutList.assignAll(tempOut);
    methodBreakdown.value = tempBreakdown;
  }

  // --- PDF GENERATION ---
  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();

    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final timeFormat = DateFormat('hh:mm a');
    final currency = NumberFormat("#,##0", "en_US");

    final pdfTheme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.nunitoRegular(),
      bold: await PdfGoogleFonts.nunitoBold(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pdfTheme,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DAILY CASH LEDGER",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "G-TEL ERP System - Consolidated Report",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        dateStr,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.Text(
                        "Net Balance: ${currency.format(netCashBalance.value)}",
                        style: pw.TextStyle(
                          color:
                              netCashBalance.value >= 0
                                  ? PdfColors.green700
                                  : PdfColors.red700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Summary Stats
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                color: PdfColors.grey50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatItem(
                    "Total Sale/Debit",
                    totalCashIn.value,
                    PdfColors.green800,
                    currency,
                  ),
                  pw.Container(width: 1, height: 20, color: PdfColors.grey400),
                  _pdfStatItem(
                    "Total Expense/Credit",
                    totalCashOut.value,
                    PdfColors.red800,
                    currency,
                  ),
                  pw.Container(width: 1, height: 20, color: PdfColors.grey400),
                  _pdfStatItem(
                    "Net Cash",
                    netCashBalance.value,
                    PdfColors.black,
                    currency,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Source Breakdown
            pw.Text(
              "Income Source Breakdown (Sales + Advances)",
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children:
                  methodBreakdown.entries.map((e) {
                    return pw.Column(
                      children: [
                        pw.Text(
                          e.key.toUpperCase(),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          currency.format(e.value),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
            pw.SizedBox(height: 25),

            // TWO COLUMN LEDGER
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: CASH IN (Sales + Loans)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(5),
                        color: PdfColors.green50,
                        child: pw.Text(
                          "INCOME (SALES & ADVANCE)",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      _buildPdfTable(cashInList, timeFormat, currency),
                    ],
                  ),
                ),

                pw.SizedBox(width: 15),

                // RIGHT COLUMN: CASH OUT (Expenses + Withdrawals)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(5),
                        color: PdfColors.red50,
                        child: pw.Text(
                          "OUTFLOW (EXPENSE & WITHDRAW)",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      _buildPdfTable(cashOutList, timeFormat, currency),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              "Generated from G-TEL ERP",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  pw.Widget _buildPdfTable(
    List<LedgerItem> items,
    DateFormat timeFmt,
    NumberFormat moneyFmt,
  ) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          "No transactions",
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children:
          items.map((item) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.title,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        "${timeFmt.format(item.time)} • ${item.subtitle}",
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    moneyFmt.format(item.amount),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  pw.Widget _pdfStatItem(
    String title,
    double amount,
    PdfColor color,
    NumberFormat fmt,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          fmt.format(amount),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
