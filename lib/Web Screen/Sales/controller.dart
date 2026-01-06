// ignore_for_file: deprecated_member_use, empty_catches
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'model.dart';

class DailySalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Observables
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxList<SaleModel> salesList = <SaleModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterQuery = "".obs;

  // Computed Totals
  final RxDouble totalSales = 0.0.obs;
  final RxDouble paidAmount = 0.0.obs;
  final RxDouble debtorPending = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDailySales();
    ever(selectedDate, (_) => loadDailySales());
  }

  // 1. CHANGE DATE
  void changeDate(DateTime date) {
    selectedDate.value = date;
  }

  // 2. LOAD SALES
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
          snap.docs.map((doc) {
            return SaleModel.fromFirestore(doc);
          }).toList();
      _computeTotals();
    } finally {
      isLoading.value = false;
    }
  }

  // 3. REVERSE DEBTOR PAYMENT
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

      double remainingToReverse = amount;
      final batch = _db.batch();

      for (var doc in salesSnap.docs) {
        if (remainingToReverse <= 0) break;

        final data = doc.data();
        double currentPaid = (data['paid'] as num).toDouble();

        if (currentPaid > 0) {
          double toSubtract =
              remainingToReverse >= currentPaid
                  ? currentPaid
                  : remainingToReverse;
          batch.update(doc.reference, {
            'paid': currentPaid - toSubtract,
            'lastReversalAt': FieldValue.serverTimestamp(),
          });
          remainingToReverse -= toSubtract;
        }
      }
      await batch.commit();
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Reversal Error", e.toString());
    }
  }

  // 4. COMPUTE TOTALS
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

    totalSales.value = total;
    paidAmount.value = paid;
    debtorPending.value = pending;
  }

  // 5. ADD SALE
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

      final entry = {
        "name": name,
        "amount": amount,
        "paid": paidPart,
        "customerType": customerType,
        "timestamp": Timestamp.fromDate(date),
        "paymentMethod": paymentMethod,
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

  // 6. APPLY DEBTOR PAYMENT
  Future<void> applyDebtorPayment(
    String debtorName,
    double paymentAmount,
    Map<String, dynamic> paymentMethod, {
    required DateTime date,
    String? transactionId,
  }) async {
    try {
      double remaining = paymentAmount;
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

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

      for (var doc in snap.docs) {
        if (remaining <= 0) break;

        final data = doc.data();
        final double amt = (data['amount'] as num).toDouble();
        final double alreadyPaid = (data['paid'] as num).toDouble();
        final double due = amt - alreadyPaid;

        if (due > 0) {
          final double toApply = remaining >= due ? due : remaining;
          List applied = List.from(data['appliedDebits'] ?? []);

          if (transactionId != null) {
            applied.add({"id": transactionId, "amount": toApply});
          }

          batch.update(doc.reference, {
            "paid": alreadyPaid + toApply,
            "paymentMethod": paymentMethod,
            "lastPaymentAt": FieldValue.serverTimestamp(),
            "appliedDebits": applied,
          });
          remaining -= toApply;
        }
      }

      if (remaining > 0) {
        await addSale(
          name: debtorName,
          amount: remaining,
          customerType: "debtor",
          isPaid: true,
          date: date,
          paymentMethod: paymentMethod,
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

  // 7. DELETE SALE & DELETE ENTIRE ORDER DOCUMENT
  Future<void> deleteSale(String saleId) async {
    isLoading.value = true;
    try {
      DocumentSnapshot saleSnap =
          await _db.collection("daily_sales").doc(saleId).get();

      if (!saleSnap.exists) {
        await loadDailySales();
        return;
      }

      final saleData = saleSnap.data() as Map<String, dynamic>;
      String? invoiceId = saleData['transactionId'] ?? saleData['invoiceId'];

      await _db.runTransaction((transaction) async {
        // 1. Delete Daily Sales
        transaction.delete(_db.collection("daily_sales").doc(saleId));

        // 2. Delete Master Sales Order (P&L Data)
        if (invoiceId != null && invoiceId.isNotEmpty) {
          transaction.delete(_db.collection("sales_orders").doc(invoiceId));
        }

        // 3. Delete Customer's copy (Legacy)
        // We skip searching every subcollection for performance,
        // assuming Master Record is what matters for P&L.
      });

      await loadDailySales();
      Get.snackbar(
        "Deleted",
        "Sale removed from Daily and P&L records.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Could not delete: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // 8. FORMAT PAYMENT METHOD
  String formatPaymentMethod(dynamic pm) {
    if (pm == null || pm == "") return "CREDIT/DUE";
    if (pm is! Map) return pm.toString().toUpperCase();

    String type = (pm["type"] ?? "CASH").toString().toLowerCase();

    if (type == "multi") {
      List<String> parts = [];
      double cash = double.tryParse(pm['cash'].toString()) ?? 0;
      double bkash = double.tryParse(pm['bkash'].toString()) ?? 0;
      double nagad = double.tryParse(pm['nagad'].toString()) ?? 0;
      double bank = double.tryParse(pm['bank'].toString()) ?? 0;

      if (cash > 0) parts.add("Cash: ${cash.toStringAsFixed(0)}");
      if (bkash > 0) parts.add("Bkash: ${bkash.toStringAsFixed(0)}");
      if (nagad > 0) parts.add("Nagad: ${nagad.toStringAsFixed(0)}");
      if (bank > 0) parts.add("Bank: ${bank.toStringAsFixed(0)}");

      return parts.isEmpty ? "MULTI-PAY" : parts.join("\n");
    }

    switch (type) {
      case "cash":
        return "CASH";
      case "bkash":
      case "nagad":
        String number = (pm["number"] ?? pm["details"] ?? "").toString();
        return number.isEmpty
            ? type.toUpperCase()
            : "${type.toUpperCase()}: $number";
      case "bank":
        String bName = (pm["bankName"] ?? "BANK").toString();
        String acc = (pm["accountNumber"] ?? "").toString();
        if (acc.isNotEmpty) return "$bName\n($acc)";
        return bName;
      default:
        return type.toUpperCase();
    }
  }

  // 9. PROFESSIONAL PDF GENERATOR
  Future<void> generateProfessionalPDF() async {
    final pdf = pw.Document();
    final dateStr = DateFormat("dd MMMM yyyy").format(selectedDate.value);
    final primaryColor = PdfColors.blue900;

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
                cellHeight: 25,
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
                data:
                    salesList
                        .map(
                          (s) => [
                            s.name,
                            s.transactionId ?? "-",
                            formatPaymentMethod(
                              s.paymentMethod,
                            ).replaceAll("\n", ", "),
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

  // ==========================================
  // 10. PROCESS REFUND (UPDATED FOR P&L SYNC)
  // ==========================================
  Future<void> processRefund({
    required String saleId,
    required String invoiceId,
    required String customerName,
    required double refundAmount,
  }) async {
    isLoading.value = true;
    try {
      if (invoiceId.isEmpty) throw "Invalid Invoice ID, cannot process refund.";

      // 1. Get Daily Sale Ref
      final dailySaleRef = _db.collection('daily_sales').doc(saleId);

      // 2. Get Master Order Ref (The P&L Source)
      final masterOrderRef = _db.collection('sales_orders').doc(invoiceId);

      await _db.runTransaction((transaction) async {
        // A. Read Data
        final saleSnap = await transaction.get(dailySaleRef);
        final orderSnap = await transaction.get(masterOrderRef);

        if (!saleSnap.exists) throw "Sales entry missing.";
        // Order might be missing if it was created before the update
        bool hasOrder = orderSnap.exists;

        final saleData = saleSnap.data() as Map<String, dynamic>;

        // B. Calculate Daily Sale Update
        final double currentSaleAmount =
            (saleData['amount'] as num?)?.toDouble() ?? 0.0;
        final double currentSalePaid =
            (saleData['paid'] as num?)?.toDouble() ?? 0.0;

        if (refundAmount > currentSalePaid) {
          throw "Refund (৳$refundAmount) cannot exceed paid amount (৳$currentSalePaid).";
        }

        // C. Update Daily Sales (Cash Flow)
        transaction.update(dailySaleRef, {
          'amount': currentSaleAmount - refundAmount,
          'paid': currentSalePaid - refundAmount,
          'lastRefundAt': FieldValue.serverTimestamp(),
        });

        // D. Update Master P&L Record (If exists)
        if (hasOrder) {
          final orderData = orderSnap.data() as Map<String, dynamic>;
          final double currentProfit =
              (orderData['profit'] as num?)?.toDouble() ?? 0.0;
          final double currentGrandTotal =
              (orderData['grandTotal'] as num?)?.toDouble() ?? 0.0;

          // CRITICAL P&L UPDATE:
          // Profit decreases by the refund amount directly
          transaction.update(masterOrderRef, {
            'profit': currentProfit - refundAmount,
            'grandTotal': currentGrandTotal - refundAmount,
            'status': 'refunded_partial',
            // Add to refunds log
            'refunds': FieldValue.arrayUnion([
              {
                'amount': refundAmount,
                'date': Timestamp.now(),
                'reason': 'Manual Refund from Daily Sales',
              },
            ]),
          });
        }
      });

      await loadDailySales();
      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Refund Successful",
        "Refunded ৳$refundAmount. P&L updated.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        "Refund Failed",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- RE-PRINT INDIVIDUAL INVOICE (UPDATED) ---
  Future<void> reprintInvoice(String invoiceId) async {
    isLoading.value = true;
    try {
      // 1. Fetch the UP-TO-DATE Order from sales_orders
      // We do this instead of using local data to ensure we get the "Returned" version
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(invoiceId).get();

      if (!doc.exists) {
        Get.snackbar("Error", "Invoice not found in master records.");
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> items = data['items'] ?? [];
      Map<String, dynamic> payMap = data['paymentDetails'] ?? {};

      // 2. Generate PDF
      // We reuse the exact same PDF logic you already have in LiveSalesController
      // or we build a quick one here.
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

                // ITEMS TABLE
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
                              double.parse(
                                e['saleRate'].toString(),
                              ).toStringAsFixed(2),
                              e['qty']
                                  .toString(), // This will show the NEW reduced Qty
                              double.parse(
                                e['subtotal'].toString(),
                              ).toStringAsFixed(2),
                            ],
                          )
                          .toList(),
                ),

                pw.SizedBox(height: 10),

                // TOTALS
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
                              "Tk ${double.parse(data['grandTotal'].toString()).toStringAsFixed(2)}",
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
                              "Tk ${double.parse(payMap['actualReceived'].toString()).toStringAsFixed(2)}",
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
