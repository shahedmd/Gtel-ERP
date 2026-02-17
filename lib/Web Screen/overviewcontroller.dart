// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- MODEL FOR UI ---
class LedgerItem {
  final DateTime time;
  final String title;
  final String subtitle;
  final double amount;
  final String type; // 'income' or 'expense'
  final String method;

  LedgerItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.method,
  });
}

// --- MAIN CONTROLLER ---
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

  // --- LISTS FOR UI ---
  RxList<LedgerItem> cashInList = <LedgerItem>[].obs;
  RxList<LedgerItem> cashOutList = <LedgerItem>[].obs;

  // --- BREAKDOWN ---
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

  // --- ACTIONS ---

  void pickDate(DateTime date) {
    selectedDate.value = date;
  }

  void refreshData() {
    _syncDateToSubControllers();
    _fetchPreviousBalance();
    _listenToExternalLedger();
    Get.snackbar("Refreshed", "Ledger synced successfully.");
  }

  void _syncDateToSubControllers() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  // --- 1. CALCULATE PREVIOUS BALANCE (FIXED: Ignored Transfers) ---
  Future<void> _fetchPreviousBalance() async {
    isLoadingHistory.value = true;
    try {
      DateTime startOfDay = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );

      // A. Past Sales
      var salesSnap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastSales = 0.0;
      for (var doc in salesSnap.docs) {
        Map<String, dynamic> data = doc.data();
        double paid = double.tryParse(data['paid'].toString()) ?? 0;
        double lPaid = 0.0;
        if (data.containsKey('ledgerPaid')) {
          lPaid = double.tryParse(data['ledgerPaid'].toString()) ?? 0;
        }
        pastSales += (paid - lPaid);
      }

      // B. Past Ledger (FIXED HERE)
      var ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastLedgerSum = 0.0;
      for (var doc in ledgerSnap.docs) {
        var d = doc.data();
        if (d['source'] == 'pos_sale') continue;

        String type = (d['type'] ?? 'deposit').toString();

        // --- KEY FIX: Ignore Transfers in History Calculation ---
        if (type == 'transfer') continue;

        double amt = double.tryParse(d['amount'].toString()) ?? 0;
        if (type == 'withdraw') {
          pastLedgerSum -= amt;
        } else {
          pastLedgerSum += amt;
        }
      }

      // C. Past Expenses
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
      print(e);
    } finally {
      isLoadingHistory.value = false;
    }
  }

  // --- 2. LISTEN TO EXTERNAL LEDGER ---
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
          var filtered =
              rawList.where((data) {
                String src = (data['source'] ?? '').toString();
                return src != 'pos_sale';
              }).toList();
          externalLedgerData.assignAll(filtered);
        });
  }

  // --- 3. PROCESS DATA FOR UI ---
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

    // --- A. PROCESS SALES (Unchanged) ---
    for (var sale in salesCtrl.salesList) {
      double realCash = sale.paid - sale.ledgerPaid;

      if (realCash > 0.01) {
        tIn += realCash;

        String methodLabel = "Cash";
        String displaySubtitle = "Direct Sale";
        dynamic pm = sale.paymentMethod;

        if (pm is Map) {
          String valBank = (pm['bankName'] ?? '').toString().trim();
          String valBkash = (pm['bkashNumber'] ?? '').toString().trim();
          String valNagad = (pm['nagadNumber'] ?? '').toString().trim();

          if (valBank.isNotEmpty) {
            methodLabel = "Bank";
            displaySubtitle = "Bank: $valBank";
            tempBreakdown['Bank'] = (tempBreakdown['Bank'] ?? 0) + realCash;
          } else if (valBkash.isNotEmpty) {
            methodLabel = "Bkash";
            displaySubtitle = "Bkash: $valBkash";
            tempBreakdown['Bkash'] = (tempBreakdown['Bkash'] ?? 0) + realCash;
          } else if (valNagad.isNotEmpty) {
            methodLabel = "Nagad";
            displaySubtitle = "Nagad: $valNagad";
            tempBreakdown['Nagad'] = (tempBreakdown['Nagad'] ?? 0) + realCash;
          } else {
            tempBreakdown['Cash'] = (tempBreakdown['Cash'] ?? 0) + realCash;
          }
        } else {
          if (pm.toString().toLowerCase().contains('bank')) {
            tempBreakdown['Bank'] = (tempBreakdown['Bank'] ?? 0) + realCash;
            methodLabel = "Bank";
          } else {
            tempBreakdown['Cash'] = (tempBreakdown['Cash'] ?? 0) + realCash;
          }
        }

        tempIn.add(
          LedgerItem(
            time: sale.timestamp,
            title: "Sale: ${sale.name}",
            subtitle: displaySubtitle,
            amount: realCash,
            type: 'income',
            method: methodLabel,
          ),
        );
      }
    }

    // --- B. PROCESS LEDGER (FIXED LOGIC HERE) ---
    for (var item in externalLedgerData) {
      String type = item['type'] ?? 'deposit';

      // Skip Transfers
      if (type == 'transfer') continue;

      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      DateTime time = (item['timestamp'] as Timestamp).toDate();
      String description = item['description'] ?? "Entry";

      // --- METHOD DETECTION FIX ---
      String displayMethod = "Cash";
      String methodRaw = (item['method'] ?? 'Cash').toString().toLowerCase();

      // Get bank name and ensure it's not null AND not empty string
      var bankNameVal = item['bankName'];
      bool hasBankDetails =
          bankNameVal != null && bankNameVal.toString().trim().isNotEmpty;

      // 1. Check Bank
      if (methodRaw.contains('bank') || hasBankDetails) {
        displayMethod = "Bank";
      }
      // 2. Check Bkash
      else if (methodRaw.contains('bkash')) {
        displayMethod = "Bkash";
      }
      // 3. Check Nagad
      else if (methodRaw.contains('nagad')) {
        displayMethod = "Nagad";
      }
      // 4. Default is Cash (already set)

      // Add to totals
      if (type == 'deposit') {
        tIn += amt;

        // Add to Breakdown
        if (displayMethod == 'Bank') {
          tempBreakdown['Bank'] = (tempBreakdown['Bank'] ?? 0) + amt;
        } else if (displayMethod == 'Bkash') {
          tempBreakdown['Bkash'] = (tempBreakdown['Bkash'] ?? 0) + amt;
        } else if (displayMethod == 'Nagad') {
          tempBreakdown['Nagad'] = (tempBreakdown['Nagad'] ?? 0) + amt;
        } else {
          tempBreakdown['Cash'] = (tempBreakdown['Cash'] ?? 0) + amt;
        }

        tempIn.add(
          LedgerItem(
            time: time,
            title: description,
            subtitle:
                displayMethod == "Bank" && hasBankDetails
                    ? "Bank: $bankNameVal" // Show bank name if available
                    : displayMethod,
            amount: amt,
            type: 'income',
            method: displayMethod,
          ),
        );
      } else {
        // Withdraw/Expense from Ledger
        tOut += amt;
        tempOut.add(
          LedgerItem(
            time: time,
            title: description,
            subtitle:
                displayMethod == "Bank" && hasBankDetails
                    ? "Bank: $bankNameVal"
                    : displayMethod,
            amount: amt,
            type: 'expense',
            method: displayMethod,
          ),
        );
      }
    }

    // --- C. PROCESS EXPENSES (Unchanged) ---
    for (var expense in expenseCtrl.dailyList) {
      double amt = expense.amount.toDouble();
      tOut += amt;
      tempOut.add(
        LedgerItem(
          time: expense.time,
          title: "Exp: ${expense.name}",
          subtitle: expense.note,
          amount: amt,
          type: 'expense',
          method: "Cash",
        ),
      );
    }

    // Sort & Update Observables
    tempIn.sort((a, b) => b.time.compareTo(a.time));
    tempOut.sort((a, b) => b.time.compareTo(a.time));

    totalCashIn.value = tIn;
    totalCashOut.value = tOut;
    netCashBalance.value = tIn - tOut;
    closingCash.value = previousCash.value + (tIn - tOut);

    cashInList.assignAll(tempIn);
    cashOutList.assignAll(tempOut);
    methodBreakdown.value = tempBreakdown;
  }

  // --- PDF GENERATION (UNCHANGED) ---
  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final currency = NumberFormat("#,##0", "en_US");
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
                pw.Text(
                  "DAILY CASH STATEMENT",
                  style: pw.TextStyle(font: fontBold, fontSize: 18),
                ),
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfBalanceCol(
                  "Previous",
                  previousCash.value,
                  fontBold,
                  currency,
                  PdfColors.grey700,
                ),
                pw.Text("+", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "Income",
                  totalCashIn.value,
                  fontBold,
                  currency,
                  PdfColors.green700,
                ),
                pw.Text("-", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "Expense",
                  totalCashOut.value,
                  fontBold,
                  currency,
                  PdfColors.red700,
                ),
                pw.Text("=", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "CLOSING",
                  closingCash.value,
                  fontBold,
                  currency,
                  PdfColors.blue900,
                  isLarge: true,
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold),
                    _pdfCell("Description", fontBold),
                    _pdfCell("Income", fontBold, align: pw.TextAlign.right),
                    _pdfCell("Expense", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                ..._generateMergedLedgerRows(
                  cashInList,
                  cashOutList,
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
      onLayout: (f) => doc.save(),
      name: 'Ledger_$dateStr',
    );
  }

  List<pw.TableRow> _generateMergedLedgerRows(
    List<LedgerItem> inList,
    List<LedgerItem> outList,
    NumberFormat cFmt,
    pw.Font font,
  ) {
    List<LedgerItem> all = [...inList, ...outList];
    all.sort((a, b) => a.time.compareTo(b.time));

    return all.map((item) {
      bool isIncome = item.type == 'income';
      return pw.TableRow(
        children: [
          _pdfCell(DateFormat('hh:mm a').format(item.time), font, size: 8),
          _pdfCell("${item.title}\n${item.subtitle}", font, size: 8),
          _pdfCell(
            isIncome ? cFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
          ),
          _pdfCell(
            !isIncome ? cFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
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
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: size),
      ),
    );
  }

  pw.Widget _pdfBalanceCol(
    String label,
    double val,
    pw.Font font,
    NumberFormat fmt,
    PdfColor color, {
    bool isLarge = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(
          fmt.format(val),
          style: pw.TextStyle(
            font: font,
            fontSize: isLarge ? 12 : 10,
            color: color,
          ),
        ),
      ],
    );
  }
}
