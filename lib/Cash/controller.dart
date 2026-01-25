import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Enum for Date Filters
enum DateFilter { daily, monthly, yearly, custom }

/// Model to unify Sales, Expenses, and Ledger items for the UI
class DrawerTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final String type; // 'sale', 'expense', 'deposit', 'withdraw'
  final String method; // 'cash', 'bank', 'bkash', 'nagad', 'mixed', 'deducted'

  DrawerTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.method,
  });
}

class CashDrawerController extends GetxController {
  static CashDrawerController get to => Get.find();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Observables (State) ---
  final RxBool isLoading = false.obs;
  final Rx<DateFilter> filterType = DateFilter.monthly.obs;
  final Rx<DateTimeRange> selectedRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now()).obs;

  // --- Real-Time Calculated Balances (The "Actual" Cash) ---
  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;

  // This is the "All Together" Cash
  final RxDouble grandTotal = 0.0.obs;

  // --- Raw Totals for Reporting ---
  final RxDouble rawSalesTotal = 0.0.obs;
  final RxDouble rawExpenseTotal = 0.0.obs;
  final RxDouble rawManualAddTotal = 0.0.obs;

  // --- Transaction History ---
  final RxList<DrawerTransaction> recentTransactions =
      <DrawerTransaction>[].obs;

  // Helper for formatting numbers in the Controller/PDF
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  @override
  void onInit() {
    super.onInit();
    setFilter(DateFilter.monthly);
  }

  // =========================================================
  // 1. FILTER LOGIC
  // =========================================================
  void setFilter(DateFilter filter) {
    filterType.value = filter;
    DateTime now = DateTime.now();

    switch (filter) {
      case DateFilter.daily:
        selectedRange.value = DateTimeRange(start: now, end: now);
        break;
      case DateFilter.monthly:
        selectedRange.value = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
        break;
      case DateFilter.yearly:
        selectedRange.value = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31),
        );
        break;
      default:
        break;
    }
    fetchData();
  }

  void updateCustomDate(DateTimeRange range) {
    selectedRange.value = range;
    filterType.value = DateFilter.custom;
    fetchData();
  }

  // =========================================================
  // 2. MAIN DATA FETCHING & CALCULATION ENGINE
  // =========================================================
  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      // 1. Define Boundaries
      DateTime start = DateTime(
        selectedRange.value.start.year,
        selectedRange.value.start.month,
        selectedRange.value.start.day,
        0,
        0,
        0,
      );
      DateTime end = DateTime(
        selectedRange.value.end.year,
        selectedRange.value.end.month,
        selectedRange.value.end.day,
        23,
        59,
        59,
      );

      // 2. Prepare Futures
      var salesFuture =
          _db
              .collection('daily_sales')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThanOrEqualTo: end)
              .orderBy('timestamp', descending: true)
              .get();

      var ledgerFuture =
          _db
              .collection('cash_ledger')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThanOrEqualTo: end)
              .orderBy('timestamp', descending: true)
              .get();

      var expensesFuture = _fetchExpensesOptimized(start, end);

      // 3. Wait for all data
      var results = await Future.wait([
        salesFuture,
        ledgerFuture,
        expensesFuture,
      ]);

      var salesSnap = results[0] as QuerySnapshot;
      var ledgerSnap = results[1] as QuerySnapshot;
      List<DrawerTransaction> expenseList =
          results[2] as List<DrawerTransaction>;

      // --- PROCESS DATA ---
      List<DrawerTransaction> allTx = [...expenseList];

      double tempCash = 0, tempBank = 0, tempBkash = 0, tempNagad = 0;
      double tSales = 0, tExp = 0, tAdd = 0;

      // Process Sales
      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double c = 0, b = 0, bk = 0, n = 0;
        var pm = data['paymentMethod'];

        if (pm is Map && pm['type'] == 'multi') {
          c = double.tryParse(pm['cash'].toString()) ?? 0;
          b = double.tryParse(pm['bank'].toString()) ?? 0;
          bk = double.tryParse(pm['bkash'].toString()) ?? 0;
          n = double.tryParse(pm['nagad'].toString()) ?? 0;
        } else {
          double paid = double.tryParse(data['paid'].toString()) ?? 0;
          String type = (pm is Map ? pm['type'] : pm).toString().toLowerCase();
          if (type.contains('bank')) {
            b = paid;
          } else if (type.contains('bkash')) {
            bk = paid;
          } else if (type.contains('nagad')) {
            n = paid;
          } else {
            c = paid;
          }
        }

        tempCash += c;
        tempBank += b;
        tempBkash += bk;
        tempNagad += n;
        tSales += (c + b + bk + n);

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description:
                "Sale #${data['transactionId'] ?? data['invoiceId'] ?? 'NA'}",
            amount: (c + b + bk + n),
            type: 'sale',
            method: 'mixed',
          ),
        );
      }

      // -----------------------------------------------------------------------
      // FIX IS HERE: Process Ledger (Correctly handling if/else logic)
      // -----------------------------------------------------------------------
      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double amount = double.tryParse(data['amount'].toString()) ?? 0;
        String type = data['type'];
        // Normalize string to lowercase to match logic
        String method = (data['method'] ?? 'cash').toString().toLowerCase();

        if (type == 'deposit') {
          if (method.contains('bank')) {
            tempBank += amount;
          } else if (method.contains('bkash')) {
            tempBkash += amount;
          } else if (method.contains('nagad')) {
            tempNagad += amount;
          } else {
            // Only adds to cash if it's NOT Bank, Bkash or Nagad
            tempCash += amount;
          }
          tAdd += amount;
        } else if (type == 'withdraw') {
          if (method.contains('bank')) {
            tempBank -= amount;
          } else if (method.contains('bkash')) {
            tempBkash -= amount;
          } else if (method.contains('nagad')) {
            tempNagad -= amount;
          }
          // Assuming 'withdraw' here means taking money FROM bank TO cash drawer
          // If 'withdraw' means taking money OUT of the shop entirely, remove this line.
          // Based on your 'cashOutFromBank' function, it seems to imply moving to Cash.
          tempCash += amount;
        }

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: data['description'] ?? type,
            amount: amount,
            type: type,
            method: method,
          ),
        );
      }

      // Process Expenses (Cascading Deduction)
      for (var ex in expenseList) {
        tExp += ex.amount;
      }

      double remainingExpense = tExp;
      // Deduct from Cash -> Bank -> Bkash -> Nagad
      if (tempCash >= remainingExpense) {
        tempCash -= remainingExpense;
        remainingExpense = 0;
      } else {
        remainingExpense -= tempCash;
        tempCash = 0;
      }
      if (remainingExpense > 0) {
        if (tempBank >= remainingExpense) {
          tempBank -= remainingExpense;
          remainingExpense = 0;
        } else {
          remainingExpense -= tempBank;
          tempBank = 0;
        }
      }
      if (remainingExpense > 0) {
        if (tempBkash >= remainingExpense) {
          tempBkash -= remainingExpense;
          remainingExpense = 0;
        } else {
          remainingExpense -= tempBkash;
          tempBkash = 0;
        }
      }
      if (remainingExpense > 0) {
        if (tempNagad >= remainingExpense) {
          tempNagad -= remainingExpense;
          remainingExpense = 0;
        } else {
          remainingExpense -= tempNagad;
          tempNagad = 0;
        }
      }

      // --- UPDATE STATE ---
      netCash.value = tempCash;
      netBank.value = tempBank;
      netBkash.value = tempBkash;
      netNagad.value = tempNagad;
      grandTotal.value = tempCash + tempBank + tempBkash + tempNagad;

      rawSalesTotal.value = tSales;
      rawExpenseTotal.value = tExp;
      rawManualAddTotal.value = tAdd;

      allTx.sort((a, b) => b.date.compareTo(a.date));
      recentTransactions.assignAll(allTx.take(20).toList());
    } catch (e) {
      print("Cash Drawer Error: $e");
      Get.snackbar("Error", "Could not calculate cash drawer.");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // 3. OPTIMIZED EXPENSE FETCHING
  // =========================================================
  Future<List<DrawerTransaction>> _fetchExpensesOptimized(
    DateTime start,
    DateTime end,
  ) async {
    List<DrawerTransaction> expenses = [];
    try {
      var snap =
          await _db
              .collectionGroup('items')
              .where('time', isGreaterThanOrEqualTo: start)
              .where('time', isLessThanOrEqualTo: end)
              .orderBy('time', descending: true)
              .get();

      for (var doc in snap.docs) {
        _addExpenseFromDoc(doc.data(), expenses);
      }
    } catch (e) {
      return await _fetchExpensesParallel(start, end);
    }
    return expenses;
  }

  Future<List<DrawerTransaction>> _fetchExpensesParallel(
    DateTime start,
    DateTime end,
  ) async {
    List<DrawerTransaction> allExpenses = [];
    List<Future<void>> tasks = [];
    int days = end.difference(start).inDays;

    for (int i = 0; i <= days; i++) {
      DateTime current = start.add(Duration(days: i));
      tasks.add(_fetchSingleDayExpense(current, allExpenses));
    }
    await Future.wait(tasks);
    return allExpenses;
  }

  Future<void> _fetchSingleDayExpense(
    DateTime date,
    List<DrawerTransaction> list,
  ) async {
    String dateDocId = DateFormat('yyyy-MM-dd').format(date);
    try {
      var snap =
          await _db
              .collection('daily_expenses')
              .doc(dateDocId)
              .collection('items')
              .get();
      for (var doc in snap.docs) {
        _addExpenseFromDoc(doc.data(), list);
      }
    } catch (e) {
      // Ignore
    }
  }

  void _addExpenseFromDoc(
    Map<String, dynamic> data,
    List<DrawerTransaction> list,
  ) {
    double amt = double.tryParse(data['amount'].toString()) ?? 0.0;
    DateTime txDate = DateTime.now();
    if (data['time'] is Timestamp) {
      txDate = (data['time'] as Timestamp).toDate();
    } else if (data['lastUpdated'] is Timestamp) {
      txDate = (data['lastUpdated'] as Timestamp).toDate();
    }
    list.add(
      DrawerTransaction(
        date: txDate,
        description: data['name'] ?? data['note'] ?? 'Expense',
        amount: amt,
        type: 'expense',
        method: 'deducted',
      ),
    );
  }

  // =========================================================
  // 4. ACTIONS & PDF
  // =========================================================
  Future<void> addManualCash({
    required double amount,
    required String method,
    required String desc,
  }) async {
    await _db.collection('cash_ledger').add({
      'type': 'deposit',
      'amount': amount,
      'method': method,
      'description': desc,
      'timestamp': FieldValue.serverTimestamp(),
    });
    fetchData();
  }

  Future<void> cashOutFromBank({
    required double amount,
    required String fromMethod,
  }) async {
    await _db.collection('cash_ledger').add({
      'type': 'withdraw',
      'amount': amount,
      'method': fromMethod,
      'description': 'Cash Out / Withdrawal',
      'timestamp': FieldValue.serverTimestamp(),
    });
    fetchData();
    Get.back();
  }

  Future<void> downloadPdf() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    String period =
        "${DateFormat('dd MMM').format(selectedRange.value.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange.value.end)}";

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Cash Drawer Report",
                      style: pw.TextStyle(font: fontBold, fontSize: 22),
                    ),
                    pw.Text(
                      "Generated: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Text(
                "Period: $period",
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.SizedBox(height: 15),

              // Total Assets Box (Updated Prominence)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "GRAND TOTAL CASH (ALL SOURCES)",
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "${_currencyFormat.format(grandTotal.value)} BDT",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 24,
                        color: PdfColors.green900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Overview Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStat(
                    "Sales Income",
                    rawSalesTotal.value,
                    fontBold,
                    isPos: true,
                  ),
                  _pdfStat(
                    "Total Expenses",
                    rawExpenseTotal.value,
                    fontBold,
                    isPos: false,
                  ),
                  _pdfStat(
                    "Manual Adds",
                    rawManualAddTotal.value,
                    fontBold,
                    isPos: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Net Balances Table
              pw.Text(
                "CASH POSITIONS (Where is the money?)",
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfTableRow(
                    "Direct Cash (In Hand)",
                    netCash.value,
                    fontBold,
                    isTotal: true,
                  ),
                  _pdfTableRow("Bank Balance", netBank.value, font),
                  _pdfTableRow("Bkash Balance", netBkash.value, font),
                  _pdfTableRow("Nagad Balance", netNagad.value, font),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                "Transaction Log",
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.Divider(),

              // Transactions Table
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Date', 'Description', 'Type', 'Amount'],
                data:
                    recentTransactions.map((tx) {
                      String sign = tx.type == 'expense' ? '-' : '+';
                      return [
                        DateFormat('dd-MMM HH:mm').format(tx.date),
                        tx.description,
                        tx.type.toUpperCase(),
                        "$sign${_currencyFormat.format(tx.amount)}",
                      ];
                    }).toList(),
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  pw.Widget _pdfStat(
    String label,
    double val,
    pw.Font font, {
    bool isPos = true,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          _currencyFormat.format(val),
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
            color: isPos ? PdfColors.black : PdfColors.red,
          ),
        ),
      ],
    );
  }

  pw.TableRow _pdfTableRow(
    String label,
    double val,
    pw.Font font, {
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration:
          isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(font: font)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            "${_currencyFormat.format(val)} BDT",
            style: pw.TextStyle(font: font),
          ),
        ),
      ],
    );
  }
}
