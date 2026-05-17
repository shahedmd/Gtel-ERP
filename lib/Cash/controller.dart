// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum DateFilter { daily, monthly, yearly, custom }

// --- MODEL ---
class DrawerTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final String type; // 'sale', 'collection', 'expense', 'transfer', 'withdraw'
  final String method; // 'Cash', 'Bank', 'Bkash', 'Nagad', 'Mixed'
  final String? bankName;
  final String? accountDetails;

  final String? transferFrom;
  final String? transferTo;

  DrawerTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.method,
    this.bankName,
    this.accountDetails,
    this.transferFrom,
    this.transferTo,
  });
}

// --- CONTROLLER ---
class CashDrawerController extends GetxController {
  static CashDrawerController get to => Get.find();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final Rx<DateFilter> filterType = DateFilter.monthly.obs;
  final Rx<DateTimeRange> selectedRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now()).obs;

  // --- LIVE BALANCES (NET LIQUID ASSET - CUMULATIVE) ---
  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs; // TOTAL ASSET

  // --- REPORT TOTALS (PERIOD SPECIFIC) ---
  final RxDouble rawSalesTotal = 0.0.obs;
  final RxDouble rawCollectionTotal = 0.0.obs;
  final RxDouble rawExpenseTotal = 0.0.obs;

  // --- LISTS ---
  final List<DrawerTransaction> _allTransactions = [];
  final RxList<DrawerTransaction> paginatedTransactions =
      <DrawerTransaction>[].obs;

  final RxInt currentPage = 1.obs;
  final int itemsPerPage = 30;
  final RxInt totalItems = 0.obs;

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  String formatNumber(double amount) {
    return _currencyFormat.format(amount);
  }

  @override
  void onInit() {
    super.onInit();
    setFilter(DateFilter.monthly);
  }

  // --- PAGINATION ---
  void _applyPagination() {
    totalItems.value = _allTransactions.length;
    int startIndex = (currentPage.value - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;

    if (startIndex >= _allTransactions.length) {
      paginatedTransactions.clear();
    } else {
      if (endIndex > _allTransactions.length)
        endIndex = _allTransactions.length;
      paginatedTransactions.assignAll(
        _allTransactions.sublist(startIndex, endIndex),
      );
    }
  }

  void nextPage() {
    int maxPage = (totalItems.value / itemsPerPage).ceil();
    if (currentPage.value < maxPage) {
      currentPage.value++;
      _applyPagination();
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      _applyPagination();
    }
  }

  // --- DATE FILTER ---
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

  // ========================================================================
  // CORE FETCH LOGIC (UPDATED FOR MULTI-PAYMENT + EXPENSE METHOD SUPPORT)
  // ========================================================================
  Future<void> fetchData() async {
    isLoading.value = true;
    _allTransactions.clear();
    paginatedTransactions.clear();
    currentPage.value = 1;

    try {
      // 1. Filter Range
      DateTime filterStart = DateTime(
        selectedRange.value.start.year,
        selectedRange.value.start.month,
        selectedRange.value.start.day,
        0,
        0,
        0,
      );
      DateTime filterEnd = DateTime(
        selectedRange.value.end.year,
        selectedRange.value.end.month,
        selectedRange.value.end.day,
        23,
        59,
        59,
      );

      // 2. Absolute Start (for cumulative balances)
      DateTime absoluteStart = DateTime(2020, 1, 1);

      // 3. Fetch Data
      var salesFuture =
          _db
              .collection('daily_sales')
              .where('timestamp', isGreaterThanOrEqualTo: absoluteStart)
              .where('timestamp', isLessThanOrEqualTo: filterEnd)
              .get();

      var ledgerFuture =
          _db
              .collection('cash_ledger')
              .where('timestamp', isGreaterThanOrEqualTo: absoluteStart)
              .where('timestamp', isLessThanOrEqualTo: filterEnd)
              .get();

      var expensesFuture = _fetchExpensesList(absoluteStart, filterEnd);

      var results = await Future.wait([
        salesFuture,
        ledgerFuture,
        expensesFuture,
      ]);

      // 4. Combine & Sort
      List<dynamic> allRawItems = [];

      for (var doc in (results[0] as QuerySnapshot).docs) {
        allRawItems.add({
          'type': 'sale',
          'data': doc.data(),
          'time': (doc['timestamp'] as Timestamp).toDate(),
        });
      }

      for (var doc in (results[1] as QuerySnapshot).docs) {
        allRawItems.add({
          'type': 'ledger',
          'data': doc.data(),
          'time': (doc['timestamp'] as Timestamp).toDate(),
        });
      }

      List<DrawerTransaction> expenseList =
          results[2] as List<DrawerTransaction>;
      for (var ex in expenseList) {
        allRawItems.add({'type': 'expense', 'data': ex, 'time': ex.date});
      }

      allRawItems.sort((a, b) => a['time'].compareTo(b['time']));

      // 5. Accumulators
      double tCash = 0, tBank = 0, tBkash = 0, tNagad = 0;
      double periodSales = 0, periodCollections = 0, periodExpenses = 0;
      List<DrawerTransaction> periodTxList = [];

      // 6. PROCESS LOOP
      for (var item in allRawItems) {
        DateTime itemTime = item['time'];
        bool isInPeriod =
            itemTime.compareTo(filterStart) >= 0 &&
            itemTime.compareTo(filterEnd) <= 0;

        // --- SALES PROCESSING ---
        if (item['type'] == 'sale') {
          var data = item['data'];
          double totalPaid = double.tryParse(data['paid'].toString()) ?? 0;
          double ledgerPaid =
              double.tryParse(data['ledgerPaid'].toString()) ?? 0;
          double actualReceived = totalPaid - ledgerPaid;

          if (actualReceived > 0.01) {
            double c = 0, b = 0, bk = 0, n = 0;
            String displayMethod = "Cash";
            String? displayBankDetails;

            var pm = data['paymentMethod'];

            if (pm is Map) {
              c = double.tryParse(pm['cash'].toString()) ?? 0;
              b = double.tryParse(pm['bank'].toString()) ?? 0;
              bk = double.tryParse(pm['bkash'].toString()) ?? 0;
              n = double.tryParse(pm['nagad'].toString()) ?? 0;

              displayBankDetails = pm['bankName'];

              // Legacy Fallback
              if ((c + b + bk + n) == 0) {
                String valBank = (pm['bankName'] ?? '').toString();
                String valBkash = (pm['bkashNumber'] ?? '').toString();
                String valNagad = (pm['nagadNumber'] ?? '').toString();

                if (valBank.isNotEmpty) {
                  b = actualReceived;
                } else if (valBkash.isNotEmpty) {
                  bk = actualReceived;
                } else if (valNagad.isNotEmpty) {
                  n = actualReceived;
                } else {
                  c = actualReceived;
                }
              }
            } else {
              String s = pm.toString().toLowerCase();
              if (s.contains('bank'))
                b = actualReceived;
              else if (s.contains('bkash'))
                bk = actualReceived;
              else if (s.contains('nagad'))
                n = actualReceived;
              else
                c = actualReceived;
            }

            List<String> activeMethods = [];
            if (c > 0) activeMethods.add("Cash");
            if (b > 0) activeMethods.add("Bank");
            if (bk > 0) activeMethods.add("Bkash");
            if (n > 0) activeMethods.add("Nagad");

            if (activeMethods.length > 1) {
              displayMethod = "Multi";
            } else if (activeMethods.isNotEmpty) {
              displayMethod = activeMethods.first;
            }

            tCash += c;
            tBank += b;
            tBkash += bk;
            tNagad += n;

            if (isInPeriod) {
              periodSales += actualReceived;

              String desc = "Sale: ${data['name'] ?? 'NA'}";
              if (displayMethod == "Multi") {
                desc +=
                    " (C:${_currencyFormat.format(c)} B:${_currencyFormat.format(b)} Bk:${_currencyFormat.format(bk)} N:${_currencyFormat.format(n)})";
              }

              periodTxList.add(
                DrawerTransaction(
                  date: itemTime,
                  description: desc,
                  amount: actualReceived,
                  type: 'sale',
                  method: displayMethod,
                  bankName: displayBankDetails,
                  accountDetails: null,
                ),
              );
            }
          }
        }
        // --- LEDGER PROCESSING ---
        else if (item['type'] == 'ledger') {
          var data = item['data'];
          if (data['source'] == 'pos_sale') continue;

          double amt = double.tryParse(data['amount'].toString()) ?? 0;
          String type = data['type'] ?? 'deposit';

          if (type == 'transfer') {
            String from = (data['fromMethod'] ?? 'Cash').toString();
            String to = (data['toMethod'] ?? 'Cash').toString();

            if (from == 'Bank')
              tBank -= amt;
            else if (from == 'Bkash')
              tBkash -= amt;
            else if (from == 'Nagad')
              tNagad -= amt;
            else
              tCash -= amt;

            if (to == 'Bank')
              tBank += amt;
            else if (to == 'Bkash')
              tBkash += amt;
            else if (to == 'Nagad')
              tNagad += amt;
            else
              tCash += amt;

            if (isInPeriod) {
              periodTxList.add(
                DrawerTransaction(
                  date: itemTime,
                  description: data['description'] ?? "Transfer",
                  amount: amt,
                  type: 'transfer',
                  method: "$from > $to",
                ),
              );
            }
          } else {
            String methodStr = (data['method'] ?? 'Cash').toString();
            bool isBank = methodStr.toLowerCase().contains('bank');
            bool isBkash = methodStr.toLowerCase().contains('bkash');
            bool isNagad = methodStr.toLowerCase().contains('nagad');

            if (type == 'deposit') {
              if (isInPeriod) periodCollections += amt;
              if (isBank)
                tBank += amt;
              else if (isBkash)
                tBkash += amt;
              else if (isNagad)
                tNagad += amt;
              else
                tCash += amt;
            } else {
              if (isInPeriod) periodExpenses += amt;
              if (isBank)
                tBank -= amt;
              else if (isBkash)
                tBkash -= amt;
              else if (isNagad)
                tNagad -= amt;
              else
                tCash -= amt;
            }

            if (isInPeriod) {
              periodTxList.add(
                DrawerTransaction(
                  date: itemTime,
                  description: data['description'] ?? "Entry",
                  amount: amt,
                  type: type == 'deposit' ? 'collection' : 'withdraw',
                  method: methodStr,
                ),
              );
            }
          }
        }
        // --- EXPENSE PROCESSING (FIXED: Uses saved method field) ---
        else if (item['type'] == 'expense') {
          DrawerTransaction ex = item['data'];
          if (isInPeriod) periodExpenses += ex.amount;

          String method = ex.method.toLowerCase();

          if (method.contains('bank')) {
            // Deduct directly from Bank
            tBank -= ex.amount;
          } else if (method.contains('bkash')) {
            // Deduct directly from Bkash
            tBkash -= ex.amount;
          } else if (method.contains('nagad')) {
            // Deduct directly from Nagad
            tNagad -= ex.amount;
          } else {
            // 'Cash' or legacy 'Auto' records → waterfall from Cash first
            double rem = ex.amount;

            if (tCash >= rem) {
              tCash -= rem;
              rem = 0;
            } else {
              rem -= tCash;
              tCash = 0;
            }

            if (rem > 0) {
              double deduct = rem.clamp(0, tBank);
              tBank -= deduct;
              rem -= deduct;
            }

            if (rem > 0) {
              double deduct = rem.clamp(0, tBkash);
              tBkash -= deduct;
              rem -= deduct;
            }

            if (rem > 0) {
              double deduct = rem.clamp(0, tNagad);
              tNagad -= deduct;
            }
          }

          if (isInPeriod) periodTxList.add(ex);
        }
      }

      // 7. Update Observables
      netCash.value = tCash;
      netBank.value = tBank;
      netBkash.value = tBkash;
      netNagad.value = tNagad;
      grandTotal.value = tCash + tBank + tBkash + tNagad;

      rawSalesTotal.value = periodSales;
      rawCollectionTotal.value = periodCollections;
      rawExpenseTotal.value = periodExpenses;

      // 8. Update List
      periodTxList.sort((a, b) => b.date.compareTo(a.date));
      _allTransactions.assignAll(periodTxList);
      _applyPagination();
    } catch (e) {
      Get.snackbar("Error", "Could not calculate cash drawer: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- HELPER: Fetch Expenses (FIXED: reads 'method' field from Firestore) ---
  Future<List<DrawerTransaction>> _fetchExpensesList(
    DateTime start,
    DateTime end,
  ) async {
    List<DrawerTransaction> list = [];
    try {
      var snap =
          await _db
              .collectionGroup('items')
              .where('time', isGreaterThanOrEqualTo: start)
              .where('time', isLessThanOrEqualTo: end)
              .orderBy('time', descending: false)
              .get();

      for (var doc in snap.docs) {
        var d = doc.data();
        double amt = double.tryParse(d['amount'].toString()) ?? 0.0;
        DateTime time =
            d['time'] is Timestamp
                ? (d['time'] as Timestamp).toDate()
                : DateTime.now();

        // Read the saved method; fallback to 'Cash' for legacy records
        // that were saved before method tracking was added
        String method = (d['method'] ?? 'Cash').toString();
        if (method == 'Auto') method = 'Cash'; // Normalize old 'Auto' values

        list.add(
          DrawerTransaction(
            date: time,
            description: d['name'] ?? 'Expense',
            amount: amt,
            type: 'expense',
            method: method, // Now correctly tracks Cash/Bank/Bkash/Nagad
          ),
        );
      }
    } catch (_) {}
    return list;
  }

  // --- MANUAL DEPOSIT ---
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
      'bankName': (bankName == null || bankName.isEmpty) ? null : bankName,
      'accountNo': (accountNo == null || accountNo.isEmpty) ? null : accountNo,
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'manual_add',
    });
    fetchData();
  }

  // --- FUND TRANSFER ---
  Future<void> transferFund({
    required double amount,
    required String fromMethod,
    required String toMethod,
    String? bankName,
    String? accountNo,
    String? description,
  }) async {
    await _db.collection('cash_ledger').add({
      'type': 'transfer',
      'amount': amount,
      'fromMethod': fromMethod,
      'toMethod': toMethod,
      'bankName': bankName,
      'accountNo': accountNo,
      'description': description ?? 'Fund Transfer',
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'manual_transfer',
    });
    fetchData();
    Get.back();
  }

  // --- WITHDRAW / CASHOUT ---
  Future<void> withdrawFund({
    required double amount,
    required String method,
    required String desc,
    required DateTime date,
    String? bankName,
    String? accountNo,
  }) async {
    try {
      await _db.collection('cash_ledger').add({
        'type': 'withdraw',
        'amount': amount,
        'method': method,
        'description': desc,
        'bankName': (bankName == null || bankName.isEmpty) ? null : bankName,
        'accountNo':
            (accountNo == null || accountNo.isEmpty) ? null : accountNo,
        'timestamp': Timestamp.fromDate(date),
        'source': 'manual_withdraw',
      });

      fetchData();
      Get.back();

      Get.snackbar(
        'Success',
        'Withdrawal recorded successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to process withdrawal: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ========================================================================
  // WORLD-CLASS ERP PDF REPORT (EXECUTIVE LIQUIDITY DASHBOARD)
  // ========================================================================
  Future<void> downloadPdf() async {
    final doc = pw.Document();

    final fontReg = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    String generatedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "STATEMENT OF CASH POSITION",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                          color: PdfColors.blue900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Executive Liquidity Dashboard",
                        style: pw.TextStyle(
                          font: fontReg,
                          fontSize: 12,
                          color: PdfColors.grey600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Report Generated:",
                        style: pw.TextStyle(
                          font: fontReg,
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.Text(
                        generatedDate,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300, thickness: 1.5),
              pw.SizedBox(height: 30),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "TOTAL NET LIQUID ASSETS",
                      style: pw.TextStyle(
                        font: fontReg,
                        fontSize: 12,
                        color: PdfColors.blue100,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "BDT ${_currencyFormat.format(grandTotal.value)}",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 34,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 40),

              pw.Text(
                "ASSET BREAKDOWN",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: PdfColors.grey800,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 15),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildBalanceCard(
                      title: "CASH IN HAND",
                      amount: netCash.value,
                      primaryColor: PdfColors.green700,
                      bgColor: PdfColors.green50,
                      fontReg: fontReg,
                      fontBold: fontBold,
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildBalanceCard(
                      title: "BANK BALANCE",
                      amount: netBank.value,
                      primaryColor: PdfColors.blue700,
                      bgColor: PdfColors.blue50,
                      fontReg: fontReg,
                      fontBold: fontBold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildBalanceCard(
                      title: "bKash BALANCE",
                      amount: netBkash.value,
                      primaryColor: const PdfColor.fromInt(0xFFDF146E),
                      bgColor: const PdfColor.fromInt(0xFFFDE8F0),
                      fontReg: fontReg,
                      fontBold: fontBold,
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildBalanceCard(
                      title: "NAGAD BALANCE",
                      amount: netNagad.value,
                      primaryColor: const PdfColor.fromInt(0xFFF7931E),
                      bgColor: const PdfColor.fromInt(0xFFFEF4E8),
                      fontReg: fontReg,
                      fontBold: fontBold,
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 150,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Prepared By",
                        style: pw.TextStyle(
                          font: fontReg,
                          fontSize: 10,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 180,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Authorized Signature",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 11,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "System Generated Report - Internal Use Only",
                    style: pw.TextStyle(
                      font: fontReg,
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    "Strictly Confidential",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (f) => doc.save(),
      name:
          "Cash_Position_Report_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf",
    );
  }

  // Helper Widget for the Dashboard Cards
  pw.Widget _buildBalanceCard({
    required String title,
    required double amount,
    required PdfColor primaryColor,
    required PdfColor bgColor,
    required pw.Font fontReg,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: primaryColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: primaryColor,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            "BDT ${_currencyFormat.format(amount)}",
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 20,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}