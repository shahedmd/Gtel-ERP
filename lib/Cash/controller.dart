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
  final String type; // 'sale', 'collection', 'expense', 'withdraw'
  final String method; // 'Cash', 'Bank', 'Bkash', 'Nagad', 'Mixed'
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

// --- CONTROLLER ---
class CashDrawerController extends GetxController {
  static CashDrawerController get to => Get.find();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final Rx<DateFilter> filterType = DateFilter.monthly.obs;
  final Rx<DateTimeRange> selectedRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now()).obs;

  // --- LIVE BALANCES (NET) ---
  final RxDouble netCash = 0.0.obs;
  final RxDouble netBank = 0.0.obs;
  final RxDouble netBkash = 0.0.obs;
  final RxDouble netNagad = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  // --- REPORT TOTALS (GROSS) ---
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

      // 1. Fetch Sales
      var salesFuture =
          _db
              .collection('daily_sales')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThanOrEqualTo: end)
              .orderBy('timestamp', descending: true)
              .get();

      // 2. Fetch Ledger
      var ledgerFuture =
          _db
              .collection('cash_ledger')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThanOrEqualTo: end)
              .orderBy('timestamp', descending: true)
              .get();

      // 3. Fetch Expenses
      var expensesFuture = _fetchExpensesList(start, end);

      var results = await Future.wait([
        salesFuture,
        ledgerFuture,
        expensesFuture,
      ]);

      var salesSnap = results[0] as QuerySnapshot;
      var ledgerSnap = results[1] as QuerySnapshot;
      List<DrawerTransaction> expenseList =
          results[2] as List<DrawerTransaction>;

      // --- Accumulators ---
      double tCash = 0, tBank = 0, tBkash = 0, tNagad = 0;
      double sumSales = 0, sumCollections = 0, sumExpenses = 0;
      List<DrawerTransaction> allTx = [...expenseList];

      // --- A. PROCESS SALES (FIXED FOR CONDITION RECOVERY) ---
      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        double totalPaid = double.tryParse(data['paid'].toString()) ?? 0;
        double ledgerPaid = double.tryParse(data['ledgerPaid'].toString()) ?? 0;

        // Actual money received now = Paid - Ledger Usage
        double actualReceived = totalPaid - ledgerPaid;

        if (actualReceived <= 0.01) continue;

        sumSales += actualReceived;

        // Parse Payment Method
        var pm = data['paymentMethod'];
        double c = 0, b = 0, bk = 0, n = 0;
        String displayMethod = "Cash";
        String? displayBank;
        String? displayAcc;

        if (pm is Map) {
          // --- FIX: Check for 'type' (Condition/Single) vs keys (POS Mixed) ---
          if (pm.containsKey('type')) {
            // Condition Recovery Format: {type: 'bkash', details: '...'}
            String type = (pm['type'] ?? 'cash').toString().toLowerCase();

            if (type.contains('bank')) {
              b = actualReceived;
              displayMethod = "Bank";
              displayBank = pm['bankName']?.toString();
            } else if (type.contains('bkash')) {
              bk = actualReceived;
              displayMethod = "Bkash";
              displayAcc = pm['details']?.toString();
            } else if (type.contains('nagad')) {
              n = actualReceived;
              displayMethod = "Nagad";
              displayAcc = pm['details']?.toString();
            } else {
              c = actualReceived;
              displayMethod = "Cash";
            }
          } else {
            // POS Mixed Format: {cash: 100, bank: 50...}
            c = double.tryParse(pm['cash'].toString()) ?? 0;
            b = double.tryParse(pm['bank'].toString()) ?? 0;
            bk = double.tryParse(pm['bkash'].toString()) ?? 0;
            n = double.tryParse(pm['nagad'].toString()) ?? 0;

            // Details
            if (b > 0) {
              displayBank = pm['bankName']?.toString();
              displayAcc = pm['accountNumber']?.toString();
            }
            if (bk > 0 && displayAcc == null)
              displayAcc = "Bkash: ${pm['bkashNumber']}";

            // Label
            List<String> used = [];
            if (c > 0) used.add("Cash");
            if (b > 0) used.add("Bank");
            if (bk > 0) used.add("Bkash");
            if (n > 0) used.add("Nagad");
            if (used.length > 1)
              displayMethod = "Mixed";
            else if (used.isNotEmpty)
              displayMethod = used.first;
          }
        } else {
          // Legacy String Fallback
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

        // Add to Accumulators
        tCash += c;
        tBank += b;
        tBkash += bk;
        tNagad += n;

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: "Sale/Rec: ${data['name'] ?? 'NA'}",
            amount: actualReceived,
            type: 'sale',
            method: displayMethod,
            bankName: displayBank,
            accountDetails: displayAcc,
          ),
        );
      }

      // --- B. PROCESS LEDGER (Manual & Collections) ---
      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String source = (data['source'] ?? '').toString();

        if (source == 'pos_sale') continue;

        double amt = double.tryParse(data['amount'].toString()) ?? 0;
        String type = data['type'] ?? 'deposit';

        // Parse Details
        String methodStr = (data['method'] ?? 'Cash').toString();
        String? lBank, lAcc;

        if (data['details'] is Map) {
          var d = data['details'];
          methodStr = d['method'] ?? methodStr;
          lBank = d['bankName'];
          lAcc = d['accountNo'] ?? d['accountNumber'];
        } else {
          lBank = data['bankName'];
          lAcc = data['accountNo'];
        }

        bool isBank =
            methodStr.toLowerCase().contains('bank') ||
            (lBank != null && lBank.isNotEmpty);
        bool isBkash = methodStr.toLowerCase().contains('bkash');
        bool isNagad = methodStr.toLowerCase().contains('nagad');

        if (type == 'deposit') {
          sumCollections += amt;
          if (isBank)
            tBank += amt;
          else if (isBkash)
            tBkash += amt;
          else if (isNagad)
            tNagad += amt;
          else
            tCash += amt;
        } else {
          sumExpenses += amt;
          if (isBank)
            tBank -= amt;
          else if (isBkash)
            tBkash -= amt;
          else if (isNagad)
            tNagad -= amt;
          else
            tCash -= amt;
        }

        allTx.add(
          DrawerTransaction(
            date: (data['timestamp'] as Timestamp).toDate(),
            description: data['description'] ?? source.replaceAll('_', ' '),
            amount: amt,
            type: type == 'deposit' ? 'collection' : 'withdraw',
            method: methodStr.capitalizeFirst ?? "Cash",
            bankName: lBank,
            accountDetails: lAcc,
          ),
        );
      }

      // --- C. PROCESS EXPENSES (Waterfall Deduction) ---
      for (var ex in expenseList) {
        sumExpenses += ex.amount;
        double remaining = ex.amount;

        if (tCash >= remaining) {
          tCash -= remaining;
          remaining = 0;
        } else {
          remaining -= tCash;
          tCash = 0;
        }

        if (remaining > 0) {
          if (tBank >= remaining) {
            tBank -= remaining;
            remaining = 0;
          } else {
            remaining -= tBank;
            tBank = 0;
          }
        }

        if (remaining > 0) {
          if (tBkash >= remaining) {
            tBkash -= remaining;
            remaining = 0;
          } else {
            remaining -= tBkash;
            tBkash = 0;
          }
        }

        if (remaining > 0) {
          if (tNagad >= remaining) {
            tNagad -= remaining;
            remaining = 0;
          } else {
            remaining -= tNagad;
            tNagad = 0;
          }
        }
      }

      // --- FINAL UPDATES ---
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
              .orderBy('time', descending: true)
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
            description: d['name'] ?? d['note'] ?? 'Expense',
            amount: amt,
            type: 'expense',
            method: 'Auto-Deduct',
          ),
        );
      }
    } catch (_) {}
    return list;
  }

  // --- MANUAL ACTIONS ---

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

              // Summary
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
                      "Collections",
                      rawCollectionTotal.value,
                      fontBold,
                      PdfColors.blue900,
                    ),
                    _pdfSummaryCol(
                      "Expenses/Out",
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

              // Detailed Balances
              pw.Text(
                "Breakdown by Source",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfRow("Cash In Hand", netCash.value, font),
                  _pdfRow("Bank Balance", netBank.value, font),
                  _pdfRow("Bkash Balance", netBkash.value, font),
                  _pdfRow("Nagad Balance", netNagad.value, font),
                ],
              ),

              pw.SizedBox(height: 20),

              // Transactions List
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
                            "${(tx.type == 'withdraw' || tx.type == 'expense') ? '-' : '+'}${_currencyFormat.format(tx.amount)}",
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
