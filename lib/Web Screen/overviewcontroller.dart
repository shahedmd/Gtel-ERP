// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// IMPORTANT: Update imports to match your file structure
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';

// --- MODEL FOR UI & PDF ---
class LedgerItem {
  final DateTime time;
  final String title;
  final String subtitle;
  final double amount;
  final String type; // 'income' or 'expense'
  final String method; // 'Cash', 'Bank', 'Bkash', 'Nagad'
  final String? methodDetails; // NEW: Bank Name, Account No, etc.

  LedgerItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.method,
    this.methodDetails,
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

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

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

  // --- 1. CALCULATE PREVIOUS BALANCE ---
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
        double lPaid =
            double.tryParse(data['ledgerPaid']?.toString() ?? '0') ?? 0;
        pastSales += (paid - lPaid);
      }

      // B. Past Ledger
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
        if (type == 'transfer')
          continue; // Ignore Transfers in History Calculation

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

    // ==========================================================
    // A. PROCESS SALES
    // ==========================================================
    for (var sale in salesCtrl.salesList) {
      double realCash = sale.paid - sale.ledgerPaid;

      if (realCash > 0.01) {
        tIn += realCash;

        // 1. DETERMINE EXACT SALE TYPE
        String sType = "${sale.customerType} ${sale.source}".toLowerCase();
        String saleTypeDesc = "Cash Sale";

        if (sType.contains('condition')) {
          saleTypeDesc = "Condition Sale";
        } else if (sType.contains('agent')) {
          saleTypeDesc = "Agent Sale";
        } else if (sType.contains('collection') ||
            sType.contains('due') ||
            sType.contains('ledger')) {
          saleTypeDesc = "Bill Collection";
        }

        // 2. PARSE AMOUNTS AND EXTRACT DETAILED PAYMENT DETAILS
        dynamic pm = sale.paymentMethod;
        double c = 0, b = 0, bk = 0, n = 0;

        String valBankName = '';
        String valAccountNum = '';
        String valBkashNum = '';
        String valNagadNum = '';

        if (pm is Map) {
          c = double.tryParse(pm['cash'].toString()) ?? 0;
          b = double.tryParse(pm['bank'].toString()) ?? 0;
          bk = double.tryParse(pm['bkash'].toString()) ?? 0;
          n = double.tryParse(pm['nagad'].toString()) ?? 0;

          // Extract detailed strings
          valBankName = (pm['bankName'] ?? '').toString().trim();
          valAccountNum = (pm['accountNumber'] ?? '').toString().trim();
          valBkashNum = (pm['bkashNumber'] ?? '').toString().trim();
          valNagadNum = (pm['nagadNumber'] ?? '').toString().trim();

          // Legacy Fallback
          if ((c + b + bk + n) == 0) {
            if (valBankName.isNotEmpty || valAccountNum.isNotEmpty)
              b = realCash;
            else if (valBkashNum.isNotEmpty)
              bk = realCash;
            else if (valNagadNum.isNotEmpty)
              n = realCash;
            else
              c = realCash;
          }
        } else {
          // String Fallback
          String s = pm.toString().toLowerCase();
          if (s.contains('bank'))
            b = realCash;
          else if (s.contains('bkash'))
            bk = realCash;
          else if (s.contains('nagad'))
            n = realCash;
          else
            c = realCash;
        }

        // 3. SPLIT ROWS FOR PERFECT METHOD DISPLAY & ASSIGN DETAILS
        if (c > 0) {
          tempBreakdown['Cash'] = (tempBreakdown['Cash'] ?? 0) + c;
          tempIn.add(
            LedgerItem(
              time: sale.timestamp,
              title: saleTypeDesc,
              subtitle: sale.name,
              amount: c,
              type: 'income',
              method: "Cash",
            ),
          );
        }
        if (b > 0) {
          tempBreakdown['Bank'] = (tempBreakdown['Bank'] ?? 0) + b;
          String bDetails = [
            valBankName,
            valAccountNum,
          ].where((e) => e.isNotEmpty).join('\n');
          tempIn.add(
            LedgerItem(
              time: sale.timestamp,
              title: saleTypeDesc,
              subtitle: sale.name,
              amount: b,
              type: 'income',
              method: "Bank",
              methodDetails: bDetails,
            ),
          );
        }
        if (bk > 0) {
          tempBreakdown['Bkash'] = (tempBreakdown['Bkash'] ?? 0) + bk;
          tempIn.add(
            LedgerItem(
              time: sale.timestamp,
              title: saleTypeDesc,
              subtitle: sale.name,
              amount: bk,
              type: 'income',
              method: "Bkash",
              methodDetails: valBkashNum,
            ),
          );
        }
        if (n > 0) {
          tempBreakdown['Nagad'] = (tempBreakdown['Nagad'] ?? 0) + n;
          tempIn.add(
            LedgerItem(
              time: sale.timestamp,
              title: saleTypeDesc,
              subtitle: sale.name,
              amount: n,
              type: 'income',
              method: "Nagad",
              methodDetails: valNagadNum,
            ),
          );
        }
      }
    }

    // ==========================================================
    // B. PROCESS LEDGER (EXTERNAL DEPOSITS/WITHDRAWALS)
    // ==========================================================
    for (var item in externalLedgerData) {
      String type = item['type'] ?? 'deposit';
      if (type == 'transfer') continue; // Skip transfers in simple view

      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      DateTime time = (item['timestamp'] as Timestamp).toDate();
      String description = item['description'] ?? "Entry";

      // LOOK IN DETAILS MAP FIRST, FALLBACK TO ROOT
      var detailsMap = item['details'] as Map<String, dynamic>?;
      String extractedBankName =
          (detailsMap?['bankName'] ?? item['bankName'] ?? '').toString().trim();
      String extractedAccountNo =
          (detailsMap?['accountNo'] ?? item['accountNo'] ?? '')
              .toString()
              .trim();

      String detailsStr = [
        extractedBankName,
        extractedAccountNo,
      ].where((e) => e.isNotEmpty).join('\n');

      String displayMethod = "Cash";
      String methodRaw = (item['method'] ?? 'Cash').toString().toLowerCase();

      if (methodRaw.contains('bank') ||
          extractedBankName.isNotEmpty ||
          extractedAccountNo.toLowerCase().contains('brac') ||
          extractedAccountNo.toLowerCase().contains('bank')) {
        displayMethod = "Bank";
      } else if (methodRaw.contains('bkash')) {
        displayMethod = "Bkash";
      } else if (methodRaw.contains('nagad')) {
        displayMethod = "Nagad";
      }

      if (type == 'deposit') {
        tIn += amt;
        tempBreakdown[displayMethod] =
            (tempBreakdown[displayMethod] ?? 0) + amt;
        tempIn.add(
          LedgerItem(
            time: time,
            title: "Deposit",
            subtitle: description,
            amount: amt,
            type: 'income',
            method: displayMethod,
            methodDetails: detailsStr,
          ),
        );
      } else {
        tOut += amt;
        tempOut.add(
          LedgerItem(
            time: time,
            title: "Withdrawal",
            subtitle: description,
            amount: amt,
            type: 'expense',
            method: displayMethod,
            methodDetails: detailsStr,
          ),
        );
      }
    }

    // ==========================================================
    // C. PROCESS EXPENSES
    // ==========================================================
    for (var expense in expenseCtrl.dailyList) {
      double amt = expense.amount.toDouble();
      tOut += amt;
      tempOut.add(
        LedgerItem(
          time: expense.time,
          title: "Expense: ${expense.name}",
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

  // ==========================================================
  // PDF GENERATION (5 COLUMNS WITH BANK DETAILS)
  // ==========================================================
  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            // --- HEADER ---
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

            // --- BALANCE SUMMARY ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfBalanceCol(
                  "Previous",
                  previousCash.value,
                  fontBold,
                  PdfColors.grey700,
                ),
                pw.Text("+", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "Income",
                  totalCashIn.value,
                  fontBold,
                  PdfColors.green700,
                ),
                pw.Text("-", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "Expense",
                  totalCashOut.value,
                  fontBold,
                  PdfColors.red700,
                ),
                pw.Text("=", style: pw.TextStyle(font: fontBold)),
                _pdfBalanceCol(
                  "CLOSING",
                  closingCash.value,
                  fontBold,
                  PdfColors.blue900,
                  isLarge: true,
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // --- 5 COLUMN MAIN TABLE ---
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Time
                1: const pw.FlexColumnWidth(2.7), // Description
                2: const pw.FlexColumnWidth(
                  2.0,
                ), // Method (Expanded for details)
                3: const pw.FlexColumnWidth(1.5), // Income
                4: const pw.FlexColumnWidth(1.5), // Expense
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold),
                    _pdfCell("Description", fontBold),
                    _pdfCell("Method Details", fontBold),
                    _pdfCell("Income", fontBold, align: pw.TextAlign.right),
                    _pdfCell("Expense", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                // Table Data
                ..._generateMergedLedgerRows(
                  cashInList,
                  cashOutList,
                  fontRegular,
                ),
              ],
            ),

            // --- BOSS SIGNATURE SECTION ---
            pw.SizedBox(height: 60),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
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
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "Authorized Signature",
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                  ],
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

  // --- HELPER: TABLE ROWS GENERATOR ---
  List<pw.TableRow> _generateMergedLedgerRows(
    List<LedgerItem> inList,
    List<LedgerItem> outList,
    pw.Font font,
  ) {
    List<LedgerItem> all = [...inList, ...outList];
    all.sort((a, b) => a.time.compareTo(b.time));

    return all.map((item) {
      bool isIncome = item.type == 'income';

      // Merge method and methodDetails for display
      String methodDisplay = item.method;
      if (item.methodDetails != null && item.methodDetails!.isNotEmpty) {
        methodDisplay += "\n${item.methodDetails}";
      }

      return pw.TableRow(
        children: [
          _pdfCell(DateFormat('hh:mm a').format(item.time), font, size: 8),
          _pdfCell("${item.title}\n${item.subtitle}", font, size: 8),
          _pdfCell(methodDisplay, font, size: 8), // NOW SHOWS FULL DETAILS
          _pdfCell(
            isIncome ? _currencyFormat.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
          ),
          _pdfCell(
            !isIncome ? _currencyFormat.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
          ),
        ],
      );
    }).toList();
  }

  // --- HELPER: PDF CELL ---
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

  // --- HELPER: PDF BALANCE COLUMN ---
  pw.Widget _pdfBalanceCol(
    String label,
    double val,
    pw.Font font,
    PdfColor color, {
    bool isLarge = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(
          _currencyFormat.format(val),
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