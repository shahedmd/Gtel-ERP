import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';
import 'package:gtel_erp/Cash/controller.dart';
import '../../Web Screen/Sales/controller.dart';
import 'debtordartmodel.dart';
import 'paid_invoice_running_due.dart';
import 'regular_customer_collection_plan.dart';
import 'regular_customer_discount_plan.dart';

class DebatorController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final RxList<DebtorModel> bodies = <DebtorModel>[].obs;
  final RxList<DebtorModel> filteredBodies = <DebtorModel>[].obs;

  final RxList<DebtorModel> regularCustomerDues = <DebtorModel>[].obs;

  // Loading States
  final RxBool isBodiesLoading = false.obs;
  final RxBool isSearching = false.obs;
  final RxBool gbIsLoading = false.obs;
  final RxBool isAddingBody = false.obs;
  final RxBool isMoreLoading = false.obs;

  // Debtor Pagination
  final int _limit = 30;
  List<DocumentSnapshot?> pageCursors = [null];
  final RxInt currentPage = 1.obs;
  final RxBool hasMore = true.obs;
  DocumentSnapshot? _lastDocument;

  // Market Totals
  final RxDouble totalMarketOutstanding = 0.0.obs;
  final RxDouble totalMarketPayable = 0.0.obs;

  // Transaction States
  final RxList<TransactionModel> currentTransactions = <TransactionModel>[].obs;
  final RxBool isTxLoading = false.obs;
  final RxBool hasMoreTx = true.obs;
  final int _txLimit = 20;
  List<DocumentSnapshot?> txPageCursors = [null];
  final RxInt currentTxPage = 1.obs;
  final Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);

  Timer? _searchDebounce;

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  Future<Set<String>> _getConditionCourierInvoiceIds(
    Iterable<Map<String, dynamic>> sales,
  ) async {
    final invoiceIds = <String>{};
    for (final sale in sales) {
      final id = (sale['_docId'] ?? '').toString().trim();
      if (id.isNotEmpty) invoiceIds.add(id);
      for (final key in ['transactionId', 'invoiceId']) {
        final value = (sale[key] ?? '').toString().trim();
        if (value.isNotEmpty) invoiceIds.add(value);
      }
    }

    final conditionInvoiceIds = <String>{};
    final ids = invoiceIds.toList();
    for (var start = 0; start < ids.length; start += 30) {
      final end = start + 30 < ids.length ? start + 30 : ids.length;
      final chunk = ids.sublist(start, end);
      final ordersByDocumentId =
          await db
              .collection('sales_orders')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      final ordersByInvoiceId =
          await db
              .collection('sales_orders')
              .where('invoiceId', whereIn: chunk)
              .get();
      final orders = {
        for (final order in ordersByDocumentId.docs) order.id: order,
        for (final order in ordersByInvoiceId.docs) order.id: order,
      };

      for (final order in orders.values) {
        final data = order.data();
        final saleMode = (data['saleMode'] ?? '').toString().toLowerCase();
        final isLegacyCondition =
            saleMode.isEmpty && data['isCondition'] == true;
        if (saleMode == 'condition' || isLegacyCondition) {
          conditionInvoiceIds.add(order.id);
          final invoiceId = (data['invoiceId'] ?? '').toString().trim();
          if (invoiceId.isNotEmpty) conditionInvoiceIds.add(invoiceId);
        }
      }
    }
    return conditionInvoiceIds;
  }

  bool _isConditionCourierInvoice(
    Map<String, dynamic> sale,
    Set<String> conditionInvoiceIds,
  ) {
    final saleMode = (sale['saleMode'] ?? '').toString().toLowerCase();
    final source = (sale['source'] ?? '').toString().toLowerCase();
    if (source == 'pos_condition_sale' ||
        saleMode == 'condition' ||
        (sale['isCondition'] == true && saleMode != 'non_condition')) {
      return true;
    }
    if (conditionInvoiceIds.contains((sale['_docId'] ?? '').toString())) {
      return true;
    }
    return conditionInvoiceIds.contains(
          (sale['transactionId'] ?? '').toString(),
        ) ||
        conditionInvoiceIds.contains((sale['invoiceId'] ?? '').toString());
  }

  @override
  @override
  void onInit() {
    super.onInit();
    _silentAutoRepair();
    loadPage(1);
    calculateTotalOutstanding();
    _fetchRegularCustomerDues();
  }

  // ==========================================
  // 2. SEARCH & PAGINATION
  // ==========================================
  void nextPage() {
    if (isSearching.value || !hasMore.value) return;
    loadPage(currentPage.value + 1);
  }

  void prevPage() {
    if (isSearching.value || currentPage.value <= 1) return;
    loadPage(currentPage.value - 1);
  }

  void searchDebtors(String queryText) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (queryText.trim().isEmpty) {
      isSearching.value = false;
      _applyMergedList();
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _performGlobalSearch(queryText),
    );
  }

  Future<bool> _fetchRegularCustomerDues() async {
    try {
      final snap =
          await db
              .collection('daily_sales')
              .where('pending', isGreaterThan: 0.5)
              .get();
      final candidateSales =
          snap.docs
              .where((doc) {
                final type =
                    (doc.data()['customerType'] ?? '').toString().toUpperCase();
                return type == 'WHOLESALE' || type == 'VIP';
              })
              .map((doc) => {'_docId': doc.id, ...doc.data()})
              .toList();
      final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
        candidateSales,
      );
      final advanceSnapshot =
          await db
              .collection('customers')
              .where('advanceBalance', isGreaterThan: 0.5)
              .get();

      final Map<String, DebtorModel> grouped = {};

      for (var doc in snap.docs) {
        final data = doc.data();
        final type = (data['customerType'] ?? '').toString().toUpperCase();

        if (type != 'WHOLESALE' && type != 'VIP') continue;
        if (_isConditionCourierInvoice({
          '_docId': doc.id,
          ...data,
        }, conditionInvoiceIds)) {
          continue;
        }

        final name = (data['name'] ?? '').toString().trim();
        final phone = (data['customerPhone'] ?? '').toString().trim();
        final pending = effectiveRegularCustomerPending(data);

        if (name.isEmpty || pending <= 0.5) continue;

        final key = phone.isNotEmpty ? phone : '$type-$name';
        final existing = grouped[key];

        grouped[key] = DebtorModel(
          id: phone.isNotEmpty ? phone : key,
          name: name,
          des: existing?.des ?? (data['shop'] ?? '').toString().trim(),
          nid: '',
          phone: phone,
          address:
              existing?.address ??
              (data['address'] ?? data['deliveryAddress'] ?? '')
                  .toString()
                  .trim(),
          payments: const [],
          balance: (existing?.balance ?? 0.0) + pending,
          purchaseDue: 0.0,
          lastTransactionDate:
              data['timestamp'] is Timestamp
                  ? (data['timestamp'] as Timestamp).toDate()
                  : existing?.lastTransactionDate,
          sourceType: DebtorSourceType.regular,
          customerCategory: type,
        );
      }

      final regularDues = await Future.wait(
        grouped.values.map((due) async {
          var phone = due.phone;
          var shop = due.des;
          var address = due.address;
          var balance = due.balance;

          if (address.isEmpty || phone.isEmpty) {
            Query<Map<String, dynamic>> orderQuery = db.collection(
              'sales_orders',
            );
            orderQuery =
                phone.isNotEmpty
                    ? orderQuery.where('customerPhone', isEqualTo: phone)
                    : orderQuery.where('customerName', isEqualTo: due.name);
            final orderSnap =
                await orderQuery
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get();
            if (orderSnap.docs.isNotEmpty) {
              final order = orderSnap.docs.first.data();
              address =
                  (order['deliveryAddress'] ?? order['address'] ?? '')
                      .toString()
                      .trim();
              phone = (order['customerPhone'] ?? phone).toString().trim();
              shop = (order['shopName'] ?? shop).toString().trim();
            }
          }

          if (phone.isNotEmpty) {
            final customerDoc =
                await db.collection('customers').doc(phone).get();
            final customerData = customerDoc.data() ?? <String, dynamic>{};
            phone = (customerData['phone'] ?? phone).toString().trim();
            shop = (customerData['shop'] ?? shop).toString().trim();
            final profileAddress =
                (customerData['address'] ?? '').toString().trim();
            if (profileAddress.isNotEmpty) address = profileAddress;
            final advanceBalance =
                (customerData['advanceBalance'] as num?)?.toDouble() ?? 0.0;
            balance -= advanceBalance;
          }

          return due.copyWith(
            phone: phone,
            des: shop,
            address: address,
            balance: balance,
          );
        }),
      );

      final regularCustomerPhones =
          regularDues
              .map((due) => due.phone)
              .where((phone) => phone.isNotEmpty)
              .toSet();
      for (final doc in advanceSnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toUpperCase();
        if (type != 'WHOLESALE' && type != 'VIP') continue;

        final phone = (data['phone'] ?? doc.id).toString().trim();
        if (phone.isEmpty || regularCustomerPhones.contains(phone)) continue;

        final advanceBalance =
            (data['advanceBalance'] as num?)?.toDouble() ?? 0.0;
        if (advanceBalance <= 0.5) continue;

        regularDues.add(
          DebtorModel(
            id: doc.id,
            name: (data['name'] ?? phone).toString().trim(),
            des: (data['shop'] ?? '').toString().trim(),
            nid: '',
            phone: phone,
            address: (data['address'] ?? '').toString().trim(),
            payments: const [],
            balance: -advanceBalance,
            purchaseDue: 0.0,
            lastTransactionDate:
                data['lastShopDate'] is Timestamp
                    ? (data['lastShopDate'] as Timestamp).toDate()
                    : null,
            sourceType: DebtorSourceType.regular,
            customerCategory: type,
          ),
        );
      }

      regularCustomerDues.value =
          regularDues..sort((a, b) => b.balance.compareTo(a.balance));

      _applyMergedList();
      return true;
    } catch (e) {
      AppLogger.i("Error fetching pending regular customer dues: $e");
      return false;
    }
  }

  void _applyMergedList() {
    if (isSearching.value) return;

    if (currentPage.value == 1) {
      filteredBodies.assignAll([...regularCustomerDues, ...bodies]);
    } else {
      filteredBodies.assignAll(bodies);
    }
  }

  // Call this after collecting a regular customer's due payment
  // (used by the payment-collection step we'll add later).
  Future<void> refreshRegularCustomerDues() async {
    await _fetchRegularCustomerDues();
    await calculateTotalOutstanding();
  }

  static List<Map<String, dynamic>> buildRegularCustomerLedgerRows({
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> advanceHistory,
  }) {
    final events = <Map<String, dynamic>>[];
    final receiptEvents = <String, Map<String, dynamic>>{};
    var sequence = 0;

    DateTime dateFrom(dynamic value, DateTime fallback) =>
        value is Timestamp ? value.toDate() : fallback;

    for (final invoice in invoices) {
      final invoiceId =
          (invoice['invoiceId'] ?? invoice['transactionId'] ?? '').toString();
      final invoiceDate = dateFrom(invoice['timestamp'], DateTime.now());
      final invoiceAmount = (invoice['amount'] as num?)?.toDouble() ?? 0.0;
      final paymentHistory =
          (invoice['paymentHistory'] as List<dynamic>? ?? []);
      final initialPayments = <Map<String, dynamic>>[];
      var advanceApplied = 0.0;

      for (var index = 0; index < paymentHistory.length; index++) {
        final item = paymentHistory[index];
        if (item is! Map) continue;
        final payment = Map<String, dynamic>.from(item);
        final mode = (payment['collectionMode'] ?? '').toString();
        final paymentAmount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        if (paymentAmount <= 0.01) continue;
        if (mode == 'advance_credit') {
          advanceApplied += paymentAmount;
          continue;
        }

        final paymentDate = dateFrom(payment['timestamp'], invoiceDate);
        if (mode.isEmpty) {
          initialPayments.add(payment);
          continue;
        }

        final sourceTxId = (payment['sourceTxId'] ?? '').toString();
        if (mode == 'sale_return_refund') {
          events.add({
            'id':
                'refund-${sourceTxId.isEmpty ? invoiceId : sourceTxId}-$index',
            'date': paymentDate,
            'label': 'REFUND',
            'note': (payment['note'] ?? 'Invoice return refund').toString(),
            'debit': paymentAmount,
            'credit': 0.0,
            'paymentMethod': {'type': 'refund'},
            '_priority': 1,
            '_sequence': sequence++,
          });
          continue;
        }

        if (mode == 'discount') {
          events.add({
            'id':
                'discount-${sourceTxId.isEmpty ? invoiceId : sourceTxId}-$index',
            'date': paymentDate,
            'label': 'DISCOUNT',
            'note':
                invoiceId.isEmpty ? 'Invoice discount' : 'Invoice $invoiceId',
            'debit': 0.0,
            'credit': paymentAmount,
            'paymentMethod': {'type': 'discount'},
            '_priority': 1,
            '_sequence': sequence++,
          });
          continue;
        }

        final groupKey =
            sourceTxId.isEmpty
                ? 'legacy-${invoice['docId'] ?? invoiceId}-$index'
                : sourceTxId;
        final event = receiptEvents.putIfAbsent(groupKey, () {
          final created = <String, dynamic>{
            'id': 'receipt-$groupKey',
            'date': paymentDate,
            'label': 'PAYMENT',
            'note': '',
            'debit': 0.0,
            'credit': 0.0,
            'paymentMethod': <String, dynamic>{'type': ''},
            '_sourceTxId': sourceTxId,
            '_advanceAmount': 0.0,
            '_allocations': <String, double>{},
            '_methods': <String>{},
            '_priority': 1,
            '_sequence': sequence++,
          };
          events.add(created);
          return created;
        });
        event['credit'] = (event['credit'] as double) + paymentAmount;
        final allocations = event['_allocations'] as Map<String, double>;
        final allocatedInvoiceId =
            (payment['invoiceId'] ?? invoiceId).toString();
        if (allocatedInvoiceId.isNotEmpty) {
          allocations[allocatedInvoiceId] =
              (allocations[allocatedInvoiceId] ?? 0.0) + paymentAmount;
        }
        final methods = event['_methods'] as Set<String>;
        methods.add((payment['type'] ?? 'cash').toString());
        if (paymentDate.isBefore(event['date'] as DateTime)) {
          event['date'] = paymentDate;
        }
      }

      final initialCredit = initialPayments.fold<double>(
        0.0,
        (total, payment) =>
            total + ((payment['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final initialMethods =
          initialPayments
              .map((payment) => (payment['type'] ?? 'cash').toString())
              .toSet();
      events.add({
        'id': 'invoice-${invoice['docId'] ?? invoiceId}',
        'date': invoiceDate,
        'label': 'INVOICE',
        'advanceApplied': advanceApplied,
        'note': [
          invoiceId.isEmpty ? 'Invoice' : invoiceId,
          if (advanceApplied > 0.01)
            'Advance used ৳${advanceApplied.toStringAsFixed(0)}',
        ].join(' • '),
        'debit': invoiceAmount,
        'credit': initialCredit,
        'paymentMethod': {
          'type':
              initialMethods.isEmpty ? 'invoice' : initialMethods.join(', '),
        },
        '_priority': 0,
        '_sequence': sequence++,
      });
    }

    for (final advance in advanceHistory) {
      final amount = (advance['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0.01) continue;
      final sourceTxId = (advance['sourceTxId'] ?? '').toString();
      final receipt = receiptEvents[sourceTxId];
      if (sourceTxId.isNotEmpty && receipt != null) {
        receipt['credit'] = (receipt['credit'] as double) + amount;
        receipt['_advanceAmount'] =
            (receipt['_advanceAmount'] as double) + amount;
        final date = dateFrom(
          advance['timestamp'],
          receipt['date'] as DateTime,
        );
        if (date.isBefore(receipt['date'] as DateTime)) {
          receipt['date'] = date;
        }
        final methods = receipt['_methods'] as Set<String>;
        methods.add((advance['type'] ?? 'cash').toString());
        continue;
      }

      final advanceDate = dateFrom(advance['timestamp'], DateTime.now());
      events.add({
        'id': 'advance-$sourceTxId-${advanceDate.millisecondsSinceEpoch}',
        'date': advanceDate,
        'label': 'PAYMENT',
        'note':
            sourceTxId.isEmpty
                ? 'Advance deposit'
                : 'Advance deposit • Ref: $sourceTxId',
        'debit': 0.0,
        'credit': amount,
        'paymentMethod': {'type': (advance['type'] ?? 'cash').toString()},
        '_priority': 1,
        '_sequence': sequence++,
      });
    }

    for (final event in receiptEvents.values) {
      final sourceTxId = (event['_sourceTxId'] ?? '').toString();
      final allocations = event['_allocations'] as Map<String, double>;
      final details = <String>[
        if (allocations.isNotEmpty)
          allocations.entries
              .map((entry) => '${entry.key} ৳${entry.value.toStringAsFixed(0)}')
              .join(', '),
        if ((event['_advanceAmount'] as double) > 0.01)
          'Extra advance ৳${(event['_advanceAmount'] as double).toStringAsFixed(0)}',
      ];
      event['note'] =
          details.isEmpty
              ? (sourceTxId.isEmpty ? 'Payment received' : 'Ref: $sourceTxId')
              : details.join(' • ');
      final methods = event['_methods'] as Set<String>;
      (event['paymentMethod'] as Map<String, dynamic>)['type'] =
          methods.isEmpty ? 'cash' : methods.join(', ');
    }

    events.sort((a, b) {
      final dateCompare = (a['date'] as DateTime).compareTo(
        b['date'] as DateTime,
      );
      if (dateCompare != 0) return dateCompare;
      final priorityCompare = (a['_priority'] as int).compareTo(
        b['_priority'] as int,
      );
      if (priorityCompare != 0) return priorityCompare;
      return (a['_sequence'] as int).compareTo(b['_sequence'] as int);
    });

    var balance = 0.0;
    for (final event in events) {
      balance += (event['debit'] as num).toDouble();
      balance -= (event['credit'] as num).toDouble();
      event['due'] = balance;
      event.remove('_priority');
      event.remove('_sequence');
      event.remove('_sourceTxId');
      event.remove('_advanceAmount');
      event.remove('_allocations');
      event.remove('_methods');
    }
    return events;
  }

  static double effectiveRegularCustomerPending(Map<String, dynamic> data) {
    final pending = (data['pending'] as num?)?.toDouble() ?? 0.0;
    final amount = data['amount'];
    final paid = data['paid'];
    if (amount is! num || paid is! num) {
      return pending > 0 ? pending : 0.0;
    }

    final calculatedPending = amount.toDouble() - paid.toDouble();
    if (calculatedPending <= 0.0) return 0.0;
    return pending < calculatedPending ? pending : calculatedPending;
  }

  static List<Map<String, dynamic>> buildRegularCustomerDueLedgerRows({
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> advanceHistory,
  }) {
    final dueInvoices =
        invoices.where((invoice) {
          final pending = effectiveRegularCustomerPending(invoice);
          return pending > 0.5;
        }).toList();
    if (dueInvoices.isEmpty) return [];

    final dueInvoiceRowIds = <String>{};
    DateTime? oldestDueInvoiceDate;
    for (final invoice in dueInvoices) {
      final invoiceId =
          (invoice['invoiceId'] ?? invoice['transactionId'] ?? '').toString();
      dueInvoiceRowIds.add('invoice-${invoice['docId'] ?? invoiceId}');
      final timestamp = invoice['timestamp'];
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        if (oldestDueInvoiceDate == null ||
            date.isBefore(oldestDueInvoiceDate)) {
          oldestDueInvoiceDate = date;
        }
      }
    }

    final allRows = buildRegularCustomerLedgerRows(
      invoices: invoices,
      advanceHistory: advanceHistory,
    );
    final rows = <Map<String, dynamic>>[];
    var balance = 0.0;

    for (final row in allRows) {
      final label = (row['label'] ?? '').toString();
      final credit = (row['credit'] as num?)?.toDouble() ?? 0.0;
      final rowDate = row['date'] as DateTime;

      if (label == 'INVOICE') {
        if (!dueInvoiceRowIds.contains(row['id'])) continue;
        final advanceApplied =
            (row['advanceApplied'] as num?)?.toDouble() ?? 0.0;
        final shownCredit = credit + advanceApplied;
        balance += (row['debit'] as num).toDouble() - shownCredit;
        rows.add({...row, 'credit': shownCredit, 'due': balance});
        continue;
      }

      if (label != 'PAYMENT' ||
          (oldestDueInvoiceDate != null &&
              rowDate.isBefore(oldestDueInvoiceDate))) {
        continue;
      }

      balance -= credit;
      rows.add({...row, 'note': 'Payment received', 'due': balance});
    }

    return rows;
  }

  Future<void> downloadRegularCustomerStatement(
    String customerId,
    String customerName, {
    String? customerCategory,
  }) async {
    gbIsLoading.value = true;
    try {
      final invoices = await getRegularCustomerInvoices(
        customerName: customerName,
        customerCategory: customerCategory,
        customerPhone: customerId,
      );

      final advanceHistory = await getRegularCustomerAdvanceHistory(
        customerId,
        customerName: customerName,
      );
      if (invoices.isEmpty && advanceHistory.isEmpty) {
        Get.snackbar(
          'Info',
          'No invoice data found for this customer statement.',
        );
        return;
      }

      final pdf = pw.Document();
      final fontReg = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      final ledgerRows = DebatorController.buildRegularCustomerLedgerRows(
        invoices: invoices,
        advanceHistory: advanceHistory,
      );
      final totalDebit = ledgerRows.fold<double>(
        0.0,
        (total, row) => total + (row['debit'] as num).toDouble(),
      );
      final totalCredit = ledgerRows.fold<double>(
        0.0,
        (total, row) => total + (row['credit'] as num).toDouble(),
      );
      final netDue =
          ledgerRows.isEmpty ? 0.0 : (ledgerRows.last['due'] as num).toDouble();
      final rows =
          ledgerRows.map((row) {
            final date = row['date'] as DateTime;
            final paymentMethod =
                row['paymentMethod'] as Map<String, dynamic>? ?? {};
            final description = (row['note'] ?? '').toString();
            return [
              DateFormat('dd/MM/yyyy').format(date),
              '${row['label']}\n$description',
              (paymentMethod['type'] ?? '-').toString().toUpperCase(),
              (row['debit'] as num).toDouble() > 0.01
                  ? bdCurrency.format((row['debit'] as num).toDouble())
                  : '-',
              (row['credit'] as num).toDouble() > 0.01
                  ? bdCurrency.format((row['credit'] as num).toDouble())
                  : '-',
              bdCurrency.format((row['due'] as num).toDouble()),
            ];
          }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header:
              (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'STATEMENT OF ACCOUNT',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                            style: pw.TextStyle(font: fontReg, fontSize: 10),
                          ),
                          pw.Text(
                            'Page ${context.pageNumber} of ${context.pagesCount}',
                            style: pw.TextStyle(font: fontReg, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Account Name: $customerName',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Text(
                    'Category: ${customerCategory ?? 'WHOLESALE'}',
                    style: pw.TextStyle(font: fontReg, fontSize: 10),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColors.grey400),
                ],
              ),
          build:
              (context) => [
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Date',
                    'Description',
                    'Payment Method',
                    'Debit',
                    'Credit',
                    'Balance',
                  ],
                  data: rows,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue800,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                  },
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue400),
                    color: PdfColors.blue50,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfStat(
                        'Total Debit',
                        totalDebit,
                        PdfColors.red900,
                        fontReg,
                        fontBold,
                      ),
                      _pdfStat(
                        'Total Credit',
                        totalCredit,
                        PdfColors.green900,
                        fontReg,
                        fontBold,
                      ),
                      _pdfStat(
                        'Due Balance',
                        netDue,
                        PdfColors.blue900,
                        fontReg,
                        fontBold,
                      ),
                    ],
                  ),
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: '${customerName.replaceAll(' ', '_')}_Statement.pdf',
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not generate customer statement: $e');
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> applyRegularCustomerDiscount({
    required String customerId,
    required String customerName,
    required String? customerCategory,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final normalizedType = (customerCategory ?? '').trim().toLowerCase();
    if (normalizedType != 'wholesale' && normalizedType != 'vip') {
      Get.snackbar(
        "Not Allowed",
        "Discount is only available for Wholesale/VIP customers.",
      );
      return;
    }
    if (!amount.isFinite || amount <= 0) {
      Get.snackbar("Error", "Enter a valid discount amount.");
      return;
    }

    try {
      final safePhone = customerId.trim();
      final safeName = customerName.trim();
      if (safePhone.isEmpty || safePhone.contains('-')) {
        throw StateError(
          'A valid customer phone number is required to apply a discount safely.',
        );
      }

      final Map<String, QueryDocumentSnapshot> docs = {};

      if (safePhone.isNotEmpty) {
        final phoneSnap =
            await db
                .collection('daily_sales')
                .where('customerPhone', isEqualTo: safePhone)
                .get();
        for (var doc in phoneSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      if (safeName.isNotEmpty) {
        final nameSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: safeName)
                .get();
        for (var doc in nameSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
        docs.values.map(
          (doc) => {'_docId': doc.id, ...doc.data() as Map<String, dynamic>},
        ),
      );
      final pendingDocs =
          docs.values.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final pending = effectiveRegularCustomerPending(data);
            final type = (data['customerType'] ?? '').toString().toLowerCase();
            final invoicePhone =
                (data['customerPhone'] ?? '').toString().trim();
            return type == normalizedType &&
                (invoicePhone.isEmpty || invoicePhone == safePhone) &&
                !_isConditionCourierInvoice({
                  '_docId': doc.id,
                  ...data,
                }, conditionInvoiceIds) &&
                pending > 0.5;
          }).toList();

      if (pendingDocs.isEmpty) {
        Get.snackbar("No Due", "No pending invoice found for this customer.");
        return;
      }

      DateTime invoiceDate(Map<String, dynamic> data) {
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) return timestamp.toDate();
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) return createdAt.toDate();
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      pendingDocs.sort((a, b) {
        final da = a.data() as Map<String, dynamic>;
        final dbb = b.data() as Map<String, dynamic>;
        final dateCompare = invoiceDate(da).compareTo(invoiceDate(dbb));
        return dateCompare != 0 ? dateCompare : a.id.compareTo(b.id);
      });

      if (pendingDocs.length > 200) {
        throw StateError(
          'This customer has too many due invoices to discount safely in one operation.',
        );
      }

      final customerRef = db.collection('customers').doc(safePhone);
      final sourceTxId = 'DISCOUNT-${db.collection('daily_sales').doc().id}';
      final appliedAmount = await db.runTransaction<double>((
        transaction,
      ) async {
        final customerSnapshot = await transaction.get(customerRef);
        if (!customerSnapshot.exists) {
          throw StateError('Customer profile was not found.');
        }
        final customerData = customerSnapshot.data() ?? <String, dynamic>{};
        final profileType =
            (customerData['type'] ?? '').toString().trim().toLowerCase();
        if (profileType.isNotEmpty && profileType != normalizedType) {
          throw StateError(
            'Customer profile category does not match the selected account.',
          );
        }
        final customerCurrentDue = customerData['currentDue'];
        if (customerCurrentDue is! num || !customerCurrentDue.isFinite) {
          throw StateError(
            'Customer current due is missing or invalid; no discount was applied.',
          );
        }

        final currentInvoices = <RegularCustomerDiscountInvoice>[];
        final dailySnapshots = <String, DocumentSnapshot>{};
        for (final doc in pendingDocs) {
          final snapshot = await transaction.get(doc.reference);
          if (!snapshot.exists) continue;
          final data = snapshot.data() as Map<String, dynamic>;
          final type = (data['customerType'] ?? '').toString().toLowerCase();
          final invoicePhone = (data['customerPhone'] ?? '').toString().trim();
          if (type != normalizedType ||
              (invoicePhone.isNotEmpty && invoicePhone != safePhone) ||
              conditionInvoiceIds.contains(doc.id)) {
            continue;
          }

          final invoiceId =
              (data['invoiceId'] ?? data['transactionId'] ?? '').toString();
          final pending = effectiveRegularCustomerPending(data);
          if (pending <= 0.5) continue;
          if (invoiceId.isEmpty) {
            throw StateError(
              'A due invoice is missing its invoice ID; no discount was applied.',
            );
          }
          final invoiceAmount = (data['amount'] as num?)?.toDouble() ?? 0;
          final paid = (data['paid'] as num?)?.toDouble() ?? 0;
          final ledgerPaid = (data['ledgerPaid'] as num?)?.toDouble() ?? 0;
          final discount = (data['discount'] as num?)?.toDouble() ?? 0;
          if (!invoiceAmount.isFinite ||
              !paid.isFinite ||
              !ledgerPaid.isFinite ||
              !discount.isFinite ||
              invoiceAmount <= 0 ||
              paid < 0 ||
              ledgerPaid < 0 ||
              discount < 0 ||
              ledgerPaid > paid + 0.01 ||
              paid + pending > invoiceAmount + 0.01) {
            throw StateError(
              'Invoice $invoiceId has inconsistent payment totals; no discount was applied.',
            );
          }
          currentInvoices.add(
            RegularCustomerDiscountInvoice(
              dailySalesDocumentId: doc.id,
              invoiceId: invoiceId,
              amount: invoiceAmount,
              pending: pending,
              paid: paid,
              ledgerPaid: ledgerPaid,
              discount: discount,
            ),
          );
          dailySnapshots[doc.id] = snapshot;
        }

        final plan = RegularCustomerDiscountPlan.build(
          invoices: currentInvoices,
          amount: amount,
        );
        if (plan.allocations.isEmpty) return 0;
        if (customerCurrentDue + 0.01 < plan.appliedAmount) {
          throw StateError(
            'Customer profile due is lower than the invoice discount; no discount was applied.',
          );
        }

        final orderSnapshots = <String, DocumentSnapshot>{};
        final seenInvoiceIds = <String>{};
        for (final allocation in plan.allocations) {
          final invoice = allocation.invoice;
          if (!seenInvoiceIds.add(invoice.invoiceId)) {
            throw StateError(
              'More than one due record points to invoice ${invoice.invoiceId}; no discount was applied.',
            );
          }
          final orderRef = db.collection('sales_orders').doc(invoice.invoiceId);
          final orderSnapshot = await transaction.get(orderRef);
          if (!orderSnapshot.exists) {
            throw StateError(
              'Sales order ${invoice.invoiceId} was not found; no discount was applied.',
            );
          }
          final orderData = orderSnapshot.data() as Map<String, dynamic>;
          final orderType =
              (orderData['customerType'] ?? '').toString().trim().toLowerCase();
          final saleMode =
              (orderData['saleMode'] ?? '').toString().toLowerCase();
          final orderPhone =
              (orderData['customerPhone'] ?? '').toString().trim();
          final dailyData =
              dailySnapshots[invoice.dailySalesDocumentId]!.data()
                  as Map<String, dynamic>;
          final dailyPhone =
              (dailyData['customerPhone'] ?? '').toString().trim();
          if ((orderType.isNotEmpty && orderType != normalizedType) ||
              saleMode == 'condition' ||
              (saleMode != 'non_condition' &&
                  orderData['isCondition'] == true) ||
              (dailyPhone.isNotEmpty && dailyPhone != safePhone) ||
              (dailyPhone.isEmpty && orderPhone != safePhone)) {
            throw StateError(
              'Sales order ${invoice.invoiceId} is not an eligible Wholesale/VIP invoice.',
            );
          }
          final orderTotal = (orderData['grandTotal'] as num?)?.toDouble() ?? 0;
          final orderPaid = (orderData['paid'] as num?)?.toDouble() ?? 0;
          if (!orderTotal.isFinite ||
              !orderPaid.isFinite ||
              orderPaid < 0 ||
              orderPaid > orderTotal + 0.01 ||
              invoice.amount <= 0 ||
              (orderTotal - invoice.amount).abs() > 0.01) {
            throw StateError(
              'Sales order ${invoice.invoiceId} total does not match daily sales; no discount was applied.',
            );
          }
          orderSnapshots[invoice.invoiceId] = orderSnapshot;
        }

        final discountNote =
            note.trim().isNotEmpty ? note.trim() : 'Customer Discount';
        final paidAt = Timestamp.now();
        for (final allocation in plan.allocations) {
          final invoice = allocation.invoice;
          final dailySnapshot = dailySnapshots[invoice.dailySalesDocumentId]!;
          final orderSnapshot = orderSnapshots[invoice.invoiceId]!;
          final fullyPaid = allocation.isFullyPaid;
          final historyEntry = {
            'amount': allocation.amount,
            'note': discountNote,
            'timestamp': Timestamp.fromDate(date),
            'paidAt': paidAt,
            'type': 'discount',
            'number': '',
            'bankName': '',
            'accountNumber': '',
            'sourceTxId': sourceTxId,
            'appliedTo': invoice.dailySalesDocumentId,
            'invoiceId': invoice.invoiceId,
            'collectionMode': 'discount',
            'discount': true,
          };

          transaction.update(dailySnapshot.reference, {
            'paid': allocation.newPaid,
            'ledgerPaid': allocation.newLedgerPaid,
            'pending': allocation.newPending,
            'paymentMethod.pending': allocation.newPending,
            'discount': allocation.newDiscount,
            'status': fullyPaid ? 'paid' : 'partial',
            'lastPaymentAt': FieldValue.serverTimestamp(),
            'paymentHistory': FieldValue.arrayUnion([historyEntry]),
          });
          transaction.update(orderSnapshot.reference, {
            'paid': allocation.newPaid,
            'paymentDetails.due': allocation.newPending,
            'paymentDetails.paidForInvoice': allocation.newPaid,
            'isFullyPaid': fullyPaid,
            'status': fullyPaid ? 'completed' : 'partial',
          });
        }

        transaction.update(customerRef, {
          'currentDue': FieldValue.increment(-plan.appliedAmount),
          'lastShopDate': FieldValue.serverTimestamp(),
        });
        return plan.appliedAmount;
      });

      if (appliedAmount <= 0.01) {
        Get.snackbar("No Due", "No pending invoice found for this customer.");
        return;
      }

      await refreshRegularCustomerDues();
      if (Get.isRegistered<DailySalesController>()) {
        await Get.find<DailySalesController>().loadDailySales();
      }
      if (Get.isRegistered<OverviewController>()) {
        Get.find<OverviewController>().refreshData();
      }

      final message =
          appliedAmount + 0.01 < amount
              ? "৳${appliedAmount.toStringAsFixed(2)} discount applied to $customerName. Remaining amount exceeded the available invoice due."
              : "৳${appliedAmount.toStringAsFixed(2)} discount applied to $customerName.";
      Get.snackbar("Success", message);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> getRegularCustomerInvoices({
    required String customerName,
    String? customerCategory,
    String? customerPhone,
  }) async {
    try {
      final normalizedType = (customerCategory ?? '').trim().toLowerCase();
      final safePhone = (customerPhone ?? '').trim();
      final safeName = customerName.trim();

      final Map<String, QueryDocumentSnapshot> docs = {};

      if (safePhone.isNotEmpty) {
        final phoneSnap =
            await db
                .collection('daily_sales')
                .where('customerPhone', isEqualTo: safePhone)
                .get();

        for (var doc in phoneSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      if (safeName.isNotEmpty) {
        final nameSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: safeName)
                .get();

        for (var doc in nameSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
        docs.values.map(
          (doc) => {'_docId': doc.id, ...doc.data() as Map<String, dynamic>},
        ),
      );
      final list =
          docs.values
              .map((d) {
                final data = Map<String, dynamic>.from(d.data() as Map);
                data['docId'] = d.id;
                data['_docId'] = d.id;
                data['pending'] = effectiveRegularCustomerPending(data);
                return data;
              })
              .where((data) {
                final type =
                    (data['customerType'] ?? '').toString().toLowerCase();
                final invoicePhone =
                    (data['customerPhone'] ?? '').toString().trim();

                final typeMatched =
                    normalizedType.isEmpty || type == normalizedType;
                final phoneMatched =
                    safePhone.isEmpty ||
                    invoicePhone.isEmpty ||
                    invoicePhone == safePhone;

                return typeMatched &&
                    phoneMatched &&
                    !_isConditionCourierInvoice(data, conditionInvoiceIds);
              })
              .toList();

      list.sort((a, b) {
        final t1 =
            a['timestamp'] is Timestamp
                ? a['timestamp'] as Timestamp
                : Timestamp.now();
        final t2 =
            b['timestamp'] is Timestamp
                ? b['timestamp'] as Timestamp
                : Timestamp.now();
        return t2.compareTo(t1);
      });

      return list;
    } catch (e) {
      AppLogger.i("Error fetching pending customer invoices: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRegularCustomerAdvanceHistory(
    String customerId, {
    String? customerName,
  }) async {
    try {
      final customerDoc =
          await db.collection('customers').doc(customerId).get();
      final history =
          customerDoc.data()?['advanceHistory'] as List<dynamic>? ?? [];
      final advances =
          history
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      final invoiceDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      if (customerId.trim().isNotEmpty) {
        final byPhone =
            await db
                .collection('daily_sales')
                .where('customerPhone', isEqualTo: customerId.trim())
                .get();
        invoiceDocs.addAll(byPhone.docs);
      }
      if ((customerName ?? '').trim().isNotEmpty) {
        final byName =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: customerName!.trim())
                .get();
        final knownIds = invoiceDocs.map((doc) => doc.id).toSet();
        invoiceDocs.addAll(
          byName.docs.where((doc) => !knownIds.contains(doc.id)),
        );
      }

      for (final advance in advances) {
        final allocations =
            (advance['invoiceAllocations'] as List<dynamic>? ?? []);
        if (allocations.isNotEmpty) continue;
        final sourceTxId = (advance['sourceTxId'] ?? '').toString();
        if (sourceTxId.isEmpty) continue;

        final recoveredAllocations = <Map<String, dynamic>>[];
        for (final invoiceDoc in invoiceDocs) {
          final data = invoiceDoc.data();
          final invoiceHistory =
              (data['paymentHistory'] as List<dynamic>? ?? []);
          for (final item in invoiceHistory) {
            if (item is! Map || item['sourceTxId'] != sourceTxId) continue;
            recoveredAllocations.add({
              'invoiceId':
                  (item['invoiceId'] ??
                          data['invoiceId'] ??
                          data['transactionId'] ??
                          '')
                      .toString(),
              'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }
        if (recoveredAllocations.isNotEmpty) {
          advance['invoiceAllocations'] = recoveredAllocations;
        }
      }

      return advances;
    } catch (e) {
      AppLogger.i("Error fetching regular customer advance history: $e");
      return [];
    }
  }

  Future<bool> collectRegularCustomerDue({
    required String customerId,
    required String customerName,
    required String? customerCategory,
    required double amount,
    required String note,
    required DateTime date,
    required Map<String, dynamic> paymentMethodData,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      Get.snackbar("Error", "Enter a valid amount to collect.");
      return false;
    }

    gbIsLoading.value = true;

    try {
      final normalizedType = (customerCategory ?? '').trim().toLowerCase();
      final safePhone = customerId.trim();
      final safeName = customerName.trim();

      String parsedMethod = (paymentMethodData['type'] ?? 'cash').toString();
      if (parsedMethod.toLowerCase() == 'cash' &&
          (paymentMethodData['bankName'] ?? '').toString().trim().isNotEmpty) {
        parsedMethod = 'Bank';
      }

      final String pType = parsedMethod.toLowerCase();

      final Map<String, QueryDocumentSnapshot> docs = {};

      // New records: customerPhone exists.
      if (safePhone.isNotEmpty) {
        final phoneSnap =
            await db
                .collection('daily_sales')
                .where('customerPhone', isEqualTo: safePhone)
                .get();

        for (var doc in phoneSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      // Old records: customerPhone may not exist, so match by name.
      if (safeName.isNotEmpty) {
        final nameSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: safeName)
                .get();

        for (var doc in nameSnap.docs) {
          docs[doc.id] = doc;
        }
      }

      final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
        docs.values.map(
          (doc) => {'_docId': doc.id, ...doc.data() as Map<String, dynamic>},
        ),
      );
      final pendingDocs =
          docs.values.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final pending = effectiveRegularCustomerPending(data);
            final type = (data['customerType'] ?? '').toString().toLowerCase();

            final typeMatched =
                normalizedType.isEmpty || type == normalizedType;

            return typeMatched &&
                !_isConditionCourierInvoice({
                  '_docId': doc.id,
                  ...data,
                }, conditionInvoiceIds) &&
                pending > 0.5;
          }).toList();

      final docsById = {for (final doc in pendingDocs) doc.id: doc};
      final collectionPlan = RegularCustomerCollectionPlan.build(
        invoices:
            pendingDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return RegularCustomerCollectionInvoice(
                documentId: doc.id,
                pending: effectiveRegularCustomerPending(data),
                paid: (data['paid'] as num?)?.toDouble() ?? 0,
                ledgerPaid: (data['ledgerPaid'] as num?)?.toDouble() ?? 0,
                invoiceDate:
                    data['timestamp'] is Timestamp
                        ? (data['timestamp'] as Timestamp).toDate()
                        : date,
              );
            }).toList(),
        amount: amount,
        collectionDate: date,
      );
      final double amountToCollect = collectionPlan.appliedAmount;
      final double advanceAmount = collectionPlan.advanceAmount;

      if (advanceAmount > 0.01 &&
          (safePhone.isEmpty || safePhone.contains('-'))) {
        Get.snackbar(
          "Cannot Save Advance",
          "A valid customer phone number is required to keep extra payment as account credit.",
        );
        return false;
      }

      final invoiceAllocations = <Map<String, dynamic>>[];

      final String sourceTxId =
          "COLLECT-${DateTime.now().millisecondsSinceEpoch}";

      final batch = db.batch();

      for (final allocation in collectionPlan.allocations) {
        final doc = docsById[allocation.invoice.documentId]!;
        final data = doc.data() as Map<String, dynamic>;

        final double take = allocation.amount;
        final double newPending = allocation.newPending;
        final bool fullyPaid = allocation.isFullyPaid;

        final String invoiceId =
            (data['invoiceId'] ?? data['transactionId'] ?? '').toString();
        if (invoiceId.isNotEmpty) {
          invoiceAllocations.add({'invoiceId': invoiceId, 'amount': take});
        }

        final history = {
          'amount': take,
          'note': note.trim().isNotEmpty ? note.trim() : "Due Collection",
          'timestamp': Timestamp.fromDate(date),
          'paidAt': Timestamp.now(),
          'type': pType,
          'number': paymentMethodData['number'] ?? '',
          'bankName': paymentMethodData['bankName'] ?? '',
          'accountNumber':
              paymentMethodData['accountNo'] ??
              paymentMethodData['accountNumber'] ??
              '',
          'sourceTxId': sourceTxId,
          'appliedTo': doc.id,
          'invoiceId': invoiceId,
          'collectionMode':
              allocation.isPreviousDateInvoice ? 'old_due_ledger' : 'same_day',
        };

        batch.update(doc.reference, {
          'paid': allocation.newPaid,
          if (allocation.isPreviousDateInvoice)
            'ledgerPaid': allocation.newLedgerPaid,
          'pending': newPending < 0 ? 0.0 : newPending,
          'status': fullyPaid ? 'paid' : 'partial',
          'lastPaymentAt': FieldValue.serverTimestamp(),
          'paymentHistory': FieldValue.arrayUnion([history]),
          'paymentMethod.$pType': FieldValue.increment(take),
        });

        if (invoiceId.isNotEmpty) {
          final orderRef = db.collection('sales_orders').doc(invoiceId);
          final orderSnap = await orderRef.get();

          if (orderSnap.exists) {
            batch.update(orderRef, {
              'paid': FieldValue.increment(take),
              'paymentDetails.due': FieldValue.increment(-take),
              'paymentDetails.paidForInvoice': FieldValue.increment(take),
              'paymentDetails.$pType': FieldValue.increment(take),
              'isFullyPaid': fullyPaid,
              'status': fullyPaid ? 'completed' : 'partial',
              if (pType == 'bkash')
                'paymentDetails.bkashNumber': paymentMethodData['number'] ?? '',
              if (pType == 'nagad')
                'paymentDetails.nagadNumber': paymentMethodData['number'] ?? '',
              if (pType == 'bank')
                'paymentDetails.bankName': paymentMethodData['bankName'] ?? '',
              if (pType == 'bank')
                'paymentDetails.accountNumber':
                    paymentMethodData['accountNo'] ??
                    paymentMethodData['accountNumber'] ??
                    '',
            });
          }
        }
      }

      if (safePhone.isNotEmpty && !safePhone.contains('-')) {
        batch.set(db.collection('customers').doc(safePhone), {
          'name': safeName,
          'phone': safePhone,
          'type': (customerCategory ?? '').trim().toUpperCase(),
          'currentDue': FieldValue.increment(-amountToCollect),
          if (advanceAmount > 0.01)
            'advanceBalance': FieldValue.increment(advanceAmount),
          if (advanceAmount > 0.01)
            'advanceHistory': FieldValue.arrayUnion([
              {
                'amount': advanceAmount,
                'note':
                    note.trim().isNotEmpty
                        ? note.trim()
                        : 'Excess due collection kept as customer credit',
                'timestamp': Timestamp.fromDate(date),
                'paidAt': Timestamp.now(),
                'type': pType,
                'number': paymentMethodData['number'] ?? '',
                'bankName': paymentMethodData['bankName'] ?? '',
                'accountNumber':
                    paymentMethodData['accountNo'] ??
                    paymentMethodData['accountNumber'] ??
                    '',
                'sourceTxId': sourceTxId,
                'invoiceAllocations': invoiceAllocations,
              },
            ]),
          'lastShopDate': Timestamp.now(),
        }, SetOptions(merge: true));
      }

      if (collectionPlan.cashLedgerAmount > 0.01) {
        batch.set(db.collection('cash_ledger').doc(), {
          'type': 'deposit',
          'amount': collectionPlan.cashLedgerAmount,
          'method': parsedMethod,
          'details': paymentMethodData,
          'description':
              "Collection from $customerName (${customerCategory?.toUpperCase() ?? 'CUSTOMER'})",
          'timestamp': Timestamp.fromDate(date),
          'linkedCustomerId': customerId,
          'linkedTxId': sourceTxId,
          'source': 'customer_due_collection',
        });
      }

      await batch.commit();

      await refreshRegularCustomerDues();

      if (Get.isRegistered<DailySalesController>()) {
        await Get.find<DailySalesController>().loadDailySales();
      }

      if (Get.isRegistered<OverviewController>()) {
        Get.find<OverviewController>().refreshData();
      }

      if (Get.isRegistered<CashDrawerController>()) {
        Get.find<CashDrawerController>().fetchData();
      }

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Success",
        advanceAmount > 0.01
            ? "Payment collected. ৳${advanceAmount.toStringAsFixed(2)} kept as customer credit."
            : "Payment collected from $customerName",
      );
      return true;
    } catch (e) {
      Get.snackbar("Error", e.toString());
      return false;
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> calculateTotalOutstanding() async {
    try {
      final snap = await db.collection('debatorbody').get();
      double totalRec = 0;
      double totalPay = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        double bal = (data['balance'] as num?)?.toDouble() ?? 0.0;
        double pDue = (data['purchaseDue'] as num?)?.toDouble() ?? 0.0;

        if (bal > 0) totalRec += bal;
        if (pDue > 0) totalPay += pDue;
      }

      final dueSalesSnap =
          await db
              .collection('daily_sales')
              .where('pending', isGreaterThan: 0.5)
              .get();
      final regularDueSales =
          dueSalesSnap.docs
              .where((doc) {
                final type =
                    (doc.data()['customerType'] ?? '').toString().toUpperCase();
                return type == 'WHOLESALE' || type == 'VIP';
              })
              .map((doc) => {'_docId': doc.id, ...doc.data()})
              .toList();
      final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
        regularDueSales,
      );

      for (var doc in dueSalesSnap.docs) {
        final data = doc.data();
        final type = (data['customerType'] ?? '').toString().toUpperCase();

        if (type == 'WHOLESALE' || type == 'VIP') {
          if (_isConditionCourierInvoice({
            '_docId': doc.id,
            ...data,
          }, conditionInvoiceIds)) {
            continue;
          }
          final due = (data['pending'] as num?)?.toDouble() ?? 0.0;
          if (due > 0) totalRec += due;
        }
      }

      totalMarketOutstanding.value = totalRec;
      totalMarketPayable.value = totalPay;
    } catch (e) {
      AppLogger.i(e.toString());
    }
  }

  Future<void> syncAllBalances() async {
    gbIsLoading.value = true;
    Get.snackbar(
      "Syncing...",
      "Recalculating all debtor balances (Receivables & Payables). Please wait...",
      duration: const Duration(seconds: 4),
    );

    try {
      final snap = await db.collection('debatorbody').get();
      WriteBatch batch = db.batch();
      int count = 0;

      double newMarketDue = 0.0;
      double newMarketPayable = 0.0;

      for (var doc in snap.docs) {
        String debtorId = doc.id;

        // ========================================================
        // 1. RECALCULATE RECEIVABLES (From 'transactions' collection)
        // ========================================================
        final txSnap =
            await db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('transactions')
                .get();

        double oldDueTotal = 0.0,
            oldDuePaid = 0.0,
            runningSales = 0.0,
            runningPaid = 0.0;

        for (var txDoc in txSnap.docs) {
          final data = txDoc.data();
          String type = (data['type'] ?? '').toString().toLowerCase();
          double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

          if (type == 'previous_due') {
            oldDueTotal += amount;
          } else if (type == 'loan_payment' ||
              type == 'eid_bonus' ||
              type == 'discount') {
            oldDuePaid += amount;
          } else if (type == 'credit' || type == 'advance_given') {
            runningSales += amount;
          } else if (type == 'debit' || type == 'advance_received') {
            runningPaid += amount;
          }
        }

        double currentLoan = oldDueTotal - oldDuePaid;
        if (currentLoan < 0) {
          runningPaid += currentLoan.abs();
          currentLoan = 0;
        }
        double accurateBalance = currentLoan + (runningSales - runningPaid);

        // ========================================================
        // 2. RECALCULATE PAYABLES (From 'purchases' collection)
        // ========================================================
        final purchaseSnap =
            await db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('purchases')
                .get();

        double accuratePayable = 0.0;

        for (var pDoc in purchaseSnap.docs) {
          final pData = pDoc.data();
          String pType = (pData['type'] ?? '').toString().toLowerCase();
          double pAmount =
              double.tryParse(
                (pData['totalAmount'] ?? pData['amount']).toString(),
              ) ??
              0.0;

          if (pType == 'invoice') {
            accuratePayable += pAmount;
          } else if (pType == 'payment' || pType == 'adjustment') {
            accuratePayable -= pAmount;
          }
        }

        // ========================================================
        // 3. UPDATE THE DEBTOR DOCUMENT WITH BOTH CORRECTED VALUES
        // ========================================================
        batch.update(doc.reference, {
          'balance': accurateBalance,
          'purchaseDue': accuratePayable,
        });

        if (accurateBalance > 0) newMarketDue += accurateBalance;
        if (accuratePayable > 0) newMarketPayable += accuratePayable;

        count++;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      totalMarketOutstanding.value = newMarketDue;
      totalMarketPayable.value = newMarketPayable;
      await loadBodies(loadMore: false);

      Get.snackbar(
        "Success",
        "All Receivables & Payables synchronized perfectly!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Sync failed: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> _performGlobalSearch(String queryText) async {
    isSearching.value = true;
    isBodiesLoading.value = true;

    try {
      if (!await _fetchRegularCustomerDues()) {
        Get.snackbar(
          "Error",
          "Could not refresh customer dues. Please try searching again.",
        );
        return;
      }

      String qLower = queryText.trim().toLowerCase();
      Map<String, DebtorModel> agentResults = {};
      Map<String, DebtorModel> regularResults = {};
      final regularDuesByIdentity = <String, DebtorModel>{};
      for (final due in regularCustomerDues) {
        regularDuesByIdentity[due.id] = due;
        if (due.phone.isNotEmpty) regularDuesByIdentity[due.phone] = due;
      }
      List<String> searchTerms = qLower.split(RegExp(r'\s+'));
      String primaryTerm = searchTerms.first;

      if (primaryTerm.isNotEmpty) {
        var kwSnap =
            await db
                .collection('debatorbody')
                .where('searchKeywords', arrayContains: primaryTerm)
                .limit(50)
                .get();
        for (var doc in kwSnap.docs) {
          agentResults[doc.id] = DebtorModel.fromFirestore(doc);
        }

        // Customer documents provide searchable profile fields, but currentDue
        // can lag behind invoice payments. Only include them when an invoice-
        // based outstanding balance exists in regularCustomerDues.
        var custKwSnap =
            await db
                .collection('customers')
                .where('searchKeywords', arrayContains: primaryTerm)
                .limit(50)
                .get();
        for (var doc in custKwSnap.docs) {
          final customer = DebtorModel.fromRegularCustomer(doc);
          final due =
              regularDuesByIdentity[doc.id] ??
              (customer.phone.isNotEmpty
                  ? regularDuesByIdentity[customer.phone]
                  : null);
          if (due != null) {
            regularResults[due.id] = due.copyWith(
              name: customer.name,
              des: customer.des,
              address: customer.address,
            );
          }
        }
      }

      for (var m in bodies) {
        agentResults[m.id] = m;
      }
      for (var m in regularCustomerDues) {
        regularResults.putIfAbsent(m.id, () => m);
      }

      bool matchesTerms(DebtorModel d) {
        String combinedString =
            "${d.name} ${d.phone} ${d.nid} ${d.address} ${d.des}".toLowerCase();
        for (String term in searchTerms) {
          if (!combinedString.contains(term)) return false;
        }
        return true;
      }

      List<DebtorModel> finalMatches = [
        ...regularResults.values.where(matchesTerms),
        ...agentResults.values.where(matchesTerms),
      ];

      filteredBodies.value = finalMatches;
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> runServerSearch(String queryText) async =>
      searchDebtors(queryText);

  List<String> _generateSearchKeywords(
    String name,
    String phone,
    String des,
    String address,
  ) {
    Set<String> keywords = {};
    void addAllSubstrings(String text) {
      if (text.isEmpty) return;
      if (text.length > 50) {
        List<String> words = text.split(RegExp(r'\s+'));
        for (String w in words) {
          for (int i = 1; i <= w.length; i++) {
            keywords.add(w.substring(0, i));
          }
        }
        for (int i = 1; i <= 50; i++) {
          keywords.add(text.substring(0, i));
        }
        return;
      }
      for (int i = 0; i < text.length; i++) {
        for (int j = i + 1; j <= text.length; j++) {
          keywords.add(text.substring(i, j));
        }
      }
    }

    addAllSubstrings(name.trim().toLowerCase());
    addAllSubstrings(phone.trim().toLowerCase());
    addAllSubstrings(des.trim().toLowerCase());
    addAllSubstrings(address.trim().toLowerCase());
    return keywords.toList();
  }

  Future<void> repairSearchKeywords() async {
    gbIsLoading.value = true;
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      for (var doc in snap.docs) {
        final data = doc.data();
        batch.update(doc.reference, {
          'searchKeywords': _generateSearchKeywords(
            data['name'] ?? '',
            data['phone'] ?? '',
            data['des'] ?? '',
            data['address'] ?? '',
          ),
        });
      }
      await batch.commit();
      Get.snackbar("Success", "All Search Keywords Updated Successfully!");
    } catch (e) {
      Get.snackbar("Error", "Failed to fix search data: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> addBody({
    required String name,
    required String des,
    required String nid,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> payments,
  }) async {
    isAddingBody.value = true;
    try {
      final safePhone = phone.trim();
      if (safePhone.isNotEmpty) {
        final existing =
            await db
                .collection('debatorbody')
                .where('phone', isEqualTo: safePhone)
                .limit(1)
                .get();
        if (existing.docs.isNotEmpty) {
          Get.snackbar(
            "Already Exists",
            "A debtor account already uses this phone number.",
          );
          return;
        }
      }

      await db.collection('debatorbody').add({
        "name": name.trim(),
        "des": des.trim(),
        "nid": nid,
        "phone": safePhone,
        "address": address,
        "payments": payments,
        "balance": 0.0,
        "purchaseDue": 0.0,
        "searchKeywords": _generateSearchKeywords(
          name.trim(),
          phone.trim(),
          des.trim(),
          address.trim(),
        ),
        "createdAt": Timestamp.now(),
        "lastTransactionDate": Timestamp.now(),
      });
      await loadBodies(loadMore: false);
      Get.back();
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isAddingBody.value = false;
    }
  }

  Future<void> editDebtor({
    required String id,
    required String oldName,
    required String newName,
    required String des,
    required String nid,
    required String phone,
    required String address,
    List<Map<String, dynamic>>? payments,
  }) async {
    gbIsLoading.value = true;
    try {
      final safePhone = phone.trim();
      if (safePhone.isNotEmpty) {
        final matchingDebtors =
            await db
                .collection('debatorbody')
                .where('phone', isEqualTo: safePhone)
                .get();
        if (matchingDebtors.docs.any((doc) => doc.id != id)) {
          throw StateError(
            "Another debtor account already uses this phone number.",
          );
        }
      }

      Map<String, dynamic> updateData = {
        "name": newName.trim(),
        "des": des.trim(),
        "nid": nid,
        "phone": safePhone,
        "address": address,
        "searchKeywords": _generateSearchKeywords(
          newName.trim(),
          phone.trim(),
          des.trim(),
          address.trim(),
        ),
      };
      if (payments != null) updateData["payments"] = payments;

      await db.collection('debatorbody').doc(id).update(updateData);

      if (oldName != newName) {
        final batch = db.batch();
        final orderSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: id)
                .get();
        List<String> linkedInvoiceIds = [];
        for (var doc in orderSnap.docs) {
          batch.update(doc.reference, {"customerName": newName.trim()});
          linkedInvoiceIds.add((doc.data() as Map)['invoiceId'] ?? doc.id);
        }

        final salesSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: oldName)
                .get();
        for (var doc in salesSnap.docs) {
          batch.update(doc.reference, {"name": newName.trim()});
        }

        for (int i = 0; i < linkedInvoiceIds.length; i += 10) {
          int end =
              i + 10 > linkedInvoiceIds.length
                  ? linkedInvoiceIds.length
                  : i + 10;
          List<String> chunk = linkedInvoiceIds.sublist(i, end);
          if (chunk.isNotEmpty) {
            final chunkSnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', whereIn: chunk)
                    .get();
            for (var doc in chunkSnap.docs) {
              batch.update(doc.reference, {"name": newName.trim()});
            }
          }
        }
        await batch.commit();
      }

      await loadBodies(loadMore: false);
      Get.back();
      Get.snackbar("Success", "Debtor profile updated");
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
      rethrow;
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> updateRegularCustomerProfile({
    required String oldPhone,
    required String oldName,
    required String newName,
    required String newPhone,
    required String shop,
    required String address,
    required String category,
  }) async {
    final safeOldPhone = oldPhone.trim();
    final safeOldName = oldName.trim();
    final safeName = newName.trim();
    final safePhone = newPhone.trim();
    final safeShop = shop.trim();
    final safeAddress = address.trim();
    final normalizedCategory = category.trim().toLowerCase();

    if (safeName.isEmpty || safePhone.isEmpty) {
      throw ArgumentError('Customer name and phone number are required.');
    }

    final oldCustomerRef =
        safeOldPhone.isEmpty
            ? null
            : db.collection('customers').doc(safeOldPhone);
    final newCustomerRef = db.collection('customers').doc(safePhone);
    final oldCustomerData =
        oldCustomerRef == null
            ? <String, dynamic>{}
            : (await oldCustomerRef.get()).data() ?? <String, dynamic>{};
    if (safePhone != safeOldPhone) {
      final newCustomerSnapshot = await newCustomerRef.get();
      if (newCustomerSnapshot.exists) {
        throw StateError('A customer account already uses this phone number.');
      }
    }

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> dailyDocs =
        {};
    if (safeOldPhone.isNotEmpty) {
      final byPhone =
          await db
              .collection('daily_sales')
              .where('customerPhone', isEqualTo: safeOldPhone)
              .get();
      for (final doc in byPhone.docs) {
        final type =
            (doc.data()['customerType'] ?? '').toString().toLowerCase();
        if (type == normalizedCategory) dailyDocs[doc.id] = doc;
      }
    }
    if (safeOldName.isNotEmpty) {
      final byName =
          await db
              .collection('daily_sales')
              .where('name', isEqualTo: safeOldName)
              .get();
      for (final doc in byName.docs) {
        final data = doc.data();
        final invoicePhone = (data['customerPhone'] ?? '').toString().trim();
        final type = (data['customerType'] ?? '').toString().toLowerCase();
        if (invoicePhone.isEmpty && type == normalizedCategory) {
          dailyDocs[doc.id] = doc;
        }
      }
    }

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> salesOrders =
        {};
    if (safeOldPhone.isNotEmpty) {
      final byPhone =
          await db
              .collection('sales_orders')
              .where('customerPhone', isEqualTo: safeOldPhone)
              .get();
      for (final doc in byPhone.docs) {
        final type =
            (doc.data()['customerType'] ?? '').toString().toLowerCase();
        if (type == normalizedCategory) salesOrders[doc.id] = doc;
      }
    }
    if (safeOldName.isNotEmpty) {
      final byName =
          await db
              .collection('sales_orders')
              .where('customerName', isEqualTo: safeOldName)
              .get();
      for (final doc in byName.docs) {
        final data = doc.data();
        final orderPhone = (data['customerPhone'] ?? '').toString().trim();
        final type = (data['customerType'] ?? '').toString().toLowerCase();
        if (orderPhone.isEmpty && type == normalizedCategory) {
          salesOrders[doc.id] = doc;
        }
      }
    }

    final oldOrderDocs =
        oldCustomerRef == null
            ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
            : (await oldCustomerRef.collection('orders').get()).docs;
    if (safePhone != safeOldPhone) {
      final destinationOrdersRef = newCustomerRef.collection('orders');
      for (final order in oldOrderDocs) {
        final destinationOrder = await destinationOrdersRef.doc(order.id).get();
        if (destinationOrder.exists) {
          throw StateError(
            'An invoice history entry already exists in the new customer account.',
          );
        }
      }
    }

    final currentDue = dailyDocs.values.fold<double>(0, (total, doc) {
      final pending = doc.data()['pending'];
      return total + (pending is num ? pending.toDouble() : 0.0);
    });

    final writes = <void Function(WriteBatch)>[];
    for (final doc in dailyDocs.values) {
      writes.add(
        (batch) => batch.update(doc.reference, {
          'name': safeName,
          'customerPhone': safePhone,
        }),
      );
    }
    for (final doc in salesOrders.values) {
      writes.add(
        (batch) => batch.update(doc.reference, {
          'customerName': safeName,
          'customerPhone': safePhone,
          'shopName': safeShop,
          'deliveryAddress': safeAddress,
        }),
      );
    }
    await _commitRegularCustomerProfileWrites(writes);

    final updatedCustomerData = <String, dynamic>{
      ...oldCustomerData,
      'name': safeName,
      'phone': safePhone,
      'shop': safeShop,
      'address': safeAddress,
      'type': category.trim().toUpperCase(),
      'currentDue': currentDue,
      'searchKeywords': _generateSearchKeywords(
        safeName,
        safePhone,
        safeShop,
        safeAddress,
      ),
      'lastShopDate': FieldValue.serverTimestamp(),
    };

    if (safePhone == safeOldPhone) {
      await newCustomerRef.set(updatedCustomerData, SetOptions(merge: true));
    } else {
      await newCustomerRef.set(updatedCustomerData);
      final orderWrites = <void Function(WriteBatch)>[];
      for (final order in oldOrderDocs) {
        final destinationRef = newCustomerRef
            .collection('orders')
            .doc(order.id);
        orderWrites.add((batch) => batch.set(destinationRef, order.data()));
        orderWrites.add((batch) => batch.delete(order.reference));
      }
      await _commitRegularCustomerProfileWrites(orderWrites);
      await oldCustomerRef?.delete();
    }

    isSearching.value = false;
    await _fetchRegularCustomerDues();
    await calculateTotalOutstanding();
    await loadPage(1);
  }

  Future<void> _commitRegularCustomerProfileWrites(
    List<void Function(WriteBatch)> writes,
  ) async {
    for (var start = 0; start < writes.length; start += 400) {
      final batch = db.batch();
      final end = start + 400 < writes.length ? start + 400 : writes.length;
      for (final write in writes.sublist(start, end)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  Stream<double> getLiveBalance(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  Future<void> loadPage(int pageIndex) async {
    if (pageIndex < 1 || pageIndex > pageCursors.length) return;
    isBodiesLoading.value = true;
    isSearching.value = false;

    try {
      Query query = db
          .collection('debatorbody')
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      DocumentSnapshot? startAfterDoc = pageCursors[pageIndex - 1];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        bodies.value =
            snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();
        if (snap.docs.length < _limit) {
          hasMore.value = false;
        } else {
          hasMore.value = true;
          if (pageCursors.length <= pageIndex) {
            pageCursors.add(snap.docs.last);
          } else {
            pageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentPage.value = pageIndex;
        _applyMergedList();
      } else {
        if (pageIndex == 1) bodies.clear();
        hasMore.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load page: $e");
    } finally {
      isBodiesLoading.value = false;
    }
  }

  Future<void> loadBodies({bool loadMore = false}) async {
    if (loadMore) {
      if (isMoreLoading.value || !hasMore.value) return;
      isMoreLoading.value = true;
    } else {
      isBodiesLoading.value = true;
      _lastDocument = null;
      hasMore.value = true;
    }

    try {
      Query query = db
          .collection('debatorbody')
          .orderBy('createdAt', descending: true)
          .limit(_limit);
      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();
      if (snap.docs.length < _limit) hasMore.value = false;

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
        List<DebtorModel> newBodies =
            snap.docs.map((d) => DebtorModel.fromFirestore(d)).toList();
        if (loadMore) {
          bodies.addAll(newBodies);
        } else {
          bodies.value = newBodies;
        }
      } else {
        if (!loadMore) bodies.clear();
      }

      calculateTotalOutstanding();
      if (!isSearching.value) _applyMergedList();
    } catch (e) {
      Get.snackbar("Error", "Could not load debtors: $e");
    } finally {
      isBodiesLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  Future<Map<String, double>> getInstantDebtorBreakdown(String debtorId) async {
    try {
      final snap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();
      double oldDueTotal = 0.0,
          oldDuePaid = 0.0,
          runningSales = 0.0,
          runningPaid = 0.0;

      for (var doc in snap.docs) {
        final data = doc.data();
        String type = (data['type'] ?? '').toString();
        double amount = (data['amount'] as num).toDouble();

        if (type == 'previous_due') {
          oldDueTotal += amount;
        } else if (type == 'loan_payment' ||
            type == 'eid_bonus' ||
            type == 'discount') {
          oldDuePaid += amount;
        } else if (type == 'credit' || type == 'advance_given') {
          runningSales += amount;
        } else if (type == 'debit' || type == 'advance_received') {
          runningPaid += amount;
        }
      }

      double currentLoan = oldDueTotal - oldDuePaid;
      if (currentLoan < 0) {
        runningPaid += currentLoan.abs();
        currentLoan = 0;
      }
      double runningDue = runningSales - runningPaid;

      return {
        'loan': currentLoan,
        'running': runningDue,
        'total': currentLoan + runningDue,
      };
    } catch (e) {
      return {'loan': 0.0, 'running': 0.0, 'total': 0.0};
    }
  }

  Stream<Map<String, double>> getDebtorBreakdown(String debtorId) {
    return db
        .collection('debatorbody')
        .doc(debtorId)
        .collection('transactions')
        .snapshots()
        .map((snap) {
          double oldDueTotal = 0.0,
              oldDuePaid = 0.0,
              runningSales = 0.0,
              runningPaid = 0.0;

          for (var doc in snap.docs) {
            final data = doc.data();
            String type = (data['type'] ?? '').toString();
            double amount = (data['amount'] as num).toDouble();

            if (type == 'previous_due') {
              oldDueTotal += amount;
            } else if (type == 'loan_payment' ||
                type == 'eid_bonus' ||
                type == 'discount') {
              oldDuePaid += amount;
            } else if (type == 'credit' || type == 'advance_given') {
              runningSales += amount;
            } else if (type == 'debit' || type == 'advance_received') {
              runningPaid += amount;
            }
          }
          double currentLoan = oldDueTotal - oldDuePaid;
          if (currentLoan < 0) {
            runningPaid += currentLoan.abs();
            currentLoan = 0;
          }
          return {
            'loan': currentLoan,
            'running': runningSales - runningPaid,
            'total': currentLoan + (runningSales - runningPaid),
          };
        });
  }

  // =========================================================
  // 4. TRANSACTION OPERATIONS
  // =========================================================
  void clearTransactionState() {
    currentTransactions.clear();
    txPageCursors = [null];
    currentTxPage.value = 1;
    hasMoreTx.value = true;
    isTxLoading.value = false;
    selectedDateRange.value = null;
  }

  void setDateFilter(DateTimeRange? range, String debtorId) {
    selectedDateRange.value = range;
    txPageCursors = [null];
    currentTxPage.value = 1;
    hasMoreTx.value = true;
    loadTxPage(debtorId, 1);
  }

  void nextTxPage(String debtorId) {
    if (!hasMoreTx.value) return;
    loadTxPage(debtorId, currentTxPage.value + 1);
  }

  void prevTxPage(String debtorId) {
    if (currentTxPage.value <= 1) return;
    loadTxPage(debtorId, currentTxPage.value - 1);
  }

  Future<void> loadTxPage(String debtorId, int pageIndex) async {
    if (pageIndex < 1 || pageIndex > txPageCursors.length) return;
    isTxLoading.value = true;

    try {
      Query query = db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .orderBy('date', descending: true);

      if (selectedDateRange.value != null) {
        query = query
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                selectedDateRange.value!.start,
              ),
            )
            .where(
              'date',
              isLessThanOrEqualTo: Timestamp.fromDate(
                selectedDateRange.value!.end,
              ),
            );
      }
      query = query.limit(_txLimit);

      DocumentSnapshot? startAfterDoc = txPageCursors[pageIndex - 1];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      if (snap.docs.isNotEmpty) {
        currentTransactions.value =
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
        if (snap.docs.length < _txLimit) {
          hasMoreTx.value = false;
        } else {
          hasMoreTx.value = true;
          if (txPageCursors.length <= pageIndex) {
            txPageCursors.add(snap.docs.last);
          } else {
            txPageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentTxPage.value = pageIndex;
      } else {
        if (pageIndex == 1) currentTransactions.clear();
        hasMoreTx.value = false;
      }
    } catch (e) {
      AppLogger.i(e.toString());
    } finally {
      isTxLoading.value = false;
    }
  }

  Future<void> _recalculateSingleDebtorBalance(String debtorId) async {
    try {
      final breakdown = await getInstantDebtorBreakdown(debtorId);
      await db.collection('debatorbody').doc(debtorId).update({
        'balance': breakdown['total'],
        'lastTransactionDate': Timestamp.now(),
      });
      calculateTotalOutstanding();
    } catch (e) {
      AppLogger.i(e.toString());
    }
  }

  Future<void> addTransaction({
    required String debtorId,
    required double amount,
    required String note,
    required String type,
    required DateTime date,
    required Map<String, dynamic> paymentMethodData,
    String? txid,
  }) async {
    gbIsLoading.value = true;
    try {
      final debtorRef = db.collection('debatorbody').doc(debtorId);
      final debtorSnap = await debtorRef.get();
      if (!debtorSnap.exists) throw "Debtor not found";
      final String debtorName = debtorSnap.data()?['name'] ?? 'Unknown';

      double amountForRunningBills = 0.0;
      if (type.toLowerCase() == 'eid_bonus' ||
          type.toLowerCase() == 'discount') {
        Map<String, double> breakdown = await getInstantDebtorBreakdown(
          debtorId,
        );
        double currentLoan = breakdown['loan'] ?? 0.0;
        if (amount > currentLoan) amountForRunningBills = amount - currentLoan;
      }

      DocumentReference newTxRef =
          (txid != null && txid.isNotEmpty)
              ? debtorRef.collection('transactions').doc(txid)
              : debtorRef.collection('transactions').doc();
      String finalTxId = newTxRef.id;

      Map<String, dynamic>? finalPaymentMethod = paymentMethodData;
      if (['credit', 'previous_due'].contains(type.toLowerCase())) {
        finalPaymentMethod = null;
      }

      await newTxRef.set({
        'transactionId': finalTxId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': Timestamp.fromDate(date),
        'paymentMethod': finalPaymentMethod,
        'createdAt': Timestamp.now(),
      });

      String parsedMethod = (paymentMethodData['type'] ?? 'cash').toString();
      if (type.toLowerCase() == 'eid_bonus') {
        parsedMethod = 'eid_bonus';
      } else if (type.toLowerCase() == 'discount') {
        parsedMethod = 'discount';
      }

      if (parsedMethod.toLowerCase() == 'cash' &&
          paymentMethodData.containsKey('bankName') &&
          paymentMethodData['bankName'].toString().trim().isNotEmpty) {
        parsedMethod = 'Bank';
      } else if (parsedMethod.toLowerCase() == 'cash' &&
          paymentMethodData.containsKey('bkashNumber') &&
          paymentMethodData['bkashNumber'].toString().trim().isNotEmpty) {
        parsedMethod = 'Bkash';
      }

      bool isCollection = [
        'debit',
        'loan_payment',
        'advance_received',
        'collection',
        'payment',
        'received',
      ].contains(type.toLowerCase());

      if (isCollection) {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': parsedMethod,
          'details': paymentMethodData,
          'description': "Collection from $debtorName",
          'timestamp': Timestamp.fromDate(date),
          'linkedDebtorId': debtorId,
          'linkedTxId': finalTxId,
          'source': 'debtor_collection',
        });
      } else if (type == 'advance_given') {
        await db.collection('cash_ledger').add({
          'type': 'withdraw',
          'amount': amount,
          'method': parsedMethod,
          'details': paymentMethodData,
          'description': "Advance Given to $debtorName",
          'timestamp': Timestamp.fromDate(date),
          'linkedDebtorId': debtorId,
          'linkedTxId': finalTxId,
          'source': 'debtor_payment',
        });
      }

      bool isRunningBillPayment = [
        'debit',
        'collection',
        'payment',
        'received',
      ].contains(type.toLowerCase());
      double remainingToAllocate = amount;

      if ((type.toLowerCase() == 'eid_bonus' ||
              type.toLowerCase() == 'discount') &&
          amountForRunningBills > 0.01) {
        isRunningBillPayment = true;
        remainingToAllocate = amountForRunningBills;
      }

      if (isRunningBillPayment) {
        String pType = parsedMethod.toLowerCase();
        String bNum = paymentMethodData['bkashNumber'] ?? '';
        String nNum = paymentMethodData['nagadNumber'] ?? '';
        String bankName = paymentMethodData['bankName'] ?? '';
        String accNum =
            paymentMethodData['accountNo'] ??
            paymentMethodData['accountNumber'] ??
            '';

        QuerySnapshot ordersSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();
        List<DocumentSnapshot> allOrders = ordersSnap.docs.toList();

        allOrders.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp t1 =
              dataA['timestamp'] is Timestamp
                  ? dataA['timestamp']
                  : Timestamp.now();
          Timestamp t2 =
              dataB['timestamp'] is Timestamp
                  ? dataB['timestamp']
                  : Timestamp.now();
          return t1.compareTo(t2);
        });

        List<DocumentSnapshot> pendingOrders =
            allOrders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double pending = 0.0;
              if (data['paymentDetails'] != null &&
                  data['paymentDetails']['due'] != null) {
                pending =
                    double.tryParse(data['paymentDetails']['due'].toString()) ??
                    0.0;
              } else {
                pending =
                    (double.tryParse(data['grandTotal']?.toString() ?? '0') ??
                        0.0) -
                    (double.tryParse(data['paid']?.toString() ?? '0') ?? 0.0);
              }
              return pending > 0.5;
            }).toList();

        if (pendingOrders.isNotEmpty) {
          WriteBatch batch = db.batch();
          bool hasUpdates = false;
          Map<String, double> middleInvoiceReductions = {};

          for (var orderDoc in pendingOrders) {
            if (remainingToAllocate <= 0.01) break;

            Map<String, dynamic> oData =
                orderDoc.data() as Map<String, dynamic>;
            String invoiceId = oData['invoiceId'] ?? orderDoc.id;

            QuerySnapshot dailySnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', isEqualTo: invoiceId)
                    .limit(1)
                    .get();

            double currentPendingD = 0.0;
            double currentPaidD = 0.0;
            double currentLedgerPaidD = 0.0;
            DocumentSnapshot? dailyDoc;

            if (dailySnap.docs.isNotEmpty) {
              dailyDoc = dailySnap.docs.first;
              Map<String, dynamic> dData =
                  dailyDoc.data() as Map<String, dynamic>;
              currentPendingD =
                  double.tryParse(dData['pending'].toString()) ?? 0.0;
              currentPaidD = double.tryParse(dData['paid'].toString()) ?? 0.0;
              currentLedgerPaidD =
                  double.tryParse(dData['ledgerPaid']?.toString() ?? '0') ??
                  0.0;
            }

            double salesOrderPending =
                oData['paymentDetails'] != null &&
                        oData['paymentDetails']['due'] != null
                    ? (double.tryParse(
                          oData['paymentDetails']['due'].toString(),
                        ) ??
                        0.0)
                    : ((double.tryParse(
                              oData['grandTotal']?.toString() ?? '0',
                            ) ??
                            0.0) -
                        (double.tryParse(oData['paid']?.toString() ?? '0') ??
                            0.0));

            double actualPending =
                dailyDoc != null ? currentPendingD : salesOrderPending;

            if (actualPending <= 0.5) {
              if (salesOrderPending > 0.5) {
                batch.update(orderDoc.reference, {
                  "paid":
                      double.tryParse(oData['grandTotal']?.toString() ?? '0') ??
                      0.0,
                  "paymentDetails.due": 0.0,
                  "isFullyPaid": true,
                  "status": "completed",
                  ...PaidInvoiceRunningDueSnapshot.markPaid(oData),
                });
                hasUpdates = true;
              }
              continue;
            }

            double take =
                (remainingToAllocate >= actualPending)
                    ? actualPending
                    : remainingToAllocate;
            bool isNowFullyPaid = (actualPending - take) <= 0.5;

            Map<String, dynamic> orderUpdate = {
              "paid": FieldValue.increment(take),
              "paymentDetails.due": FieldValue.increment(-take),
              "paymentDetails.$pType": FieldValue.increment(take),
            };

            if (oData['customerName'] != debtorName) {
              orderUpdate['customerName'] = debtorName;
            }
            if (pType == 'bkash' && bNum.isNotEmpty) {
              orderUpdate["paymentDetails.bkashNumber"] = bNum;
            } else if (pType == 'nagad' && nNum.isNotEmpty) {
              orderUpdate["paymentDetails.nagadNumber"] = nNum;
            } else if (pType == 'bank') {
              if (bankName.isNotEmpty) {
                orderUpdate["paymentDetails.bankName"] = bankName;
              }
              if (accNum.isNotEmpty) {
                orderUpdate["paymentDetails.accountNumber"] = accNum;
              }
            }

            if (isNowFullyPaid) {
              orderUpdate["isFullyPaid"] = true;
              orderUpdate["status"] = "completed";
              orderUpdate.addAll(PaidInvoiceRunningDueSnapshot.markPaid(oData));
            }
            batch.update(orderDoc.reference, orderUpdate);

            int currentIndex = allOrders.indexWhere(
              (doc) => doc.id == orderDoc.id,
            );
            if (currentIndex != -1 && currentIndex < allOrders.length - 1) {
              for (int i = currentIndex + 1; i < allOrders.length; i++) {
                String newerDocId = allOrders[i].id;
                middleInvoiceReductions[newerDocId] =
                    (middleInvoiceReductions[newerDocId] ?? 0.0) + take;
              }
            }

            if (dailyDoc != null) {
              Map<String, dynamic> dData =
                  dailyDoc.data() as Map<String, dynamic>;
              final newHistoryEntry = {
                'amount': take,
                'note':
                    note.isNotEmpty
                        ? note
                        : (type.toLowerCase() == 'eid_bonus'
                            ? "Eid Bonus Applied"
                            : (type.toLowerCase() == 'discount'
                                ? "Discount Applied"
                                : "Late Due Collection")),
                'timestamp': Timestamp.fromDate(date),
                'type': pType,
                'bkashNumber': bNum,
                'nagadNumber': nNum,
                'bankName': bankName,
                'accountNumber': accNum,
                'sourceTxId': finalTxId,
              };
              Map<String, dynamic> dailyUpdate = {
                "paid": currentPaidD + take,
                "pending": currentPendingD - take,
                "ledgerPaid": currentLedgerPaidD + take,
                "status": (currentPendingD - take) <= 0.5 ? "paid" : "partial",
                "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
                "paymentMethod.$pType": FieldValue.increment(take),
              };

              if (dData['name'] != debtorName) dailyUpdate['name'] = debtorName;
              if (pType == 'bkash' && bNum.isNotEmpty) {
                dailyUpdate["paymentMethod.bkashNumber"] = bNum;
              } else if (pType == 'nagad' && nNum.isNotEmpty) {
                dailyUpdate["paymentMethod.nagadNumber"] = nNum;
              } else if (pType == 'bank') {
                if (bankName.isNotEmpty) {
                  dailyUpdate["paymentMethod.bankName"] = bankName;
                }
                if (accNum.isNotEmpty) {
                  dailyUpdate["paymentMethod.accountNumber"] = accNum;
                }
              }
              batch.update(dailyDoc.reference, dailyUpdate);
            }
            hasUpdates = true;
            remainingToAllocate -= take;
          }

          if (middleInvoiceReductions.isNotEmpty) {
            middleInvoiceReductions.forEach((docId, totalTake) {
              batch.update(db.collection('sales_orders').doc(docId), {
                "snapshotRunningDue": FieldValue.increment(-totalTake),
              });
            });
            hasUpdates = true;
          }
          if (hasUpdates) await batch.commit();
        }
      }

      await _recalculateSingleDebtorBalance(debtorId);
      await loadBodies(loadMore: false);

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);

      if (Get.isRegistered<DailySalesController>()) {
        await Get.find<DailySalesController>().loadDailySales();
      }
      if (Get.isRegistered<OverviewController>()) {
        Get.find<OverviewController>().refreshData();
      }
      if (Get.isRegistered<CashDrawerController>()) {
        Get.find<CashDrawerController>().fetchData();
      }

      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Success",
        type.toLowerCase() == 'eid_bonus'
            ? "Eid Bonus Recorded Perfectly!"
            : (type.toLowerCase() == 'discount'
                ? "Discount Recorded Perfectly!"
                : "Collection Recorded & Bills Updated"),
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> deleteTransaction(String debtorId, String transactionId) async {
    gbIsLoading.value = true;
    try {
      DocumentSnapshot txSnap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc(transactionId)
              .get();
      if (!txSnap.exists) {
        gbIsLoading.value = false;
        return;
      }
      final txData = txSnap.data() as Map<String, dynamic>;
      final type = (txData['type'] ?? '').toString();
      final isInvoiceSale = (txData['note'] ?? '')
          .toString()
          .trim()
          .toLowerCase()
          .startsWith('invoice');
      DocumentSnapshot<Map<String, dynamic>>? saleOrderSnap;

      if (type == 'credit') {
        final invoiceId =
            (txData['transactionId'] ?? transactionId).toString().trim();
        if (invoiceId.isNotEmpty) {
          final directOrderSnap =
              await db.collection('sales_orders').doc(invoiceId).get();
          saleOrderSnap = directOrderSnap;

          if (!saleOrderSnap.exists) {
            final matchingOrders =
                await db
                    .collection('sales_orders')
                    .where('invoiceId', isEqualTo: invoiceId)
                    .limit(1)
                    .get();
            if (matchingOrders.docs.isNotEmpty) {
              saleOrderSnap = matchingOrders.docs.first;
            }
          }

          if (saleOrderSnap.exists) {
            final saleOrder = saleOrderSnap.data()!;
            final orderDebtorId = (saleOrder['debtorId'] ?? '').toString();
            if (orderDebtorId.isNotEmpty && orderDebtorId != debtorId) {
              throw StateError(
                'Invoice $invoiceId is not linked to this debtor account.',
              );
            }

            if (saleOrder['status'] != 'deleted') {
              final items = saleOrder['items'] as List<dynamic>? ?? [];
              final stockReturns = <Map<String, dynamic>>[];
              for (final item in items) {
                if (item is! Map) continue;
                final productId =
                    int.tryParse(
                      (item['productId'] ?? item['id'] ?? '').toString(),
                    ) ??
                    0;
                final quantity = (item['qty'] as num?)?.toInt() ?? 0;
                final costRate = (item['costRate'] as num?)?.toDouble() ?? 0.0;
                if (productId > 0 && quantity > 0) {
                  stockReturns.add({
                    'id': productId,
                    'sea_qty': quantity,
                    'air_qty': 0,
                    'local_qty': 0,
                    'local_price': costRate,
                  });
                }
              }

              if (stockReturns.isNotEmpty) {
                if (!Get.isRegistered<ProductController>()) {
                  throw StateError(
                    'Stock controller is unavailable; sale was not deleted.',
                  );
                }
                final stockRestored = await Get.find<ProductController>()
                    .bulkAddStockMixed(stockReturns);
                if (!stockRestored) {
                  throw StateError(
                    'Failed to restore sale stock; sale was not deleted.',
                  );
                }
              }
            }
          }
        }
        if (isInvoiceSale && (saleOrderSnap == null || !saleOrderSnap.exists)) {
          throw StateError(
            'Master invoice was not found; sale was not deleted.',
          );
        }
      }

      await db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId)
          .delete();

      QuerySnapshot lSnap =
          await db
              .collection('cash_ledger')
              .where('linkedTxId', isEqualTo: transactionId)
              .get();
      for (var doc in lSnap.docs) {
        await doc.reference.delete();
      }

      if (type == 'credit' ||
          type == 'debit' ||
          type == 'collection' ||
          type == 'payment' ||
          type == 'eid_bonus' ||
          type == 'discount') {
        if (!Get.isRegistered<DailySalesController>()) {
          Get.put(DailySalesController());
        }
        final daily = Get.find<DailySalesController>();
        final debtorSnap =
            await db.collection('debatorbody').doc(debtorId).get();
        final debtorName = debtorSnap.data()?['name'] ?? "";

        Map<String, DocumentSnapshot> dailyDocsToProcess = {};

        final salesByNameSnap =
            await db
                .collection('daily_sales')
                .where('name', isEqualTo: debtorName)
                .get();
        for (var doc in salesByNameSnap.docs) {
          dailyDocsToProcess[doc.id] = doc;
        }

        final ordersByIdSnap =
            await db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();
        List<String> orderTxIds = [];
        for (var doc in ordersByIdSnap.docs) {
          orderTxIds.add((doc.data() as Map)['invoiceId'] ?? doc.id);
        }

        for (int i = 0; i < orderTxIds.length; i += 10) {
          int end = i + 10 > orderTxIds.length ? orderTxIds.length : i + 10;
          List<String> chunk = orderTxIds.sublist(i, end);
          if (chunk.isNotEmpty) {
            final chunkSnap =
                await db
                    .collection('daily_sales')
                    .where('transactionId', whereIn: chunk)
                    .get();
            for (var doc in chunkSnap.docs) {
              dailyDocsToProcess[doc.id] = doc;
            }
          }
        }

        final batch = db.batch();

        for (final doc in dailyDocsToProcess.values) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['transactionId'] == transactionId) {
            batch.delete(doc.reference);
          } else {
            List history = List.from(data['paymentHistory'] ?? []);
            bool changed = false;
            double amountReversed = 0.0;
            String reversedType = 'cash';

            history.removeWhere((h) {
              if (h['sourceTxId'] == transactionId) {
                amountReversed += (h['amount'] as num).toDouble();
                reversedType = (h['type'] ?? 'cash').toString().toLowerCase();
                changed = true;
                return true;
              }
              return false;
            });

            if (changed) {
              double currentPaid = (data['paid'] as num).toDouble();
              double currentPending = (data['pending'] as num).toDouble();
              double newPaid = (currentPaid - amountReversed).clamp(
                0,
                double.infinity,
              );

              batch.update(doc.reference, {
                'paid': newPaid,
                'pending': currentPending + amountReversed,
                'paymentHistory': history,
                'status': 'partial',
                'paymentMethod.$reversedType': FieldValue.increment(
                  -amountReversed,
                ),
              });

              String saleTxId = data['transactionId'] ?? '';
              if (saleTxId.isNotEmpty) {
                DocumentReference orderRef = db
                    .collection('sales_orders')
                    .doc(saleTxId);
                final orderSnapshot = await orderRef.get();
                final orderData =
                    orderSnapshot.data() as Map<String, dynamic>? ?? {};
                final orderUpdate = <String, dynamic>{
                  "paid": FieldValue.increment(-amountReversed),
                  "paymentDetails.due": FieldValue.increment(amountReversed),
                  "paymentDetails.$reversedType": FieldValue.increment(
                    -amountReversed,
                  ),
                  "isFullyPaid": false,
                  "status": "completed",
                };
                if (currentPending + amountReversed > 0.5) {
                  orderUpdate.addAll(
                    PaidInvoiceRunningDueSnapshot.restoreIfUnpaid(orderData),
                  );
                }
                batch.update(orderRef, orderUpdate);
              }
            }
          }
        }
        await batch.commit();
        await daily.loadDailySales();
      }

      if (saleOrderSnap != null && saleOrderSnap.exists) {
        final invoiceId =
            (saleOrderSnap.data()?['invoiceId'] ?? saleOrderSnap.id).toString();
        final batch = db.batch();
        batch.delete(saleOrderSnap.reference);
        batch.delete(
          db.collection('debtor_transaction_history').doc(invoiceId),
        );
        await batch.commit();
      }

      await _recalculateSingleDebtorBalance(debtorId);

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);
      await loadBodies();

      Get.snackbar("Deleted", "Transaction removed & Balance corrected");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> editTransaction({
    required String debtorId,
    required String transactionId,
    required double oldAmount,
    required double newAmount,
    required String oldType,
    required String newType,
    required String note,
    required DateTime date,
    required Map<String, dynamic> paymentMethod,
  }) async {
    gbIsLoading.value = true;
    try {
      Map<String, dynamic>? finalPaymentMethod = paymentMethod;
      if (['credit', 'previous_due'].contains(newType.toLowerCase())) {
        finalPaymentMethod = null;
      }

      await db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(transactionId)
          .update({
            'amount': newAmount,
            'type': newType,
            'note': note,
            'date': Timestamp.fromDate(date),
            'paymentMethod': finalPaymentMethod,
          });

      await _recalculateSingleDebtorBalance(debtorId);

      QuerySnapshot lSnap =
          await db
              .collection('cash_ledger')
              .where('linkedTxId', isEqualTo: transactionId)
              .get();
      for (var d in lSnap.docs) {
        String method = (paymentMethod['type'] ?? 'cash').toString();
        if (method == 'cash' && paymentMethod.containsKey('bankName')) {
          method = 'Bank';
        }
        await d.reference.update({
          'amount': newAmount,
          'details': paymentMethod,
          'method': method,
          'bankName': paymentMethod['bankName'],
          'accountNo': paymentMethod['accountNumber'],
        });
      }

      txPageCursors = [null];
      currentTxPage.value = 1;
      hasMoreTx.value = true;
      await loadTxPage(debtorId, 1);
      await loadBodies();

      Get.back();
      Get.snackbar("Success", "Updated successfully");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> deleteDebtor(String id) async {
    gbIsLoading.value = true;
    try {
      final txSnap =
          await db
              .collection('debatorbody')
              .doc(id)
              .collection('transactions')
              .get();
      WriteBatch batch = db.batch();
      int count = 0;
      for (var doc in txSnap.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 490) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      batch.delete(db.collection('debatorbody').doc(id));
      await batch.commit();

      bodies.removeWhere((element) => element.id == id);
      filteredBodies.removeWhere(
        (element) => element.id == id && element.isAgent,
      );

      calculateTotalOutstanding();
      Get.snackbar("Success", "Debtor account deleted successfully.");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete debtor: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> _generateGeneralReport({
    required String title,
    required bool isPayable,
    String reportType = 'both', // agent / regular / both
  }) async {
    gbIsLoading.value = true;

    try {
      final List<DebtorModel> targetDebtors = [];

      // =========================
      // PAYABLE REPORT
      // Only agent/vendor payable comes from debatorbody.purchaseDue
      // =========================
      if (isPayable) {
        final snap = await db.collection('debatorbody').get();

        final allDebtors =
            snap.docs
                .map((d) {
                  try {
                    return DebtorModel.fromFirestore(d);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<DebtorModel>()
                .toList();

        targetDebtors.addAll(
          allDebtors.where((d) => d.purchaseDue > 0.01).toList(),
        );
      } else {
        // =========================
        // AGENT RECEIVABLE DUE
        // Source: debatorbody.balance
        // =========================
        if (reportType == 'agent' || reportType == 'both') {
          final agentSnap = await db.collection('debatorbody').get();

          final agentDebtors =
              agentSnap.docs
                  .map((d) {
                    try {
                      return DebtorModel.fromFirestore(d);
                    } catch (e) {
                      return null;
                    }
                  })
                  .whereType<DebtorModel>()
                  .where((d) => d.balance > 0.01)
                  .toList();

          targetDebtors.addAll(agentDebtors);
        }

        // =========================
        // WHOLESALE / VIP RECEIVABLE DUE
        // Source: actual pending daily_sales invoices
        // This avoids stale customers.currentDue problems.
        // =========================
        if (reportType == 'regular' || reportType == 'both') {
          final dueSalesSnap =
              await db
                  .collection('daily_sales')
                  .where('pending', isGreaterThan: 0.5)
                  .get();
          final regularDueSales =
              dueSalesSnap.docs
                  .where((doc) {
                    final type =
                        (doc.data()['customerType'] ?? '')
                            .toString()
                            .toUpperCase();
                    return type == 'WHOLESALE' || type == 'VIP';
                  })
                  .map((doc) => {'_docId': doc.id, ...doc.data()})
                  .toList();
          final conditionInvoiceIds = await _getConditionCourierInvoiceIds(
            regularDueSales,
          );

          final Map<String, DebtorModel> grouped = {};

          for (var doc in dueSalesSnap.docs) {
            final data = doc.data();
            final type = (data['customerType'] ?? '').toString().toUpperCase();

            if (type != 'WHOLESALE' && type != 'VIP') continue;
            if (_isConditionCourierInvoice({
              '_docId': doc.id,
              ...data,
            }, conditionInvoiceIds)) {
              continue;
            }

            final name = (data['name'] ?? '').toString().trim();
            final phone = (data['customerPhone'] ?? '').toString().trim();
            final pending = (data['pending'] as num?)?.toDouble() ?? 0.0;

            if (name.isEmpty || pending <= 0.5) continue;

            final key = phone.isNotEmpty ? phone : '$type-$name';
            final existing = grouped[key];

            grouped[key] = DebtorModel(
              id: phone.isNotEmpty ? phone : key,
              name: name,
              des: existing?.des ?? '',
              nid: '',
              phone: phone,
              address: existing?.address ?? '',
              payments: const [],
              balance: (existing?.balance ?? 0.0) + pending,
              purchaseDue: 0.0,
              lastTransactionDate:
                  data['timestamp'] is Timestamp
                      ? (data['timestamp'] as Timestamp).toDate()
                      : existing?.lastTransactionDate,
              sourceType: DebtorSourceType.regular,
              customerCategory: type,
            );
          }

          targetDebtors.addAll(grouped.values);
        }
      }

      if (targetDebtors.isEmpty) {
        Get.snackbar("Info", "No data to print.");
        return;
      }

      targetDebtors.sort((a, b) {
        final av = isPayable ? a.purchaseDue : a.balance;
        final bv = isPayable ? b.purchaseDue : b.balance;
        return bv.compareTo(av);
      });

      double grandTotal = 0.0;
      for (var d in targetDebtors) {
        grandTotal += isPayable ? d.purchaseDue : d.balance;
      }

      final pdf = pw.Document();
      final fontReg = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header:
              (context) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                        style: pw.TextStyle(font: fontReg, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                ],
              ),
          build:
              (context) => [
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: ["SL", "Type", "Name", "Phone", "Amount"],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(1.4),
                    2: const pw.FlexColumnWidth(3.5),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                  },
                  data: List<List<String>>.generate(targetDebtors.length, (
                    idx,
                  ) {
                    final d = targetDebtors[idx];

                    final String typeLabel =
                        isPayable
                            ? "PAYABLE"
                            : d.isAgent
                            ? "AGENT"
                            : (d.customerCategory ?? "CUSTOMER").toUpperCase();

                    return [
                      "${idx + 1}",
                      typeLabel,
                      d.name,
                      d.phone,
                      bdCurrency.format(isPayable ? d.purchaseDue : d.balance),
                    ];
                  }),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue300),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            "GRAND TOTAL:",
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            "${bdCurrency.format(grandTotal)} BDT",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Error generating PDF: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  void _silentAutoRepair() async {
    try {
      final snap = await db.collection('debatorbody').get();
      final batch = db.batch();
      bool needsUpdate = false;
      for (var doc in snap.docs) {
        if (!(doc.data() as Map).containsKey('balance') ||
            !(doc.data() as Map).containsKey('purchaseDue')) {
          needsUpdate = true;
          batch.update(doc.reference, {
            if (!(doc.data() as Map).containsKey('balance')) 'balance': 0.0,
            if (!(doc.data() as Map).containsKey('purchaseDue'))
              'purchaseDue': 0.0,
          });
        }
      }
      if (needsUpdate) await batch.commit();
    } catch (e) {
      AppLogger.i(e.toString());
    }
  }

  String _formatMethodForPdf(dynamic pm, [String? txType]) {
    if (txType != null &&
        ['credit', 'previous_due'].contains(txType.toLowerCase())) {
      return "-";
    }
    if (pm == null) return "Cash";
    if (pm is String) return pm;
    if (pm is Map) {
      String type = (pm['type'] ?? 'Cash').toString();
      String lowerType = type.toLowerCase();
      if (lowerType == 'eid_bonus') return "Eid Bonus";
      if (lowerType == 'discount') return "Discount";
      bool hasBank =
          pm.containsKey('bankName') &&
          pm['bankName'].toString().trim().isNotEmpty;
      if (lowerType == 'cash' && hasBank) return "Bank: ${pm['bankName']}";
      if (lowerType == 'bank') {
        return hasBank ? "Bank: ${pm['bankName']}" : "Bank";
      }
      if (lowerType.contains('bkash')) return "Bkash";
      if (lowerType.contains('nagad')) return "Nagad";
      if (lowerType.contains('rocket')) return "Rocket";
      return type.toUpperCase();
    }
    return "Cash";
  }

  // --- INDIVIDUAL DEBTOR STATEMENT (FIXED LIFETIME TOTALS) ---
  Future<void> downloadFullDebtorStatement(
    String debtorId,
    String debtorName,
  ) async {
    gbIsLoading.value = true;
    try {
      // 1. FETCH ALL TRANSACTIONS (To calculate accurate All-Time Totals)
      final allSnap =
          await db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .get();

      if (allSnap.docs.isEmpty) {
        Get.snackbar("Info", "No transactions found to print.");
        return;
      }

      double allTimeDebit = 0.0;
      double allTimeCredit = 0.0;
      List<Map<String, dynamic>> allTransactions = [];

      for (var doc in allSnap.docs) {
        final data = doc.data();
        allTransactions.add(data);

        String type = (data['type'] ?? '').toString().toLowerCase();
        bool isDebit = [
          'credit',
          'previous_due',
          'advance_given',
        ].contains(type);
        double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (isDebit) {
          allTimeDebit += amount;
        } else {
          allTimeCredit += amount;
        }
      }

      // 2. FILTER FOR PDF ROWS (Based on selected Date Range)
      List<Map<String, dynamic>> pdfTransactions = List.from(allTransactions);

      if (selectedDateRange.value != null) {
        DateTime start = selectedDateRange.value!.start;
        DateTime end = selectedDateRange.value!.end;

        DateTime normalizedStart = DateTime(
          start.year,
          start.month,
          start.day,
          0,
          0,
          0,
        );
        DateTime normalizedEnd = DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
        );

        pdfTransactions =
            allTransactions.where((t) {
              DateTime tDate =
                  (t['date'] is Timestamp)
                      ? (t['date'] as Timestamp).toDate()
                      : t['date'];
              return tDate.isAfter(
                    normalizedStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  tDate.isBefore(normalizedEnd.add(const Duration(seconds: 1)));
            }).toList();
      }

      // 3. GENERATE PDF (Pass both the filtered rows AND the all-time totals)
      final pdfBytes = await generatePDF(
        debtorName,
        pdfTransactions,
        allTimeDebit,
        allTimeCredit,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${debtorName.replaceAll(' ', '_')}_Statement.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate full PDF: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  // --- PDF GENERATOR (Accepts lifetime totals as parameters) ---
  Future<Uint8List> generatePDF(
    String debtorName,
    List<Map<String, dynamic>> transactions,
    double totalDebit, // NEW PARAM: Lifetime Debit
    double totalCredit, // NEW PARAM: Lifetime Credit
  ) async {
    final pdf = pw.Document();
    final fontReg = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    // Sort Chronologically for PDF rows
    transactions.sort((a, b) {
      DateTime dA =
          (a['date'] is Timestamp)
              ? (a['date'] as Timestamp).toDate()
              : (a['date'] as DateTime);
      DateTime dB =
          (b['date'] is Timestamp)
              ? (b['date'] as Timestamp).toDate()
              : (b['date'] as DateTime);
      return dA.compareTo(dB);
    });

    // Calculate Net Balance from Lifetime Totals
    double netBalance = totalDebit - totalCredit;
    String balanceLabel =
        netBalance > 0
            ? "Due Balance"
            : (netBalance < 0 ? "Advance Balance" : "Net Balance");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "STATEMENT OF ACCOUNT",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Account Name: $debtorName",
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                          style: pw.TextStyle(font: fontReg, fontSize: 10),
                        ),
                        pw.Text(
                          "Page ${context.pageNumber} of ${context.pagesCount}",
                          style: pw.TextStyle(font: fontReg, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 15),
              ],
            ),
        build:
            (context) => [
              if (transactions.isEmpty)
                pw.Center(
                  child: pw.Text(
                    "No transactions found in this date range.",
                    style: pw.TextStyle(font: fontReg, fontSize: 12),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: [
                    "Date",
                    "Description",
                    "Payment Method",
                    "Debit",
                    "Credit",
                  ],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                  },
                  data:
                      transactions.map((t) {
                        DateTime date =
                            (t['date'] is Timestamp)
                                ? (t['date'] as Timestamp).toDate()
                                : t['date'];
                        String type =
                            (t['type'] ?? '').toString().toLowerCase();
                        bool isDebit = [
                          'credit',
                          'previous_due',
                          'advance_given',
                        ].contains(type);
                        double amount =
                            (t['amount'] as num?)?.toDouble() ?? 0.0;
                        String method = _formatMethodForPdf(
                          t['paymentMethod'],
                          type,
                        );

                        String desc =
                            isDebit
                                ? "DEBIT"
                                : (type == 'eid_bonus'
                                    ? "EID BONUS"
                                    : (type == 'discount'
                                        ? "DISCOUNT"
                                        : "CREDIT"));
                        if (t['note'] != null &&
                            t['note'].toString().trim().isNotEmpty) {
                          desc += "\nNote: ${t['note']}";
                        }

                        return [
                          DateFormat('dd/MM/yyyy').format(date),
                          desc,
                          method,
                          isDebit ? bdCurrency.format(amount) : "-",
                          !isDebit ? bdCurrency.format(amount) : "-",
                        ];
                      }).toList(),
                ),

              pw.SizedBox(height: 20),

              // Summary Block (Uses Lifetime Totals!)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue400),
                  color: PdfColors.blue50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfStat(
                      "All-Time Debit",
                      totalDebit,
                      PdfColors.red900,
                      fontReg,
                      fontBold,
                    ),
                    _pdfStat(
                      "All-Time Credit",
                      totalCredit,
                      PdfColors.green900,
                      fontReg,
                      fontBold,
                    ),
                    _pdfStat(
                      balanceLabel,
                      netBalance.abs(),
                      PdfColors.blue900,
                      fontReg,
                      fontBold,
                    ),
                  ],
                ),
              ),

              // Signatures
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Prepared By",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Authorized Signature",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
      ),
    );

    return pdf.save();
  }

  // --- EID BONUS REPORT (UPGRADED) ---
  Future<void> downloadYearlyEidBonusReport() async {
    gbIsLoading.value = true;
    try {
      DateTime now = DateTime.now();
      DateTime startOfYear = DateTime(now.year, 1, 1);
      DateTime endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

      QuerySnapshot debtorSnap = await db.collection('debatorbody').get();
      Map<String, Map<String, dynamic>> debtorDataMap = {};
      for (var d in debtorSnap.docs) {
        debtorDataMap[d.id] = d.data() as Map<String, dynamic>;
      }

      List<Map<String, dynamic>> yearlyBonuses = [];
      double totalBonus = 0.0;

      QuerySnapshot txSnap =
          await db
              .collectionGroup('transactions')
              .where('type', isEqualTo: 'eid_bonus')
              .get();

      for (var doc in txSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime date =
            (data['date'] is Timestamp)
                ? (data['date'] as Timestamp).toDate()
                : (data['date'] as DateTime);
        if (date.isAfter(startOfYear) && date.isBefore(endOfYear)) {
          String debtorId = doc.reference.parent.parent!.id;
          double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          yearlyBonuses.add({
            'date': date,
            'amount': amount,
            'note': data['note'] ?? '',
            'debtorName': debtorDataMap[debtorId]?['name'] ?? 'Unknown',
            'debtorPhone': debtorDataMap[debtorId]?['phone'] ?? 'Unknown',
          });
          totalBonus += amount;
        }
      }

      if (yearlyBonuses.isEmpty) {
        Get.snackbar("Info", "No Eid Bonus given in ${now.year}.");
        return;
      }
      yearlyBonuses.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      final pdf = pw.Document();
      final fontReg = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header:
              (context) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "EID BONUS REPORT - ${now.year}",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.Text(
                        "Generated: ${DateFormat('dd MMM yyyy').format(now)}",
                        style: pw.TextStyle(font: fontReg, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                ],
              ),
          build:
              (context) => [
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.green800,
                  ),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(font: fontReg, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  headers: [
                    "SL",
                    "Date",
                    "Debtor Name",
                    "Phone",
                    "Bonus Amount",
                  ],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  data: List<List<String>>.generate(yearlyBonuses.length, (
                    idx,
                  ) {
                    final b = yearlyBonuses[idx];
                    return [
                      "${idx + 1}",
                      DateFormat('dd/MM/yyyy').format(b['date'] as DateTime),
                      b['debtorName'],
                      b['debtorPhone'],
                      bdCurrency.format(b['amount']),
                    ];
                  }),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green300),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            "TOTAL BONUS GIVEN:",
                            style: pw.TextStyle(font: fontBold, fontSize: 10),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            "${bdCurrency.format(totalBonus)} BDT",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColors.green900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Eid_Bonus_Report_${now.year}.pdf',
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate report: $e");
    } finally {
      gbIsLoading.value = false;
    }
  }

  Future<void> downloadAllDebtorsReport({String reportType = 'both'}) async {
    await _generateGeneralReport(
      title:
          reportType == 'agent'
              ? "Agent Receivable Due Report"
              : reportType == 'regular'
              ? "Wholesale & VIP Receivable Due Report"
              : "All Receivable Due Report",
      isPayable: false,
      reportType: reportType,
    );
  }

  Future<void> downloadAllPayablesReport() async =>
      await _generateGeneralReport(
        title: "MARKET PAYABLE REPORT",
        isPayable: true,
      );

  pw.Widget _pdfStat(
    String label,
    double val,
    PdfColor col,
    pw.Font fontReg,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontReg,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          bdCurrency.format(val),
          style: pw.TextStyle(font: fontBold, fontSize: 14, color: col),
        ),
      ],
    );
  }
}
