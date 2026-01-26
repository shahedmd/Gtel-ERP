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
  var aggregatedList = <CustomerAnalyticsModel>[].obs;

  // Totals for the whole period
  var periodTotalSales = 0.0.obs;
  var periodTotalProfit = 0.0.obs;

  // Filters
  var selectedYear = DateTime.now().year.obs;
  var selectedMonth = DateTime.now().month.obs;
  var isYearlyReport = false.obs; // Toggle between Monthly vs Yearly

  // ----------------------------------------------------------------
  // 1. DATA PROCESSING LOGIC
  // ----------------------------------------------------------------
  Future<void> generateReport() async {
    isLoading.value = true;
    aggregatedList.clear();
    periodTotalSales.value = 0.0;
    periodTotalProfit.value = 0.0;

    try {
      // A. Calculate Date Range
      DateTime start;
      DateTime end;

      if (isYearlyReport.value) {
        // Whole Year: Jan 1 to Dec 31
        start = DateTime(selectedYear.value, 1, 1);
        end = DateTime(selectedYear.value, 12, 31, 23, 59, 59);
      } else {
        // Specific Month
        start = DateTime(selectedYear.value, selectedMonth.value, 1);
        // Trick to get last day of month: Day 0 of next month
        end = DateTime(
          selectedYear.value,
          selectedMonth.value + 1,
          0,
          23,
          59,
          59,
        );
      }

      print("Querying from $start to $end");

      // B. Fetch Data
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      print("Found ${snap.docs.length} orders");

      // C. Aggregate (Group By Customer Phone)
      Map<String, CustomerAnalyticsModel> tempMap = {};

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Identifiers
        String phone = data['customerPhone'] ?? 'Unknown';
        String name = data['customerName'] ?? 'Unknown';
        String shop = data['shopName'] ?? '';

        // Metrics
        double saleAmt = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
        double profitAmt = (data['profit'] as num?)?.toDouble() ?? 0.0;

        // If customer exists in map, update values. If not, create new.
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

      // D. Convert to List & Sort (Highest Sales First)
      List<CustomerAnalyticsModel> finalResult = tempMap.values.toList();
      finalResult.sort((a, b) => b.totalSales.compareTo(a.totalSales));

      aggregatedList.value = finalResult;

      // E. Calculate Period Totals
      for (var item in finalResult) {
        periodTotalSales.value += item.totalSales;
        periodTotalProfit.value += item.totalProfit;
      }
    } catch (e) {
      Get.snackbar("Error", "Analysis Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 2. PDF GENERATION
  // ----------------------------------------------------------------
  Future<void> downloadPdf() async {
    if (aggregatedList.isEmpty) {
      Get.snackbar("Alert", "No data to print. Generate report first.");
      return;
    }

    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    String periodTitle =
        isYearlyReport.value
            ? "Yearly Report: ${selectedYear.value}"
            : "Monthly Report: ${DateFormat('MMMM yyyy').format(DateTime(selectedYear.value, selectedMonth.value))}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "CUSTOMER BUSINESS REPORT",
                      style: pw.TextStyle(font: fontBold, fontSize: 16),
                    ),
                    pw.Text(
                      "G-TEL ERP Analytics",
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  periodTitle,
                  style: pw.TextStyle(font: fontBold, fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatParam(
                    "Total Customers",
                    aggregatedList.length.toString(),
                    fontRegular,
                    fontBold,
                  ),
                  _pdfStatParam(
                    "Total Sales",
                    periodTotalSales.value.toStringAsFixed(2),
                    fontRegular,
                    fontBold,
                  ),
                  _pdfStatParam(
                    "Total Profit",
                    periodTotalProfit.value.toStringAsFixed(2),
                    fontRegular,
                    fontBold,
                    color: PdfColors.green800,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Table
            pw.Table.fromTextArray(
              headers: [
                "Rank",
                "Customer / Shop",
                "Orders",
                "Sales (Tk)",
                "Profit (Tk)",
              ],
              headerStyle: pw.TextStyle(
                font: fontBold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
              ),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              data: List<List<dynamic>>.generate(aggregatedList.length, (
                index,
              ) {
                final item = aggregatedList[index];
                return [
                  (index + 1).toString(),
                  "${item.name}\n${item.phone}",
                  item.orderCount.toString(),
                  item.totalSales.toStringAsFixed(0),
                  item.totalProfit.toStringAsFixed(0),
                ];
              }),
            ),

            // Footer
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Generated on ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _pdfStatParam(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: reg, fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(font: bold, fontSize: 11, color: color),
        ),
      ],
    );
  }
}
