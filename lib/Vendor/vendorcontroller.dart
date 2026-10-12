// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class VendorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<VendorModel> _allVendors = <VendorModel>[].obs;
  final RxList<VendorModel> vendors = <VendorModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  final int _itemsPerPage = 40;
  final RxInt currentVendorPage = 1.obs;
  final RxBool hasMoreVendors = false.obs;
  final RxList<VendorTransaction> currentTransactions =
      <VendorTransaction>[].obs;
  final RxBool isHistoryLoading = false.obs;
  final RxString currentTransFilter = 'All'.obs;
  DocumentSnapshot? _lastTransDoc;
  final List<DocumentSnapshot> _transPageStartDocs = [];
  final RxInt currentTransPage = 1.obs;
  final RxBool hasMoreTrans = true.obs;
  String? _activeVendorId;

  StreamSubscription? _vendorSub;

  @override
  void onInit() {
    super.onInit();
    bindVendors();
  }

  @override
  void onClose() {
    _vendorSub?.cancel();
    super.onClose();
  }

  void bindVendors() {
    isLoading.value = true;
    _vendorSub = _firestore
        .collection('vendors')
        .orderBy('name')
        .snapshots()
        .listen(
          (event) {
            _allVendors.value =
                event.docs.map((e) => VendorModel.fromSnapshot(e)).toList();
            _refreshVendorPage();
            isLoading.value = false;
          },
          onError: (e) {
            isLoading.value = false;
            debugPrint("Vendor Stream Error: $e");
          },
        );
  }

  void searchVendors(String query) {
    searchQuery.value = query;
    currentVendorPage.value = 1;
    _refreshVendorPage();
  }

  void nextVendorPage() {
    if (hasMoreVendors.value) {
      currentVendorPage.value++;
      _refreshVendorPage();
    }
  }

  void previousVendorPage() {
    if (currentVendorPage.value > 1) {
      currentVendorPage.value--;
      _refreshVendorPage();
    }
  }

  void _refreshVendorPage() {
    List<VendorModel> filtered =
        _allVendors.where((v) {
          return v.name.toLowerCase().contains(searchQuery.value.toLowerCase());
        }).toList();

    int totalItems = filtered.length;
    int startIndex = (currentVendorPage.value - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= totalItems) {
      startIndex = 0;
      currentVendorPage.value = 1;
    }
    if (endIndex > totalItems) endIndex = totalItems;

    vendors.value = filtered.sublist(startIndex, endIndex);
    hasMoreVendors.value = endIndex < totalItems;
  }

  void setTransactionFilter(String filter) {
    if (currentTransFilter.value == filter) return;
    currentTransFilter.value = filter;
    if (_activeVendorId != null) {
      loadHistoryInitial(_activeVendorId!);
    }
  }

  Future<void> loadHistoryInitial(String vendorId) async {
    _activeVendorId = vendorId;
    isHistoryLoading.value = true;
    currentTransPage.value = 1;
    _transPageStartDocs.clear();
    _lastTransDoc = null;
    currentTransactions.clear();

    try {
      Query query = _buildHistoryQuery(vendorId);
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastTransDoc = snapshot.docs.last;
        _transPageStartDocs.add(snapshot.docs.first);
        currentTransactions.value =
            snapshot.docs
                .map((e) => VendorTransaction.fromSnapshot(e))
                .toList();
        hasMoreTrans.value = snapshot.docs.length == _itemsPerPage;
      } else {
        hasMoreTrans.value = false;
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> nextHistoryPage() async {
    if (!hasMoreTrans.value ||
        isHistoryLoading.value ||
        _activeVendorId == null) {
      return;
    }
    isHistoryLoading.value = true;
    try {
      Query query = _buildHistoryQuery(
        _activeVendorId!,
      ).startAfterDocument(_lastTransDoc!);
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastTransDoc = snapshot.docs.last;
        _transPageStartDocs.add(snapshot.docs.first);
        currentTransactions.value =
            snapshot.docs
                .map((e) => VendorTransaction.fromSnapshot(e))
                .toList();
        currentTransPage.value++;
        hasMoreTrans.value = snapshot.docs.length == _itemsPerPage;
      } else {
        hasMoreTrans.value = false;
      }
    } catch (e) {
      debugPrint("Error next history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> previousHistoryPage() async {
    if (currentTransPage.value <= 1 ||
        isHistoryLoading.value ||
        _activeVendorId == null) {
      return;
    }
    isHistoryLoading.value = true;
    try {
      _transPageStartDocs.removeLast();
      DocumentSnapshot targetStartDoc = _transPageStartDocs.last;

      Query query = _buildHistoryQuery(
        _activeVendorId!,
      ).startAtDocument(targetStartDoc);
      QuerySnapshot snapshot = await query.get();

      _lastTransDoc = snapshot.docs.last;
      currentTransactions.value =
          snapshot.docs.map((e) => VendorTransaction.fromSnapshot(e)).toList();
      currentTransPage.value--;
      hasMoreTrans.value = true;
    } catch (e) {
      debugPrint("Error prev history: $e");
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Query _buildHistoryQuery(String vendorId) {
    Query query = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('history')
        .orderBy('date', descending: true);

    if (currentTransFilter.value == 'CREDIT') {
      query = query.where('type', isEqualTo: 'CREDIT');
    } else if (currentTransFilter.value == 'DEBIT') {
      query = query.where('type', isEqualTo: 'DEBIT');
    }

    return query.limit(_itemsPerPage);
  }

  // ===========================================================================
  // 3. WRITES (Add Vendor, Add/Edit/Delete Transaction)
  // ===========================================================================

  Future<void> addVendor(String name, String contact) async {
    try {
      await _firestore.collection('vendors').add({
        'name': name,
        'contact': contact,
        'totalDue': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.back();
      Get.snackbar(
        "Success",
        "Vendor Added Successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> addTransaction({
    required String vendorId,
    required String vendorName,
    required String type,
    required double amount,
    required DateTime date,
    String? paymentMethod,
    String? shipmentName,
    String? cartons,
    String? notes,
    bool isIncomingCash = false,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();
      WriteBatch batch = _firestore.batch();

      double amountChange = 0.0;
      if (isIncomingCash) {
        amountChange = amount;
      } else if (type == 'CREDIT') {
        amountChange = amount;
      } else {
        amountChange = -amount;
      }

      batch.update(vendorRef, {'totalDue': FieldValue.increment(amountChange)});
      batch.set(historyRef, {
        'type': isIncomingCash ? 'CREDIT' : type,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
        'shipmentName': shipmentName,
        'cartons': cartons,
        'notes': notes,
        'isIncomingCash': isIncomingCash,
      });

      await batch.commit();

      if (isIncomingCash) {
        await _ensureCashLedgerEntry(
          type: 'deposit',
          amount: amount,
          method: paymentMethod ?? 'Cash',
          desc: "Advance/Refund from Vendor: $vendorName",
          date: date,
        );
      } else if (type == 'DEBIT') {
        await _ensureCashLedgerEntry(
          type: 'withdraw',
          amount: amount,
          method: paymentMethod ?? 'Cash',
          desc: "Payment to $vendorName ($notes)",
          date: date,
        );
      }

      Get.back();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);

      Get.snackbar(
        "Success",
        "Transaction Recorded",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Transaction Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureCashLedgerEntry({
    required String type,
    required double amount,
    required String method,
    required String desc,
    required DateTime date,
  }) async {
    try {
      await _firestore.collection('cash_ledger').add({
        'type': type,
        'amount': amount,
        'method': method,
        'description': desc,
        'timestamp': Timestamp.fromDate(date),
        'source': 'vendor_transaction',
      });
    } catch (e) {
      debugPrint("Cash Ledger Error: $e");
    }
  }

  Future<void> deleteTransaction(
    String vendorId,
    VendorTransaction trans,
  ) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc(trans.id);

      String vName = "Vendor";
      try {
        vName = _allVendors.firstWhere((v) => v.docId == vendorId).name;
      } catch (_) {}

      WriteBatch batch = _firestore.batch();
      double reverseAmount = 0.0;

      if (trans.type == 'CREDIT') {
        reverseAmount = -trans.amount;
      } else {
        reverseAmount = trans.amount;
      }

      batch.delete(historyRef);
      batch.update(vendorRef, {
        'totalDue': FieldValue.increment(reverseAmount),
      });

      await batch.commit();

      if (trans.type == 'DEBIT' && !trans.isIncomingCash) {
        await _ensureCashLedgerEntry(
          type: 'deposit',
          amount: trans.amount,
          method: trans.paymentMethod ?? 'Cash',
          desc: "Reversal: Deleted payment to $vName",
          date: DateTime.now(),
        );
      } else if (trans.isIncomingCash) {
        await _ensureCashLedgerEntry(
          type: 'withdraw',
          amount: trans.amount,
          method: trans.paymentMethod ?? 'Cash',
          desc: "Reversal: Deleted advance from $vName",
          date: DateTime.now(),
        );
      }

      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);
      Get.back();
      Get.snackbar(
        "Success",
        "Transaction Deleted & Reversed",
        backgroundColor: Colors.grey,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Delete Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateTransaction({
    required String vendorId,
    required VendorTransaction oldTrans,
    required double newAmount,
    required DateTime newDate,
    required String newNotes,
  }) async {
    isLoading.value = true;
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc(oldTrans.id);

      String vName = "Vendor";
      try {
        vName = _allVendors.firstWhere((v) => v.docId == vendorId).name;
      } catch (_) {}

      WriteBatch batch = _firestore.batch();

      double balanceAdjustment = 0.0;
      double diff = newAmount - oldTrans.amount;

      if (oldTrans.type == 'CREDIT') {
        balanceAdjustment = diff;
      } else {
        balanceAdjustment = -diff;
      }

      batch.update(historyRef, {
        'amount': newAmount,
        'date': Timestamp.fromDate(newDate),
        'notes': newNotes,
      });

      if (balanceAdjustment != 0.0) {
        batch.update(vendorRef, {
          'totalDue': FieldValue.increment(balanceAdjustment),
        });
      }

      await batch.commit();

      if (diff != 0.0) {
        if (oldTrans.type == 'DEBIT' && !oldTrans.isIncomingCash) {
          if (diff > 0) {
            await _ensureCashLedgerEntry(
              type: 'withdraw',
              amount: diff,
              method: oldTrans.paymentMethod ?? 'Cash',
              desc: "Adjustment: Increased payment to $vName",
              date: DateTime.now(),
            );
          } else {
            await _ensureCashLedgerEntry(
              type: 'deposit',
              amount: diff.abs(),
              method: oldTrans.paymentMethod ?? 'Cash',
              desc: "Adjustment: Decreased payment to $vName",
              date: DateTime.now(),
            );
          }
        } else if (oldTrans.isIncomingCash) {
          if (diff > 0) {
            await _ensureCashLedgerEntry(
              type: 'deposit',
              amount: diff,
              method: oldTrans.paymentMethod ?? 'Cash',
              desc: "Adjustment: Increased advance from $vName",
              date: DateTime.now(),
            );
          } else {
            await _ensureCashLedgerEntry(
              type: 'withdraw',
              amount: diff.abs(),
              method: oldTrans.paymentMethod ?? 'Cash',
              desc: "Adjustment: Decreased advance from $vName",
              date: DateTime.now(),
            );
          }
        }
      }

      Get.back();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);

      Get.snackbar(
        "Success",
        "Transaction Updated & Ledger Adjusted",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Update Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addAutomatedShipmentCredit({
    required String vendorId,
    required double amount,
    required String shipmentName,
    required DateTime date,
  }) async {
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final historyRef = vendorRef.collection('history').doc();
      WriteBatch batch = _firestore.batch();

      batch.update(vendorRef, {'totalDue': FieldValue.increment(amount)});
      batch.set(historyRef, {
        'type': 'CREDIT',
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'paymentMethod': 'Stock Receive',
        'shipmentName': shipmentName,
        'cartons': 'N/A',
        'notes': 'Auto-entry from Shipment: $shipmentName',
        'isIncomingCash': false,
      });

      await batch.commit();
      if (_activeVendorId == vendorId) loadHistoryInitial(vendorId);
    } catch (e) {
      throw "Vendor Credit Failed: $e";
    }
  }

  // ============================================================
  // UPDATE / DELETE VENDOR
  // ============================================================

  Future<void> updateVendor({
    required String vendorId,
    required String name,
    required String contact,
  }) async {
    try {
      await _firestore.collection('vendors').doc(vendorId).update({
        'name': name,
        'contact': contact,
      });

      Get.back();

      Get.snackbar(
        "Updated",
        "Vendor information updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteVendor(String vendorId) async {
    try {
      final history =
          await _firestore
              .collection('vendors')
              .doc(vendorId)
              .collection('history')
              .limit(1)
              .get();

      if (history.docs.isNotEmpty) {
        Get.snackbar(
          "Blocked",
          "Vendor has transactions. Delete transactions first.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      await _firestore.collection('vendors').doc(vendorId).delete();

      Get.snackbar(
        "Deleted",
        "Vendor removed",
        backgroundColor: Colors.grey,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ============================================================
  // PROFESSIONAL VENDOR PDF (MULTIPAGE, DATE-RANGE FILTER & FIXED COLUMN WIDTHS)
  // ============================================================

  /// Generates a Statement of Account PDF for [vendor].
  /// Pass [startDate] and [endDate] to restrict the statement to that range
  /// (both inclusive). If either is null, the full history is used.
  Future<void> generateVendorReport(
    VendorModel vendor, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Show loading indicator while we fetch the history
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // 2. Build the query — optionally scoped to the selected date range
      Query historyQuery = _firestore
          .collection('vendors')
          .doc(vendor.docId)
          .collection('history')
          .orderBy('date', descending: false);

      if (startDate != null) {
        final DateTime dayStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        historyQuery = historyQuery.where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        );
      }

      if (endDate != null) {
        final DateTime dayEnd = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        );
        historyQuery = historyQuery.where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(dayEnd),
        );
      }

      QuerySnapshot snapshot = await historyQuery.get();

      Get.back(); // Close loading dialog

      if (snapshot.docs.isEmpty) {
        Get.snackbar(
          "Info",
          "No transactions found to print for this vendor${startDate != null || endDate != null ? ' in the selected date range' : ''}.",
        );
        return;
      }

      // 3. Map to model
      List<VendorTransaction> transactions =
          snapshot.docs.map((e) => VendorTransaction.fromSnapshot(e)).toList();

      final pdf = pw.Document();
      final NumberFormat bdCurrency = NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
        decimalDigits: 2,
      );

      double totalBills = 0.0;
      double totalPayments = 0.0;
      double totalAdvanceRefund = 0.0;

      // 4. Calculate Totals
      for (var t in transactions) {
        if (t.isIncomingCash) {
          totalAdvanceRefund += t.amount;
        } else if (t.type.toUpperCase() == 'CREDIT') {
          totalBills += t.amount;
        } else {
          totalPayments += t.amount;
        }
      }

      double netBalance = (totalBills + totalAdvanceRefund) - totalPayments;
      String balanceLabel = "Net Balance";
      if (netBalance > 0) {
        balanceLabel = "Due Balance";
      } else if (netBalance < 0) {
        balanceLabel = "Advance Balance";
      }

      String? rangeLabel;
      if (startDate != null && endDate != null) {
        rangeLabel =
            "Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}";
      } else if (startDate != null) {
        rangeLabel = "From: ${DateFormat('dd MMM yyyy').format(startDate)}";
      } else if (endDate != null) {
        rangeLabel = "Up to: ${DateFormat('dd MMM yyyy').format(endDate)}";
      }

      pw.Widget pdfStat(String label, double amount, PdfColor color) {
        return pw.Column(
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              bdCurrency.format(amount),
              style: pw.TextStyle(
                color: color,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        );
      }

      String formatMethodForPdf(String? method, String type) {
        if (method == null || method.isEmpty) return "-";
        return method;
      }

      // 'bill'            -> goods purchased / manually added bill
      // 'payment'         -> paid to vendor
      // 'advance_refund'  -> advance or refund received FROM the vendor
      String transactionCategory(VendorTransaction t) {
        if (t.isIncomingCash) return 'advance_refund';
        return (t.type.toUpperCase() == 'CREDIT') ? 'bill' : 'payment';
      }

      String transactionTypeLabel(String category) {
        switch (category) {
          case 'bill':
            return "BILL";
          case 'advance_refund':
            return "ADVANCE/REFUND";
          default:
            return "PAYMENT";
        }
      }

      // 5. MultiPage builder
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            return pw.Column(
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
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Account Name: ${vendor.name}",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (rangeLabel != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            rangeLabel,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          "Page ${context.pageNumber} of ${context.pagesCount}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            );
          },
          build: (context) {
            return [
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerHeight: 28,
                cellHeight: 25,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.3), // Date
                  1: const pw.FlexColumnWidth(2.8), // Description
                  2: const pw.FlexColumnWidth(1.4), // Payment Method
                  3: const pw.FlexColumnWidth(1.3), // Debit
                  4: const pw.FlexColumnWidth(1.3), // Credit
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: [
                  "Date",
                  "Description",
                  "Payment Method",
                  "Debit",
                  "Credit",
                ],
                // Debit column  : Bill (red) + Advance/Refund (blue)
                // Credit column : Payment (green)
                cellDecoration: (int columnIndex, dynamic data, int rowNum) {
                  final int dataIndex = rowNum - 1; // headerCount == 1
                  if ((columnIndex != 3 && columnIndex != 4) ||
                      dataIndex < 0 ||
                      dataIndex >= transactions.length) {
                    return const pw.BoxDecoration();
                  }
                  final String category = transactionCategory(
                    transactions[dataIndex],
                  );
                  if (columnIndex == 3 && category == 'bill') {
                    return const pw.BoxDecoration(color: PdfColors.red50);
                  }
                  if (columnIndex == 3 && category == 'advance_refund') {
                    return const pw.BoxDecoration(color: PdfColors.blue50);
                  }
                  if (columnIndex == 4 && category == 'payment') {
                    return const pw.BoxDecoration(color: PdfColors.green50);
                  }
                  return const pw.BoxDecoration();
                },
                data:
                    transactions.map((t) {
                      final String category = transactionCategory(t);
                      // Bill AND Advance/Refund both go in the Debit column
                      final bool isDebit =
                          category == 'bill' || category == 'advance_refund';
                      String method = formatMethodForPdf(
                        t.paymentMethod,
                        t.type,
                      );

                      String desc = transactionTypeLabel(category);
                      if (t.shipmentName != null &&
                          t.shipmentName!.trim().isNotEmpty) {
                        desc += "\n${t.shipmentName}";
                      }
                      if (t.notes != null && t.notes!.trim().isNotEmpty) {
                        desc += "\nNote: ${t.notes}";
                      }

                      return [
                        DateFormat('dd/MM/yyyy').format(t.date),
                        desc,
                        method,
                        isDebit ? bdCurrency.format(t.amount) : "",
                        !isDebit ? bdCurrency.format(t.amount) : "",
                      ];
                    }).toList(),
              ),

              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  color: PdfColors.grey50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pdfStat("Total Bills", totalBills, PdfColors.red900),
                    pdfStat(
                      "Total Payments",
                      totalPayments,
                      PdfColors.green900,
                    ),
                    pdfStat(
                      "Advance/Refund",
                      totalAdvanceRefund,
                      PdfColors.blue900,
                    ),
                    pdfStat(balanceLabel, netBalance.abs(), PdfColors.black),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final String fileSuffix =
          (startDate != null && endDate != null)
              ? '_${DateFormat('ddMMyyyy').format(startDate)}-${DateFormat('ddMMyyyy').format(endDate)}'
              : '';

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Statement_${vendor.name.replaceAll(' ', '_')}$fileSuffix.pdf',
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Error", "PDF Generation Failed: $e");
    }
  }

  /// Convenience wrapper: opens a date-range picker dialog, then generates
  /// the statement for the selected range. Call this directly from a button
  /// (e.g. onPressed: () => controller.pickRangeAndGenerateReport(vendor)).
  Future<void> pickRangeAndGenerateReport(
    VendorModel vendor, {
    BuildContext? context,
  }) async {
    final BuildContext ctx = context ?? Get.context!;
    final DateTimeRange? picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked == null) return; // User cancelled

    await generateVendorReport(
      vendor,
      startDate: picked.start,
      endDate: picked.end,
    );
  }
}
