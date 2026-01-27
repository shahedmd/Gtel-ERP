// ignore_for_file: empty_catches

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
  final String title;
  final String subtitle;
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
  var isLoadingHistory = false.obs;

  // To handle the subscription for external cash (Loans/Advances)
  StreamSubscription? _ledgerSubscription;
  RxList<Map<String, dynamic>> externalLedgerData =
      <Map<String, dynamic>>[].obs;

  // --- BALANCE STATS ---
  RxDouble previousCash = 0.0.obs; // Cash before 12:00 AM of selected date
  RxDouble totalCashIn = 0.0.obs; // Today's In
  RxDouble totalCashOut = 0.0.obs; // Today's Out
  RxDouble netCashBalance = 0.0.obs; // Today's Net (In - Out)
  RxDouble closingCash = 0.0.obs; // Previous + Net

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
    _fetchPreviousBalance(); // Calculate history once
    _listenToExternalLedger();

    // 2. Listeners
    ever(salesCtrl.salesList, (_) => _processLedgerData());
    ever(expenseCtrl.dailyList, (_) => _processLedgerData());
    ever(externalLedgerData, (_) => _processLedgerData());

    // 3. Date Change Listener
    ever(selectedDate, (_) {
      _syncDateToSubControllers();
      _fetchPreviousBalance(); // Recalculate history for new date
      _listenToExternalLedger();
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
    _fetchPreviousBalance();
    _listenToExternalLedger();
    Get.snackbar(
      "Refreshed",
      "Ledger & Balances synced.",
      duration: const Duration(seconds: 1),
    );
  }

  // --- LOGIC ---

  void _syncDateToSubControllers() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  // Calculate accumulated cash from beginning of time until [selectedDate] 00:00:00
  Future<void> _fetchPreviousBalance() async {
    isLoadingHistory.value = true;
    try {
      DateTime startOfDay = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );

      // 1. Fetch Past Sales
      // Note: For optimal performance on large datasets, consider maintaining a 'daily_closing' collection.
      // Here we aggregate manually based on existing structure.
      var salesSnap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastSales = 0.0;
      for (var doc in salesSnap.docs) {
        pastSales += (double.tryParse(doc['paid'].toString()) ?? 0);
      }

      // 2. Fetch Past Ledger (Add/Withdraw)
      var ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastLedgerSum = 0.0;
      for (var doc in ledgerSnap.docs) {
        double amt = double.tryParse(doc['amount'].toString()) ?? 0;
        if (doc['type'] == 'withdraw') {
          pastLedgerSum -= amt;
        } else {
          pastLedgerSum += amt;
        }
      }

      // 3. Fetch Past Expenses
      // Using collectionGroup to get all items from all daily_expenses subcollections
      var expenseSnap =
          await _db
              .collectionGroup('items')
              .where('time', isLessThan: startOfDay)
              .get();

      double pastExpenses = 0.0;
      for (var doc in expenseSnap.docs) {
        pastExpenses += (double.tryParse(doc['amount'].toString()) ?? 0);
      }

      previousCash.value = (pastSales + pastLedgerSum) - pastExpenses;

      // Trigger recalculation of closing balance
      _processLedgerData();
    } catch (e) {
    } finally {
      isLoadingHistory.value = false;
    }
  }

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

    Map<String, double> tempBreakdown = {
      "Cash": 0.0,
      "Bkash": 0.0,
      "Nagad": 0.0,
      "Bank": 0.0,
    };

    List<LedgerItem> tempIn = [];
    List<LedgerItem> tempOut = [];

    // 1. SALES
    for (var sale in salesCtrl.salesList) {
      double paid = double.tryParse(sale.paid.toString()) ?? 0.0;
      if (paid > 0) {
        tIn += paid;
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

    // 2. EXTERNAL LEDGER
    for (var item in externalLedgerData) {
      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      String type = item['type'] ?? 'deposit';
      String method = (item['method'] ?? 'cash').toString();
      String desc = item['description'] ?? 'Manual Entry';
      DateTime time = (item['timestamp'] as Timestamp).toDate();

      String chartKey = "Cash";
      if (method.toLowerCase().contains('bkash')) chartKey = "Bkash";
      if (method.toLowerCase().contains('nagad')) chartKey = "Nagad";
      if (method.toLowerCase().contains('bank')) chartKey = "Bank";

      if (type == 'deposit') {
        tIn += amt;
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
        tOut += amt;
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

    // 3. EXPENSES
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

    tempIn.sort((a, b) => a.time.compareTo(b.time));
    tempOut.sort((a, b) => a.time.compareTo(b.time));

    totalCashIn.value = tIn;
    totalCashOut.value = tOut;
    netCashBalance.value = tIn - tOut;

    // Update Closing Cash (Previous + Today's Net)
    closingCash.value = previousCash.value + (tIn - tOut);

    cashInList.assignAll(tempIn);
    cashOutList.assignAll(tempOut);
    methodBreakdown.value = tempBreakdown;
  }

  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final timeFormat = DateFormat('hh:mm a');
    final currency = NumberFormat("#,##0.00", "en_US");

    // Load fonts
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),

        // ✅ FIX 1: Move Footer logic here.
        // This places the signature and page numbers at the bottom of EVERY page.
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Authorized Signature",
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                  ),
                  pw.Text(
                    "Page ${context.pageNumber} of ${context.pagesCount}",
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },

        build: (pw.Context context) {
          return [
            // 1. Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "DAILY CASH STATEMENT",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.Text(
                      "G-TEL ERP SYSTEM",
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      dateStr,
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                    pw.Text(
                      "Generated: ${DateFormat('hh:mm a').format(DateTime.now())}",
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // 2. Balance Sheet
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfBalanceColumn(
                    "Previous Balance",
                    previousCash.value,
                    fontBold,
                    currency,
                    PdfColors.grey700,
                  ),
                  pw.Text(
                    "+",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.grey500,
                    ),
                  ),
                  _pdfBalanceColumn(
                    "Today's Net Income",
                    netCashBalance.value,
                    fontBold,
                    currency,
                    netCashBalance.value >= 0
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                  pw.Text(
                    "=",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.grey500,
                    ),
                  ),
                  _pdfBalanceColumn(
                    "TOTAL CLOSING CASH",
                    closingCash.value,
                    fontBold,
                    currency,
                    PdfColors.blue900,
                    isLarge: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 3. Stats
            pw.Row(
              children: [
                pw.Expanded(
                  child: _pdfStatBox(
                    "Total Collected",
                    totalCashIn.value,
                    PdfColors.green50,
                    PdfColors.green800,
                    fontBold,
                    currency,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _pdfStatBox(
                    "Total Expenses",
                    totalCashOut.value,
                    PdfColors.red50,
                    PdfColors.red800,
                    fontBold,
                    currency,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 4. Sources
            pw.Text(
              "Collection Sources",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
            pw.Divider(thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children:
                  methodBreakdown.entries.map((e) {
                    if (e.value == 0) return pw.Container();
                    return pw.Row(
                      children: [
                        pw.Container(
                          width: 6,
                          height: 6,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.black,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          "${e.key}: ${currency.format(e.value)}",
                          style: pw.TextStyle(font: fontRegular, fontSize: 9),
                        ),
                      ],
                    );
                  }).toList(),
            ),
            pw.SizedBox(height: 20),

            // 5. Table
            pw.Text(
              "TRANSACTION DETAILS",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 5),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold, align: pw.TextAlign.center),
                    _pdfCell("Description", fontBold),
                    _pdfCell("Type", fontBold),
                    _pdfCell("Credit (+)", fontBold, align: pw.TextAlign.right),
                    _pdfCell("Debit (-)", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                // Ensure this returns List<pw.TableRow>
                ..._generateMergedLedgerRows(
                  cashInList,
                  cashOutList,
                  timeFormat,
                  currency,
                  fontRegular,
                ),
              ],
            ),
            // ✅ FIX 2: Spacer() and Footer removed from here
          ];
        },
      ),
    );

    // This opens the Native Print Preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      // Optional: Give the document a name for when they save it
      name: 'Daily_Statement_${dateStr.replaceAll(' ', '_')}',
    );
  }

  // Helper to merge In and Out lists for a single chronological table
  List<pw.TableRow> _generateMergedLedgerRows(
    List<LedgerItem> inList,
    List<LedgerItem> outList,
    DateFormat tFmt,
    NumberFormat mFmt,
    pw.Font font,
  ) {
    List<LedgerItem> all = [...inList, ...outList];
    all.sort((a, b) => a.time.compareTo(b.time));

    return all.map((item) {
      bool isIncome = item.type == 'income';
      return pw.TableRow(
        children: [
          _pdfCell(
            tFmt.format(item.time),
            font,
            align: pw.TextAlign.center,
            size: 8,
          ),
          _pdfCell("${item.title}\n${item.subtitle}", font, size: 8),
          _pdfCell(isIncome ? "Income" : "Expense", font, size: 8),
          _pdfCell(
            isIncome ? mFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
            size: 8,
            color: isIncome ? PdfColors.green900 : PdfColors.black,
          ),
          _pdfCell(
            !isIncome ? mFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
            size: 8,
            color: !isIncome ? PdfColors.red900 : PdfColors.black,
          ),
        ],
      );
    }).toList();
  }

  pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    double size = 9,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: size, color: color),
      ),
    );
  }

  pw.Widget _pdfBalanceColumn(
    String label,
    double amount,
    pw.Font font,
    NumberFormat fmt,
    PdfColor color, {
    bool isLarge = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          fmt.format(amount),
          style: pw.TextStyle(
            font: font,
            fontSize: isLarge ? 14 : 11,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfStatBox(
    String title,
    double val,
    PdfColor bg,
    PdfColor txtColor,
    pw.Font font,
    NumberFormat fmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, color: txtColor)),
          pw.Text(
            fmt.format(val),
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: txtColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
