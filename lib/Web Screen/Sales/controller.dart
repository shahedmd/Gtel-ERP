// ignore_for_file: deprecated_member_use, empty_catches, avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'model.dart';

class DailySalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxList<SaleModel> salesList = <SaleModel>[].obs;
  final RxList<SaleModel> filteredList = <SaleModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterQuery = "".obs;

  final RxDouble totalSales = 0.0.obs;
  final RxDouble paidAmount = 0.0.obs;
  final RxDouble debtorPending = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDailySales();
    ever(selectedDate, (_) => loadDailySales());
    ever(filterQuery, (_) => _applyFilter());
  }

  double _round(double val) {
    return double.parse(val.toStringAsFixed(2));
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
  }

  // ==========================================
  // 1. LOAD DATA
  // ==========================================
  Future<void> loadDailySales() async {
    isLoading.value = true;
    try {
      final start = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );
      final end = start.add(const Duration(days: 1));

      final snap =
          await _db
              .collection("daily_sales")
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(end))
              .orderBy("timestamp", descending: true)
              .get();

      salesList.value =
          snap.docs.map((doc) => SaleModel.fromFirestore(doc)).toList();
      _applyFilter();
      _computeTotals();
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void _applyFilter() {
    if (filterQuery.value.isEmpty) {
      filteredList.assignAll(salesList);
    } else {
      filteredList.assignAll(
        salesList.where((sale) {
          return sale.name.toLowerCase().contains(
                filterQuery.value.toLowerCase(),
              ) ||
              (sale.transactionId ?? "").toLowerCase().contains(
                filterQuery.value.toLowerCase(),
              );
        }).toList(),
      );
    }
  }

  void _computeTotals() {
    double total = 0.0;
    double paid = 0.0;
    double pending = 0.0;

    for (var s in salesList) {
      total += s.amount;
      paid += s.paid;
      if (s.customerType == "debtor") {
        pending += s.pending;
      }
    }

    totalSales.value = _round(total);
    paidAmount.value = _round(paid);
    debtorPending.value = _round(pending);
  }

  // ==========================================
  // 2. ADD SALE (UPDATED FOR PAYMENT DETAILS)
  // ==========================================
  /// [paymentMethod] expected structure:
  /// - Cash: {'type': 'cash', 'amount': 500}
  /// - Mobile: {'type': 'bkash', 'amount': 500, 'number': '017xx...'}
  /// - Bank: {'type': 'bank', 'amount': 500, 'bankName': 'City', 'accountNumber': '123'}
  Future<void> addSale({
    required String name,
    required double amount,
    required String customerType,
    required DateTime date,
    String source = "direct",
    bool isPaid = false,
    Map<String, dynamic>? paymentMethod,
    List<Map<String, dynamic>>? appliedDebits,
    String? transactionId,
  }) async {
    try {
      final paidPart = (customerType == "debtor" && !isPaid) ? 0.0 : amount;
      List<Map<String, dynamic>> initialHistory = [];

      // Only add to history if there is a payment
      if (paidPart > 0 && paymentMethod != null) {
        // We create a clean map to ensure no nulls are passed for details
        Map<String, dynamic> historyEntry = {
          'type': paymentMethod['type'] ?? 'cash',
          'amount': paidPart,
          'timestamp': Timestamp.fromDate(date),
        };

        // Add details if they exist
        if (paymentMethod.containsKey('number')) {
          historyEntry['number'] = paymentMethod['number'];
        }
        if (paymentMethod.containsKey('bankName')) {
          historyEntry['bankName'] = paymentMethod['bankName'];
        }
        if (paymentMethod.containsKey('accountNumber')) {
          historyEntry['accountNumber'] = paymentMethod['accountNumber'];
        }

        initialHistory.add(historyEntry);
      }

      final entry = {
        "name": name,
        "amount": _round(amount),
        "paid": _round(paidPart),
        "customerType": customerType,
        "timestamp": Timestamp.fromDate(date),
        // Save the current payment method details for quick access
        "paymentMethod": paymentMethod,
        "paymentHistory": initialHistory,
        "createdAt": FieldValue.serverTimestamp(),
        "source": source,
        "appliedDebits": appliedDebits ?? [],
        "transactionId": transactionId,
      };

      await _db.collection("daily_sales").add(entry);
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Error", "Failed to add sale: $e");
    }
  }

  // ==========================================
  // 3. APPLY DEBTOR PAYMENT (UPDATED)
  // ==========================================
  Future<void> applyDebtorPayment(
    String debtorName,
    double paymentAmount,
    Map<String, dynamic> paymentMethod, {
    required DateTime date,
    String? transactionId,
  }) async {
    try {
      double remaining = _round(paymentAmount);
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Fetch unpaid or partial debtor records for this day
      final snap =
          await _db
              .collection("daily_sales")
              .where("customerType", isEqualTo: "debtor")
              .where("name", isEqualTo: debtorName)
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(endOfDay))
              .orderBy("timestamp", descending: false)
              .get();

      final batch = _db.batch();

      // Distribute payment across existing entries
      for (var doc in snap.docs) {
        if (remaining <= 0) break;
        final data = doc.data();
        final double amt = (data['amount'] as num).toDouble();
        final double alreadyPaid = (data['paid'] as num).toDouble();
        final double due = _round(amt - alreadyPaid);

        if (due > 0) {
          final double toApply = remaining >= due ? due : remaining;
          List applied = List.from(data['appliedDebits'] ?? []);

          if (transactionId != null) {
            applied.add({"id": transactionId, "amount": toApply});
          }

          // Create detailed history entry
          final newHistoryEntry = {
            'type': paymentMethod['type'] ?? 'cash',
            'amount': toApply,
            'paidAt': Timestamp.now(),
            'appliedTo': doc.id,
            // Include details explicitly
            'number': paymentMethod['number'],
            'bankName': paymentMethod['bankName'],
            'accountNumber': paymentMethod['accountNumber'],
          };

          // Remove nulls just in case
          newHistoryEntry.removeWhere((key, value) => value == null);

          batch.update(doc.reference, {
            "paid": _round(alreadyPaid + toApply),
            "paymentMethod": paymentMethod, // Update latest method
            "lastPaymentAt": FieldValue.serverTimestamp(),
            "appliedDebits": applied,
            "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
          });
          remaining = _round(remaining - toApply);
        }
      }

      // If money is left over (Advance Payment), create a new entry
      if (remaining > 0) {
        await addSale(
          name: debtorName,
          amount: remaining,
          customerType: "debtor",
          isPaid: true,
          date: date,
          paymentMethod: paymentMethod, // Pass full details here
          source: "advance_payment",
          transactionId: transactionId,
          appliedDebits:
              transactionId != null
                  ? [
                    {"id": transactionId, "amount": remaining},
                  ]
                  : [],
        );
      }

      await batch.commit();
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Payment Error", "Could not process daily payment.");
    }
  }

  // ==========================================
  // 4. REVERSE PAYMENT
  // ==========================================
  Future<void> reverseDebtorPayment(
    String debtorName,
    double amount,
    DateTime date,
  ) async {
    try {
      final salesSnap =
          await _db
              .collection('daily_sales')
              .where('name', isEqualTo: debtorName)
              .where('customerType', isEqualTo: 'debtor')
              .orderBy('timestamp', descending: true)
              .get();

      double remainingToReverse = _round(amount);
      final batch = _db.batch();

      for (var doc in salesSnap.docs) {
        if (remainingToReverse <= 0) break;
        final data = doc.data();
        double currentPaid = _round((data['paid'] as num).toDouble());

        if (currentPaid > 0) {
          double toSubtract =
              remainingToReverse >= currentPaid
                  ? currentPaid
                  : remainingToReverse;
          toSubtract = _round(toSubtract);

          batch.update(doc.reference, {
            'paid': _round(currentPaid - toSubtract),
            'lastReversalAt': FieldValue.serverTimestamp(),
            'reversalHistory': FieldValue.arrayUnion([
              {
                'amount': toSubtract,
                'date': Timestamp.now(),
                'reason': 'Manual Reversal',
              },
            ]),
          });
          remainingToReverse = _round(remainingToReverse - toSubtract);
        }
      }
      await batch.commit();
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Reversal Error", e.toString());
    }
  }

  // ==========================================
  // 5. DELETE & RESTORE STOCK
  // ==========================================
  Future<void> deleteSale(String saleId) async {
    isLoading.value = true;
    try {
      DocumentSnapshot dailySnap =
          await _db.collection('daily_sales').doc(saleId).get();
      if (!dailySnap.exists) throw "Daily entry does not exist!";

      final saleData = dailySnap.data() as Map<String, dynamic>;
      String customerType =
          (saleData['customerType'] ?? '').toString().toLowerCase();

      if (customerType.contains('debtor')) {
        Get.snackbar(
          "Access Denied",
          "Debtor sales must be managed in the Debtor Ledger.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        isLoading.value = false;
        return;
      }

      String? invoiceId = saleData['transactionId'] ?? saleData['invoiceId'];

      if (invoiceId != null && invoiceId.isNotEmpty) {
        DocumentSnapshot invSnap =
            await _db.collection("sales_orders").doc(invoiceId).get();

        if (invSnap.exists) {
          final invData = invSnap.data() as Map<String, dynamic>;
          final List<dynamic> items = invData['items'] ?? [];

          // RESTORE STOCK
          if (invData['status'] != 'deleted') {
            List<Map<String, dynamic>> restockUpdates = [];
            for (var item in items) {
              String? pId = item['productId'] ?? item['id'];
              int qty = item['qty'] ?? 0;
              if (pId != null && qty > 0) {
                restockUpdates.add({'id': pId, 'qty': -qty});
              }
            }
            bool restockSuccess = await Get.find<ProductController>()
                .updateStockBulk(restockUpdates);
            if (!restockSuccess) {
              Get.snackbar(
                "Error",
                "Failed to restore stock. Sale not deleted.",
              );
              return;
            }
          }

          // DELETE
          await _db.runTransaction((transaction) async {
            DocumentReference invRef = _db
                .collection("sales_orders")
                .doc(invoiceId);
            transaction.delete(invRef);

            String? custPhone = invData['customerPhone'];
            if (custPhone != null && custPhone.isNotEmpty) {
              DocumentReference custHistRef = _db
                  .collection('customers')
                  .doc(custPhone)
                  .collection('orders')
                  .doc(invoiceId);
              transaction.delete(custHistRef);
            }
            transaction.delete(dailySnap.reference);
          });
        }
      } else {
        await dailySnap.reference.delete();
      }

      await loadDailySales();
      Get.snackbar(
        "Deleted",
        "Sale deleted & Stock restored.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not delete: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 6. FORMATTING (UPDATED FOR DETAILS)
  // ==========================================
  String formatPaymentMethod(dynamic pm) {
    if (pm == null || pm == "") return "CREDIT/DUE";
    if (pm is! Map) return pm.toString().toUpperCase();

    String type = (pm["type"] ?? "CASH").toString().toLowerCase();

    // 1. Handle Multi-Pay
    if (type == "multi") {
      List<String> parts = [];
      double cash = double.tryParse(pm['cash'].toString()) ?? 0;
      double bkash = double.tryParse(pm['bkash'].toString()) ?? 0;
      double nagad = double.tryParse(pm['nagad'].toString()) ?? 0;
      double bank = double.tryParse(pm['bank'].toString()) ?? 0;

      if (cash > 0) parts.add("Cash: ${cash.toStringAsFixed(0)}");
      if (bkash > 0) {
        String num = pm['bkashNumber'] ?? "";
        parts.add(
          num.isEmpty
              ? "Bkash: ${bkash.toStringAsFixed(0)}"
              : "Bkash($num): ${bkash.toStringAsFixed(0)}",
        );
      }
      if (nagad > 0) {
        String num = pm['nagadNumber'] ?? "";
        parts.add(
          num.isEmpty
              ? "Nagad: ${nagad.toStringAsFixed(0)}"
              : "Nagad($num): ${nagad.toStringAsFixed(0)}",
        );
      }
      if (bank > 0) {
        String bName = pm['bankName'] ?? "Bank";
        parts.add("$bName: ${bank.toStringAsFixed(0)}");
      }

      return parts.isEmpty ? "MULTI-PAY" : parts.join("\n");
    }

    // 2. Handle Single Payment Methods with details
    switch (type) {
      case "cash":
        return "CASH";

      case "bkash":
      case "nagad":
      case "rocket":
        // Look for 'number' or 'details'
        String number = (pm["number"] ?? pm["details"] ?? "").toString();
        return number.isEmpty
            ? type.toUpperCase()
            : "${type.toUpperCase()}\n($number)";

      case "bank":
        String bName = (pm["bankName"] ?? "BANK").toString();
        String acc = (pm["accountNumber"] ?? "").toString();

        if (bName != "BANK" && acc.isNotEmpty) {
          return "$bName\n($acc)";
        } else if (bName != "BANK") {
          return bName;
        } else if (acc.isNotEmpty) {
          return "BANK ($acc)";
        }
        return "BANK";

      default:
        return type.toUpperCase();
    }
  }

  // ==========================================
  // 7. PDF GENERATION
  // ==========================================
  Future<void> generateProfessionalPDF() async {
    final pdf = pw.Document();
    final dateStr = DateFormat("dd MMMM yyyy").format(selectedDate.value);
    final primaryColor = PdfColors.blue900;
    final listToPrint =
        filteredList.isEmpty && filterQuery.value.isEmpty
            ? salesList
            : filteredList;

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
                      "G-TEL ERP SALES SYSTEM",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        fontSize: 18,
                      ),
                    ),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(thickness: 1, color: primaryColor),
                pw.SizedBox(height: 10),
              ],
            ),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfStat("Total Sales", totalSales.value, PdfColors.black),
                    _pdfStat(
                      "Total Paid",
                      paidAmount.value,
                      PdfColors.green800,
                    ),
                    _pdfStat(
                      "Debtor Pending",
                      debtorPending.value,
                      PdfColors.red800,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  "Customer",
                  "Inv ID",
                  "Method",
                  "Amount",
                  "Paid",
                  "Pending",
                ],
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                ),
                cellHeight:
                    30, // Increased height for multiline payment details
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft, // Payment details left aligned
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
                data:
                    listToPrint
                        .map(
                          (s) => [
                            s.name,
                            s.transactionId ?? "-",
                            formatPaymentMethod(
                              s.paymentMethod,
                            ), // Handles \n automatically
                            s.amount.toStringAsFixed(2),
                            s.paid.toStringAsFixed(2),
                            s.pending.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfStat(String label, double val, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          "Tk ${val.toStringAsFixed(2)}",
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> reprintInvoice(String invoiceId) async {
    // ... (This method remains unchanged as it fetches from master record)
    isLoading.value = true;
    try {
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Error", "Invoice not found in master records.");
        return;
      }
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> items = data['items'] ?? [];
      Map<String, dynamic> payMap = data['paymentDetails'] ?? {};
      double getDouble(dynamic val) => double.tryParse(val.toString()) ?? 0.0;
      final pdf = pw.Document();
      final boldFont = await PdfGoogleFonts.nunitoBold();
      final regularFont = await PdfGoogleFonts.nunitoRegular();

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
                        "G-TEL",
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 24,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        data['status'] == 'returned_partial'
                            ? "INVOICE (UPDATED)"
                            : "INVOICE",
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 20,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Invoice ID: $invoiceId",
                          style: pw.TextStyle(font: regularFont),
                        ),
                        pw.Text(
                          "Date: ${data['date']}",
                          style: pw.TextStyle(font: regularFont),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Bill To:",
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.Text(
                          data['customerName'] ?? "",
                          style: pw.TextStyle(font: regularFont),
                        ),
                        pw.Text(
                          data['customerPhone'] ?? "",
                          style: pw.TextStyle(font: regularFont),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  cellStyle: pw.TextStyle(font: regularFont),
                  headers: ['Item / Model', 'Rate', 'Qty', 'Total'],
                  data:
                      items
                          .map(
                            (e) => [
                              e['name'],
                              getDouble(e['saleRate']).toStringAsFixed(2),
                              e['qty'].toString(),
                              getDouble(e['subtotal']).toStringAsFixed(2),
                            ],
                          )
                          .toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Grand Total",
                              style: pw.TextStyle(font: boldFont, fontSize: 16),
                            ),
                            pw.Text(
                              "Tk ${getDouble(data['grandTotal']).toStringAsFixed(2)}",
                              style: pw.TextStyle(font: boldFont, fontSize: 16),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Paid Amount",
                              style: pw.TextStyle(font: regularFont),
                            ),
                            pw.Text(
                              "Tk ${getDouble(payMap['actualReceived']).toStringAsFixed(2)}",
                              style: pw.TextStyle(font: regularFont),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (f) => pdf.save());
    } catch (e) {
      Get.snackbar("Error", "Could not reprint: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
