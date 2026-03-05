// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:async'; // Added for Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum HistoryFilter { daily, monthly, yearly, custom }

class GlobalPurchaseHistoryController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- DEPENDENCIES ---
  ProductController get stockCtrl => Get.find<ProductController>();
  DebatorController get debtorCtrl => Get.find<DebatorController>();
  DailyExpensesController get dailyExpenseCtrl =>
      Get.isRegistered<DailyExpensesController>()
          ? Get.find<DailyExpensesController>()
          : Get.put(DailyExpensesController());

  // --- OBSERVABLES ---
  var purchaseList = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isPdfLoading = false.obs;
  var isSinglePdfLoading = false.obs;

  // Name Cache
  var debtorNameCache = <String, String>{}.obs;

  // --- FILTER & DATE STATE ---
  var activeFilter = HistoryFilter.monthly.obs;
  var dateRange =
      DateTimeRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      ).obs;

  var totalAmount = 0.0.obs;

  // ========================================================
  // SUPPLIER SEARCH STATE
  // ========================================================
  var selectedDebtorId = Rx<String?>(null);
  var isSearchingSupplier = false.obs;
  var searchedSuppliers = <Map<String, dynamic>>[].obs;
  Timer? _searchDebounce;

  // Pagination for Purchases
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

  // ========================================================
  // 1. ADVANCED GLOBAL SEARCH LOGIC (Cloned from DebatorController)
  // ========================================================

  void searchSupplier(String queryText) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (queryText.trim().isEmpty) {
      isSearchingSupplier.value = false;
      searchedSuppliers.clear();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSupplierSearch(queryText);
    });
  }

  Future<void> _performSupplierSearch(String queryText) async {
    isSearchingSupplier.value = true;

    try {
      String qLower = queryText.trim().toLowerCase();
      Map<String, Map<String, dynamic>> results = {};

      List<String> searchTerms = qLower.split(RegExp(r'\s+'));
      String primaryTerm = searchTerms.first;

      if (primaryTerm.isNotEmpty) {
        // Query database using the exact same keyword array logic as your debtor controller
        var kwSnap =
            await _db
                .collection('debatorbody')
                .where('searchKeywords', arrayContains: primaryTerm)
                .limit(50)
                .get();

        for (var doc in kwSnap.docs) {
          results[doc.id] = {...doc.data(), 'id': doc.id};
        }
      }

      List<Map<String, dynamic>> finalMatches = [];

      for (var d in results.values) {
        String name = d['name']?.toString() ?? 'Unknown';
        String phone = d['phone']?.toString() ?? '';
        String nid = d['nid']?.toString() ?? '';
        String address = d['address']?.toString() ?? '';
        String des = d['des']?.toString() ?? '';

        // Combine string exactly like DebatorController
        String combinedString = "$name $phone $nid $address $des".toLowerCase();

        bool isMatch = true;
        for (String term in searchTerms) {
          if (!combinedString.contains(term)) {
            isMatch = false;
            break;
          }
        }

        if (isMatch) {
          finalMatches.add({
            'id': d['id'],
            'name': name,
            'phone': phone,
            'address': address,
          });
        }
      }

      searchedSuppliers.value = finalMatches;
    } catch (e) {
      print("Supplier Search Error: $e");
    } finally {
      isSearchingSupplier.value = false;
    }
  }

  void setSupplierFilter(String? debtorId) {
    selectedDebtorId.value = debtorId;
    searchedSuppliers.clear(); // Clear search UI dropdown
    _resetPagination();
    fetchPurchases();
  }

  // ========================================================
  // 2. FILTER LOGIC
  // ========================================================
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

    _resetPagination();
    fetchPurchases();
  }

  void _resetPagination() {
    _pageStartStack.clear();
    _lastDocument = null;
    isFirstPage.value = true;
  }

  // ========================================================
  // 3. DATA FETCHING (PURCHASES)
  // ========================================================
  Future<void> fetchPurchases({bool next = false, bool prev = false}) async {
    isLoading.value = true;
    try {
      Query query;

      // Filter by supplier if selected
      if (selectedDebtorId.value != null &&
          selectedDebtorId.value!.isNotEmpty) {
        query = _db
            .collection('debatorbody')
            .doc(selectedDebtorId.value)
            .collection('purchases');
      } else {
        query = _db.collectionGroup('purchases');
      }

      query = query
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

          String debtorId = doc.reference.parent.parent?.id ?? 'Unknown';
          data['debtorId'] = debtorId;

          if (!debtorNameCache.containsKey(debtorId)) {
            await _fetchDebtorName(debtorId);
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
      print("Error fetching purchases: $e");
    } finally {
      isLoading.value = false;
    }
  }

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

  // ========================================================
  // 4. MAKE PAYMENT
  // ========================================================
  Future<void> makePayment({
    required String debtorId,
    required String debtorName,
    required double amount,
    required String method,
    String? note,
    DateTime? customDate,
  }) async {
    if (amount <= 0) return;
    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      DocumentReference histRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      dynamic dateField =
          customDate != null
              ? Timestamp.fromDate(customDate)
              : FieldValue.serverTimestamp();

      batch.set(histRef, {
        'date': dateField,
        'type': 'payment',
        'amount': amount,
        'method': method,
        'note': note,
        'isAdjustment': false,
      });

      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});

      await batch.commit();

      try {
        await dailyExpenseCtrl.addDailyExpense(
          "Payment to $debtorName",
          amount.toInt(),
          note: "Debtor Payment. Method: $method. ${note ?? ''}",
          date: customDate ?? DateTime.now(),
        );
      } catch (e) {
        print("Expense Auto-add failed: $e");
      }

      await fetchPurchases();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Success", "Payment Recorded.");
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ========================================================
  // 5. EDIT PURCHASE
  // ========================================================
  Future<void> editPurchase({
    required String debtorId,
    required String purchaseId,
    required List<Map<String, dynamic>> oldItems,
    required List<Map<String, dynamic>> newItems,
    required double oldTotal,
    required double newTotal,
    String? note,
    DateTime? customDate,
  }) async {
    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      DocumentReference purchaseRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .doc(purchaseId);

      batch.update(purchaseRef, {
        'items': newItems,
        'totalAmount': newTotal,
        'note': note,
        if (customDate != null) 'date': Timestamp.fromDate(customDate),
      });

      double difference = newTotal - oldTotal;
      if (difference != 0) {
        DocumentReference debtorRef = _db
            .collection('debatorbody')
            .doc(debtorId);
        batch.update(debtorRef, {
          'purchaseDue': FieldValue.increment(difference),
        });
      }

      await batch.commit();

      List<Future> stockUpdates = [];

      for (var item in oldItems) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        String loc = item['location'] ?? 'Local';
        int qty = item['qty'] ?? 0;
        stockUpdates.add(
          stockCtrl.addMixedStock(
            productId: pid,
            localQty: loc == "Local" ? -qty : 0,
            airQty: loc == "Air" ? -qty : 0,
            seaQty: loc == "Sea" ? -qty : 0,
            localUnitPrice: item['cost'] ?? 0.0,
          ),
        );
      }

      for (var item in newItems) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        String loc = item['location'] ?? 'Local';
        int qty = item['qty'] ?? 0;
        stockUpdates.add(
          stockCtrl.addMixedStock(
            productId: pid,
            localQty: loc == "Local" ? qty : 0,
            airQty: loc == "Air" ? qty : 0,
            seaQty: loc == "Sea" ? qty : 0,
            localUnitPrice: item['cost'] ?? 0.0,
          ),
        );
      }

      await Future.wait(stockUpdates);

      await fetchPurchases();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Success", "Purchase Invoice successfully updated.");
    } catch (e) {
      Get.snackbar(
        "Error",
        "Update failed: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ========================================================
  // 6. BULK PDF LOGIC
  // ========================================================
  Future<void> downloadBulkPdf() async {
    isPdfLoading.value = true;
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      Query query =
          (selectedDebtorId.value != null && selectedDebtorId.value!.isNotEmpty)
              ? _db
                  .collection('debatorbody')
                  .doc(selectedDebtorId.value)
                  .collection('purchases')
              : _db.collectionGroup('purchases');

      QuerySnapshot allSnap =
          await query
              .where('date', isGreaterThanOrEqualTo: dateRange.value.start)
              .where('date', isLessThanOrEqualTo: dateRange.value.end)
              .orderBy('date', descending: true)
              .limit(500)
              .get();

      final dataList = <List<String>>[];
      double totalPeriod = 0.0;

      for (var docSnap in allSnap.docs) {
        var item = docSnap.data() as Map<String, dynamic>;
        String debtorId = docSnap.reference.parent.parent?.id ?? '';
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

  // ========================================================
  // 7. SINGLE INVOICE PDF
  // ========================================================
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
