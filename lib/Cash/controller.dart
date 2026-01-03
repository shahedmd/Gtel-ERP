import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CashDrawerController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Observables
  final RxList<Map<String, dynamic>> filteredSales =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  // Filters
  final RxInt selectedYear = DateTime.now().year.obs;
  final RxInt selectedMonth = DateTime.now().month.obs;

  // Totals
  final RxDouble cashTotal = 0.0.obs;
  final RxDouble bkashTotal = 0.0.obs;
  final RxDouble nagadTotal = 0.0.obs;
  final RxDouble bankTotal = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDrawerData();
  }

  Future<void> fetchDrawerData() async {
    isLoading.value = true;
    try {
      DateTime startOfMonth = DateTime(
        selectedYear.value,
        selectedMonth.value,
        1,
      );
      DateTime endOfMonth = DateTime(
        selectedYear.value,
        selectedMonth.value + 1,
        0,
        23,
        59,
        59,
      );

      QuerySnapshot snap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
              .where('timestamp', isLessThanOrEqualTo: endOfMonth)
              .orderBy('timestamp', descending: true)
              .get();

      double cash = 0, bkash = 0, nagad = 0, bank = 0;
      List<Map<String, dynamic>> tempList = [];

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tempList.add(data);

        // --- NEW LOGIC: Handle Multi-Payment & Legacy Data ---
        var payMethod = data['paymentMethod'];

        // Case 1: New Multi-Payment System
        if (payMethod is Map && payMethod['type'] == 'multi') {
          cash += (double.tryParse(payMethod['cash'].toString()) ?? 0.0);
          bkash += (double.tryParse(payMethod['bkash'].toString()) ?? 0.0);
          nagad += (double.tryParse(payMethod['nagad'].toString()) ?? 0.0);
          bank += (double.tryParse(payMethod['bank'].toString()) ?? 0.0);
        }
        // Case 2: Old/Simple System
        else {
          double amount = double.tryParse(data['paid'].toString()) ?? 0.0;
          String type = 'cash';

          if (payMethod is Map) {
            type = (payMethod['type'] ?? 'cash').toString().toLowerCase();
          } else if (payMethod is String) {
            type = payMethod.toString().toLowerCase();
          }

          switch (type) {
            case 'bkash':
              bkash += amount;
              break;
            case 'nagad':
              nagad += amount;
              break;
            case 'bank':
              bank += amount;
              break;
            default:
              cash += amount;
              break;
          }
        }
      }

      filteredSales.assignAll(tempList);
      cashTotal.value = cash;
      bkashTotal.value = bkash;
      nagadTotal.value = nagad;
      bankTotal.value = bank;

      // Grand Total is the sum of all settled payments
      grandTotal.value = cash + bkash + nagad + bank;
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void changeDate(int month, int year) {
    selectedMonth.value = month;
    selectedYear.value = year;
    fetchDrawerData();
  }

  // --- PDF GENERATION LOGIC ---
  Future<void> downloadPdf() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final bold = await PdfGoogleFonts.nunitoBold();

    String monthName = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(selectedYear.value, selectedMonth.value));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Monthly Revenue Report",
                      style: pw.TextStyle(font: font, fontSize: 24),
                    ),
                    pw.Text(
                      "Generated: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Text(
                "Period: $monthName",
                style: pw.TextStyle(font: font, fontSize: 16),
              ),
              pw.SizedBox(height: 20),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _pdfSummaryItem("Cash", cashTotal.value),
                    _pdfSummaryItem("Bkash", bkashTotal.value),
                    _pdfSummaryItem("Nagad", nagadTotal.value),
                    _pdfSummaryItem("Bank", bankTotal.value),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Revenue: ${grandTotal.value.toStringAsFixed(2)} BDT",
                  style: pw.TextStyle(font: bold, fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 20),

              // Data Table
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                headers: [
                  'Date',
                  'Invoice ID',
                  'Customer',
                  'Method',
                  'Paid Amount',
                ],
                data:
                    filteredSales.map((item) {
                      String date = "-";
                      if (item['timestamp'] != null) {
                        date = DateFormat(
                          'dd-MMM',
                        ).format((item['timestamp'] as Timestamp).toDate());
                      }

                      String inv = item['transactionId'] ?? '-';
                      String name = item['name'] ?? 'Unknown';

                      // Handle Method Display for PDF
                      String methodDisplay = "CASH";
                      var pm = item['paymentMethod'];
                      if (pm is Map && pm['type'] == 'multi') {
                        methodDisplay = "SPLIT/MULTI";
                      } else if (pm is Map) {
                        methodDisplay =
                            (pm['type'] ?? 'cash').toString().toUpperCase();
                      }

                      // Handle Total Paid amount specifically for this transaction
                      double amount = 0.0;
                      if (pm is Map && pm['type'] == 'multi') {
                        amount =
                            double.tryParse(pm['totalPaid'].toString()) ?? 0.0;
                      } else {
                        amount =
                            double.tryParse(item['paid'].toString()) ?? 0.0;
                      }

                      return [
                        date,
                        inv,
                        name,
                        methodDisplay,
                        amount.toStringAsFixed(2),
                      ];
                    }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Revenue_Report_$monthName.pdf',
    );
  }

  pw.Widget _pdfSummaryItem(String title, double amount) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          amount.toStringAsFixed(0),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}
 