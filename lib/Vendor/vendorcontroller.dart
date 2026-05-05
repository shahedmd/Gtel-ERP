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
  // PROFESSIONAL VENDOR PDF (MULTIPAGE & FULL HISTORY SAFE)
  // ============================================================

  Future<void> generateVendorReport(VendorModel vendor) async {
    try {
      // 1. Show loading indicator while we fetch the full history
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // 2. Fetch ALL transactions for this vendor (ignoring pagination limits)
      QuerySnapshot snapshot =
          await _firestore
              .collection('vendors')
              .doc(vendor.docId)
              .collection('history')
              .orderBy('date', descending: false) // Fetch chronologically
              .get();

      Get.back(); // Close loading dialog

      if (snapshot.docs.isEmpty) {
        Get.snackbar("Info", "No transactions found to print for this vendor.");
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

      double totalDebit = 0.0;
      double totalCredit = 0.0;

      // 4. Calculate Totals
      for (var t in transactions) {
        bool isDebit = (t.type.toUpperCase() == 'CREDIT');
        double amount = t.amount;

        if (isDebit) {
          totalDebit += amount;
        } else {
          totalCredit += amount;
        }
      }

      double netBalance = totalDebit - totalCredit;
      String balanceLabel = "Net Balance";
      if (netBalance > 0) {
        balanceLabel = "Due Balance";
      } else if (netBalance < 0) {
        balanceLabel = "Advance Balance";
      }

      // Helper widget
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

      // 5. MultiPage builder ensures NO rows are ever missed.
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            // Repeats perfectly on every page
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
              // This table will auto-break onto new pages and repeat the header!
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
                data:
                    transactions.map((t) {
                      bool isDebit = (t.type.toUpperCase() == 'CREDIT');
                      String method = formatMethodForPdf(
                        t.paymentMethod,
                        t.type,
                      );

                      String desc = isDebit ? "DEBIT" : "CREDIT";
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

              // Summary block stays intact at the very end of the document
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
                    pdfStat("Total Debit", totalDebit, PdfColors.red900),
                    pdfStat("Total Credit", totalCredit, PdfColors.green900),
                    pdfStat(balanceLabel, netBalance.abs(), PdfColors.black),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Statement_${vendor.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(); // Close dialog if error occurs
      Get.snackbar("Error", "PDF Generation Failed: $e");
    }
  }
}
