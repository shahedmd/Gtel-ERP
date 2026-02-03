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
  final String type; // 'sale', 'collection', 'expense', 'withdraw'
  final String method; // 'Cash', 'Bank', 'Multi'
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

  // --- LIVE BALANCES ---
  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  // --- REPORT TOTALS ---
  final RxDouble rawSalesTotal = 0.0.obs;
  final RxDouble rawCollectionTotal = 0.0.obs;
  final RxDouble rawExpenseTotal = 0.0.obs;

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
      double tCash = 0, tBank = 0, tBkash = 0, tNagad = 0;
      double sumSales = 0, sumCollections = 0, sumExpenses = 0;

      // =========================================================
      // PART A: PROCESS DAILY SALES (Current Invoice Payments)
      // =========================================================
      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double paidAmount = double.tryParse(data['paid'].toString()) ?? 0;
        if (paidAmount <= 0) continue;

        sumSales += paidAmount;

        var pm = data['paymentMethod'];
        double c = 0, b = 0, bk = 0, n = 0;
        String? saleBankName;
        String? saleAccountInfo;
        String methodStr = 'cash';

        if (pm is Map) {
          methodStr = (pm['type'] ?? 'unknown').toString();

          if (pm.containsKey('bankName'))
            saleBankName = pm['bankName'].toString();
          if (pm.containsKey('accountNumber'))
            saleAccountInfo = pm['accountNumber'].toString();
          else if (pm.containsKey('bkashNumber'))
            saleAccountInfo = "Bkash: ${pm['bkashNumber']}";
          else if (pm.containsKey('nagadNumber'))
            saleAccountInfo = "Nagad: ${pm['nagadNumber']}";

          // Multi / Partial Logic
          if (methodStr == 'multi' || methodStr == 'condition_partial') {
            double inCash = double.tryParse(pm['cash'].toString()) ?? 0;
            double inBank = double.tryParse(pm['bank'].toString()) ?? 0;
            double inBkash = double.tryParse(pm['bkash'].toString()) ?? 0;
            double inNagad = double.tryParse(pm['nagad'].toString()) ?? 0;

            // Simple allocation (assuming paidAmount matches sum of parts)
            // But if paidAmount < sum (e.g. allocated to old due), we scale down proportionally or prioritize
            // For now, assume paidAmount is the net new cash in.

            // Recalculate buckets based on paidAmount proportionally if needed,
            // but usually 'paid' field matches the sum of these inputs for new sales.
            c = inCash;
            b = inBank;
            bk = inBkash;
            n = inNagad;

            // Update Method String for Display
            List<String> parts = [];
            if (c > 0) parts.add("Cash");
            if (b > 0) parts.add("Bank");
            if (bk > 0) parts.add("Bkash");
            if (n > 0) parts.add("Nagad");
            methodStr = parts.join("/");
          } else {
            // Single Method
            String typeCheck = methodStr.toLowerCase();
            if (typeCheck.contains('bank') || (saleBankName != null))
              b = paidAmount;
            else if (typeCheck.contains('bkash'))
              bk = paidAmount;
            else if (typeCheck.contains('nagad'))
              n = paidAmount;
            else
              c = paidAmount;
          }
        } else {
          // Legacy String
          methodStr = pm.toString().toLowerCase();
          if (methodStr.contains('bank'))
            b = paidAmount;
          else if (methodStr.contains('bkash'))
            bk = paidAmount;
          else if (methodStr.contains('nagad'))
            n = paidAmount;
          else
            c = paidAmount;
        }

        tCash += c;
        tBank += b;
        tBkash += bk;
        tNagad += n;

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description:
                (data['customerType'] == 'debtor')
                    ? "Inv #${data['transactionId']} (Current)"
                    : "Sale #${data['transactionId'] ?? 'NA'}",
            amount: paidAmount,
            type: 'sale',
            method: methodStr.toUpperCase(),
            bankName: saleBankName,
            accountDetails: saleAccountInfo,
          ),
        );
      }

      // =========================================================
      // PART B: PROCESS LEDGER
      // =========================================================
      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String source = (data['source'] ?? '').toString();

        if (source == 'pos_sale') continue;
        if (source == '' && data.containsKey('linkedInvoiceId')) continue;

        double amount = double.tryParse(data['amount'].toString()) ?? 0;
        String type = data['type'];
        String method =
            (data['method'] ?? 'cash').toString().toLowerCase().trim();
        String desc = data['description'] ?? type.toUpperCase();

        String? ledgerBankName = data['bankName']?.toString();
        String? ledgerAccountNo = data['accountNo']?.toString();

        if (data['details'] is Map) {
          var d = data['details'];
          if (d['bankName'] != null) ledgerBankName = d['bankName'].toString();
          if (d['accountNumber'] != null)
            ledgerAccountNo = d['accountNumber'].toString();
          else if (d['bkashNumber'] != null)
            ledgerAccountNo = "Bkash: ${d['bkashNumber']}";
          else if (d['nagadNumber'] != null)
            ledgerAccountNo = "Nagad: ${d['nagadNumber']}";
          if (d['type'] != null) method = d['type'].toString().toLowerCase();
        }

        bool isBank =
            method.contains('bank') ||
            (ledgerBankName != null && ledgerBankName.isNotEmpty);
        bool isBkash = method.contains('bkash');
        bool isNagad = method.contains('nagad');

        if (type == 'deposit') {
          sumCollections += amount;
          if (isBank)
            tBank += amount;
          else if (isBkash)
            tBkash += amount;
          else if (isNagad)
            tNagad += amount;
          else
            tCash += amount;
        } else {
          sumExpenses += amount;
          if (isBank)
            tBank -= amount;
          else if (isBkash)
            tBkash -= amount;
          else if (isNagad)
            tNagad -= amount;
          else
            tCash -= amount;
        }

        if (source == 'pos_old_due') desc = "Old Due Collection";

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: desc,
            amount: amount,
            type: type == 'deposit' ? 'collection' : 'withdraw',
            method: method.toUpperCase(),
            bankName: ledgerBankName,
            accountDetails: ledgerAccountNo,
          ),
        );
      }

      // =========================================================
      // PART C: EXPENSES
      // =========================================================
      for (var ex in expenseList) {
        sumExpenses += ex.amount;
        // Waterfall deduction: Cash -> Bank -> Bkash -> Nagad
        double rem = ex.amount;
        if (tCash >= rem) {
          tCash -= rem;
          rem = 0;
        } else {
          rem -= tCash;
          tCash = 0;
        }
        if (rem > 0) {
          if (tBank >= rem) {
            tBank -= rem;
            rem = 0;
          } else {
            rem -= tBank;
            tBank = 0;
          }
        }
        if (rem > 0) {
          if (tBkash >= rem) {
            tBkash -= rem;
            rem = 0;
          } else {
            rem -= tBkash;
            tBkash = 0;
          }
        }
        if (rem > 0) {
          if (tNagad >= rem) {
            tNagad -= rem;
            rem = 0;
          } else {
            rem -= tNagad;
            tNagad = 0;
          }
        }
      }

      netCash.value = tCash;
      netBank.value = tBank;
      netBkash.value = tBkash;
      netNagad.value = tNagad;
      grandTotal.value = tCash + tBank + tBkash + tNagad;

      rawSalesTotal.value = sumSales;
      rawCollectionTotal.value = sumCollections;
      rawExpenseTotal.value = sumExpenses;

      allTx.sort((a, b) => b.date.compareTo(a.date));
      recentTransactions.assignAll(allTx);
    } catch (e) {
      Get.snackbar("Error", "Could not calculate cash drawer.");
    } finally {
      isLoading.value = false;
    }
  }

  // --- HELPERS & MANUAL ACTIONS ---

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
      return []; // Fallback empty or parallel logic
    }
    return expenses;
  }

  void _addExpenseFromDoc(
    Map<String, dynamic> data,
    List<DrawerTransaction> list,
  ) {
    double amt = double.tryParse(data['amount'].toString()) ?? 0.0;
    DateTime txDate = DateTime.now();
    if (data['time'] is Timestamp)
      txDate = (data['time'] as Timestamp).toDate();

    list.add(
      DrawerTransaction(
        date: txDate,
        description: data['name'] ?? data['note'] ?? 'Expense',
        amount: amt,
        type: 'expense',
        method: 'DEDUCTED',
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
      'source': 'manual_add',
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
      'source': 'manual_withdraw',
    });
    fetchData();
    Get.back();
  }

  // --- PDF REPORT ---
  Future<void> downloadPdf() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
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
                      "Cash Position Report",
                      style: pw.TextStyle(font: fontBold, fontSize: 18),
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
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 15),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSummaryCol(
                      "Sales Income",
                      rawSalesTotal.value,
                      fontBold,
                      PdfColors.green900,
                    ),
                    _pdfSummaryCol(
                      "Collections/Add",
                      rawCollectionTotal.value,
                      fontBold,
                      PdfColors.blue900,
                    ),
                    _pdfSummaryCol(
                      "Expenses",
                      rawExpenseTotal.value,
                      fontBold,
                      PdfColors.red900,
                    ),
                    _pdfSummaryCol(
                      "Net Cash",
                      grandTotal.value,
                      fontBold,
                      PdfColors.black,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Balances
              pw.Text(
                "Current Balances",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfRow("Cash In Hand", netCash.value, font),
                  _pdfRow("Bank", netBank.value, font),
                  _pdfRow("Bkash", netBkash.value, font),
                  _pdfRow("Nagad", netNagad.value, font),
                ],
              ),

              pw.SizedBox(height: 20),

              // Transactions
              pw.Text(
                "Transaction History",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.Divider(),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Desc', 'Method', 'Amount'],
                data:
                    recentTransactions
                        .map(
                          (tx) => [
                            DateFormat('dd-MMM HH:mm').format(tx.date),
                            tx.description,
                            tx.method,
                            "${tx.type == 'withdraw' || tx.type == 'expense' ? '-' : '+'}${_currencyFormat.format(tx.amount)}",
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  pw.Widget _pdfSummaryCol(
    String label,
    double val,
    pw.Font font,
    PdfColor color, {
    bool isTotal = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          _currencyFormat.format(val),
          style: pw.TextStyle(
            font: font,
            fontSize: isTotal ? 14 : 11,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.TableRow _pdfRow(String label, double val, pw.Font font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            "${_currencyFormat.format(val)} BDT",
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
        ),
      ],
    );
  }
}
