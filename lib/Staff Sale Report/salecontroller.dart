import 'package:cloud_firestore/cloud_firestore.dart';
 import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StaffPerformanceModel {
  final String uid;
  final String name;
  double totalSales;
  double totalProfit;
  int totalInvoices;

  StaffPerformanceModel({
    required this.uid,
    required this.name,
    this.totalSales = 0.0,
    this.totalProfit = 0.0,
    this.totalInvoices = 0,
  });

  // Helper for margin calculation
  double get margin => totalSales > 0 ? (totalProfit / totalSales) * 100 : 0.0;
}

class StaffReportController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State
  var isLoading = false.obs;
  var staffStats = <StaffPerformanceModel>[].obs;

  // Date Filters (Default to Today)
  var startDate = DateTime.now().obs;
  var endDate = DateTime.now().obs;

  // Summary Totals
  double get grandTotalSales =>
      staffStats.fold(0, (sumv, item) => sumv + item.totalSales);
  double get grandTotalProfit =>
      staffStats.fold(0, (sumv, item) => sumv + item.totalProfit);

  @override
  void onInit() {
    super.onInit();
    fetchReport();
  }

  void pickDateRange(DateTime start, DateTime end) {
    startDate.value = start;
    endDate.value = end;
    fetchReport();
  }

  Future<void> fetchReport() async {
    isLoading.value = true;
    staffStats.clear();

    try {
      String startStr =
          "${DateFormat('yyyy-MM-dd').format(startDate.value)} 00:00:00";
      String endStr =
          "${DateFormat('yyyy-MM-dd').format(endDate.value)} 23:59:59";

      QuerySnapshot snapshot =
          await _db
              .collection('sales_orders')
              .orderBy('date')
              .startAt([startStr])
              .endAt([endStr])
              .get();

      Map<String, StaffPerformanceModel> tempMap = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        Map<String, dynamic>? soldBy =
            data['soldBy'] != null
                ? data['soldBy'] as Map<String, dynamic>
                : null;

        if (soldBy == null) continue;

        String uid = soldBy['uid'] ?? 'unknown';
        String name = soldBy['name'] ?? 'Unknown Staff';

        double saleAmount =
            double.tryParse(data['grandTotal'].toString()) ?? 0.0;
        double profitAmount = double.tryParse(data['profit'].toString()) ?? 0.0;

        if (!tempMap.containsKey(uid)) {
          tempMap[uid] = StaffPerformanceModel(uid: uid, name: name);
        }

        tempMap[uid]!.totalSales += saleAmount;
        tempMap[uid]!.totalProfit += profitAmount;
        tempMap[uid]!.totalInvoices += 1;
      }

      // Default Screen Sort: By Profit (Highest first) for the dashboard view
      List<StaffPerformanceModel> result = tempMap.values.toList();
      result.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
      staffStats.value = result;
    } catch (e) {
      Get.snackbar("Error", "Could not fetch report: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- PDF GENERATION LOGIC ---
  Future<void> generatePdf() async {
    if (staffStats.isEmpty) {
      Get.snackbar("Alert", "No data to print");
      return;
    }

    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontReg = await PdfGoogleFonts.robotoRegular();

    // 1. Sort by Staff Name alphabetically for the PDF as requested
    List<StaffPerformanceModel> pdfList = List.from(staffStats);
    pdfList.sort((a, b) => a.name.compareTo(b.name));

    // 2. Format Dates
    String dateRange =
        "${DateFormat('dd MMM yyyy').format(startDate.value)} - ${DateFormat('dd MMM yyyy').format(endDate.value)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    "G TEL - JOY EXPRESS",
                    style: pw.TextStyle(font: fontBold, fontSize: 20),
                  ),
                  pw.Text(
                    "Staff Performance Report",
                    style: pw.TextStyle(font: fontReg, fontSize: 16),
                  ),
                  pw.Text(
                    "Period: $dateRange",
                    style: pw.TextStyle(
                      font: fontReg,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // SL
                1: const pw.FlexColumnWidth(3), // Name
                2: const pw.FixedColumnWidth(60), // Invoices
                3: const pw.FixedColumnWidth(80), // Sales
                4: const pw.FixedColumnWidth(80), // Profit
                5: const pw.FixedColumnWidth(60), // Margin
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th("SL", fontBold),
                    _th("Staff Name", fontBold, align: pw.TextAlign.left),
                    _th("Inv.", fontBold),
                    _th("Total Sales", fontBold, align: pw.TextAlign.right),
                    _th("Total Profit", fontBold, align: pw.TextAlign.right),
                    _th("Margin", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                // Table Data
                ...List.generate(pdfList.length, (index) {
                  final item = pdfList[index];
                  return pw.TableRow(
                    children: [
                      _td(
                        (index + 1).toString(),
                        fontReg,
                        align: pw.TextAlign.center,
                      ),
                      _td(item.name, fontReg, align: pw.TextAlign.left),
                      _td(
                        item.totalInvoices.toString(),
                        fontReg,
                        align: pw.TextAlign.center,
                      ),
                      _td(
                        NumberFormat.currency(
                          symbol: '',
                          decimalDigits: 2,
                        ).format(item.totalSales),
                        fontReg,
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        NumberFormat.currency(
                          symbol: '',
                          decimalDigits: 2,
                        ).format(item.totalProfit),
                        fontBold,
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        "${item.margin.toStringAsFixed(1)}%",
                        fontReg,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
                // Table Footer (Totals)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _td("", fontReg),
                    _td("TOTAL", fontBold, align: pw.TextAlign.right),
                    _td(
                      pdfList
                          .fold<int>(0, (sumv, i) => sumv + i.totalInvoices)
                          .toString(),
                      fontBold,
                      align: pw.TextAlign.center,
                    ),
                    _td(
                      NumberFormat.currency(
                        symbol: '',
                        decimalDigits: 2,
                      ).format(grandTotalSales),
                      fontBold,
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      NumberFormat.currency(
                        symbol: '',
                        decimalDigits: 2,
                      ).format(grandTotalProfit),
                      fontBold,
                      align: pw.TextAlign.right,
                    ),
                    _td("", fontReg),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    );
  }
}