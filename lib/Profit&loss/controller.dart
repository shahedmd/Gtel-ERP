// ignore_for_file: deprecated_member_use, avoid_print, empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Required for DateRangePicker
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProfitController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = false.obs;

  // --- FILTERS ---
  var startDate = DateTime.now().obs;
  var endDate = DateTime.now().obs;
  var selectedFilterLabel = "This Month".obs;

  // --- METRICS ---
  var totalRevenue = 0.0.obs; // Total Sales (Grand Total)
  var totalCostOfGoods = 0.0.obs; // Total Cost
  var profitOnRevenue = 0.0.obs; // PAPER PROFIT (Accrual)

  var totalCollected = 0.0.obs; // Total Cash In Hand (Actual Cash)
  var netRealizedProfit = 0.0.obs; // YOUR MAIN PROFIT (Based on isFullyPaid)
  var netPendingChange = 0.0.obs; // Receivables Gap
  var effectiveProfitMargin = 0.0.obs;

  // --- BREAKDOWNS ---
  var saleDailyCustomer = 0.0.obs;
  var saleDebtor = 0.0.obs;
  var saleCondition = 0.0.obs;
  var collectionCustomer = 0.0.obs;
  var collectionDebtor = 0.0.obs;
  var collectionCondition = 0.0.obs;

  // --- LISTS ---
  var transactionList = <Map<String, dynamic>>[].obs;
  var sortOption = 'Date (Newest)'.obs;

  @override
  void onInit() {
    super.onInit();
    setDateRange('This Month');
  }

  void refreshData() => fetchProfitAndLoss();

  // --- SORTING ---
  void sortTransactions(String? type) {
    if (type != null) sortOption.value = type;
    List<Map<String, dynamic>> temp = List.from(transactionList);

    if (sortOption.value == 'Profit (High > Low)') {
      temp.sort((a, b) => b['profit'].compareTo(a['profit']));
    } else if (sortOption.value == 'Loss (High > Low)') {
      temp.sort((a, b) => a['profit'].compareTo(b['profit']));
    } else if (sortOption.value == 'Date (Newest)') {
      temp.sort((a, b) => b['date'].compareTo(a['date']));
    }
    transactionList.value = temp;
  }

  // =========================================================================
  // DATE FILTERS & CUSTOM PICKER
  // =========================================================================

  // 1. Standard Presets (Today, This Month, etc.)
  void setDateRange(String type) {
    selectedFilterLabel.value = type;
    final now = DateTime.now();

    if (type == 'Today') {
      startDate.value = DateTime(now.year, now.month, now.day);
      endDate.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (type == 'This Month') {
      startDate.value = DateTime(now.year, now.month, 1);
      endDate.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (type == 'Last 30 Days') {
      startDate.value = now.subtract(const Duration(days: 30));
      endDate.value = now;
    } else if (type == 'This Year') {
      startDate.value = DateTime(now.year, 1, 1);
      endDate.value = DateTime(now.year, 12, 31, 23, 59, 59);
    }

    // Trigger fetch automatically
    fetchProfitAndLoss();
  }

  // 2. Custom Date Range Picker (New Feature)
  Future<void> pickDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022), // Adjust to your app's start year
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate.value,
        end: endDate.value,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue[900],
            colorScheme: ColorScheme.light(primary: Colors.blue[900]!),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedFilterLabel.value = 'Custom'; // Update label for UI highlight

      // Set Start Date (Beginning of day)
      startDate.value = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );

      // Set End Date (End of day)
      endDate.value = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );

      // Fetch data for the selected range
      fetchProfitAndLoss();
    }
  }

  // =========================================================================
  // MAIN CALCULATION LOGIC
  // =========================================================================
  Future<void> fetchProfitAndLoss() async {
    isLoading.value = true;
    _resetMetrics();

    try {
      // 1. Process SALES
      // This now uses isFullyPaid to count profit immediately
      double salesProfit = await _processSalesData();

      // 2. Calculate Global Average Margin (For reference)
      if (totalRevenue.value > 0) {
        effectiveProfitMargin.value =
            profitOnRevenue.value / totalRevenue.value;
      }

      // 3. Process COLLECTIONS
      // (Money coming in from PREVIOUS dues)
      double oldDueCashProfit = await _processCollectionData();

      // 4. FINAL PROFIT CALCULATION
      // Profit = (Profit from Sales marked Fully Paid) + (Profit from Old Collections)
      netRealizedProfit.value = salesProfit + oldDueCashProfit;

      // 5. Net Receivables Gap
      // (Total Sales - Total Cash Collected)
      netPendingChange.value = totalRevenue.value - totalCollected.value;

      sortTransactions(null);
    } catch (e) {
      Get.snackbar("Error", "P&L Calculation Failed: $e");
      print("P&L Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------------------
  // 1. SALES DATA (UPDATED LOGIC)
  // -------------------------------------------------------------------------
  Future<double> _processSalesData() async {
    QuerySnapshot invoiceSnap =
        await _db
            .collection('sales_orders')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate.value),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate.value),
            )
            .get();

    double tRev = 0;
    double tCost = 0;
    double tPaperProfit = 0; // Total Potential Profit

    // This tracks the profit based on your "isFullyPaid" rule
    double tCalculatedProfit = 0;

    double tDaily = 0;
    double tDebtor = 0;
    double tCondition = 0;

    List<Map<String, dynamic>> tempTransactions = [];

    for (var doc in invoiceSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;

      String status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'deleted' || status == 'cancelled') continue;

      // --- 1. DATA EXTRACTION ---
      double amount = double.tryParse(data['grandTotal'].toString()) ?? 0;
      double cost = double.tryParse(data['totalCost'].toString()) ?? 0;
      bool isFullyPaid = data['isFullyPaid'] == true;

      // Get Profit
      double docProfit = 0;
      if (data['profit'] != null) {
        docProfit = double.tryParse(data['profit'].toString()) ?? 0;
      } else {
        docProfit = amount - cost;
      }

      // Get Paid Amount (for Pending Column display)
      double paidNow = 0;
      if (data['paymentDetails'] != null && data['paymentDetails'] is Map) {
        paidNow =
            double.tryParse(
              data['paymentDetails']['totalPaidInput'].toString(),
            ) ??
            0;
      }

      // --- 2. THE FIX: PROFIT COUNTING LOGIC ---
      if (isFullyPaid) {
        // RULE: If isFullyPaid is TRUE, we count 100% of the profit immediately.
        // This includes Credit Sales that are "Settled" to Ledger.
        tCalculatedProfit += docProfit;
      } else {
        // RULE: If NOT fully paid (Partial), calculate ratio.
        if (amount > 0 && paidNow > 0) {
          double paidRatio = (paidNow / amount);
          if (paidRatio > 1.0) paidRatio = 1.0;
          tCalculatedProfit += (docProfit * paidRatio);
        }
      }

      // --- 3. AGGREGATES ---
      tRev += amount;
      tCost += cost;
      tPaperProfit += docProfit;

      // Customer Classification
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      bool isCondition = data['isCondition'] == true;
      String name = data['customerName'] ?? 'Unknown';

      DateTime date;
      if (data['timestamp'] != null) {
        date = (data['timestamp'] as Timestamp).toDate();
      } else {
        date = DateTime.now();
      }

      if (isCondition) {
        tCondition += amount;
      } else if (type == 'debtor' || type == 'agent' || type == 'wholesale') {
        tDebtor += amount;
      } else {
        tDaily += amount;
      }

      // Visual Pending Amount
      double pending = amount - paidNow;
      if (pending < 0) pending = 0;

      tempTransactions.add({
        'invoiceId': data['invoiceId'] ?? '',
        'name': name,
        'date': date,
        'type':
            isCondition
                ? 'Condition'
                : (type.contains('agent') || type == 'debtor'
                    ? 'Debtor'
                    : 'Cash'),
        'total': amount,
        'cost': cost,
        'profit': docProfit,
        'pending': pending,
        'isLoss': docProfit < 0,
        // Helper to see why it was counted
        'status_debug': isFullyPaid ? 'Full/Credit' : 'Partial',
      });
    }

    saleDailyCustomer.value = tDaily;
    saleDebtor.value = tDebtor;
    saleCondition.value = tCondition;

    totalRevenue.value = tRev;
    totalCostOfGoods.value = tCost;
    profitOnRevenue.value = tPaperProfit;

    transactionList.value = tempTransactions;

    return tCalculatedProfit;
  }

  // -------------------------------------------------------------------------
  // 2. COLLECTION DATA (FIXED)
  // -------------------------------------------------------------------------
  Future<double> _processCollectionData() async {
    double tColCust = 0;
    double tColDebtor = 0;
    double tColCond = 0;
    double oldMoneyCollected = 0.0;

    // A. DAILY SALES COLLECTION
    // This loops through everything generated by the POS system.
    // It captures: Fresh Sales, Condition Payments, AND Old Due/Loan Recoveries.
    QuerySnapshot dailySnap =
        await _db
            .collection('daily_sales')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate.value),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate.value),
            )
            .get();

    for (var doc in dailySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;

      // Get the amount actually paid
      double amount = double.tryParse(data['paid'].toString()) ?? 0;
      if (amount <= 0) continue;

      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();

      // --- LOGIC TO CLASSIFY INCOME ---

      // 1. Condition / Courier Payments
      if (source.contains('condition') || type == 'courier_payment') {
        tColCond += amount;
        oldMoneyCollected += amount;
      }
      // 2. Old Due / Loan Recovery / Debtor Payments
      // This catches the 15,400 if it is recorded as a payment in daily_sales
      else if (type == 'debtor' ||
          source.contains('payment') ||
          source.contains('due') ||
          source.contains('old') ||
          source.contains('recovery')) {
        tColDebtor += amount;
        oldMoneyCollected += amount;
      }
      // 3. Fresh Customer Sales (Standard Cash/Digital)
      else {
        tColCust += amount;
        // We do NOT add to oldMoneyCollected here, because fresh sales profit
        // is already calculated in _processSalesData based on the full amount.
      }
    }

    // B. LEDGER (MANUAL DEPOSITS ONLY)
    // FIX: We removed 'pos_old_due' from here to stop the double counting.
    try {
      QuerySnapshot ledgerSnap =
          await _db
              .collection('cash_ledger')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate.value),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate.value),
              )
              .where('type', isEqualTo: 'deposit')
              .get();

      for (var doc in ledgerSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String source = (data['source'] ?? '').toString().toLowerCase();

        // ONLY count deposits that are MANUALLY entered (not from POS).
        // If the source is 'pos_old_due', we ignore it here because
        // it was already counted in Section A (daily_sales) above.
        if (source == 'manual_deposit') {
          double amount = double.tryParse(data['amount'].toString()) ?? 0;
          if (amount > 0) {
            tColDebtor += amount;
            oldMoneyCollected += amount;
          }
        }
      }
    } catch (e) {
      print("Ledger Error: $e");
    }

    // Update Observables
    collectionCustomer.value = tColCust;
    collectionDebtor.value = tColDebtor;
    collectionCondition.value = tColCond;

    // Total Cash In Hand
    totalCollected.value = tColCust + tColDebtor + tColCond;

    // Return the estimated profit generated from collecting old debts
    return oldMoneyCollected * effectiveProfitMargin.value;
  }

  void _resetMetrics() {
    saleDailyCustomer.value = 0;
    saleDebtor.value = 0;
    saleCondition.value = 0;
    totalRevenue.value = 0;
    totalCostOfGoods.value = 0;
    collectionCustomer.value = 0;
    collectionDebtor.value = 0;
    collectionCondition.value = 0;
    totalCollected.value = 0;
    profitOnRevenue.value = 0;
    netRealizedProfit.value = 0;
    netPendingChange.value = 0;
    effectiveProfitMargin.value = 0;
    transactionList.clear();
  }

  // =========================================================================
  // PDF REPORT
  // =========================================================================
  Future<void> generateProfitLossPDF() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final dateRangeStr =
        "${DateFormat('dd MMM').format(startDate.value)} - ${DateFormat('dd MMM yyyy').format(endDate.value)}";
    final primaryColor = PdfColors.blue900;

    List<Map<String, dynamic>> pdfList = List.from(transactionList);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build:
            (context) => [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "PROFIT STATEMENT",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: primaryColor,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "G-TEL ERP",
                        style: pw.TextStyle(font: fontBold, fontSize: 12),
                      ),
                      pw.Text(
                        dateRangeStr,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // TRADING ACCOUNT
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey100,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfSectionHeader("Trading Account", fontBold),
                    _buildPdfRow("Total Sales", totalRevenue.value, fontBold),
                    _buildPdfRow(
                      "Cost of Goods",
                      -totalCostOfGoods.value,
                      fontRegular,
                    ),
                    pw.Divider(),
                    _buildPdfRow(
                      "GROSS PROFIT",
                      profitOnRevenue.value,
                      fontBold,
                      color: PdfColors.blue900,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // CASH/REALIZED ACCOUNT
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfSectionHeader("Net Realized Profit", fontBold),
                    _buildPdfRow(
                      "Profit from Sales (Paid/Settled)",
                      netRealizedProfit.value,
                      fontBold,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Divider(thickness: 0.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL NET PROFIT",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.Text(
                          "Tk ${netRealizedProfit.value.toStringAsFixed(0)}",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // RECEIVABLES
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color:
                    netPendingChange.value > 0
                        ? PdfColors.orange50
                        : PdfColors.green50,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "CASH FLOW GAP",
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                        pw.Text(
                          "(Diff between Sold vs Collected)",
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      "Tk ${netPendingChange.value.toStringAsFixed(0)}",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color:
                            netPendingChange.value > 0
                                ? PdfColors.orange900
                                : PdfColors.green900,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 25),
              pw.Text(
                "Sales Breakdown",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 5),

              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FixedColumnWidth(45),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FixedColumnWidth(50),
                  5: const pw.FixedColumnWidth(50),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _th("Date", fontBold),
                      _th("Customer", fontBold, align: pw.TextAlign.left),
                      _th("Type", fontBold),
                      _th("Total", fontBold, align: pw.TextAlign.right),
                      _th("Profit", fontBold, align: pw.TextAlign.right),
                      _th("Pending", fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  ...pdfList.map((item) {
                    final isLoss = (item['profit'] as double) < 0;
                    return pw.TableRow(
                      children: [
                        _td(
                          DateFormat('dd-MM').format(item['date']),
                          fontRegular,
                        ),
                        _td(
                          item['name'],
                          fontRegular,
                          align: pw.TextAlign.left,
                        ),
                        _td(item['type'], fontRegular),
                        _td(
                          item['total'].toStringAsFixed(0),
                          fontRegular,
                          align: pw.TextAlign.right,
                        ),
                        _td(
                          item['profit'].toStringAsFixed(0),
                          fontBold,
                          align: pw.TextAlign.right,
                          color: isLoss ? PdfColors.red900 : PdfColors.green900,
                        ),
                        _td(
                          item['pending'].toStringAsFixed(0),
                          fontRegular,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildPdfSectionHeader(String title, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          decoration: pw.TextDecoration.underline,
        ),
      ),
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    double val,
    pw.Font font, {
    PdfColor color = PdfColors.black,
    bool isPercent = false,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 9, color: color),
          ),
          pw.Text(
            isPercent
                ? "${val.toStringAsFixed(1)}%"
                : "Tk ${val.toStringAsFixed(0)}",
            style: pw.TextStyle(font: font, fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8, color: color),
      ),
    );
  }
}
