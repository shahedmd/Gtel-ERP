// ignore_for_file: deprecated_member_use, avoid_print, empty_catches

import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Holds the daily breakdown
class DailyStat {
  DateTime date;
  double totalSales; // Invoiced Amount
  double totalCollected; // Cash Received
  int invoiceCount;

  DailyStat({
    required this.date,
    this.totalSales = 0.0,
    this.totalCollected = 0.0,
    this.invoiceCount = 0,
  });

  double get netDifference => totalSales - totalCollected;
}

class MonthlySalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = false.obs;

  // --- SELECTION STATE ---
  var selectedDate = DateTime.now().obs;

  // --- AGGREGATE METRICS ---
  var totalMonthlySales = 0.0.obs;
  var totalMonthlyCollection = 0.0.obs;
  var totalMonthlyDue = 0.0.obs;

  // --- DAILY BREAKDOWN ---
  final dailyStats = Rx<SplayTreeMap<int, DailyStat>>(SplayTreeMap());

  @override
  void onInit() {
    super.onInit();
    loadMonthlyData(DateTime.now());
  }

  // Call this from your Dropdown
  void loadMonthlyData(DateTime date) {
    selectedDate.value = date;
    _fetchData();
  }

  Future<void> _fetchData() async {
    isLoading.value = true;

    // Reset Metrics
    totalMonthlySales.value = 0.0;
    totalMonthlyCollection.value = 0.0;
    totalMonthlyDue.value = 0.0;

    // Clear Map
    dailyStats.value.clear();

    // Define Time Range
    DateTime startOfMonth = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      1,
    );
    DateTime endOfMonth = DateTime(
      selectedDate.value.year,
      selectedDate.value.month + 1,
      0,
      23,
      59,
      59,
    );

    try {
      // 1. FETCH SALES (From 'sales_orders')
      QuerySnapshot salesSnap =
          await _db
              .collection('sales_orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
              )
              .get();

      for (var doc in salesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Skip deleted
        if ((data['status'] ?? '') == 'deleted') continue;

        double amount = double.tryParse(data['grandTotal'].toString()) ?? 0.0;
        DateTime date = (data['timestamp'] as Timestamp).toDate();
        int day = date.day;

        // Update Total
        totalMonthlySales.value += amount;

        // Update Daily Stat
        _updateDailyStat(day, date, salesAmount: amount, count: 1);
      }

      // 2. FETCH COLLECTIONS (From 'daily_sales')
      QuerySnapshot collectionSnap =
          await _db
              .collection('daily_sales')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
              )
              .get();

      for (var doc in collectionSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        double collected = double.tryParse(data['paid'].toString()) ?? 0.0;

        DateTime date = (data['timestamp'] as Timestamp).toDate();
        int day = date.day;

        // Update Total
        totalMonthlyCollection.value += collected;

        // Update Daily Stat
        _updateDailyStat(day, date, collectionAmount: collected);
      }

      // 3. Final Calculation
      totalMonthlyDue.value =
          totalMonthlySales.value - totalMonthlyCollection.value;

      // Force UI update
      dailyStats.refresh();
    } catch (e) {
      Get.snackbar("Error", "Failed to load monthly data: $e");
      print(e);
    } finally {
      isLoading.value = false;
    }
  }

  void _updateDailyStat(
    int day,
    DateTime fullDate, {
    double salesAmount = 0.0,
    double collectionAmount = 0.0,
    int count = 0,
  }) {
    if (!dailyStats.value.containsKey(day)) {
      dailyStats.value[day] = DailyStat(date: fullDate);
    }

    dailyStats.value[day]!.totalSales += salesAmount;
    dailyStats.value[day]!.totalCollected += collectionAmount;
    dailyStats.value[day]!.invoiceCount += count;
  }

  // ==========================================
  //  MISSING METHOD ADDED HERE
  // ==========================================
  Future<List<Map<String, dynamic>>> fetchTransactionsForDay(
    DateTime date,
  ) async {
    // Define start and end of the selected day
    DateTime start = DateTime(date.year, date.month, date.day);
    DateTime end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .orderBy('timestamp', descending: true)
              .get();

      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'invoiceId': data['invoiceId'] ?? doc.id,
          'customerName': data['customerName'] ?? 'Unknown',
          'customerPhone': data['customerPhone'] ?? '',
          'grandTotal': double.tryParse(data['grandTotal'].toString()) ?? 0.0,
          'customerType': data['customerType'] ?? 'General',
          'isCondition': data['isCondition'] == true,
          'courierName': data['courierName'] ?? '',
        };
      }).toList();
    } catch (e) {
      print("Error fetching daily transactions: $e");
      return [];
    }
  }

  // ==========================================
  // PDF GENERATION
  // ==========================================
  Future<void> generateMonthlyReportPDF() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();

    final String monthName = DateFormat('MMMM yyyy').format(selectedDate.value);
    final primaryColor = PdfColors.blue900;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "MONTHLY BUSINESS REPORT",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      "Period: $monthName",
                      style: pw.TextStyle(font: fontRegular, fontSize: 12),
                    ),
                  ],
                ),
                pw.Text(
                  "G-TEL ERP",
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // SUMMARY CARDS
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                  "TOTAL SALES",
                  totalMonthlySales.value,
                  PdfColors.blue100,
                  fontBold,
                ),
                _buildSummaryCard(
                  "TOTAL COLLECTED",
                  totalMonthlyCollection.value,
                  PdfColors.green100,
                  fontBold,
                ),
                _buildSummaryCard(
                  "BALANCE / DUE",
                  totalMonthlyDue.value,
                  totalMonthlyDue.value > 0
                      ? PdfColors.orange100
                      : PdfColors.grey200,
                  fontBold,
                ),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Text(
              "DAILY BREAKDOWN",
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 10),

            // TABLE
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date
                1: const pw.FlexColumnWidth(1), // Count
                2: const pw.FlexColumnWidth(2), // Sales
                3: const pw.FlexColumnWidth(2), // Collection
                4: const pw.FlexColumnWidth(2), // Difference
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th("Date", fontBold, align: pw.TextAlign.left),
                    _th("Bills", fontBold),
                    _th("Sales (Inv)", fontBold, align: pw.TextAlign.right),
                    _th("Collected", fontBold, align: pw.TextAlign.right),
                    _th("Balance", fontBold, align: pw.TextAlign.right),
                  ],
                ),
                // Table Data
                ...dailyStats.value.entries.map((entry) {
                  final stat = entry.value;
                  final isNegative = stat.netDifference < 0;

                  return pw.TableRow(
                    children: [
                      _td(
                        DateFormat('dd MMM (EEE)').format(stat.date),
                        fontRegular,
                        align: pw.TextAlign.left,
                      ),
                      _td(stat.invoiceCount.toString(), fontRegular),
                      _td(
                        stat.totalSales.toStringAsFixed(0),
                        fontRegular,
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        stat.totalCollected.toStringAsFixed(0),
                        fontRegular,
                        align: pw.TextAlign.right,
                        color: PdfColors.green800,
                      ),
                      _td(
                        stat.netDifference.toStringAsFixed(0),
                        fontBold,
                        align: pw.TextAlign.right,
                        color:
                            isNegative ? PdfColors.green900 : PdfColors.red900,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildSummaryCard(
    String title,
    double value,
    PdfColor bg,
    pw.Font font,
  ) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 5),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "Tk ${value.toStringAsFixed(0)}",
              style: pw.TextStyle(
                font: font,
                fontSize: 14,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9, color: color),
      ),
    );
  }
}