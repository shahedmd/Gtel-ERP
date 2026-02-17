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
  final String type; // 'sale', 'collection', 'expense', 'transfer'
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
  // CORE FETCH LOGIC (FIXED)
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

      // 2. Absolute Start (2020)
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
            if (isInPeriod) periodSales += actualReceived;

            // --- SPLIT PAYMENT LOGIC ---
            double c = 0, b = 0, bk = 0, n = 0;
            String displayMethod = "Cash";
            String? displayBankDetails;

            var pm = data['paymentMethod'];

            if (pm is Map) {
              // 1. Try to read explicit split amounts first
              c = double.tryParse(pm['cash'].toString()) ?? 0;
              b = double.tryParse(pm['bank'].toString()) ?? 0;
              bk = double.tryParse(pm['bkash'].toString()) ?? 0;
              n = double.tryParse(pm['nagad'].toString()) ?? 0;

              displayBankDetails = pm['bankName'];

              // 2. If explicit amounts sum to 0 (legacy data format), fallback to total assignment
              if ((c + b + bk + n) == 0) {
                // Check for keys/values indicating method
                String valBank = (pm['bankName'] ?? '').toString();
                String valBkash = (pm['bkashNumber'] ?? '').toString();
                String valNagad = (pm['nagadNumber'] ?? '').toString();

                if (valBank.isNotEmpty) {
                  b = actualReceived;
                  displayMethod = "Bank";
                } else if (valBkash.isNotEmpty) {
                  bk = actualReceived;
                  displayMethod = "Bkash";
                } else if (valNagad.isNotEmpty) {
                  n = actualReceived;
                  displayMethod = "Nagad";
                } else {
                  c = actualReceived;
                  displayMethod = "Cash";
                }
              } else {
                // Determine display label for Mixed
                List<String> mParts = [];
                if (c > 0) mParts.add("Cash");
                if (b > 0) mParts.add("Bank");
                if (bk > 0) mParts.add("Bkash");
                if (n > 0) mParts.add("Nagad");
                displayMethod = mParts.join('/');
              }
            } else {
              // String format legacy
              String s = pm.toString().toLowerCase();
              if (s.contains('bank')) {
                b = actualReceived;
                displayMethod = "Bank";
              } else if (s.contains('bkash')) {
                bk = actualReceived;
                displayMethod = "Bkash";
              } else if (s.contains('nagad')) {
                n = actualReceived;
                displayMethod = "Nagad";
              } else {
                c = actualReceived;
                displayMethod = "Cash";
              }
            }

            // Add to totals
            tCash += c;
            tBank += b;
            tBkash += bk;
            tNagad += n;

            if (isInPeriod) {
              periodTxList.add(
                DrawerTransaction(
                  date: itemTime,
                  description: "Sale: ${data['name'] ?? 'NA'}",
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
          if (data['source'] == 'pos_sale') continue; // Skip auto-entries

          double amt = double.tryParse(data['amount'].toString()) ?? 0;
          String type = data['type'] ?? 'deposit';

          if (type == 'transfer') {
            // ... (Keep your existing Transfer Logic here, it looked okay) ...
            String from = (data['fromMethod'] ?? 'Cash').toString();
            String to = (data['toMethod'] ?? 'Cash').toString();

            // Deduct From
            if (from == 'Bank')
              tBank -= amt;
            else if (from == 'Bkash')
              tBkash -= amt;
            else if (from == 'Nagad')
              tNagad -= amt;
            else
              tCash -= amt;

            // Add To
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
            // Deposit / Withdraw
            String methodStr = (data['method'] ?? 'Cash').toString();
            bool isBank = methodStr.toLowerCase().contains('bank');
            bool isBkash = methodStr.toLowerCase().contains('bkash');
            bool isNagad = methodStr.toLowerCase().contains('nagad');

            // Adjust balances
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
        // --- EXPENSE PROCESSING ---
        else if (item['type'] == 'expense') {
          DrawerTransaction ex = item['data'];
          if (isInPeriod) periodExpenses += ex.amount;

          // Note: Waterfall deduction is risky if expenses are paid by Bank but
          // code subtracts from Cash because Cash > 0.
          // However, for Grand Total Net Asset, this is mathematically fine.

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

  // --- HELPER: Fetch Expenses ---
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
        list.add(
          DrawerTransaction(
            date: time,
            description: d['name'] ?? 'Expense',
            amount: amt,
            type: 'expense',
            method: 'Auto',
          ),
        );
      }
    } catch (_) {}
    return list;
  }

  // In CashDrawerController
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
      // Fix: If bankName is empty string, save as null
      'bankName': (bankName == null || bankName.isEmpty) ? null : bankName,
      'accountNo': (accountNo == null || accountNo.isEmpty) ? null : accountNo,
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'manual_add',
    });
    fetchData();
  }

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

  // --- PDF REPORT ---
  Future<void> downloadPdf() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    String period =
        "${DateFormat('dd MMM').format(selectedRange.value.start)} - ${DateFormat('dd MMM').format(selectedRange.value.end)}";
    final txList = _allTransactions;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Text(
                "Cash Position Report ($period)",
                style: pw.TextStyle(font: fontBold, fontSize: 18),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfCol("Total Sales", rawSalesTotal.value, fontBold),
                  _pdfCol("Collections", rawCollectionTotal.value, fontBold),
                  _pdfCol("Expenses", rawExpenseTotal.value, fontBold),
                  _pdfCol(
                    "CLOSING NET ASSET",
                    grandTotal.value,
                    fontBold,
                    isTotal: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Desc', 'Method', 'Amount'],
                data:
                    txList
                        .map(
                          (t) => [
                            DateFormat('dd-MMM HH:mm').format(t.date),
                            t.description,
                            t.method,
                            "${t.type == 'withdraw' || t.type == 'expense' ? '-' : ''}${_currencyFormat.format(t.amount)}",
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  pw.Widget _pdfCol(
    String label,
    double val,
    pw.Font font, {
    bool isTotal = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          _currencyFormat.format(val),
          style: pw.TextStyle(font: font, fontSize: isTotal ? 14 : 11),
        ),
      ],
    );
  }
}
