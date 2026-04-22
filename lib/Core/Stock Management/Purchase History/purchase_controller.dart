// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpensecontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../stock_controller.dart';


enum HistoryFilter { daily, monthly, yearly, custom }

/// Typed record representing a single purchase or payment row.
class PurchaseRecord {
  final String id;
  final String debtorId;
  final DateTime date;
  final String type; // 'invoice' | 'payment' | 'adjustment'
  final double amount;
  final List<Map<String, dynamic>> items;
  final String? note;
  final String? method;

  const PurchaseRecord({
    required this.id,
    required this.debtorId,
    required this.date,
    required this.type,
    required this.amount,
    required this.items,
    this.note,
    this.method,
  });

  factory PurchaseRecord.fromFirestore(
    DocumentSnapshot doc,
    String resolvedDebtorId,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    final rawDate = d['date'];

    return PurchaseRecord(
      id: doc.id,
      debtorId: resolvedDebtorId,
      date:
          rawDate is Timestamp
              ? rawDate.toDate()
              : (rawDate is DateTime ? rawDate : DateTime.now()),
      type: (d['type'] ?? 'unknown').toString().toLowerCase(),
      amount:
          double.tryParse(
            (d['totalAmount'] ?? d['amount'] ?? 0).toString(),
          ) ??
          0.0,
      items: List<Map<String, dynamic>>.from(d['items'] ?? []),
      note: d['note']?.toString(),
      method: d['method']?.toString(),
    );
  }

  /// Convert back to a raw map for edit operations.
  Map<String, dynamic> toEditMap() => {
    'id': id,
    'debtorId': debtorId,
    'date': Timestamp.fromDate(date),
    'type': type,
    'totalAmount': amount,
    'amount': amount,
    'items': items,
    'note': note,
    'method': method,
  };
}

/// Pagination cursor stack — supports clean forward/backward navigation.
class _PaginationState {
  /// Stack of first-document cursors for each previously visited page.
  /// Index 0 = nothing (page 1 has no prior cursor).
  final List<DocumentSnapshot?> _stack = [null];

  DocumentSnapshot? _lastDoc;

  bool get isFirstPage => _stack.length == 1;

  void reset() {
    _stack
      ..clear()
      ..add(null);
    _lastDoc = null;
  }

  void pushForward(DocumentSnapshot firstDocOfCurrentPage) {
    _stack.add(firstDocOfCurrentPage);
  }

  void popBackward() {
    if (_stack.length > 1) _stack.removeLast();
  }

  DocumentSnapshot? get currentCursor => _stack.last;
  DocumentSnapshot? get lastDoc => _lastDoc;
  set lastDoc(DocumentSnapshot? v) => _lastDoc = v;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class GlobalPurchaseHistoryController extends GetxController {
  // ── Dependencies ────────────────────────────────────────────────────────────
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ProductController get _stockCtrl => Get.find<ProductController>();
  DailyExpensesController get _expenseCtrl =>
      Get.isRegistered<DailyExpensesController>()
          ? Get.find<DailyExpensesController>()
          : Get.put(DailyExpensesController());

  // ── Observable State ────────────────────────────────────────────────────────
  final records = <PurchaseRecord>[].obs;
  final isLoading = false.obs;
  final isPdfLoading = false.obs;
  final isSinglePdfLoading = false.obs;

  /// Local name cache to avoid redundant Firestore reads.
  final debtorNameCache = <String, String>{}.obs;

  // Filters
  final activeFilter = HistoryFilter.monthly.obs;
  final dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
      23,
      59,
      59,
    ),
  ).obs;

  // Summary totals (invoice-only, current page)
  final totalInvoiced = 0.0.obs;
  final totalPayments = 0.0.obs;

  // Supplier search
  final selectedDebtorId = Rx<String?>(null);
  final isSearchingSupplier = false.obs;
  final searchedSuppliers = <Map<String, dynamic>>[].obs;

  // Pagination
  final hasMore = true.obs;
  final isFirstPage = true.obs;

  static const int _pageSize = 20;
  final _pagination = _PaginationState();

  Timer? _searchDebounce;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    applyFilter(HistoryFilter.monthly);
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  // ── Supplier Search ──────────────────────────────────────────────────────────

  void searchSupplier(String query) {
    _searchDebounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      isSearchingSupplier.value = false;
      searchedSuppliers.clear();
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _performSupplierSearch(trimmed),
    );
  }

  Future<void> _performSupplierSearch(String queryText) async {
    isSearchingSupplier.value = true;
    try {
      final qLower = queryText.toLowerCase();
      final terms = qLower.split(RegExp(r'\s+'));
      final primaryTerm = terms.first;

      final snap =
          await _db
              .collection('debatorbody')
              .where('searchKeywords', arrayContains: primaryTerm)
              .limit(50)
              .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final combined =
            '${data['name']} ${data['phone']} ${data['nid']} ${data['address']} ${data['des']}'
                .toLowerCase();

        if (terms.every((t) => combined.contains(t))) {
          results.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'address': data['address'] ?? '',
          });
        }
      }
      searchedSuppliers.value = results;
    } catch (e) {
      print('[PurchaseHistory] Supplier search error: $e');
    } finally {
      isSearchingSupplier.value = false;
    }
  }

  void setSupplierFilter(String? debtorId) {
    selectedDebtorId.value = debtorId;
    searchedSuppliers.clear();
    _resetAndFetch();
  }

  // ── Filter / Date Range ──────────────────────────────────────────────────────

  Future<void> applyFilter(HistoryFilter filter) async {
    activeFilter.value = filter;
    final now = DateTime.now();

    switch (filter) {
      case HistoryFilter.daily:
        final picked = await showDatePicker(
          context: Get.context!,
          initialDate: now,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        dateRange.value = DateTimeRange(
          start: DateTime(picked.year, picked.month, picked.day),
          end: DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
        );

      case HistoryFilter.monthly:
        dateRange.value = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );

      case HistoryFilter.yearly:
        dateRange.value = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );

      case HistoryFilter.custom:
        final picked = await showDateRangePicker(
          context: Get.context!,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        dateRange.value = DateTimeRange(
          start: picked.start,
          end: picked.end.add(const Duration(hours: 23, minutes: 59)),
        );
    }

    _resetAndFetch();
  }

  void _resetAndFetch() {
    _pagination.reset();
    isFirstPage.value = true;
    hasMore.value = true;
    fetchRecords();
  }

  // ── Data Fetching ─────────────────────────────────────────────────────────────

  Future<void> fetchRecords({bool goNext = false, bool goPrev = false}) async {
    isLoading.value = true;
    try {
      // ── Build base query ──────────────────────────────────────────────────
      Query baseQuery =
          (selectedDebtorId.value?.isNotEmpty == true)
              ? _db
                  .collection('debatorbody')
                  .doc(selectedDebtorId.value)
                  .collection('purchases')
              : _db.collectionGroup('purchases');

      baseQuery = baseQuery
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.value.start),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(dateRange.value.end),
          )
          .orderBy('date', descending: true);

      // ── Apply pagination cursor ───────────────────────────────────────────
      if (goNext && _pagination.lastDoc != null) {
        // Before moving forward, save the first doc of the current page
        // so we can navigate back.
        if (records.isNotEmpty) {
          // The first doc of current page is tracked inside the stack.
          // We re-fetch current first doc from _pagination current cursor.
        }
        baseQuery = baseQuery
            .startAfterDocument(_pagination.lastDoc!)
            .limit(_pageSize);
        isFirstPage.value = false;
      } else if (goPrev) {
        _pagination.popBackward();
        isFirstPage.value = _pagination.isFirstPage;
        final cursor = _pagination.currentCursor;
        baseQuery =
            cursor != null
                ? baseQuery.startAtDocument(cursor).limit(_pageSize)
                : baseQuery.limit(_pageSize);
      } else {
        // Fresh fetch — don't apply any cursor
        baseQuery = baseQuery.limit(_pageSize);
      }

      final snap = await baseQuery.get();

      if (snap.docs.isEmpty) {
        hasMore.value = false;
        if (!goPrev) {
          records.clear();
          _updateTotals([]);
        }
        return;
      }

      // Track the last document for forward navigation.
      _pagination.lastDoc = snap.docs.last;
      // Track the first document of this page for backward navigation.
      if (goNext) {
        _pagination.pushForward(snap.docs.first);
      }

      hasMore.value = snap.docs.length == _pageSize;

      // ── Resolve debtor names ──────────────────────────────────────────────
      final futures = <Future>[];
      final seen = <String>{};
      for (final doc in snap.docs) {
        final debtorId = doc.reference.parent.parent?.id ?? 'unknown';
        if (!debtorNameCache.containsKey(debtorId) && seen.add(debtorId)) {
          futures.add(_resolveDebtorName(debtorId));
        }
      }
      await Future.wait(futures);

      // ── Map to typed records ──────────────────────────────────────────────
      final parsed = snap.docs.map((doc) {
        final debtorId = doc.reference.parent.parent?.id ?? 'unknown';
        return PurchaseRecord.fromFirestore(doc, debtorId);
      }).toList();

      records.value = parsed;
      _updateTotals(parsed);
    } catch (e) {
      print('[PurchaseHistory] Fetch error: $e');
      Get.snackbar(
        'Load Error',
        'Failed to load records. Please try again.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _resolveDebtorName(String id) async {
    if (id == 'unknown') {
      debtorNameCache[id] = 'Unknown';
      return;
    }
    try {
      final doc = await _db.collection('debatorbody').doc(id).get();
      debtorNameCache[id] =
          doc.exists ? (doc['name'] ?? 'Unnamed Debtor') : 'Deleted Debtor';
    } catch (_) {
      debtorNameCache[id] = 'Unknown';
    }
  }

  void _updateTotals(List<PurchaseRecord> list) {
    double inv = 0, pay = 0;
    for (final r in list) {
      if (r.type == 'invoice') {
        inv += r.amount;
      } else if (r.type == 'payment') {
        pay += r.amount;
      }
    }
    totalInvoiced.value = inv;
    totalPayments.value = pay;
  }

  void nextPage() => fetchRecords(goNext: true);
  void prevPage() => fetchRecords(goPrev: true);

  // ── Make Payment ─────────────────────────────────────────────────────────────

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
      final batch = _db.batch();
      final histRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .doc();
      final debtorRef = _db.collection('debatorbody').doc(debtorId);

      batch.set(histRef, {
        'date':
            customDate != null
                ? Timestamp.fromDate(customDate)
                : FieldValue.serverTimestamp(),
        'type': 'payment',
        'amount': amount,
        'method': method,
        'note': note ?? '',
        'isAdjustment': false,
      });
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});
      await batch.commit();

      // Auto-add to daily expenses — non-blocking
      _expenseCtrl
          .addDailyExpense(
            'Payment to $debtorName',
            amount,
            note: 'Debtor Payment. Method: $method. ${note ?? ''}',
            date: customDate ?? DateTime.now(),
          )
          .catchError(
            (e) => print('[PurchaseHistory] Expense auto-add failed: $e'),
          );

      if (Get.isDialogOpen ?? false) Get.back();
      await fetchRecords();
      Get.snackbar(
        'Payment Recorded',
        '৳${amount.toStringAsFixed(2)} paid to $debtorName.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Payment Failed',
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── Edit Purchase Invoice ─────────────────────────────────────────────────────

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
      // ── 1. Update the invoice document ─────────────────────────────────
      final batch = _db.batch();
      final purchaseRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .doc(purchaseId);

      batch.update(purchaseRef, {
        'items': newItems,
        'totalAmount': newTotal,
        if (note != null) 'note': note,
        if (customDate != null) 'date': Timestamp.fromDate(customDate),
      });

      // ── 2. Adjust supplier payable ──────────────────────────────────────
      final diff = newTotal - oldTotal;
      if (diff != 0) {
        final debtorRef = _db.collection('debatorbody').doc(debtorId);
        batch.update(debtorRef, {
          'purchaseDue': FieldValue.increment(diff),
        });
      }

      await batch.commit();

      // ── 3. Net stock delta (prevents duplicate stock additions) ─────────
      final netChanges = <String, Map<String, dynamic>>{};

      void applyQty(Map<String, dynamic> item, int sign) {
        final pid = item['productId'].toString();
        final loc = (item['location'] ?? 'Local').toString();
        final key = '${pid}_$loc';
        netChanges.putIfAbsent(
          key,
          () => {
            'productId': pid,
            'location': loc,
            'qty': 0,
            'cost': item['cost'] ?? 0.0,
          },
        );
        netChanges[key]!['qty'] =
            (netChanges[key]!['qty'] as int) + sign * ((item['qty'] as int?) ?? 0);
        // Always take the latest cost
        if (sign > 0) netChanges[key]!['cost'] = item['cost'] ?? 0.0;
      }

      for (final item in oldItems) {
        applyQty(item, -1);
      }
      for (final item in newItems) {
        applyQty(item, 1);
      }

      final stockFutures = <Future>[];
      for (final change in netChanges.values) {
        final netQty = change['qty'] as int;
        if (netQty == 0) continue; // cost-only change — skip stock update

        final pid = int.tryParse(change['productId'].toString()) ?? 0;
        final loc = change['location'] as String;
        stockFutures.add(
          _stockCtrl.addMixedStock(
            productId: pid,
            localQty: loc == 'Local' ? netQty : 0,
            airQty: loc == 'Air' ? netQty : 0,
            seaQty: loc == 'Sea' ? netQty : 0,
            localUnitPrice: (change['cost'] as num).toDouble(),
          ),
        );
      }
      if (stockFutures.isNotEmpty) await Future.wait(stockFutures);

      if (Get.isDialogOpen ?? false) Get.back();
      await fetchRecords();
      Get.snackbar(
        'Invoice Updated',
        'Purchase invoice was updated successfully.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Update Failed',
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── PDF — Bulk Report ─────────────────────────────────────────────────────────

  Future<void> downloadBulkPdf() async {
    isPdfLoading.value = true;
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      Query query =
          (selectedDebtorId.value?.isNotEmpty == true)
              ? _db
                  .collection('debatorbody')
                  .doc(selectedDebtorId.value)
                  .collection('purchases')
              : _db.collectionGroup('purchases');

      final snap =
          await query
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  dateRange.value.start,
                ),
              )
              .where(
                'date',
                isLessThanOrEqualTo: Timestamp.fromDate(dateRange.value.end),
              )
              .orderBy('date', descending: true)
              .limit(500)
              .get();

      double grandTotal = 0;
      final rows = <List<String>>[];

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final debtorId = doc.reference.parent.parent?.id ?? '';
        final name = debtorNameCache[debtorId] ?? 'Debtor #${debtorId.substring(0, 6)}';
        final date =
            (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final type = (data['type'] ?? '').toString().toUpperCase();
        final amount =
            double.tryParse(
              (data['totalAmount'] ?? data['amount']).toString(),
            ) ??
            0.0;

        if (type == 'INVOICE') grandTotal += amount;

        rows.add([
          DateFormat('dd-MMM-yy').format(date),
          name,
          type,
          '৳${amount.toStringAsFixed(2)}',
        ]);
      }

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build:
              (ctx) => [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Master Purchase Report',
                      style: pw.TextStyle(font: bold, fontSize: 18),
                    ),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(dateRange.value.start)} — ${DateFormat('dd MMM yyyy').format(dateRange.value.end)}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['Date', 'Supplier', 'Type', 'Amount'],
                  data: rows,
                  headerStyle: pw.TextStyle(
                    font: bold,
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignments: {3: pw.Alignment.centerRight},
                ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total Invoiced: ৳${grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                ),
              ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      Get.snackbar('PDF Error', e.toString());
    } finally {
      isPdfLoading.value = false;
    }
  }

  // ── PDF — Single Invoice ──────────────────────────────────────────────────────

  Future<void> generateSingleInvoicePdf(PurchaseRecord record) async {
    isSinglePdfLoading.value = true;
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      final supplierName =
          debtorNameCache[record.debtorId] ?? 'Unknown Supplier';
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PURCHASE INVOICE',
                    style: pw.TextStyle(font: bold, fontSize: 20),
                  ),
                  pw.Text(
                    'GTEL ERP',
                    style: pw.TextStyle(font: bold, fontSize: 14),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Supplier:', style: pw.TextStyle(font: bold)),
                      pw.Text(supplierName, style: pw.TextStyle(font: font)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: ${DateFormat('dd-MMM-yyyy').format(record.date)}',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Inv ID: ${record.id.substring(0, 6).toUpperCase()}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Table.fromTextArray(
                headers: ['Item', 'Model', 'Loc', 'Qty', 'Cost', 'Total'],
                data:
                    record.items
                        .map(
                          (e) => [
                            e['name'] ?? '',
                            e['model'] ?? '-',
                            e['location'] ?? '-',
                            e['qty'].toString(),
                            '৳${e['cost']}',
                            '৳${e['subtotal']}',
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(
                  font: bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Grand Total: ৳${record.amount.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (e) {
      Get.snackbar('PDF Error', e.toString());
    } finally {
      isSinglePdfLoading.value = false;
    }
  }
}