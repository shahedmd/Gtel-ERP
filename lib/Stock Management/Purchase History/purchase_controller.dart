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

class PurchaseRecord {
  final String id;
  final String debtorId;
  final DateTime date;
  final String type;
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
    final data = doc.data() as Map<String, dynamic>;
    final rawDate = data['date'];

    return PurchaseRecord(
      id: doc.id,
      debtorId: resolvedDebtorId,
      date:
          rawDate is Timestamp
              ? rawDate.toDate()
              : (rawDate is DateTime ? rawDate : DateTime.now()),
      type: (data['type'] ?? 'unknown').toString().toLowerCase(),
      amount: _toDouble(data['totalAmount'] ?? data['amount']),
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      note: data['note']?.toString(),
      method: data['method']?.toString(),
    );
  }

  Map<String, dynamic> toEditMap() {
    return {
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
}

class _PaginationState {
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
  set lastDoc(DocumentSnapshot? value) => _lastDoc = value;
}

class GlobalPurchaseHistoryController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ProductController get _stockCtrl => Get.find<ProductController>();

  DailyExpensesController get _expenseCtrl {
    return Get.isRegistered<DailyExpensesController>()
        ? Get.find<DailyExpensesController>()
        : Get.put(DailyExpensesController());
  }

  final records = <PurchaseRecord>[].obs;
  final debtorNameCache = <String, String>{}.obs;
  final searchedSuppliers = <Map<String, dynamic>>[].obs;

  final isLoading = false.obs;
  final isPdfLoading = false.obs;
  final isSinglePdfLoading = false.obs;
  final isSearchingSupplier = false.obs;

  final activeFilter = HistoryFilter.monthly.obs;
  final selectedDebtorId = Rx<String?>(null);
  final selectedSupplierName = ''.obs;

  final dateRange =
      DateTimeRange(
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

  final totalInvoiced = 0.0.obs;
  final totalPayments = 0.0.obs;

  final hasMore = true.obs;
  final isFirstPage = true.obs;

  static const int _pageSize = 20;
  final _pagination = _PaginationState();

  Timer? _searchDebounce;
  int _fetchVersion = 0;

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

        if (terms.every((term) => combined.contains(term))) {
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

  Future<void> setSupplierFilter(
    String? debtorId, {
    String supplierName = '',
  }) async {
    _searchDebounce?.cancel();

    final cleanId = debtorId?.trim() ?? '';

    selectedDebtorId.value = cleanId.isEmpty ? null : cleanId;
    selectedSupplierName.value = cleanId.isEmpty ? '' : supplierName.trim();

    searchedSuppliers.clear();
    records.clear();
    _updateTotals([]);

    _pagination.reset();
    isFirstPage.value = true;
    hasMore.value = true;

    await fetchRecords();
  }

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
        break;

      case HistoryFilter.monthly:
        dateRange.value = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;

      case HistoryFilter.yearly:
        dateRange.value = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;

      case HistoryFilter.custom:
        final picked = await showDateRangePicker(
          context: Get.context!,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );

        if (picked == null) return;

        dateRange.value = DateTimeRange(
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
        break;
    }

    _resetAndFetch();
  }

  void _resetAndFetch() {
    _pagination.reset();
    isFirstPage.value = true;
    hasMore.value = true;
    records.clear();
    _updateTotals([]);
    fetchRecords();
  }

  Future<void> fetchRecords({bool goNext = false, bool goPrev = false}) async {
    final requestVersion = ++_fetchVersion;

    isLoading.value = true;

    try {
      final selectedId = selectedDebtorId.value?.trim();

      Query baseQuery =
          selectedId != null && selectedId.isNotEmpty
              ? _db
                  .collection('debatorbody')
                  .doc(selectedId)
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

      if (goNext && _pagination.lastDoc != null) {
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
        baseQuery = baseQuery.limit(_pageSize);
      }

      final snap = await baseQuery.get();

      if (requestVersion != _fetchVersion) return;

      if (snap.docs.isEmpty) {
        hasMore.value = false;
        records.clear();
        _updateTotals([]);
        return;
      }

      _pagination.lastDoc = snap.docs.last;

      if (goNext) {
        _pagination.pushForward(snap.docs.first);
      }

      hasMore.value = snap.docs.length == _pageSize;

      final futures = <Future>[];
      final seen = <String>{};

      for (final doc in snap.docs) {
        final debtorId =
            selectedId != null && selectedId.isNotEmpty
                ? selectedId
                : doc.reference.parent.parent?.id ?? 'unknown';

        if (!debtorNameCache.containsKey(debtorId) && seen.add(debtorId)) {
          futures.add(_resolveDebtorName(debtorId));
        }
      }

      await Future.wait(futures);

      if (requestVersion != _fetchVersion) return;

      final parsed =
          snap.docs.map((doc) {
            final debtorId =
                selectedId != null && selectedId.isNotEmpty
                    ? selectedId
                    : doc.reference.parent.parent?.id ?? 'unknown';

            return PurchaseRecord.fromFirestore(doc, debtorId);
          }).toList();

      records.value = parsed;
      _updateTotals(parsed);
    } catch (e) {
      if (requestVersion != _fetchVersion) return;

      records.clear();
      _updateTotals([]);

      print('[PurchaseHistory] Fetch error: $e');

      Get.snackbar(
        'Load Error',
        'Failed to load records. Please try again.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      if (requestVersion == _fetchVersion) {
        isLoading.value = false;
      }
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
          doc.exists ? (doc['name'] ?? 'Unnamed Supplier') : 'Deleted Supplier';
    } catch (_) {
      debtorNameCache[id] = 'Unknown';
    }
  }

  void _updateTotals(List<PurchaseRecord> list) {
    double invoiced = 0;
    double paid = 0;

    for (final record in list) {
      if (record.type == 'invoice') {
        invoiced += record.amount;
      } else if (record.type == 'payment') {
        paid += record.amount;
      }
    }

    totalInvoiced.value = invoiced;
    totalPayments.value = paid;
  }

  void nextPage() => fetchRecords(goNext: true);
  void prevPage() => fetchRecords(goPrev: true);

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

      final histRef =
          _db
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

      _expenseCtrl
          .addDailyExpense(
            'Payment to $debtorName',
            amount,
            note: 'Supplier payment. Method: $method. ${note ?? ''}',
            date: customDate ?? DateTime.now(),
          )
          .catchError(
            (e) => print('[PurchaseHistory] Expense auto-add failed: $e'),
          );

      if (Get.isDialogOpen ?? false) Get.back();

      await fetchRecords();

      Get.snackbar(
        'Payment Recorded',
        '${_money(amount)} paid to $debtorName.',
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

      final diff = newTotal - oldTotal;

      if (diff != 0) {
        final debtorRef = _db.collection('debatorbody').doc(debtorId);
        batch.update(debtorRef, {'purchaseDue': FieldValue.increment(diff)});
      }

      await batch.commit();

      await _syncStockDelta(oldItems: oldItems, newItems: newItems);

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

  Future<void> _syncStockDelta({
    required List<Map<String, dynamic>> oldItems,
    required List<Map<String, dynamic>> newItems,
  }) async {
    final changes = <String, Map<String, dynamic>>{};

    void applyItem(Map<String, dynamic> item, int sign) {
      final productId = _toInt(item['productId']);
      final stockType = _stockTypeOf(item);
      final warehouseId = _toInt(item['warehouseId']);
      final warehouseLocation = _warehouseLocationOf(item);
      final key = '$productId|$stockType|$warehouseId|$warehouseLocation';

      changes.putIfAbsent(
        key,
        () => {
          'productId': productId,
          'stockType': stockType,
          'warehouseId': warehouseId,
          'warehouseLocation': warehouseLocation,
          'qty': 0,
          'cost': _toDouble(item['cost']),
        },
      );

      changes[key]!['qty'] =
          _toInt(changes[key]!['qty']) + (sign * _toInt(item['qty']));

      if (sign > 0) {
        changes[key]!['cost'] = _toDouble(item['cost']);
      }
    }

    for (final item in oldItems) {
      applyItem(item, -1);
    }

    for (final item in newItems) {
      applyItem(item, 1);
    }

    final futures = <Future>[];

    for (final change in changes.values) {
      final netQty = _toInt(change['qty']);
      if (netQty == 0) continue;

      final productId = _toInt(change['productId']);
      final stockType = change['stockType'].toString();
      final warehouseId = _toInt(change['warehouseId']);
      final warehouseLocation = change['warehouseLocation'].toString();
      final cost = _toDouble(change['cost']);

      if (netQty > 0) {
        futures.add(
          _stockCtrl.addMixedStock(
            productId: productId,
            localQty: stockType == 'Local' ? netQty : 0,
            airQty: stockType == 'Air' ? netQty : 0,
            seaQty: stockType == 'Sea' ? netQty : 0,
            localUnitPrice: cost,
            warehouseId: warehouseId > 0 ? warehouseId : null,
            warehouseLocation: warehouseLocation,
          ),
        );
      } else {
        futures.add(
          _stockCtrl.updateStockBulk([
            {
              'id': productId,
              'qty': netQty.abs(),
              if (warehouseId > 0) 'warehouse_id': warehouseId,
            },
          ]),
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> downloadBulkPdf() async {
    isPdfLoading.value = true;

    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      Query query =
          selectedDebtorId.value?.isNotEmpty == true
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
        final debtorId =
            selectedDebtorId.value ?? doc.reference.parent.parent?.id ?? '';
        final name =
            debtorNameCache[debtorId] ??
            (debtorId.length >= 6
                ? 'Supplier #${debtorId.substring(0, 6)}'
                : 'Supplier');
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final type = (data['type'] ?? '').toString().toUpperCase();
        final amount = _toDouble(data['totalAmount'] ?? data['amount']);

        if (type == 'INVOICE') grandTotal += amount;

        rows.add([
          DateFormat('dd-MMM-yy').format(date),
          name,
          type,
          _money(amount),
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
                      'Period: ${DateFormat('dd MMM yyyy').format(dateRange.value.start)} - ${DateFormat('dd MMM yyyy').format(dateRange.value.end)}',
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
                    'Total Invoiced: ${_money(grandTotal)}',
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

  Future<void> generateSingleInvoicePdf(PurchaseRecord record) async {
    isSinglePdfLoading.value = true;

    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      final supplierName =
          debtorNameCache[record.debtorId] ?? selectedSupplierName.value;
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build:
              (ctx) => pw.Column(
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
                          pw.Text(
                            supplierName.isEmpty
                                ? 'Unknown Supplier'
                                : supplierName,
                            style: pw.TextStyle(font: font),
                          ),
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
                    headers: [
                      'Item',
                      'Model',
                      'Type',
                      'Warehouse',
                      'Location',
                      'Qty',
                      'Cost',
                      'Total',
                    ],
                    data:
                        record.items.map((item) {
                          return [
                            item['name'] ?? '',
                            item['model'] ?? '-',
                            _stockTypeOf(item),
                            _warehouseNameOf(item),
                            _warehouseLocationOf(item),
                            item['qty'].toString(),
                            _money(item['cost']),
                            _money(item['subtotal']),
                          ];
                        }).toList(),
                    headerStyle: pw.TextStyle(
                      font: bold,
                      color: PdfColors.white,
                      fontSize: 8,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                    ),
                    cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Grand Total: ${_money(record.amount)}',
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

  static String stockTypeOf(Map<String, dynamic> item) => _stockTypeOf(item);
  static String warehouseNameOf(Map<String, dynamic> item) =>
      _warehouseNameOf(item);
  static String warehouseLocationOf(Map<String, dynamic> item) =>
      _warehouseLocationOf(item);
  static String money(dynamic value) => _money(value);
}

String _stockTypeOf(Map<String, dynamic> item) {
  final value = item['stockType'] ?? item['location'] ?? 'Local';
  final text = value.toString().trim();
  return text.isEmpty ? 'Local' : text;
}

String _warehouseNameOf(Map<String, dynamic> item) {
  final value = item['warehouseName'];
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '-' : text;
}

String _warehouseLocationOf(Map<String, dynamic> item) {
  final value = item['warehouseLocation'];
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '-' : text;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _money(dynamic value) {
  return 'Tk ${_toDouble(value).toStringAsFixed(2)}';
}