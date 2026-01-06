import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProfitController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---
  var isLoading = false.obs;

  // Date Filters
  var startDate = DateTime.now().subtract(const Duration(days: 30)).obs;
  var endDate = DateTime.now().obs;

  // Metrics
  var totalRevenue = 0.0.obs;
  var totalCostOfGoods = 0.0.obs;
  var grossProfit = 0.0.obs;
  var totalExpenses = 0.0.obs;
  var netProfit = 0.0.obs;
  var totalDiscounts = 0.0.obs;

  // Lists
  var salesReportList = <Map<String, dynamic>>[].obs;

  // NEW: Customer Performance List
  var customerPerformanceList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    setDateRange('This Month');
  }

  // ==========================================
  // 1. DATE RANGE PICKER
  // ==========================================
  void setDateRange(String type) {
    final now = DateTime.now();
    if (type == 'Today') {
      startDate.value = DateTime(now.year, now.month, now.day);
      endDate.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (type == 'Yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      startDate.value = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
      endDate.value = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        59,
      );
    } else if (type == 'This Month') {
      startDate.value = DateTime(now.year, now.month, 1);
      endDate.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (type == 'Last 30 Days') {
      startDate.value = now.subtract(const Duration(days: 30));
      endDate.value = now;
    }
    fetchProfitAndLoss();
  }

  Future<void> pickCustomDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: startDate.value,
        end: endDate.value,
      ),
    );

    if (picked != null) {
      startDate.value = picked.start;
      endDate.value = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      fetchProfitAndLoss();
    }
  }

  // ==========================================
  // 2. FETCH DATA
  // ==========================================
  Future<void> fetchProfitAndLoss() async {
    isLoading.value = true;
    _resetMetrics();

    try {
      // A. Fetch SALES
      QuerySnapshot salesQuery =
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
              .orderBy('timestamp', descending: true)
              .get();

      List<Map<String, dynamic>> tempSales = [];
      Map<String, Map<String, dynamic>> customerMap =
          {}; // Helper for aggregation

      for (var doc in salesQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        double revenue = double.tryParse(data['grandTotal'].toString()) ?? 0.0;
        double cost = double.tryParse(data['totalCost'].toString()) ?? 0.0;
        double discount = double.tryParse(data['discount'].toString()) ?? 0.0;
        double profit =
            data.containsKey('profit')
                ? (double.tryParse(data['profit'].toString()) ?? 0.0)
                : (revenue - cost);

        // Global Totals
        totalRevenue.value += revenue;
        totalCostOfGoods.value += cost;
        totalDiscounts.value += discount;
        grossProfit.value += profit;

        // Add to Sales List
        tempSales.add({
          'date': data['date'] ?? '',
          'invoiceId': data['invoiceId'] ?? 'N/A',
          'customer': data['customerName'] ?? 'Unknown',
          'revenue': revenue,
          'cost': cost,
          'profit': profit,
          'items': (data['items'] as List<dynamic>).length,
        });

        // --- NEW: AGGREGATE BY CUSTOMER ---
        String custName = data['customerName'] ?? 'Unknown';
        String custType = data['customerType'] ?? 'Retailer';

        if (!customerMap.containsKey(custName)) {
          customerMap[custName] = {
            'name': custName,
            'type': custType,
            'revenue': 0.0,
            'profit': 0.0,
            'count': 0,
          };
        }
        customerMap[custName]!['revenue'] += revenue;
        customerMap[custName]!['profit'] += profit;
        customerMap[custName]!['count'] += 1;
      }

      salesReportList.assignAll(tempSales);

      // Convert Customer Map to List & Sort by Profit (High to Low)
      List<Map<String, dynamic>> sortedCustomers = customerMap.values.toList();
      sortedCustomers.sort((a, b) => b['profit'].compareTo(a['profit']));
      customerPerformanceList.assignAll(sortedCustomers);

      // B. Fetch EXPENSES
      try {
        QuerySnapshot expenseQuery =
            await _db
                .collection('expenses')
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate.value),
                )
                .where(
                  'date',
                  isLessThanOrEqualTo: Timestamp.fromDate(endDate.value),
                )
                .get();

        for (var doc in expenseQuery.docs) {
          Map<String, dynamic> exp = doc.data() as Map<String, dynamic>;
          double amount = double.tryParse(exp['amount'].toString()) ?? 0.0;
          totalExpenses.value += amount;
        }
      } catch (e) {
        // Ignore if collection missing
      }

      // C. Net Profit
      netProfit.value = grossProfit.value - totalExpenses.value;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to generate report: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _resetMetrics() {
    totalRevenue.value = 0.0;
    totalCostOfGoods.value = 0.0;
    grossProfit.value = 0.0;
    totalExpenses.value = 0.0;
    netProfit.value = 0.0;
    totalDiscounts.value = 0.0;
    salesReportList.clear();
    customerPerformanceList.clear();
  }

  // ==========================================
  // 3. GENERATE PDF REPORT
  // ==========================================
  Future<void> generatePdfReport() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();

    final String startStr = DateFormat('dd MMM yyyy').format(startDate.value);
    final String endStr = DateFormat('dd MMM yyyy').format(endDate.value);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              // HEADER
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Profit & Loss Statement",
                      style: pw.TextStyle(font: fontBold, fontSize: 22),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "G-TEL MOBILE",
                          style: pw.TextStyle(font: fontBold, fontSize: 14),
                        ),
                        pw.Text(
                          "Period: $startStr - $endStr",
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // FINANCIAL SUMMARY
              pw.Text(
                "Financial Summary",
                style: pw.TextStyle(font: fontBold, fontSize: 16),
              ),
              pw.Divider(),
              _buildPdfRow(
                "Total Sales Revenue",
                totalRevenue.value,
                fontRegular,
              ),
              _buildPdfRow(
                "(-) Cost of Goods Sold",
                totalCostOfGoods.value,
                fontRegular,
                isNegative: true,
              ),
              pw.Divider(thickness: 0.5),
              _buildPdfRow(
                "GROSS PROFIT",
                grossProfit.value,
                fontBold,
                fontSize: 14,
              ),
              pw.SizedBox(height: 10),
              _buildPdfRow(
                "(-) Operational Expenses",
                totalExpenses.value,
                fontRegular,
                isNegative: true,
              ),
              pw.Divider(thickness: 0.5),
              _buildPdfRow(
                "NET PROFIT",
                netProfit.value,
                fontBold,
                fontSize: 16,
                color: netProfit.value >= 0 ? PdfColors.green : PdfColors.red,
              ),

              pw.SizedBox(height: 30),

              // NEW: CUSTOMER PERFORMANCE TABLE IN PDF
              pw.Text(
                "Top Customer Performance",
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Customer', 'Type', 'Orders', 'Revenue', 'Profit'],
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                data:
                    customerPerformanceList
                        .take(20)
                        .map(
                          (e) => [
                            e['name'],
                            e['type'],
                            e['count'].toString(),
                            e['revenue'].toStringAsFixed(0),
                            e['profit'].toStringAsFixed(0),
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (f) => pdf.save(),
      name: "PnL_$endStr.pdf",
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    double value,
    pw.Font font, {
    bool isNegative = false,
    PdfColor color = PdfColors.black,
    double fontSize = 12,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
          ),
          pw.Text(
            "${isNegative ? '-' : ''}${value.toStringAsFixed(2)}",
            style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
          ),
        ],
      ),
    );
  }
}
