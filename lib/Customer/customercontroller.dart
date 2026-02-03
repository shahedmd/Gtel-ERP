// ignore_for_file: avoid_print, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Customer/model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerAnalyticsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- STATE ---
  var isLoading = false.obs;

  // Data Holding
  List<CustomerAnalyticsModel> _allAggregatedData = []; // Master List (for PDF)
  var paginatedList = <CustomerAnalyticsModel>[].obs; // Page List (for UI)

  // Pagination
  var currentPage = 1.obs;
  var itemsPerPage = 50;
  var totalItems = 0.obs;
  int get totalPages => (totalItems.value / itemsPerPage).ceil();

  // Summary
  var periodTotalSales = 0.0.obs;
  var periodTotalProfit = 0.0.obs;

  // --- FILTERS ---
  // Options: 'Daily', 'Monthly', 'Yearly'
  var reportType = 'Monthly'.obs;

  var selectedYear = DateTime.now().year.obs;
  var selectedMonth = DateTime.now().month.obs;
  var selectedDate = DateTime.now().obs; // For Specific Date

  @override
  void onInit() {
    super.onInit();
    generateReport();
  }

  String formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  // ----------------------------------------------------------------
  // 1. DATA PROCESSING
  // ----------------------------------------------------------------
  Future<void> generateReport() async {
    isLoading.value = true;
    _allAggregatedData.clear();
    paginatedList.clear();
    periodTotalSales.value = 0.0;
    periodTotalProfit.value = 0.0;
    totalItems.value = 0;
    currentPage.value = 1;

    try {
      DateTime start;
      DateTime end;

      if (reportType.value == 'Yearly') {
        start = DateTime(selectedYear.value, 1, 1);
        end = DateTime(selectedYear.value, 12, 31, 23, 59, 59);
      } else if (reportType.value == 'Monthly') {
        start = DateTime(selectedYear.value, selectedMonth.value, 1);
        end = DateTime(
          selectedYear.value,
          selectedMonth.value + 1,
          0,
          23,
          59,
          59,
        );
      } else {
        // Daily
        start = DateTime(
          selectedDate.value.year,
          selectedDate.value.month,
          selectedDate.value.day,
          0,
          0,
          0,
        );
        end = DateTime(
          selectedDate.value.year,
          selectedDate.value.month,
          selectedDate.value.day,
          23,
          59,
          59,
        );
      }

      // Fetch Sales
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      // Aggregation Map
      Map<String, CustomerAnalyticsModel> tempMap = {};

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['status'] == 'deleted' || data['status'] == 'cancelled') {
          continue;
        }

        String phone = (data['customerPhone'] ?? '').toString().trim();
        if (phone.isEmpty) phone = "Unknown";

        String name = data['customerName'] ?? 'Guest';
        String shop = data['shopName'] ?? '';
        double saleAmt = double.tryParse(data['grandTotal'].toString()) ?? 0.0;
        double profitAmt = double.tryParse(data['profit'].toString()) ?? 0.0;

        if (tempMap.containsKey(phone)) {
          var entry = tempMap[phone]!;
          entry.totalSales += saleAmt;
          entry.totalProfit += profitAmt;
          entry.orderCount += 1;
        } else {
          tempMap[phone] = CustomerAnalyticsModel(
            name: name,
            phone: phone,
            shopName: shop,
            orderCount: 1,
            totalSales: saleAmt,
            totalProfit: profitAmt,
          );
        }
      }

      _allAggregatedData = tempMap.values.toList();
      _allAggregatedData.sort((a, b) => b.totalSales.compareTo(a.totalSales));

      for (var item in _allAggregatedData) {
        periodTotalSales.value += item.totalSales;
        periodTotalProfit.value += item.totalProfit;
      }

      totalItems.value = _allAggregatedData.length;
      _updatePagination();
    } catch (e) {
      Get.snackbar("Error", "Analysis Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _updatePagination() {
    if (_allAggregatedData.isEmpty) {
      paginatedList.clear();
      return;
    }
    int start = (currentPage.value - 1) * itemsPerPage;
    int end = start + itemsPerPage;
    if (end > _allAggregatedData.length) end = _allAggregatedData.length;
    paginatedList.value = _allAggregatedData.sublist(start, end);
  }

  void nextPage() {
    if (currentPage.value < totalPages) {
      currentPage.value++;
      _updatePagination();
    }
  }

  void prevPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      _updatePagination();
    }
  }

  // ----------------------------------------------------------------
  // 3. PDF GENERATION
  // ----------------------------------------------------------------
  Future<void> downloadPdf() async {
    if (_allAggregatedData.isEmpty) {
      Get.snackbar("Alert", "No data to print. Generate report first.");
      return;
    }

    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // Generate Title
    String periodStr = "";
    if (reportType.value == 'Daily') {
      periodStr = DateFormat('dd MMM yyyy').format(selectedDate.value);
    } else if (reportType.value == 'Monthly') {
      periodStr = DateFormat(
        'MMMM yyyy',
      ).format(DateTime(selectedYear.value, selectedMonth.value));
    } else {
      periodStr = "Year: ${selectedYear.value}";
    }

    final dataToPrint = _allAggregatedData; // ALL DATA (No Pagination)

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader(fontBold, fontRegular, periodStr),
        footer: (context) => _buildPdfFooter(fontRegular, context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMetric(
                    "Total Customers",
                    dataToPrint.length.toString(),
                    fontBold,
                  ),
                  _pdfMetric(
                    "Total Revenue",
                    "Tk ${formatCurrency(periodTotalSales.value)}",
                    fontBold,
                  ),
                  _pdfMetric(
                    "Total Profit",
                    "Tk ${formatCurrency(periodTotalProfit.value)}",
                    fontBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table.fromTextArray(
              headers: [
                "Rank",
                "Customer",
                "Phone",
                "Orders",
                "Sales (Tk)",
                "Profit (Tk)",
              ],
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              data: List<List<dynamic>>.generate(dataToPrint.length, (index) {
                final item = dataToPrint[index];
                return [
                  (index + 1).toString(),
                  item.name,
                  item.phone,
                  item.orderCount.toString(),
                  formatCurrency(item.totalSales),
                  formatCurrency(item.totalProfit),
                ];
              }),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildPdfHeader(pw.Font bold, pw.Font reg, String period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "CUSTOMER PERFORMANCE REPORT",
              style: pw.TextStyle(font: bold, fontSize: 16),
            ),
            pw.Text(
              period,
              style: pw.TextStyle(
                font: bold,
                fontSize: 12,
                color: PdfColors.blue900,
              ),
            ),
          ],
        ),
        pw.Text(
          "G-TEL ERP Solutions",
          style: pw.TextStyle(font: reg, fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Font reg, pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Generated on: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 8),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(font: reg, fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfMetric(String label, String value, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
      ],
    );
  }
}