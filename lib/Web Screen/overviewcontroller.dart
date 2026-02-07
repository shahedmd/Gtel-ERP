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
  final String subtitle; // Contains Bank Name / Account No details
  final double amount;
  final String type; // 'income' or 'expense'
  final String method; // 'Cash', 'Bank', 'Bkash' etc.

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
  // Dependencies
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

    // React to changes in dependent controllers
    ever(salesCtrl.salesList, (_) => _processLedgerData());
    ever(expenseCtrl.dailyList, (_) => _processLedgerData());
    ever(externalLedgerData, (_) => _processLedgerData());

    // React to Date Change
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

  // --- 1. CALCULATE PREVIOUS BALANCE (Everything before today) ---
  Future<void> _fetchPreviousBalance() async {
    isLoadingHistory.value = true;
    try {
      DateTime startOfDay = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );

      // A. Past Sales (Cash Received)
      var salesSnap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastSales = 0.0;
      for (var doc in salesSnap.docs) {
        Map<String, dynamic> data = doc.data();
        double paid = double.tryParse(data['paid'].toString()) ?? 0;
        // Subtract ledgerPaid (money allocated from ledger, not real cash today)
        double lPaid = 0.0;
        if (data.containsKey('ledgerPaid')) {
          lPaid = double.tryParse(data['ledgerPaid'].toString()) ?? 0;
        }
        pastSales += (paid - lPaid);
      }

      // B. Past Ledger (Deposits & Withdrawals)
      var ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where('timestamp', isLessThan: startOfDay)
              .get();

      double pastLedgerSum = 0.0;
      for (var doc in ledgerSnap.docs) {
        var d = doc.data();
        // Ignore pos_sale because they are covered in daily_sales
        if (d['source'] == 'pos_sale') continue;

        double amt = double.tryParse(d['amount'].toString()) ?? 0;
        if (d['type'] == 'withdraw') {
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

      // Trigger update of today's lists
      _processLedgerData();
    } catch (e) {
    } finally {
      isLoadingHistory.value = false;
    }
  }

  // --- 2. LISTEN TO EXTERNAL LEDGER (Manual Adds / Debtor Collections) ---
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

  // --- 3. PROCESS DATA FOR UI (THE CORE LOGIC - FIXED) ---
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

    // --- A. PROCESS SALES (FIXED LOGIC FOR MAP STRUCTURE) ---
    for (var sale in salesCtrl.salesList) {
      double realCash = sale.paid - sale.ledgerPaid;
      if (realCash > 0.01) {
        tIn += realCash;

        // ** NEW LOGIC: Handle Map Payment Method **
        String methodLabel = "Cash";
        String displaySubtitle = "Direct Sale";
        dynamic pm = sale.paymentMethod;

        if (pm is Map) {
          // Extract specific amounts from the map
          double c = double.tryParse(pm['cash'].toString()) ?? 0;
          double b = double.tryParse(pm['bank'].toString()) ?? 0;
          double bk = double.tryParse(pm['bkash'].toString()) ?? 0;
          double n = double.tryParse(pm['nagad'].toString()) ?? 0;

          // 1. Add precise amounts to Breakdown
          tempBreakdown['Cash'] = (tempBreakdown['Cash'] ?? 0) + c;
          tempBreakdown['Bank'] = (tempBreakdown['Bank'] ?? 0) + b;
          tempBreakdown['Bkash'] = (tempBreakdown['Bkash'] ?? 0) + bk;
          tempBreakdown['Nagad'] = (tempBreakdown['Nagad'] ?? 0) + n;

          // 2. Determine Display Label (Method)
          List<String> used = [];
          if (c > 0) used.add("Cash");
          if (b > 0) used.add("Bank");
          if (bk > 0) used.add("Bkash");
          if (n > 0) used.add("Nagad");

          if (used.length > 1) {
            methodLabel = "Mixed";
            // e.g. "Cash, Bank"
            displaySubtitle = used.join(", ");
          } else if (used.isNotEmpty) {
            methodLabel = used.first;

            // 3. Extract Details (Subtitle) based on method
            if (methodLabel == "Bank") {
              String bName = pm['bankName'] ?? '';
              String acc = pm['accountNumber'] ?? '';
              if (bName.isNotEmpty) {
                displaySubtitle = bName + (acc.isNotEmpty ? " ($acc)" : "");
              }
            } else if (methodLabel == "Bkash") {
              if (pm['bkashNumber'] != null &&
                  pm['bkashNumber'].toString().isNotEmpty) {
                displaySubtitle = "Bkash: ${pm['bkashNumber']}";
              }
            } else if (methodLabel == "Nagad") {
              if (pm['nagadNumber'] != null &&
                  pm['nagadNumber'].toString().isNotEmpty) {
                displaySubtitle = "Nagad: ${pm['nagadNumber']}";
              }
            }
          }
        } else {
          // Fallback for old string data
          _addToBreakdown(tempBreakdown, pm, realCash);
          methodLabel = _extractSimpleMethod(pm);
        }

        tempIn.add(
          LedgerItem(
            time: sale.timestamp,
            title: "Sale: ${sale.name}",
            subtitle: displaySubtitle, // Now contains Bank details
            amount: realCash,
            type: 'income',
            method: methodLabel,
          ),
        );
      }
    }

    // --- B. PROCESS LEDGER (External - Original Logic Restored) ---
    for (var item in externalLedgerData) {
      double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
      String type = item['type'] ?? 'deposit';
      DateTime time = (item['timestamp'] as Timestamp).toDate();
      String source = item['source'] ?? '';
      String description = item['description'] ?? "Entry";
      String methodRaw = item['method'] ?? 'cash';

      String displaySubtitle = "";
      String displayMethod = "Cash";

      if (source == 'manual_add') {
        String bank = item['bankName'] ?? '';
        String acc = item['accountNo'] ?? '';

        if (bank.isNotEmpty) {
          displaySubtitle = "$bank - $acc";
          displayMethod = "Bank";
        } else {
          displaySubtitle = "Manual Cash In";
          displayMethod = "Cash";
        }
        _addToBreakdown(tempBreakdown, item, amt);
      } else if (source == 'debtor_collection' || item.containsKey('details')) {
        Map<String, dynamic> det =
            item['details'] != null
                ? item['details'] as Map<String, dynamic>
                : {};

        String bank = det['bankName'] ?? item['bankName'] ?? '';
        String acc = det['accountNo'] ?? item['accountNo'] ?? '';
        String met = det['method'] ?? item['method'] ?? 'cash';

        if (bank.isNotEmpty) {
          displaySubtitle = "$bank ($acc)";
          displayMethod = "Bank";
        } else if (met.toLowerCase() == 'bkash') {
          displaySubtitle = "Bkash Pmt";
          displayMethod = "Bkash";
        } else if (met.toLowerCase() == 'nagad') {
          displaySubtitle = "Nagad Pmt";
          displayMethod = "Nagad";
        } else {
          displaySubtitle = "Collection";
          displayMethod = "Cash";
        }

        _addToBreakdown(tempBreakdown, det.isNotEmpty ? det : item, amt);
      } else {
        // GENERIC FALLBACK
        displaySubtitle = source.replaceAll('_', ' ').capitalizeFirst ?? source;
        displayMethod = methodRaw.capitalizeFirst ?? "Cash";
        _addToBreakdown(tempBreakdown, item, amt);
      }

      if (type == 'deposit') {
        tIn += amt;
        tempIn.add(
          LedgerItem(
            time: time,
            title: description,
            subtitle: displaySubtitle,
            amount: amt,
            type: 'income',
            method: displayMethod,
          ),
        );
      } else {
        tOut += amt;
        tempOut.add(
          LedgerItem(
            time: time,
            title: description,
            subtitle: displaySubtitle.isEmpty ? "Withdrawal" : displaySubtitle,
            amount: amt,
            type: 'expense',
            method: displayMethod,
          ),
        );
      }
    }

    // --- C. PROCESS EXPENSES ---
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
          method: "Cash", // Default to Cash for expenses
        ),
      );
    }

    // Sort Lists (Newest First)
    tempIn.sort((a, b) => b.time.compareTo(a.time));
    tempOut.sort((a, b) => b.time.compareTo(a.time));

    // Update Observables
    totalCashIn.value = tIn;
    totalCashOut.value = tOut;
    netCashBalance.value = tIn - tOut;
    closingCash.value = previousCash.value + (tIn - tOut);
    cashInList.assignAll(tempIn);
    cashOutList.assignAll(tempOut);
    methodBreakdown.value = tempBreakdown;
  }

  // --- HELPER: Extract Simple Method Name ---
  String _extractSimpleMethod(dynamic pm) {
    if (pm == null) return "Cash";
    if (pm is String) return pm.capitalizeFirst ?? "Cash";
    if (pm is Map) return "Mixed";
    return "Cash";
  }

  // --- HELPER: Logic to update the Breakdown Map (Legacy + Non-Sales) ---
  void _addToBreakdown(Map<String, double> bd, dynamic data, double totalAmt) {
    if (data is String) {
      String m = data.toLowerCase();
      if (m.contains('bank'))
        bd["Bank"] = bd["Bank"]! + totalAmt;
      else if (m.contains('bkash'))
        bd["Bkash"] = bd["Bkash"]! + totalAmt;
      else if (m.contains('nagad'))
        bd["Nagad"] = bd["Nagad"]! + totalAmt;
      else
        bd["Cash"] = bd["Cash"]! + totalAmt;
      return;
    }

    if (data is Map) {
      if (data.containsKey('bankName') &&
          data['bankName'].toString().isNotEmpty) {
        bd["Bank"] = bd["Bank"]! + totalAmt;
        return;
      }
      String method =
          (data['method'] ?? data['type'] ?? '').toString().toLowerCase();
      if (method.contains('bank')) {
        bd["Bank"] = bd["Bank"]! + totalAmt;
      } else if (method.contains('bkash')) {
        bd["Bkash"] = bd["Bkash"]! + totalAmt;
      } else if (method.contains('nagad')) {
        bd["Nagad"] = bd["Nagad"]! + totalAmt;
      } else {
        bd["Cash"] = bd["Cash"]! + totalAmt;
      }
    } else {
      bd["Cash"] = bd["Cash"]! + totalAmt;
    }
  }

  // --- 4. PDF GENERATION (FULL FEATURES RESTORED) ---
  Future<void> generateLedgerPdf() async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    final timeFormat = DateFormat('hh:mm a');
    final currency = NumberFormat("#,##0", "en_US");
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
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
                      style: pw.TextStyle(font: fontBold, fontSize: 18),
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
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Balance Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfBalanceCol(
                    "Previous",
                    previousCash.value,
                    fontBold,
                    currency,
                    PdfColors.grey700,
                  ),
                  pw.Text(
                    "+",
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
                  _pdfBalanceCol(
                    "Income",
                    totalCashIn.value,
                    fontBold,
                    currency,
                    PdfColors.green700,
                  ),
                  pw.Text(
                    "-",
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
                  _pdfBalanceCol(
                    "Expense",
                    totalCashOut.value,
                    fontBold,
                    currency,
                    PdfColors.red700,
                  ),
                  pw.Text(
                    "=",
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
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
            ),

            pw.SizedBox(height: 15),
            pw.Text(
              "Transaction Details",
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 5),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(50), // Time
                1: const pw.FlexColumnWidth(2), // Description
                2: const pw.FlexColumnWidth(2), // Details (Bank/Method)
                3: const pw.FixedColumnWidth(60), // Income
                4: const pw.FixedColumnWidth(60), // Expense
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Time", fontBold),
                    _pdfCell("Description", fontBold),
                    _pdfCell("Details", fontBold),
                    _pdfCell("Income", fontBold, align: pw.TextAlign.right),
                    _pdfCell("Expense", fontBold, align: pw.TextAlign.right),
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
      onLayout: (f) => doc.save(),
      name: 'Ledger_$dateStr',
    );
  }

  List<pw.TableRow> _generateMergedLedgerRows(
    List<LedgerItem> inList,
    List<LedgerItem> outList,
    DateFormat tFmt,
    NumberFormat cFmt,
    pw.Font font,
  ) {
    List<LedgerItem> all = [...inList, ...outList];
    // Sort oldest to newest for PDF flow
    all.sort((a, b) => a.time.compareTo(b.time));

    return all.map((item) {
      bool isIncome = item.type == 'income';
      return pw.TableRow(
        children: [
          _pdfCell(tFmt.format(item.time), font, size: 8),
          _pdfCell(item.title, font, size: 8),
          _pdfCell(
            "${item.subtitle}\n(${item.method})",
            font,
            size: 7,
            color: PdfColors.grey700,
          ),
          _pdfCell(
            isIncome ? cFmt.format(item.amount) : "-",
            font,
            align: pw.TextAlign.right,
            color: isIncome ? PdfColors.green900 : PdfColors.black,
          ),
          _pdfCell(
            !isIncome ? cFmt.format(item.amount) : "-",
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
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          fmt.format(val),
          style: pw.TextStyle(
            font: font,
            fontSize: isLarge ? 12 : 10,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}