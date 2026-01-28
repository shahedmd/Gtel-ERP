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

  // Subscription for external cash (Loans/Advances/Manual Adds)
  StreamSubscription? _ledgerSubscription;
  RxList<Map<String, dynamic>> externalLedgerData =
      <Map<String, dynamic>>[].obs;

  // --- BALANCE STATS ---
  RxDouble previousCash = 0.0.obs;
  RxDouble totalCashIn = 0.0.obs;
  RxDouble totalCashOut = 0.0.obs;
  RxDouble netCashBalance = 0.0.obs;
  RxDouble closingCash = 0.0.obs;

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
    _syncDateToSubControllers();
    _fetchPreviousBalance();
    _listenToExternalLedger();

    // Listeners
    ever(salesCtrl.salesList, (_) => _processLedgerData());
    ever(expenseCtrl.dailyList, (_) => _processLedgerData());
    ever(externalLedgerData, (_) => _processLedgerData());

    ever(selectedDate, (_) {
      _syncDateToSubControllers();
      _fetchPreviousBalance();
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

  Future<void> _fetchPreviousBalance() async {
    isLoadingHistory.value = true;
    try {
      DateTime startOfDay = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );

      // 1. Past Sales
      var salesSnap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isLessThan: startOfDay)
              .get();
      double pastSales = 0.0;
      for (var doc in salesSnap.docs) {
        pastSales += (double.tryParse(doc['paid'].toString()) ?? 0);
      }

      // 2. Past Ledger (Add/Withdraw)
      var ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where('timestamp', isLessThan: startOfDay)
              .get();
      double pastLedgerSum = 0.0;
      for (var doc in ledgerSnap.docs) {
        // Skip linked duplicates to avoid double counting history
        if (doc.data().containsKey('linkedTxId') ||
            doc.data().containsKey('linkedInvoiceId')) {
          continue;
        }

        double amt = double.tryParse(doc['amount'].toString()) ?? 0;
        if (doc['type'] == 'withdraw') {
          pastLedgerSum -= amt;
        } else {
          pastLedgerSum += amt;
        }
      }

      // 3. Past Expenses
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
          // Filter out duplicates (Sales/Debtor Payments) locally
          var rawList = snap.docs.map((e) => e.data()).toList();
          var filtered =
              rawList.where((data) {
                return !data.containsKey('linkedTxId') &&
                    !data.containsKey('linkedInvoiceId') &&
                    !data.containsKey('linkedDebtorId') &&
                    data['source'] != 'pos_sale' &&
                    data['source'] != 'advance_payment';
              }).toList();

          externalLedgerData.assignAll(filtered);
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

    // ---------------------------------------------------------
    // 1. SALES (Income)
    // ---------------------------------------------------------
    for (var sale in salesCtrl.salesList) {
      double paid = double.tryParse(sale.paid.toString()) ?? 0.0;
      if (paid > 0) {
        tIn += paid;

        // --- BREAKDOWN LOGIC ---
        var pm = sale.paymentMethod;
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
          } else {
            // Single Method Check
            bool isBank = type.contains('bank') || pm.containsKey('bankName');
            if (isBank) {
              tempBreakdown["Bank"] = (tempBreakdown["Bank"] ?? 0) + paid;
            }  if (type.contains('bkash')) {
              tempBreakdown["Bkash"] = (tempBreakdown["Bkash"] ?? 0) + paid;
            }
             if (type.contains('nagad')) {
               tempBreakdown["Nagad"] = (tempBreakdown["Nagad"] ?? 0) + paid;
             } else {
               tempBreakdown["Cash"] = (tempBreakdown["Cash"] ?? 0) + paid;
             }
          }
        } else {
          tempBreakdown["Cash"] = (tempBreakdown["Cash"] ?? 0) + paid;
        }

        // --- UI DESCRIPTION LOGIC ---
        String methodDesc = _formatPaymentDesc(pm);
        String sourceDesc =
            sale.customerType == 'debtor' ? "Due Payment" : "Sale";

        tempIn.add(
          LedgerItem(
            time: sale.timestamp,
            title: sale.name,
            subtitle: "$sourceDesc - $methodDesc",
            amount: paid,
            type: 'income',
          ),
        );
      }
    }

    // ---------------------------------------------------------
    // 2. EXTERNAL LEDGER (Income / Expense)
    // ---------------------------------------------------------
    for (var item in externalLedgerData) {
      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      String type = item['type'] ?? 'deposit';
      String method = (item['method'] ?? 'cash').toString().toLowerCase();
      String desc = item['description'] ?? 'Manual Entry';
      DateTime time = (item['timestamp'] as Timestamp).toDate();

      // Extract specific bank/account info
      String? bankName = item['bankName'];
      String? accNo = item['accountNo'];

      // Determine Category for Chart
      String chartKey = "Cash";
      if (bankName != null || method.contains('bank')) {
        chartKey = "Bank";
      }  if (method.contains('bkash')) {
        chartKey = "Bkash";
      }
       if (method.contains('nagad')) {
         chartKey = "Nagad";
       }

      // Build Subtitle
      String subTitle = chartKey.toUpperCase();
      if (bankName != null) subTitle += " ($bankName)";
      if (accNo != null) subTitle += "\nAcc: $accNo";

      if (type == 'deposit') {
        tIn += amt;
        tempBreakdown[chartKey] = (tempBreakdown[chartKey] ?? 0) + amt;
        tempIn.add(
          LedgerItem(
            time: time,
            title: desc,
            subtitle: "Add/Deposit - $subTitle",
            amount: amt,
            type: 'income',
          ),
        );
      } else {
        tOut += amt;
        // Withdrawals don't usually reduce "Sales Income Breakdown", they are just cash out.
        // So we don't subtract from tempBreakdown unless you want net flow per channel.
        tempOut.add(
          LedgerItem(
            time: time,
            title: desc,
            subtitle: "Withdraw - $subTitle",
            amount: amt,
            type: 'expense',
          ),
        );
      }
    }

    // ---------------------------------------------------------
    // 3. EXPENSES
    // ---------------------------------------------------------
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
    closingCash.value = previousCash.value + (tIn - tOut);

    cashInList.assignAll(tempIn);
    cashOutList.assignAll(tempOut);
    methodBreakdown.value = tempBreakdown;
  }

  // =========================================================
  // HELPER: Format Payment Description for UI
  // =========================================================
  String _formatPaymentDesc(dynamic pm) {
    if (pm == null) return "Cash";
    if (pm is! Map) return pm.toString().toUpperCase();

    String type = (pm['type'] ?? '').toString();

    // 1. Check for Specific Bank Info
    if (pm.containsKey('bankName')) {
      String bank = pm['bankName'];
      String acc = (pm['accountNumber'] ?? pm['accountNo'] ?? '').toString();
      return acc.isNotEmpty ? "$bank ($acc)" : bank;
    }

    // 2. Check for Mobile Banking Numbers
    if (pm.containsKey('bkashNumber')) return "Bkash (${pm['bkashNumber']})";
    if (pm.containsKey('nagadNumber')) return "Nagad (${pm['nagadNumber']})";

    // 3. Multi Pay
    if (type == 'multi') {
      List<String> parts = [];
      if (double.parse(pm['cash'].toString()) > 0) parts.add("Cash");
      if (double.parse(pm['bank'].toString()) > 0) parts.add("Bank");
      if (double.parse(pm['bkash'].toString()) > 0) parts.add("Bkash");
      if (double.parse(pm['nagad'].toString()) > 0) parts.add("Nagad");
      return parts.join(" + ");
    }

    // 4. Fallback
    return type.toUpperCase();
  }

  // =========================================================
  // PDF GENERATION
  // =========================================================
  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final timeFormat = DateFormat('hh:mm a');
    final currency = NumberFormat("#,##0.00", "en_US");
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
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
            // Header
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

            // Balance Summary
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

            // Source Breakdown
            pw.Text(
              "Collection Sources",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
            pw.Divider(thickness: 0.5),
            pw.Wrap(
              spacing: 15,
              children:
                  methodBreakdown.entries.map((e) {
                    if (e.value == 0) return pw.Container();
                    return pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 6,
                          height: 6,
                          decoration: const pw.BoxDecoration(
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

            // Transaction Table
            pw.Text(
              "TRANSACTION DETAILS",
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 5),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(
                  2.5,
                ), // Increased width for Type/Method
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold, align: pw.TextAlign.center),
                    _pdfCell("Description", fontBold),
                    _pdfCell("Details", fontBold),
                    _pdfCell("Credit (+)", fontBold, align: pw.TextAlign.right),
                    _pdfCell("Debit (-)", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                ..._generateMergedLedgerRows(
                  cashInList,
                  cashOutList,
                  timeFormat,
                  currency,
                  fontRegular,
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Daily_Statement_${dateStr.replaceAll(' ', '_')}',
    );
  }

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
          _pdfCell(item.title, font, size: 8),
          _pdfCell(item.subtitle, font, size: 8), // Shows the detailed method
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
}
