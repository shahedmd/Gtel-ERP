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

  // Date Filters
  var startDate = DateTime.now().obs;
  var endDate = DateTime.now().obs;
  var selectedFilterLabel = "This Month".obs;

  // --- REVENUE METRICS (Sales) ---
  var totalInvoiceRevenue = 0.0.obs;
  var totalInvoiceCost = 0.0.obs;
  var totalGrossProfit = 0.0.obs; // Sales - COGS

  // This is the key fix: The margin used to calculate profit on collections
  var effectiveProfitMargin = 0.0.obs;

  // --- EXPENSE METRICS ---
  var totalOperatingExpenses = 0.0.obs;

  // --- NET PROFIT METRICS ---
  var netProfitAccrual = 0.0.obs; // Gross Profit - Expenses
  var netProfitRealized = 0.0.obs; // Realized Profit - Expenses

  // --- CASH FLOW METRICS (Collections) ---
  var totalCashCollected = 0.0.obs;
  var realizedProfitTotal = 0.0.obs;
  var cashSales = 0.0.obs;
  var debtorCollections = 0.0.obs;
  var courierCollections = 0.0.obs;

  // --- LISTS ---
  var monthlyStats = <Map<String, dynamic>>[].obs;
  var collectionBreakdown = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    setDateRange('This Month');
  }

  void refreshData() => fetchProfitAndLoss();

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

  Future<void> fetchProfitAndLoss() async {
    isLoading.value = true;
    _resetMetrics();

    try {
      // 1. CALCULATE SALES & MARGIN
      // This determines the Gross Profit from Invoices in the selected period.
      await _calculateSalesData();

      // 2. MARGIN INTELLIGENCE (THE FIX)
      // If we have no sales in the selected period (e.g., "Today"),
      // we must fetch a historical margin (Last 30 Days) to apply to collections.
      if (totalInvoiceRevenue.value <= 0) {
        await _fetchHistoricalMargin();
      } else {
        // Normal case: Use the margin from the currently filtered sales
        effectiveProfitMargin.value =
            totalGrossProfit.value / totalInvoiceRevenue.value;
      }

      // 3. CALCULATE COLLECTIONS (Using the correct Margin)
      await _calculateCollectionData();

      // 4. CALCULATE EXPENSES
      await _calculateExpenses();

      // 5. CALCULATE NET RESULTS
      // Accrual: What you earned on paper (Invoices - Expenses)
      netProfitAccrual.value =
          totalGrossProfit.value - totalOperatingExpenses.value;

      // Realized: What you earned in cash (Collections Profit - Expenses)
      // We assume Expenses are paid in cash, so we subtract them here too.
      netProfitRealized.value =
          realizedProfitTotal.value - totalOperatingExpenses.value;
    } catch (e) {
      Get.snackbar("Error", "P&L Calculation Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- LOGIC 1: SALES & GROSS PROFIT ---
  Future<void> _calculateSalesData() async {
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

    double tempRev = 0;
    double tempCost = 0;

    for (var doc in invoiceSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'deleted' || data['status'] == 'cancelled')
        continue;
      tempRev += double.tryParse(data['grandTotal'].toString()) ?? 0;
      tempCost += double.tryParse(data['totalCost'].toString()) ?? 0;
    }

    totalInvoiceRevenue.value = tempRev;
    totalInvoiceCost.value = tempCost;
    totalGrossProfit.value = tempRev - tempCost;
  }

  // --- LOGIC 2: HISTORICAL MARGIN FALLBACK (NEW) ---
  Future<void> _fetchHistoricalMargin() async {
    // If today has 0 sales, we look back 30 days to find the shop's average margin.
    // This ensures Debtor Collections today are calculated with a realistic profit %.

    DateTime historyStart = DateTime.now().subtract(const Duration(days: 30));
    DateTime historyEnd = DateTime.now();

    QuerySnapshot historySnap =
        await _db
            .collection('sales_orders')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(historyEnd),
            )
            .limit(100) // Optimization: Limit sample size
            .get();

    double hRev = 0;
    double hCost = 0;

    for (var doc in historySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'deleted') continue;
      hRev += double.tryParse(data['grandTotal'].toString()) ?? 0;
      hCost += double.tryParse(data['totalCost'].toString()) ?? 0;
    }

    if (hRev > 0) {
      effectiveProfitMargin.value = (hRev - hCost) / hRev;
    } else {
      effectiveProfitMargin.value = 0.15; // Default 15% if brand new database
    }
  }

  // --- LOGIC 3: COLLECTIONS & REALIZED PROFIT ---
  Future<void> _calculateCollectionData() async {
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
            .orderBy('timestamp', descending: true)
            .get();

    double rProfit = 0.0;
    double cashIn = 0.0;

    // Buckets for Chart
    Map<int, double> monthlyProfitMap = {};
    for (int i = 1; i <= 12; i++) monthlyProfitMap[i] = 0.0;

    for (var doc in dailySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double amount = double.tryParse(data['paid'].toString()) ?? 0;
      if (amount <= 0) continue;

      DateTime date = (data['timestamp'] as Timestamp).toDate();
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();

      // *** THE FIX IS HERE ***
      // We use 'effectiveProfitMargin' which is guaranteed to be valid now
      double estimatedProfitOnTx = amount * effectiveProfitMargin.value;

      // Categorize
      if (source == 'pos_sale' && type != 'debtor') {
        cashSales.value += amount;
      } else if (type == 'debtor' || source == 'payment') {
        debtorCollections.value += amount;
      } else if (source.contains('condition')) {
        courierCollections.value += amount;
      }

      cashIn += amount;
      rProfit += estimatedProfitOnTx;

      if (selectedFilterLabel.value == 'This Year') {
        monthlyProfitMap[date.month] =
            (monthlyProfitMap[date.month] ?? 0) + estimatedProfitOnTx;
      }

      collectionBreakdown.add({
        'date': date,
        'name': data['name'],
        'amount': amount,
        'profit': estimatedProfitOnTx,
        'type':
            source.contains('condition')
                ? 'Courier'
                : (type == 'debtor' ? 'Debtor' : 'Cash'),
      });
    }

    totalCashCollected.value = cashIn;
    realizedProfitTotal.value = rProfit;

    // Process Chart Data
    if (selectedFilterLabel.value == 'This Year') {
      List<String> months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      monthlyStats.value =
          months.asMap().entries.map((entry) {
            int monthIndex = entry.key + 1;
            return {
              "month": entry.value,
              "profit": monthlyProfitMap[monthIndex] ?? 0.0,
            };
          }).toList();
    } else {
      monthlyStats.clear();
    }
  }

  // --- LOGIC 4: EXPENSES ---
  Future<void> _calculateExpenses() async {
    double totalExp = 0.0;
    DateTime iterator = startDate.value;
    Set<String> monthKeys = {};

    // Generate Monthly Keys (e.g. Jan-2025)
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
          String dateStr = item['date'] ?? '';
          DateTime itemDate = DateTime.tryParse(dateStr) ?? DateTime(1900);

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
    totalInvoiceRevenue.value = 0;
    totalInvoiceCost.value = 0;
    totalGrossProfit.value = 0;
    effectiveProfitMargin.value = 0;
    totalOperatingExpenses.value = 0;
    netProfitAccrual.value = 0;
    netProfitRealized.value = 0;
    totalCashCollected.value = 0;
    realizedProfitTotal.value = 0;
    cashSales.value = 0;
    debtorCollections.value = 0;
    courierCollections.value = 0;
    monthlyStats.clear();
    collectionBreakdown.clear();
  }

  // ==========================================
  // 🖨️ PDF REPORT
  // ==========================================
  Future<void> generateProfitLossPDF() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final dateRangeStr =
        "${DateFormat('dd MMM yyyy').format(startDate.value)} to ${DateFormat('dd MMM yyyy').format(endDate.value)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // HEADER
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "PROFIT & LOSS STATEMENT",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 20,
                        color: PdfColors.blue900,
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
              ),
              pw.SizedBox(height: 20),

              // 1. TRADING ACCOUNT (Gross Profit)
              _buildPdfSectionHeader("1. Trading Account (Invoiced)", fontBold),
              _buildPdfRow(
                "Total Sales Revenue",
                totalInvoiceRevenue.value,
                fontRegular,
              ),
              _buildPdfRow(
                "(-) Cost of Goods Sold",
                totalInvoiceCost.value,
                fontRegular,
                color: PdfColors.red900,
              ),
              pw.Divider(),
              _buildPdfRow(
                "GROSS PROFIT",
                totalGrossProfit.value,
                fontBold,
                isResult: true,
              ),

              pw.SizedBox(height: 10),
              pw.Text(
                "Applied Profit Margin: ${(effectiveProfitMargin.value * 100).toStringAsFixed(1)}%",
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. OPERATING EXPENSES
              _buildPdfSectionHeader("2. Operating Expenses", fontBold),
              _buildPdfRow(
                "(-) Business Expenses",
                totalOperatingExpenses.value,
                fontRegular,
                color: PdfColors.red900,
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // 3. NET PROFIT (ACCRUAL)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow(
                      "NET PROFIT (Accrual)",
                      netProfitAccrual.value,
                      fontBold,
                      fontSize: 16,
                      color: PdfColors.blue900,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "(Invoiced Profit - Expenses)",
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // 4. CASH FLOW ANALYSIS (REALIZED)
              _buildPdfSectionHeader(
                "3. Cash Flow Analysis (Realized)",
                fontBold,
              ),
              _buildPdfRow(
                "Total Collections",
                totalCashCollected.value,
                fontRegular,
              ),
              _buildPdfRow(
                "Realized Profit (Est)",
                realizedProfitTotal.value,
                fontRegular,
                color: PdfColors.green900,
              ),
              _buildPdfRow(
                "(-) Expenses Paid",
                totalOperatingExpenses.value,
                fontRegular,
                color: PdfColors.red900,
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              _buildPdfRow(
                "NET CASH PROFIT",
                netProfitRealized.value,
                fontBold,
                color: PdfColors.green900,
              ),

              pw.SizedBox(height: 40),
              pw.Align(
                alignment: pw.Alignment.bottomCenter,
                child: pw.Text(
                  "Generated by G-TEL ERP System",
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildPdfSectionHeader(String title, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    double val,
    pw.Font font, {
    PdfColor color = PdfColors.black,
    bool isResult = false,
    double fontSize = 11,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
          ),
          pw.Text(
            "Tk ${val.toStringAsFixed(2)}",
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              color: color,
              fontWeight: isResult ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}
