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

  // --- SALES METRICS (The Bills You Created) ---
  var saleDailyCustomer = 0.0.obs;
  var saleDebtor = 0.0.obs;
  var saleCondition = 0.0.obs;
  var totalRevenue = 0.0.obs;
  var totalCostOfGoods = 0.0.obs;

  // FIX #2: This now tracks "Unpaid Bills Generated in this Period" only.
  // Collecting old money will NOT lower this number.
  var totalPendingGenerated = 0.0.obs;

  // --- CASH FLOW METRICS (The Money You Received) ---
  var collectionCustomer = 0.0.obs;
  var collectionDebtor = 0.0.obs;
  var collectionCondition = 0.0.obs;
  var totalCollected = 0.0.obs;

  // --- PROFIT METRICS ---
  var totalOperatingExpenses = 0.0.obs;
  var profitOnRevenue = 0.0.obs; // Paper Profit (Sales - Cost)
  var netRealizedProfit = 0.0.obs; // Cash Profit (Collection Profit - Expenses)
  var effectiveProfitMargin =
      0.0.obs; // Used to calculate profit on collections

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

  Future<void> fetchProfitAndLoss() async {
    isLoading.value = true;
    _resetMetrics();

    try {
      // 1. Process Sales (Revenue, Cost, and Generated Pending)
      await _processSalesData();

      // FIX #1: Calculate Margin BEFORE Collections.
      // If Revenue is 0 (e.g., Sunday), fetch Historical Margin so Net Profit isn't 0.
      if (totalRevenue.value > 0) {
        effectiveProfitMargin.value =
            (totalRevenue.value - totalCostOfGoods.value) / totalRevenue.value;
      } else {
        await _fetchHistoricalMargin();
      }

      // 2. Process Collections (Apply Margin to get Gross Cash Profit)
      double realizedGrossProfit = await _processCollectionData();

      // 3. Process Expenses
      await _calculateExpenses();

      // 4. Final Totals
      profitOnRevenue.value = totalRevenue.value - totalCostOfGoods.value;

      // Net Profit = (Collected Cash * Margin) - Expenses
      netRealizedProfit.value =
          realizedGrossProfit - totalOperatingExpenses.value;

      sortTransactions(null);
    } catch (e) {
      Get.snackbar("Error", "P&L Calculation Failed: $e");
      print("P&L Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // LOGIC: Calculates Bills Generated in this period.
  // PENDING = GrandTotal - Amount Paid AT THE MOMENT OF SALE.
  // =========================================================================
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

      tRev += amount;
      tCost += cost;

      double pendingForThisInv = 0.0;

      if (isCondition) {
        // Condition Sale: Payment is expected later.
        // Pending = The full courier due amount.
        pendingForThisInv = double.tryParse(data['courierDue'].toString()) ?? 0;
        tCondition += amount;
      } else {
        // Debtor/Cash Sale:
        // We strictly check: How much did they pay RIGHT NOW?
        double paidInput = 0.0;

        if (data['paymentDetails'] != null &&
            data['paymentDetails']['totalPaidInput'] != null) {
          paidInput =
              double.tryParse(
                data['paymentDetails']['totalPaidInput'].toString(),
              ) ??
              0;
        } else {
          // Fallback for old data or manual sum
          var pd = data['paymentDetails'] ?? {};
          double c = double.tryParse(pd['cash']?.toString() ?? '0') ?? 0;
          double b = double.tryParse(pd['bkash']?.toString() ?? '0') ?? 0;
          double n = double.tryParse(pd['nagad']?.toString() ?? '0') ?? 0;
          double bank = double.tryParse(pd['bank']?.toString() ?? '0') ?? 0;
          // Fallback to root 'paid' if all else fails
          if (c + b + n + bank == 0) {
            paidInput = double.tryParse(data['paid']?.toString() ?? '0') ?? 0;
          } else {
            paidInput = c + b + n + bank;
          }
        }

        double calc = amount - paidInput;
        pendingForThisInv = calc > 0 ? calc : 0.0;

        if (type == 'debtor') {
          tDebtor += amount;
        } else {
          tDaily += amount;
        }
      }

      tPending += pendingForThisInv;

      tempTransactions.add({
        'invoiceId': invId,
        'name': name,
        'date': date,
        'type':
            isCondition ? 'Condition' : (type == 'debtor' ? 'Debtor' : 'Cash'),
        'total': amount,
        'cost': cost,
        'profit': profit,
        'pending': pendingForThisInv,
        'isLoss': profit < 0,
      });
    }

    saleDailyCustomer.value = tDaily;
    saleDebtor.value = tDebtor;
    saleCondition.value = tCondition;
    totalRevenue.value = tRev;
    totalCostOfGoods.value = tCost;

    // FIX: This is now purely "Unpaid New Bills".
    // Collecting money for old bills will NOT affect this number.
    totalPendingGenerated.value = tPending;

    transactionList.value = tempTransactions;
  }

  // =========================================================================
  // LOGIC: Sums up ACTUAL CASH Received (Daily Sales + Cash Ledger)
  // =========================================================================
  Future<double> _processCollectionData() async {
    double tRealizedGross = 0;
    double tColCust = 0;
    double tColDebtor = 0;
    double tColCond = 0;

    Map<int, double> monthlyProfitMap = {};
    for (int i = 1; i <= 12; i++) {
      monthlyProfitMap[i] = 0.0;
    }

    // 1. Daily Sales Collection (New Bills + Some Condition Payments)
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

      DateTime date = (data['timestamp'] as Timestamp).toDate();
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();

      String category = "Customer";

      if (source.contains('condition') || type == 'courier_payment') {
        tColCond += amount;
        category = "Courier";
      } else if (type == 'debtor' || source.contains('payment')) {
        tColDebtor += amount;
        category = "Debtor";
      } else {
        tColCust += amount;
      }

      // Calculate Profit on this Cash
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

    // 2. Cash Ledger Collection (Old Debtor Dues)
    // This ensures we catch money that didn't go through 'daily_sales'
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

        // Only count specific ledger entries to avoid double counting with daily_sales
        if (source == 'pos_old_due' || source == 'pos_running_collection') {
          double amount = double.tryParse(data['amount'].toString()) ?? 0;
          if (amount > 0) {
            tColDebtor += amount;

            // Calculate Profit on this Cash
            double txProfit = amount * effectiveProfitMargin.value;
            tRealizedGross += txProfit;

            DateTime date = (data['timestamp'] as Timestamp).toDate();
            if (selectedFilterLabel.value == 'This Year') {
              monthlyProfitMap[date.month] =
                  (monthlyProfitMap[date.month] ?? 0) + txProfit;
            }
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
            return {
              "month": entry.value,
              "profit": monthlyProfitMap[entry.key + 1] ?? 0.0,
            };
          }).toList();
    } else {
      monthlyStats.clear();
    }

    return tRealizedGross;
  }

  // --- Expenses ---
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

  // --- Historical Margin Fallback (Fixes "Net Profit 0" on no-sale days) ---
  Future<void> _fetchHistoricalMargin() async {
    DateTime historyStart = DateTime.now().subtract(const Duration(days: 30));
    QuerySnapshot historySnap =
        await _db
            .collection('sales_orders')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
            )
            .limit(100)
            .get();

    double hRev = 0, hCost = 0;
    for (var doc in historySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'deleted') continue;
      hRev += double.tryParse(data['grandTotal'].toString()) ?? 0;
      hCost += double.tryParse(data['totalCost'].toString()) ?? 0;
    }

    if (hRev > 0) {
      effectiveProfitMargin.value = (hRev - hCost) / hRev;
    } else {
      effectiveProfitMargin.value = 0.15; // Default safety fallback
    }
  }

  void _resetMetrics() {
    saleDailyCustomer.value = 0;
    saleDebtor.value = 0;
    saleCondition.value = 0;
    totalRevenue.value = 0;
    totalCostOfGoods.value = 0;
    totalPendingGenerated.value = 0;
    collectionCustomer.value = 0;
    collectionDebtor.value = 0;
    collectionCondition.value = 0;
    totalCollected.value = 0;
    totalOperatingExpenses.value = 0;
    profitOnRevenue.value = 0;
    netRealizedProfit.value = 0;
    effectiveProfitMargin.value = 0;
    monthlyStats.clear();
    collectionBreakdown.clear();
    transactionList.clear();
  }

  // ==========================================
  // PDF REPORT
  // ==========================================
  Future<void> generateProfitLossPDF() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final dateRangeStr =
        "${DateFormat('dd MMM').format(startDate.value)} - ${DateFormat('dd MMM yyyy').format(endDate.value)}";

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
                    "PROFIT & LOSS STATEMENT",
                    style: pw.TextStyle(font: fontBold, fontSize: 18),
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

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfSectionHeader(
                            "Sales Overview (Invoiced)",
                            fontBold,
                          ),
                          _buildPdfRow(
                            "Total Revenue",
                            totalRevenue.value,
                            fontBold,
                          ),
                          _buildPdfRow(
                            "Cost of Goods",
                            totalCostOfGoods.value,
                            fontRegular,
                          ),
                          pw.Divider(),
                          _buildPdfRow(
                            "Profit on Revenue",
                            profitOnRevenue.value,
                            fontBold,
                            color: PdfColors.blue900,
                          ),
                          pw.SizedBox(height: 5),
                          _buildPdfRow(
                            "Pending (New Bill)",
                            totalPendingGenerated.value,
                            fontRegular,
                            color: PdfColors.red900,
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfSectionHeader("Cash & Realized", fontBold),
                          _buildPdfRow(
                            "Total Collected",
                            totalCollected.value,
                            fontBold,
                          ),
                          _buildPdfRow(
                            "Operating Expenses",
                            totalOperatingExpenses.value,
                            fontRegular,
                          ),
                          pw.Divider(),
                          _buildPdfRow(
                            "Net Realized Profit",
                            netRealizedProfit.value,
                            fontBold,
                            color: PdfColors.green900,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 25),
              pw.Text(
                "TRANSACTION BREAKDOWN",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 5),

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
            "Tk ${val.toStringAsFixed(0)}",
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