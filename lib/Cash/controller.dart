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
  final String type; // 'sale', 'collection' (deposit), 'expense', 'withdraw'
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

  // --- LIVE BALANCES ---
  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  // --- REPORT TOTALS ---
  final RxDouble rawSalesTotal = 0.0.obs; // Pure Invoice Sales
  final RxDouble rawCollectionTotal = 0.0.obs; // Old Due + Manual Adds
  final RxDouble rawExpenseTotal = 0.0.obs; // Expenses + Withdrawals

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
      // 1. Prepare Date Range
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

      // 2. Fetch Data in Parallel
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

      // 3. Initialize Calculation Variables
      List<DrawerTransaction> allTx = [...expenseList];
      double tCash = 0, tBank = 0, tBkash = 0, tNagad = 0;
      double sumSales = 0, sumCollections = 0, sumExpenses = 0;

      // =========================================================
      // PART A: PROCESS DAILY SALES (Current Invoice Payments)
      // =========================================================
      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // In the new system, 'paid' is strictly the amount allocated to the invoice.
        // It does NOT include Old Due collection.
        double paidAmount = double.tryParse(data['paid'].toString()) ?? 0;

        if (paidAmount <= 0) continue; // Skip unpaid/credit invoices

        sumSales += paidAmount;

        // Parse Payment Method
        var pm = data['paymentMethod'];
        double c = 0, b = 0, bk = 0, n = 0;

        String? saleBankName;
        String? saleAccountInfo;
        String methodStr = 'cash';

        if (pm is Map) {
          methodStr = (pm['type'] ?? 'unknown').toString();

          // Extract Details
          if (pm.containsKey('bankName'))
            saleBankName = pm['bankName'].toString();

          if (pm.containsKey('accountNumber'))
            saleAccountInfo = pm['accountNumber'].toString();
          else if (pm.containsKey('bkashNumber'))
            saleAccountInfo = "Bkash: ${pm['bkashNumber']}";
          else if (pm.containsKey('nagadNumber'))
            saleAccountInfo = "Nagad: ${pm['nagadNumber']}";

          // Distribution Logic for Multi/Partial
          if (methodStr == 'multi' || methodStr == 'condition_partial') {
            // We allocate the 'paidAmount' to buckets based on what was entered.
            // We prioritize Cash -> Bank -> Bkash -> Nagad for the invoice portion
            // (Assuming Ledger took the exact specific funds for Old Due first)
            double inCash = double.tryParse(pm['cash'].toString()) ?? 0;
            double inBank = double.tryParse(pm['bank'].toString()) ?? 0;
            double inBkash = double.tryParse(pm['bkash'].toString()) ?? 0;
            double inNagad = double.tryParse(pm['nagad'].toString()) ?? 0;

            double remainingToAlloc = paidAmount;

            if (remainingToAlloc > 0 && inCash > 0) {
              double use =
                  (inCash >= remainingToAlloc) ? remainingToAlloc : inCash;
              c += use;
              remainingToAlloc -= use;
            }
            if (remainingToAlloc > 0 && inBank > 0) {
              double use =
                  (inBank >= remainingToAlloc) ? remainingToAlloc : inBank;
              b += use;
              remainingToAlloc -= use;
            }
            if (remainingToAlloc > 0 && inBkash > 0) {
              double use =
                  (inBkash >= remainingToAlloc) ? remainingToAlloc : inBkash;
              bk += use;
              remainingToAlloc -= use;
            }
            if (remainingToAlloc > 0 && inNagad > 0) {
              n += remainingToAlloc; // Dump remainder
            }
          } else {
            // Single Method Logic
            String typeCheck = methodStr.toLowerCase();
            bool isBank = typeCheck.contains('bank') || (saleBankName != null);
            bool isBkash = typeCheck.contains('bkash');
            bool isNagad = typeCheck.contains('nagad');

            if (isBank)
              b = paidAmount;
            else if (isBkash)
              bk = paidAmount;
            else if (isNagad)
              n = paidAmount;
            else
              c = paidAmount;
          }
        } else {
          // Legacy String Support
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
                    : "Sale #${data['transactionId'] ?? data['invoiceId'] ?? 'NA'}",
            amount: paidAmount,
            type: 'sale',
            method: methodStr,
            bankName: saleBankName,
            accountDetails: saleAccountInfo,
          ),
        );
      }

      // =========================================================
      // PART B: PROCESS LEDGER (Old Due, Manual Adds, Withdrawals)
      // =========================================================
      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String source = (data['source'] ?? '').toString();
        String desc = (data['description'] ?? '').toString();

        // --- FILTERING LOGIC (FIXED) ---
        // 1. Skip strictly if source is 'pos_sale' (because Part A handled it)
        if (source == 'pos_sale') continue;

        // 2. Legacy Skip: If no source, but has linkedInvoiceId (Old duplicate style)
        if (source == '' && data.containsKey('linkedInvoiceId')) continue;

        // 3. ALLOW 'pos_old_due', 'debtor_manual', 'manual_add', etc.

        double amount = double.tryParse(data['amount'].toString()) ?? 0;
        String type = data['type']; // 'deposit' or 'withdraw'/'expense'
        String method =
            (data['method'] ?? 'cash').toString().toLowerCase().trim();

        // Parse Details (New System Support)
        String? ledgerBankName = data['bankName']?.toString();
        String? ledgerAccountNo = data['accountNo']?.toString();

        // If 'details' map exists (from LiveSalesController), use it
        if (data['details'] is Map) {
          var d = data['details'];
          if (d['bankName'] != null) ledgerBankName = d['bankName'].toString();

          if (d['accountNumber'] != null)
            ledgerAccountNo = d['accountNumber'].toString();
          else if (d['bkashNumber'] != null)
            ledgerAccountNo = "Bkash: ${d['bkashNumber']}";
          else if (d['nagadNumber'] != null)
            ledgerAccountNo = "Nagad: ${d['nagadNumber']}";

          // Override method string if available
          if (d['type'] != null) method = d['type'].toString().toLowerCase();
        }

        // Determine Bucket
        bool isBank =
            method.contains('bank') ||
            (ledgerBankName != null && ledgerBankName.isNotEmpty);
        bool isBkash = method.contains('bkash');
        bool isNagad = method.contains('nagad');

        if (type == 'deposit') {
          sumCollections += amount; // This includes Old Due + Manual Adds
          if (isBank)
            tBank += amount;
          else if (isBkash)
            tBkash += amount;
          else if (isNagad)
            tNagad += amount;
          else
            tCash += amount;
        } else if (type == 'withdraw' || type == 'expense') {
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

        // Fancy Description
        String finalDesc = desc.isNotEmpty ? desc : type.toUpperCase();
        if (source == 'pos_old_due') finalDesc = "Old Due Collection";

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: finalDesc,
            amount: amount,
            type: type == 'deposit' ? 'collection' : 'expense',
            method: method,
            bankName: ledgerBankName,
            accountDetails: ledgerAccountNo,
          ),
        );
      }

      // =========================================================
      // PART C: PROCESS EXPENSES (Waterfall Deduction)
      // =========================================================
      for (var ex in expenseList) {
        sumExpenses += ex.amount;

        // Deduct from Cash -> Bank -> Bkash -> Nagad
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

      // 4. Update Observables
      netCash.value = tCash;
      netBank.value = tBank;
      netBkash.value = tBkash;
      netNagad.value = tNagad;
      grandTotal.value = tCash + tBank + tBkash + tNagad;

      rawSalesTotal.value = sumSales;
      rawCollectionTotal.value = sumCollections;
      rawExpenseTotal.value = sumExpenses;

      // Sort recent transactions new to old
      allTx.sort((a, b) => b.date.compareTo(a.date));
      recentTransactions.assignAll(allTx);
    } catch (e) {
      print("Cash Drawer Error: $e");
      Get.snackbar("Error", "Could not calculate cash drawer.");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // HELPER METHODS (Optimized & Parallel Fetching)
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
      // Fallback for index issues
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

  // =========================================================
  // MANUAL ACTIONS
  // =========================================================
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

  // =========================================================
  // PDF REPORT
  // =========================================================
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
                    "Invoice Sales",
                    rawSalesTotal.value,
                    fontBold,
                    isPos: true,
                  ),
                  _pdfStat(
                    "Due/Manual Collect",
                    rawCollectionTotal.value,
                    fontBold,
                    isPos: true,
                  ),
                  _pdfStat(
                    "Total Expenses",
                    rawExpenseTotal.value,
                    fontBold,
                    isPos: false,
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
