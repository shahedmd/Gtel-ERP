// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures

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

  StreamSubscription? _ledgerSubscription;
  RxList<Map<String, dynamic>> externalLedgerData =
      <Map<String, dynamic>>[].obs;

  // --- BALANCE STATS ---
  RxDouble previousCash = 0.0.obs;
  RxDouble totalCashIn = 0.0.obs;
  RxDouble totalCashOut = 0.0.obs;
  RxDouble netCashBalance = 0.0.obs;
  RxDouble closingCash = 0.0.obs;

  RxList<LedgerItem> cashInList = <LedgerItem>[].obs;
  RxList<LedgerItem> cashOutList = <LedgerItem>[].obs;

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

  void pickDate(DateTime date) {
    selectedDate.value = date;
  }

  void refreshData() {
    _syncDateToSubControllers();
    _fetchPreviousBalance();
    _listenToExternalLedger();
    Get.snackbar("Refreshed", "Ledger synced.");
  }

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

      // 2. Past Ledger
      var ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where('timestamp', isLessThan: startOfDay)
              .get();
      double pastLedgerSum = 0.0;
      for (var doc in ledgerSnap.docs) {
        var data = doc.data();
        String src = (data['source'] ?? '').toString();
        // Skip duplicate sales
        if (src == 'pos_sale') continue;
        if (src == '' && data.containsKey('linkedInvoiceId')) continue;

        double amt = double.tryParse(doc['amount'].toString()) ?? 0;
        if (doc['type'] == 'withdraw')
          pastLedgerSum -= amt;
        else
          pastLedgerSum += amt;
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
          var rawList = snap.docs.map((e) => e.data()).toList();
          // Filter out ONLY the 'pos_sale' entries (invoice duplicates)
          // Allow 'pos_old_due', 'debtor_manual', etc.
          var filtered =
              rawList.where((data) {
                String src = (data['source'] ?? '').toString();
                return src != 'pos_sale';
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

    // 1. SALES (Only Invoice Payments)
    for (var sale in salesCtrl.salesList) {
      double paid = double.tryParse(sale.paid.toString()) ?? 0.0;
      if (paid > 0) {
        tIn += paid;
        _addToBreakdown(tempBreakdown, sale.paymentMethod, paid);
        tempIn.add(
          LedgerItem(
            time: sale.timestamp,
            title: sale.name,
            subtitle:
                "Sale (Paid: $paid) - ${_formatPaymentDesc(sale.paymentMethod)}",
            amount: paid,
            type: 'income',
          ),
        );
      }
    }

    // 2. LEDGER (Old Due, Manual Adds)
    for (var item in externalLedgerData) {
      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      String type = item['type'] ?? 'deposit';
      String src = item['source'] ?? '';
      String desc = item['description'] ?? 'Manual Entry';
      DateTime time = (item['timestamp'] as Timestamp).toDate();

      // Read details from the new map structure if available
      dynamic details = item['details'];

      if (type == 'deposit') {
        tIn += amt;
        // If it's old due, use the details map for breakdown
        if (src == 'pos_old_due' && details != null) {
          _addToBreakdown(tempBreakdown, details, amt);
        } else {
          // Fallback for manual adds
          String m = (item['method'] ?? 'cash').toString().toLowerCase();
          if (m.contains('bank'))
            tempBreakdown["Bank"] = (tempBreakdown["Bank"]! + amt);
          else if (m.contains('bkash'))
            tempBreakdown["Bkash"] = (tempBreakdown["Bkash"]! + amt);
          else if (m.contains('nagad'))
            tempBreakdown["Nagad"] = (tempBreakdown["Nagad"]! + amt);
          else
            tempBreakdown["Cash"] = (tempBreakdown["Cash"]! + amt);
        }

        tempIn.add(
          LedgerItem(
            time: time,
            title: desc,
            subtitle:
                "Collection/Add - ${_formatPaymentDesc(details ?? item['method'])}",
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
            subtitle:
                "Withdraw/Exp - ${_formatPaymentDesc(details ?? item['method'])}",
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
          subtitle: expense.note,
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

  void _addToBreakdown(Map<String, double> bd, dynamic pm, double totalAmt) {
    if (pm == null) {
      bd["Cash"] = bd["Cash"]! + totalAmt;
      return;
    }
    if (pm is! Map) {
      bd["Cash"] = bd["Cash"]! + totalAmt;
      return;
    }

    String type = (pm['type'] ?? 'cash').toString();
    if (type == 'multi') {
      bd["Cash"] = bd["Cash"]! + (double.tryParse(pm['cash'].toString()) ?? 0);
      bd["Bank"] = bd["Bank"]! + (double.tryParse(pm['bank'].toString()) ?? 0);
      bd["Bkash"] =
          bd["Bkash"]! + (double.tryParse(pm['bkash'].toString()) ?? 0);
      bd["Nagad"] =
          bd["Nagad"]! + (double.tryParse(pm['nagad'].toString()) ?? 0);
    } else {
      if (type.contains('bank') || pm.containsKey('bankName'))
        bd["Bank"] = bd["Bank"]! + totalAmt;
      else if (type.contains('bkash'))
        bd["Bkash"] = bd["Bkash"]! + totalAmt;
      else if (type.contains('nagad'))
        bd["Nagad"] = bd["Nagad"]! + totalAmt;
      else
        bd["Cash"] = bd["Cash"]! + totalAmt;
    }
  }

  String _formatPaymentDesc(dynamic pm) {
    if (pm == null) return "Cash";
    if (pm is! Map) return pm.toString().toUpperCase();

    if (pm.containsKey('bankName'))
      return "${pm['bankName']} (${pm['accountNumber'] ?? ''})";
    if (pm.containsKey('bkashNumber')) return "Bkash (${pm['bkashNumber']})";
    if (pm.containsKey('nagadNumber')) return "Nagad (${pm['nagadNumber']})";
    return (pm['type'] ?? 'Cash').toString().toUpperCase();
  }

  Future<void> generateLedgerPdf() async {
    // ... [PDF Generation Code (Same as previous, just ensure it uses new lists)] ...
    // The structure I provided in the previous answer for generateLedgerPdf is solid.
    // Just copy-paste the generateLedgerPdf method from the previous OverviewController response here.
    // It uses cashInList, cashOutList, and methodBreakdown which are now correctly populated.

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
        build: (pw.Context context) {
          return [
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
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
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
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  _pdfBalanceColumn(
                    "Today's Net",
                    netCashBalance.value,
                    fontBold,
                    currency,
                    netCashBalance.value >= 0
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                  pw.Text(
                    "=",
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  _pdfBalanceColumn(
                    "CLOSING CASH",
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
                    return pw.Text(
                      "${e.key}: ${currency.format(e.value)}",
                      style: pw.TextStyle(font: fontRegular, fontSize: 9),
                    );
                  }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold),
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
      onLayout: (format) => doc.save(),
      name: 'Statement_$dateStr',
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
          _pdfCell(tFmt.format(item.time), font, size: 8),
          _pdfCell(item.title, font, size: 8),
          _pdfCell(item.subtitle, font, size: 8),
          _pdfCell(
            isIncome ? mFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
            color: isIncome ? PdfColors.green900 : PdfColors.black,
          ),
          _pdfCell(
            !isIncome ? mFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
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
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
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
