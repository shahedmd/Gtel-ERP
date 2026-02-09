// ignore_for_file: deprecated_member_use, avoid_print, empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
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

  // --- SALES METRICS (The Bills You Created / Paper Performance) ---
  var saleDailyCustomer = 0.0.obs;
  var saleDebtor = 0.0.obs;
  var saleCondition = 0.0.obs;

  var totalRevenue = 0.0.obs; // Total Invoiced Amount
  var totalCostOfGoods = 0.0.obs; // Total Cost of items sold
  var profitOnRevenue = 0.0.obs; // Revenue - Cost (Paper Profit)
  var effectiveProfitMargin = 0.0.obs; // (Revenue - Cost) / Revenue %

  // --- CASH FLOW METRICS (The Money You Actually Received) ---
  var collectionCustomer = 0.0.obs;
  var collectionDebtor = 0.0.obs;
  var collectionCondition = 0.0.obs;
  var totalCollected = 0.0.obs; // Total Cash In Hand

  // --- PROFIT & ANALYSIS METRICS ---
  var totalOperatingExpenses = 0.0.obs;
  var netRealizedProfit = 0.0.obs; // (Collections * Margin) - Expenses

  // FIX: This replaces "Pending Generated".
  // It calculates: Total Revenue - Total Collected.
  // Positive = Market Debt Increased. Negative = Debt Recovered.
  var netPendingChange = 0.0.obs;

  // --- LISTS ---
  var monthlyStats = <Map<String, dynamic>>[].obs;
  var collectionBreakdown = <Map<String, dynamic>>[].obs;
  var transactionList = <Map<String, dynamic>>[].obs;
  var sortOption = 'Date (Newest)'.obs;

  @override
  void onInit() {
    super.onInit();
    setDateRange('This Month');
  }

  void refreshData() => fetchProfitAndLoss();

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
    fetchProfitAndLoss();
  }

  // =========================================================================
  // MAIN CALCULATION LOGIC
  // =========================================================================
  Future<void> fetchProfitAndLoss() async {
    isLoading.value = true;
    _resetMetrics();

    try {
      // STEP 1: Process Sales Orders (Revenue, Cost, Paper Profit)
      await _processSalesData();

      // STEP 2: Calculate Margin
      if (totalRevenue.value > 0) {
        effectiveProfitMargin.value =
            (totalRevenue.value - totalCostOfGoods.value) / totalRevenue.value;
      } else {
        effectiveProfitMargin.value = 0.0; // Safe default if no sales
      }

      // STEP 3: Process Collections (Actual Cash In)
      // This populates totalCollected
      await _processCollectionData();

      // STEP 4: Process Expenses
      await _calculateExpenses();

      // STEP 5: Final Calculations

      // A. Paper Profit (If everyone paid today)
      profitOnRevenue.value = totalRevenue.value - totalCostOfGoods.value;

      // B. Realized Profit (Actual Cash Profit)
      // We assume collected money carries the same profit margin as sales
      double grossRealized = totalCollected.value * effectiveProfitMargin.value;
      netRealizedProfit.value = grossRealized - totalOperatingExpenses.value;

      // C. Net Pending Change (The Fix)
      // Sales - Collections.
      // If Positive: You gave more credit than you collected.
      // If Negative: You collected old dues.
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
  // 1. SALES DATA (INVOICES)
  // -------------------------------------------------------------------------
  Future<void> _processSalesData() async {
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

    double tDaily = 0;
    double tDebtor = 0;
    double tCondition = 0;

    List<Map<String, dynamic>> tempTransactions = [];

    for (var doc in invoiceSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;

      String status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'deleted' || status == 'cancelled') continue;

      double amount = double.tryParse(data['grandTotal'].toString()) ?? 0;
      double cost = double.tryParse(data['totalCost'].toString()) ?? 0;
      double profit = amount - cost;

      String type = (data['customerType'] ?? '').toString().toLowerCase();
      bool isCondition = data['isCondition'] == true;
      String invId = data['invoiceId'] ?? 'N/A';
      String name = data['customerName'] ?? 'Unknown';
      DateTime date = (data['timestamp'] as Timestamp).toDate();

      // Aggregate Totals
      tRev += amount;
      tCost += cost;

      // Categorize Revenue
      if (isCondition) {
        tCondition += amount;
      } else if (type == 'debtor') {
        tDebtor += amount;
      } else {
        tDaily += amount;
      }

      // Calculate individual pending for list display only (Visual Aid)
      double paid = double.tryParse(data['paid']?.toString() ?? '0') ?? 0;
      if (isCondition) {
        // Condition Logic: If unpaid, due is courierDue. If paid, 0.
        // Simplified for list:
        double cDue =
            double.tryParse(data['courierDue']?.toString() ?? '0') ?? 0;
        paid = amount - cDue;
      }
      double currentRemainingDue = (amount - paid) > 0 ? (amount - paid) : 0;

      tempTransactions.add({
        'invoiceId': invId,
        'name': name,
        'date': date,
        'type':
            isCondition ? 'Condition' : (type == 'debtor' ? 'Debtor' : 'Cash'),
        'total': amount,
        'cost': cost,
        'profit': profit,
        'pending': currentRemainingDue, // Visual only
        'isLoss': profit < 0,
      });
    }

    saleDailyCustomer.value = tDaily;
    saleDebtor.value = tDebtor;
    saleCondition.value = tCondition;
    totalRevenue.value = tRev;
    totalCostOfGoods.value = tCost;
    transactionList.value = tempTransactions;
  }

  // -------------------------------------------------------------------------
  // 2. COLLECTION DATA (ACTUAL CASH RECEIVED)
  // -------------------------------------------------------------------------
  Future<void> _processCollectionData() async {
    double tColCust = 0;
    double tColDebtor = 0;
    double tColCond = 0;

    // A. Daily Sales Collection (Includes today's sales + today's recoveries)
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
      double amount = double.tryParse(data['paid'].toString()) ?? 0;
      if (amount <= 0) continue;

      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();

      if (source.contains('condition') || type == 'courier_payment') {
        tColCond += amount;
      } else if (type == 'debtor' || source.contains('payment')) {
        tColDebtor += amount;
      } else {
        tColCust += amount;
      }
    }

    // B. Cash Ledger (For separate manual old due deposits)
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

        // Explicitly target old due collections that might not be in daily_sales
        if (source == 'pos_old_due' || source == 'manual_deposit') {
          double amount = double.tryParse(data['amount'].toString()) ?? 0;
          if (amount > 0) {
            tColDebtor += amount;
          }
        }
      }
    } catch (e) {
      print("Cash Ledger Error: $e");
    }

    collectionCustomer.value = tColCust;
    collectionDebtor.value = tColDebtor;
    collectionCondition.value = tColCond;
    totalCollected.value = tColCust + tColDebtor + tColCond;
  }

  // -------------------------------------------------------------------------
  // 3. EXPENSES
  // -------------------------------------------------------------------------
  Future<void> _calculateExpenses() async {
    double totalExp = 0.0;
    DateTime iterator = startDate.value;
    Set<String> monthKeys = {};

    while (iterator.isBefore(endDate.value) ||
        iterator.isAtSameMomentAs(endDate.value)) {
      monthKeys.add("${DateFormat('MMM').format(iterator)}-${iterator.year}");
      iterator = DateTime(iterator.year, iterator.month + 1, 1);
    }
    monthKeys.add(
      "${DateFormat('MMM').format(endDate.value)}-${endDate.value.year}",
    );

    for (String key in monthKeys) {
      DocumentSnapshot doc =
          await _db.collection('monthly_expenses').doc(key).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        List<dynamic> items = data['items'] ?? [];
        for (var item in items) {
          DateTime itemDate =
              DateTime.tryParse(item['date'] ?? '') ?? DateTime(1900);
          if (itemDate.compareTo(startDate.value) >= 0 &&
              itemDate.compareTo(endDate.value) <= 0) {
            totalExp += (item['total'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }
    totalOperatingExpenses.value = totalExp;
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

    totalOperatingExpenses.value = 0;
    profitOnRevenue.value = 0;
    netRealizedProfit.value = 0;
    netPendingChange.value = 0; // Reset new metric
    effectiveProfitMargin.value = 0;

    monthlyStats.clear();
    collectionBreakdown.clear();
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
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "PROFIT & LOSS STATEMENT",
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

              // SECTION 1: TRADING ACCOUNT (INVOICES)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey100,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfSectionHeader(
                      "Trading Account (Invoiced Sales)",
                      fontBold,
                    ),
                    _buildPdfRow(
                      "Total Sales Revenue",
                      totalRevenue.value,
                      fontBold,
                    ),
                    _buildPdfRow(
                      "Cost of Goods Sold",
                      -totalCostOfGoods.value,
                      fontRegular,
                    ),
                    pw.Divider(),
                    _buildPdfRow(
                      "GROSS PROFIT (PAPER)",
                      profitOnRevenue.value,
                      fontBold,
                      color: PdfColors.blue900,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // SECTION 2: CASH FLOW (REALIZED)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfSectionHeader(
                      "Cash Flow & Realized Profit",
                      fontBold,
                    ),
                    _buildPdfRow(
                      "Total Collections (Cash In)",
                      totalCollected.value,
                      fontBold,
                    ),
                    _buildPdfRow(
                      "Est. Margin on Collection",
                      effectiveProfitMargin.value * 100,
                      fontRegular,
                      isPercent: true,
                    ),
                    _buildPdfRow(
                      "Realized Gross Profit",
                      totalCollected.value * effectiveProfitMargin.value,
                      fontBold,
                    ),
                    _buildPdfRow(
                      "Operating Expenses",
                      -totalOperatingExpenses.value,
                      fontRegular,
                    ),
                    pw.Divider(),
                    _buildPdfRow(
                      "NET REALIZED PROFIT",
                      netRealizedProfit.value,
                      fontBold,
                      color: PdfColors.green900,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // SECTION 3: RECEIVABLES ANALYSIS (PENDING FIX)
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
                          "NET RECEIVABLES CHANGE",
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                        pw.Text(
                          netPendingChange.value > 0
                              ? "(Sales exceeded Collections - Market Debt Grew)"
                              : "(Collections exceeded Sales - Debt Recovered)",
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
                        fontSize: 14,
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
                "TRANSACTION BREAKDOWN",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 5),

              // TABLE
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
                          color:
                              (item['pending'] as double) > 0
                                  ? PdfColors.red900
                                  : PdfColors.black,
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