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

  // --- 0. FILTERS ---
  var startDate = DateTime.now().obs;
  var endDate = DateTime.now().obs;
  var selectedFilterLabel = "This Month".obs;

  var saleDailyCustomer = 0.0.obs;
  var saleDebtor = 0.0.obs;
  var saleCondition = 0.0.obs;
  var totalRevenue = 0.0.obs;
  var totalCostOfGoods = 0.0.obs;


  var collectionCustomer = 0.0.obs;
  var collectionDebtor = 0.0.obs;
  var collectionCondition = 0.0.obs;
  var totalCollected = 0.0.obs;

  // *** FIXED VARIABLE ***
  var totalPendingGenerated = 0.0.obs;

  // =========================================================
  // SECTION 3: PROFIT & LOSS
  // =========================================================
  var totalOperatingExpenses = 0.0.obs;
  var profitOnRevenue = 0.0.obs;
  var netRealizedProfit = 0.0.obs;
  var effectiveProfitMargin = 0.0.obs;

  // =========================================================
  // SECTION 4: CHARTS & LISTS
  // =========================================================
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
      await _processSalesData();

      // 2. Calculate Margin
      if (totalRevenue.value <= 0) {
        await _fetchHistoricalMargin();
      } else {
        effectiveProfitMargin.value =
            (totalRevenue.value - totalCostOfGoods.value) / totalRevenue.value;
      }

      // 3. Fetch Collection Data (Cash In)
      double realizedGrossProfit = await _processCollectionData();

      // 4. Fetch Expenses
      await _calculateExpenses();

      // 5. Final Calculations

      // Accrual Profit (Paper Profit)
      profitOnRevenue.value = totalRevenue.value - totalCostOfGoods.value;

      // Realized Profit (Cash Profit)
      netRealizedProfit.value =
          realizedGrossProfit - totalOperatingExpenses.value;
    } catch (e) {
      Get.snackbar("Error", "P&L Calculation Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

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
    double tPending = 0;

    for (var doc in invoiceSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;

      // 1. Skip deleted/cancelled
      String status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'deleted' || status == 'cancelled') continue;

      double amount = double.tryParse(data['grandTotal'].toString()) ?? 0;
      double cost = double.tryParse(data['totalCost'].toString()) ?? 0;
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      bool isCondition = data['isCondition'] == true;

      tRev += amount;
      tCost += cost;

      // 2. Calculate Pending
      if (isCondition) {
        // Condition: trust 'courierDue'
        tPending += double.tryParse(data['courierDue'].toString()) ?? 0;
        tCondition += amount;
      } else {

        double dueForThisSale = 0.0;

        if (status == 'completed' || status == 'paid') {
          dueForThisSale = 0.0;
        }
        else if (data.containsKey('due')) {
          dueForThisSale = double.tryParse(data['due'].toString()) ?? 0.0;
        }
        else {
          double livePaid = double.tryParse(data['paid'].toString()) ?? 0.0;
          dueForThisSale = amount - livePaid;
        }

        if (dueForThisSale < 0) dueForThisSale = 0;

        if (type == 'debtor') {
          tDebtor += amount;
          tPending += dueForThisSale;
        } else {
          tDaily += amount;
          tPending += dueForThisSale;
        }
      }
    }

    saleDailyCustomer.value = tDaily;
    saleDebtor.value = tDebtor;
    saleCondition.value = tCondition;
    totalRevenue.value = tRev;
    totalCostOfGoods.value = tCost;
    totalPendingGenerated.value = tPending;
  }

  Future<double> _processCollectionData() async {
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

    double tCollected = 0;
    double tColCust = 0;
    double tColDebtor = 0;
    double tColCond = 0;
    double tRealizedGross = 0;

    // For Charting
    Map<int, double> monthlyProfitMap = {};
    for (int i = 1; i <= 12; i++) {
      monthlyProfitMap[i] = 0.0;
    }

    for (var doc in dailySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double amount = double.tryParse(data['paid'].toString()) ?? 0;
      if (amount <= 0) continue;

      DateTime date = (data['timestamp'] as Timestamp).toDate();
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();

      // Categorize Collection
      String category = "Customer";
      if (source.contains('condition') || type == 'courier_payment') {
        tColCond += amount;
        category = "Courier";
      } else if (type == 'debtor' ||
          source == 'payment' ||
          source == 'advance_payment') {
        tColDebtor += amount;
        category = "Debtor";
      } else {
        tColCust += amount;
      }

      double txProfit = amount * effectiveProfitMargin.value;
      tRealizedGross += txProfit;

      collectionBreakdown.add({
        'date': date,
        'name': data['name'],
        'amount': amount,
        'profit': txProfit,
        'type': category,
      });

      if (selectedFilterLabel.value == 'This Year') {
        monthlyProfitMap[date.month] =
            (monthlyProfitMap[date.month] ?? 0) + txProfit;
      }
    }

    collectionCustomer.value = tColCust;
    collectionDebtor.value = tColDebtor;
    collectionCondition.value = tColCond;

    tCollected = tColCust + tColDebtor + tColCond;
    totalCollected.value = tCollected;

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

    return tRealizedGross;
  }

  // --- LOGIC 3: EXPENSES ---
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

  // --- LOGIC 4: HISTORICAL MARGIN ---
  Future<void> _fetchHistoricalMargin() async {
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
            .limit(100)
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
      effectiveProfitMargin.value = 0.15;
    }
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
    totalPendingGenerated.value = 0;

    totalOperatingExpenses.value = 0;
    profitOnRevenue.value = 0;
    netRealizedProfit.value = 0;
    effectiveProfitMargin.value = 0;

    monthlyStats.clear();
    collectionBreakdown.clear();
  }

  // ==========================================
  // PDF REPORT
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

              _buildPdfSectionHeader("1. Sales Overview (Invoiced)", fontBold),
              _buildPdfRow(
                "Daily Customer Sales",
                saleDailyCustomer.value,
                fontRegular,
              ),
              _buildPdfRow("Debtor Sales", saleDebtor.value, fontRegular),
              _buildPdfRow("Condition Sales", saleCondition.value, fontRegular),
              pw.Divider(),
              _buildPdfRow(
                "TOTAL REVENUE",
                totalRevenue.value,
                fontBold,
                isResult: true,
              ),

              pw.SizedBox(height: 20),

              _buildPdfSectionHeader(
                "2. Collections Overview (Cash In)",
                fontBold,
              ),
              _buildPdfRow(
                "Customer Collection",
                collectionCustomer.value,
                fontRegular,
              ),
              _buildPdfRow(
                "Debtor Collection",
                collectionDebtor.value,
                fontRegular,
              ),
              _buildPdfRow(
                "Condition Collection",
                collectionCondition.value,
                fontRegular,
              ),
              pw.Divider(),
              _buildPdfRow(
                "TOTAL COLLECTED",
                totalCollected.value,
                fontBold,
                isResult: true,
              ),
              pw.SizedBox(height: 5),
              // Corrected label for PDF as well
              _buildPdfRow(
                "Pending (From This Period's Sales)",
                totalPendingGenerated.value,
                fontRegular,
                color: PdfColors.red900,
              ),

              pw.SizedBox(height: 20),

              _buildPdfSectionHeader("3. Expenses", fontBold),
              _buildPdfRow(
                "Total Operating Expenses",
                totalOperatingExpenses.value,
                fontRegular,
                color: PdfColors.red900,
              ),

              pw.SizedBox(height: 30),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow(
                      "PROFIT ON REVENUE",
                      profitOnRevenue.value,
                      fontBold,
                      fontSize: 14,
                      color: PdfColors.blue900,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "(Revenue - COGS)",
                      style: pw.TextStyle(font: fontRegular, fontSize: 8),
                    ),
                    pw.Divider(),
                    _buildPdfRow(
                      "NET REALIZED PROFIT",
                      netRealizedProfit.value,
                      fontBold,
                      fontSize: 16,
                      color: PdfColors.green900,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "(Collected Profit - Expenses)",
                      style: pw.TextStyle(font: fontRegular, fontSize: 8),
                    ),
                  ],
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
