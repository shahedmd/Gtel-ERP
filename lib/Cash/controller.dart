// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum DateFilter { daily, monthly, yearly, custom }

class DrawerTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final String method;
  final String? bankName;
  final String? accountDetails;

  DrawerTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.method,
    this.bankName,
    this.accountDetails,
  });
}

class CashDrawerController extends GetxController {
  static CashDrawerController get to => Get.find();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final Rx<DateFilter> filterType = DateFilter.monthly.obs;
  final Rx<DateTimeRange> selectedRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now()).obs;

  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  final RxDouble rawSalesTotal = 0.0.obs;
  final RxDouble rawExpenseTotal = 0.0.obs;
  final RxDouble rawManualAddTotal = 0.0.obs;

  final RxList<DrawerTransaction> recentTransactions =
      <DrawerTransaction>[].obs;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  @override
  void onInit() {
    super.onInit();
    setFilter(DateFilter.monthly);
  }

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

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
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

      var results = await Future.wait([
        salesFuture,
        ledgerFuture,
        expensesFuture,
      ]);
      var salesSnap = results[0] as QuerySnapshot;
      var ledgerSnap = results[1] as QuerySnapshot;
      List<DrawerTransaction> expenseList =
          results[2] as List<DrawerTransaction>;

      List<DrawerTransaction> allTx = [...expenseList];
      double tempCash = 0, tempBank = 0, tempBkash = 0, tempNagad = 0;
      double tSales = 0, tExp = 0, tAdd = 0;

      // ---------------------------------------------------
      // 1. PROCESS SALES & DEBTOR PAYMENTS (Primary Source)
      // ---------------------------------------------------
      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double c = 0, b = 0, bk = 0, n = 0;
        var pm = data['paymentMethod'];

        String? saleBankName;
        String? saleAccountInfo;
        String methodStr = 'cash';

        if (pm is Map) {
          methodStr = (pm['type'] ?? 'unknown').toString();

          // Extract Bank/Method Info
          if (pm.containsKey('bankName')) {
            saleBankName = pm['bankName'].toString();
          }
          if (pm.containsKey('accountNumber') &&
              pm['accountNumber'].toString().isNotEmpty) {
            saleAccountInfo = pm['accountNumber'].toString();
          } else if (pm.containsKey('accountNo') &&
              pm['accountNo'].toString().isNotEmpty) {
            saleAccountInfo = pm['accountNo'].toString();
          }
          if (pm.containsKey('bkashNumber') &&
              pm['bkashNumber'].toString().isNotEmpty) {
            saleAccountInfo = "Bkash: ${pm['bkashNumber']}";
          }

          if (methodStr == 'multi') {
            c = double.tryParse(pm['cash'].toString()) ?? 0;
            b = double.tryParse(pm['bank'].toString()) ?? 0;
            bk = double.tryParse(pm['bkash'].toString()) ?? 0;
            n = double.tryParse(pm['nagad'].toString()) ?? 0;
          } else {
            double paid = double.tryParse(data['paid'].toString()) ?? 0;
            String typeCheck = methodStr.toLowerCase();

            // FORCE BANK/DIGITAL: If bankName exists, it IS a bank payment
            bool isBank =
                typeCheck.contains('bank') ||
                (saleBankName != null && saleBankName.isNotEmpty);
            bool isBkash = typeCheck.contains('bkash');
            bool isNagad = typeCheck.contains('nagad');

            if (isBank) {
              b = paid;
            } else if (isBkash)
              {bk = paid;}
            else if (isNagad)
             { n = paid;}
            else
             { c = paid;}
          }
        } else {
          double paid = double.tryParse(data['paid'].toString()) ?? 0;
          methodStr = pm.toString().toLowerCase();
          if (methodStr.contains('bank')) {
            b = paid;
          } else if (methodStr.contains('bkash'))
            bk = paid;
          else if (methodStr.contains('nagad'))
            n = paid;
          else
            c = paid;
        }

        tempCash += c;
        tempBank += b;
        tempBkash += bk;
        tempNagad += n;
        double totalDocPaid = c + b + bk + n;
        tSales += totalDocPaid;

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description:
                (data['source'] == 'advance_payment' ||
                        data['customerType'] == 'debtor')
                    ? "Payment: ${data['name'] ?? 'Debtor'}"
                    : "Sale #${data['transactionId'] ?? data['invoiceId'] ?? 'NA'}",
            amount: totalDocPaid,
            type: 'sale',
            method: methodStr,
            bankName: saleBankName,
            accountDetails: saleAccountInfo,
          ),
        );
      }

      // ---------------------------------------------------
      // 2. PROCESS LEDGER (Strict Deduplication & Fix for Double Cash)
      // ---------------------------------------------------
      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // >>> FIX 1: Aggressive Skipping of Duplicates
        // If the description mentions "payment from", it is likely a system-generated duplicate of a debtor payment.
        String desc = (data['description'] ?? '').toString().toLowerCase();

        bool isDuplicate =
            data.containsKey('linkedTxId') ||
            data.containsKey('linkedInvoiceId') ||
            data.containsKey('linkedDebtorId') ||
            data['source'] == 'pos_sale' ||
            data['source'] == 'advance_payment' ||
            // Safety Catch for old data:
            (desc.contains('payment from') && data['type'] == 'deposit');

        if (isDuplicate) {
          continue;
        }

        double amount = double.tryParse(data['amount'].toString()) ?? 0;
        String type = data['type'];
        String method =
            (data['method'] ?? 'cash').toString().toLowerCase().trim();

        String? ledgerBankName = data['bankName']?.toString();
        String? ledgerAccountNo = data['accountNo']?.toString();

        if (ledgerBankName == null && data['details'] is Map) {
          ledgerBankName = data['details']['bankName']?.toString();
        }
        if (ledgerAccountNo == null && data['details'] is Map) {
          ledgerAccountNo = data['details']['accountNo']?.toString();
        }

        // >>> FIX 2: Better Digital Detection
        // If bank details exist, we assume it's NOT cash, even if 'method' string is missing or weird.
        bool isBank =
            method.contains('bank') ||
            (ledgerBankName != null && ledgerBankName.isNotEmpty);
        bool isBkash = method.contains('bkash');
        bool isNagad = method.contains('nagad');

        if (type == 'deposit') {
          if (isBank) {
            tempBank += amount;
          } else if (isBkash) {
            tempBkash += amount;
          } else if (isNagad) {
            tempNagad += amount;
          } else {
            // Only add to Direct Cash if we are absolutely sure it's not the others
            tempCash += amount;
          }
          tAdd += amount;
        } else if (type == 'withdraw') {
          if (isBank) {
            tempBank -= amount;
          } else if (isBkash)
            tempBkash -= amount;
          else if (isNagad)
            tempNagad -= amount;
          tempCash += amount;
        }

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: data['description'] ?? type.toUpperCase(),
            amount: amount,
            type: type,
            method: method,
            bankName: ledgerBankName,
            accountDetails: ledgerAccountNo,
          ),
        );
      }

      // ---------------------------------------------------
      // 3. PROCESS EXPENSES
      // ---------------------------------------------------
      for (var ex in expenseList) {
        tExp += ex.amount;
      }

      double remainingExpense = tExp;

      // Waterfall Deduction: Cash -> Bank -> Bkash -> Nagad
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
      recentTransactions.assignAll(allTx);
    } catch (e) {
      Get.snackbar("Error", "Could not calculate cash drawer.");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // HELPER METHODS
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
    } catch (e) {}
  }

  void _addExpenseFromDoc(
    Map<String, dynamic> data,
    List<DrawerTransaction> list,
  ) {
    double amt = double.tryParse(data['amount'].toString()) ?? 0.0;
    DateTime txDate = DateTime.now();
    if (data['time'] is Timestamp) {
      txDate = (data['time'] as Timestamp).toDate();
    } else if (data['lastUpdated'] is Timestamp)
      txDate = (data['lastUpdated'] as Timestamp).toDate();
    list.add(
      DrawerTransaction(
        date: txDate,
        description: data['name'] ?? data['note'] ?? 'Expense',
        amount: amt,
        type: 'expense',
        method: 'deducted',
        bankName: null,
        accountDetails: null,
      ),
    );
  }

  Future<void> addManualCash({
    required double amount,
    required String method,
    required String desc,
    String? bankName,
    String? accountNo,
  }) async {
    await _db.collection('cash_ledger').add({
      'type': 'deposit',
      'amount': amount,
      'method': method,
      'description': desc,
      'bankName': bankName,
      'accountNo': accountNo,
      'timestamp': FieldValue.serverTimestamp(),
    });
    fetchData();
  }

  Future<void> cashOutFromBank({
    required double amount,
    required String fromMethod,
    String? bankName,
    String? accountNo,
  }) async {
    await _db.collection('cash_ledger').add({
      'type': 'withdraw',
      'amount': amount,
      'method': fromMethod,
      'bankName': bankName,
      'accountNo': accountNo,
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
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      "GRAND TOTAL CASH",
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
              pw.Text(
                "CASH POSITIONS",
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
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Date', 'Desc', 'Method/Details', 'Amount'],
                data:
                    recentTransactions.map((tx) {
                      String sign = tx.type == 'expense' ? '-' : '+';
                      String methodDisplay = tx.method.toUpperCase();
                      if (tx.bankName != null) {
                        methodDisplay += "\n${tx.bankName}";
                      }
                      if (tx.accountDetails != null) {
                        methodDisplay += "\n(${tx.accountDetails})";
                      }
                      return [
                        DateFormat('dd-MMM HH:mm').format(tx.date),
                        tx.description,
                        methodDisplay,
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
                cellStyle: const pw.TextStyle(fontSize: 8),
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
