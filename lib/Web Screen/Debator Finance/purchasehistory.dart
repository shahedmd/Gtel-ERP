// ignore_for_file: deprecated_member_use, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum HistoryFilter { daily, monthly, yearly, custom }

class GlobalPurchaseHistoryController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- OBSERVABLES ---
  var purchaseList = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isPdfLoading = false.obs; // For Bulk PDF
  var isSinglePdfLoading = false.obs; // For Single Invoice PDF

  // Name Cache (To store Debtor Names so we don't re-fetch them constantly)
  var debtorNameCache = <String, String>{}.obs;

  // Filter State
  var activeFilter = HistoryFilter.monthly.obs;
  var dateRange =
      DateTimeRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      ).obs;

  var totalAmount = 0.0.obs;

  // Pagination
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  var hasMore = true.obs;
  var isFirstPage = true.obs;
  final List<DocumentSnapshot?> _pageStartStack = [];

  @override
  void onInit() {
    super.onInit();
    applyFilter(HistoryFilter.monthly);
  }

  // --- 1. FILTER LOGIC ---
  Future<void> applyFilter(HistoryFilter filter) async {
    activeFilter.value = filter;
    DateTime now = DateTime.now();

    if (filter == HistoryFilter.daily) {
      DateTime? picked = await showDatePicker(
        context: Get.context!,
        initialDate: now,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        dateRange.value = DateTimeRange(
          start: DateTime(picked.year, picked.month, picked.day),
          end: DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
        );
      } else {
        return;
      }
    } else if (filter == HistoryFilter.monthly) {
      dateRange.value = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    } else if (filter == HistoryFilter.yearly) {
      dateRange.value = DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31, 23, 59, 59),
      );
    } else if (filter == HistoryFilter.custom) {
      DateTimeRange? picked = await showDateRangePicker(
        context: Get.context!,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        dateRange.value = DateTimeRange(
          start: picked.start,
          end: picked.end.add(const Duration(hours: 23, minutes: 59)),
        );
      } else {
        return;
      }
    }

    _pageStartStack.clear();
    _lastDocument = null;
    isFirstPage.value = true;
    fetchPurchases();
  }

  // --- 2. DATA FETCHING ---
  Future<void> fetchPurchases({bool next = false, bool prev = false}) async {
    isLoading.value = true;
    try {
      Query query = _db
          .collectionGroup('purchases')
          .where('date', isGreaterThanOrEqualTo: dateRange.value.start)
          .where('date', isLessThanOrEqualTo: dateRange.value.end)
          .orderBy('date', descending: true)
          .limit(_pageSize);

      if (next && _lastDocument != null) {
        _pageStartStack.add(purchaseList.first['snapshot']);
        query = query.startAfterDocument(_lastDocument!);
        isFirstPage.value = false;
      } else if (prev && _pageStartStack.isNotEmpty) {
        DocumentSnapshot? prevStart = _pageStartStack.removeLast();
        if (_pageStartStack.isEmpty) isFirstPage.value = true;
        query = query.startAtDocument(prevStart!);
      } else {
        _pageStartStack.clear();
        isFirstPage.value = true;
      }

      QuerySnapshot snap = await query.get();

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
        hasMore.value = snap.docs.length == _pageSize;

        List<Map<String, dynamic>> tempList = [];

        for (var doc in snap.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['snapshot'] = doc;

          // EXTRACT DEBTOR ID from path: /debatorbody/{debtorId}/purchases/{docId}
          String debtorId = doc.reference.parent.parent?.id ?? 'Unknown';
          data['debtorId'] = debtorId;

          // Pre-fetch name if not cached
          if (!debtorNameCache.containsKey(debtorId)) {
            _fetchDebtorName(debtorId);
          }

          tempList.add(data);
        }
        purchaseList.value = tempList;
        _calculatePageTotal();
      } else {
        hasMore.value = false;
        if (!prev) {
          purchaseList.clear();
          totalAmount.value = 0;
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Helper to fetch Name and cache it
  Future<void> _fetchDebtorName(String id) async {
    try {
      if (id == 'Unknown') return;
      DocumentSnapshot doc = await _db.collection('debatorbody').doc(id).get();
      if (doc.exists) {
        debtorNameCache[id] = doc['name'] ?? 'Unknown Debtor';
      } else {
        debtorNameCache[id] = 'Deleted Debtor';
      }
    } catch (_) {}
  }

  void _calculatePageTotal() {
    double sum = 0;
    for (var item in purchaseList) {
      if (item['type'] == 'invoice') {
        sum +=
            double.tryParse(
              (item['totalAmount'] ?? item['amount']).toString(),
            ) ??
            0;
      }
    }
    totalAmount.value = sum;
  }

  void nextPage() => fetchPurchases(next: true);
  void prevPage() => fetchPurchases(prev: true);

  // --- 3. BULK REPORT PDF ---
  Future<void> downloadBulkPdf() async {
    isPdfLoading.value = true;
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      QuerySnapshot allSnap =
          await _db
              .collectionGroup('purchases')
              .where('date', isGreaterThanOrEqualTo: dateRange.value.start)
              .where('date', isLessThanOrEqualTo: dateRange.value.end)
              .orderBy('date', descending: true)
              .limit(500)
              .get();

      final dataList = <List<String>>[];
      double totalPeriod = 0.0;

      for (var doc in allSnap.docs) {
        var item = doc.data() as Map<String, dynamic>;
        // Get name synchronously if cached, otherwise "Loading..."
        String debtorId = doc.reference.parent.parent?.id ?? '';
        String debtorName = debtorNameCache[debtorId] ?? "Debtor #$debtorId";

        DateTime date = (item['date'] as Timestamp).toDate();
        String type = (item['type'] ?? '').toString().toUpperCase();
        double amount =
            double.tryParse(
              (item['totalAmount'] ?? item['amount']).toString(),
            ) ??
            0.0;

        if (type == 'INVOICE') totalPeriod += amount;

        dataList.add([
          DateFormat('dd-MMM').format(date),
          debtorName,
          type,
          amount.toStringAsFixed(0),
        ]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build:
              (context) => [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    "Master Purchase Report",
                    style: pw.TextStyle(font: bold, fontSize: 18),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Period: ${DateFormat('dd MMM yyyy').format(dateRange.value.start)} - ${DateFormat('dd MMM yyyy').format(dateRange.value.end)}",
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Date', 'Supplier', 'Type', 'Amount'],
                  data: dataList,
                  headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {3: pw.Alignment.centerRight},
                ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Total: $totalPeriod",
                    style: pw.TextStyle(font: bold),
                  ),
                ),
              ],
        ),
      );

      await Printing.layoutPdf(onLayout: (f) => doc.save());
    } catch (e) {
      Get.snackbar("Error", "PDF Failed: $e");
    } finally {
      isPdfLoading.value = false;
    }
  }

  // --- 4. SINGLE INVOICE PDF (Like Debtor Page) ---
  Future<void> generateSingleInvoicePdf(Map<String, dynamic> data) async {
    isSinglePdfLoading.value = true;
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      String debtorId = data['debtorId'];
      String debtorName = debtorNameCache[debtorId] ?? "Debtor";

      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      final date =
          data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now();
      final total = double.tryParse(data['totalAmount'].toString()) ?? 0.0;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "PURCHASE INVOICE",
                        style: pw.TextStyle(font: bold, fontSize: 20),
                      ),
                      pw.Text(
                        "GTEL ERP",
                        style: pw.TextStyle(font: bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Supplier:", style: pw.TextStyle(font: bold)),
                        pw.Text(debtorName, style: pw.TextStyle(font: font)),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          "Date: ${DateFormat('dd-MMM-yyyy').format(date)}",
                          style: pw.TextStyle(font: font),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Inv ID: ${data['id'].toString().substring(0, 6)}",
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Table.fromTextArray(
                  headers: ['Item', 'Model', 'Loc', 'Qty', 'Cost', 'Total'],
                  data:
                      items
                          .map(
                            (e) => [
                              e['name'],
                              e['model'] ?? '-',
                              e['location'] ?? '-',
                              e['qty'].toString(),
                              e['cost'].toString(),
                              e['subtotal'].toString(),
                            ],
                          )
                          .toList(),
                  headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Grand Total: ${total.toStringAsFixed(2)}",
                    style: pw.TextStyle(font: bold, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isSinglePdfLoading.value = false;
    }
  }
}