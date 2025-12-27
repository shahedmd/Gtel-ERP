// ignore_for_file: deprecated_member_use, empty_catches
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // Re-fetch automatically if date changes
    ever(selectedDate, (_) => loadDailySales());
  }

  // 1. CHANGE DATE
  void changeDate(DateTime date) {
    selectedDate.value = date;
  }

  // 2. LOAD SALES (Upgraded with Model and Sorting)
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

      salesList.assignAll(
        snap.docs.map((d) => SaleModel.fromFirestore(d)).toList(),
      );
      _computeTotals();
    } finally {
      isLoading.value = false;
    }
  }

  // 3. REVERSE DEBTOR PAYMENT (Atomic Batch - Safe for 2025)
  Future<void> reverseDebtorPayment(
    String debtorName,
    double amount,
    DateTime date,
  ) async {
    try {
      final salesSnap =
          await _db
              .collection('daily_sales')
              .where(
                'name',
                isEqualTo: debtorName,
              ) // Matches model field 'name'
              .where('customerType', isEqualTo: 'debtor')
              .orderBy('timestamp', descending: true) // Reverse newest first
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

  // 4. COMPUTE TOTALS (Logic Preserved & Corrected)
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

  // 5. ADD SALE (Includes all original parameters)
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

  // 6. APPLY DEBTOR PAYMENT (Upgraded with FIFO logic and Batch)
  Future<void> applyDebtorPayment(
    String debtorName,
    double paymentAmount,
    Map<String, dynamic> paymentMethod, {
    required DateTime date,
    String? transactionId,
  }) async {
    try {
      double remaining = paymentAmount;

      // 1. Calculate the 24-hour window for the specific date provided
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // 2. Query sales ONLY for this specific debtor AND this specific day
      final snap =
          await _db
              .collection("daily_sales")
              .where("customerType", isEqualTo: "debtor")
              .where("name", isEqualTo: debtorName)
              // --- FIX: Strict Date Filtering ---
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(endOfDay))
              .orderBy(
                "timestamp",
                descending: false,
              ) // Pay earliest bill of THIS day first
              .get();

      final batch = _db.batch();

      // 3. Apply payment to the bills found within this specific day
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

      // 4. Handle Extra Payment (Advance / Overpayment for today)
      // If the user pays more than what they owe TODAY, we record it as a separate
      // fully-paid entry for today. It will NOT touch previous days.
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
      await loadDailySales(); // Refresh the UI
    } catch (e) {
      Get.snackbar("Payment Error", "Could not process daily payment.");
    }
  }

  // 7. DELETE SALE
  Future<void> deleteSale(String saleId) async {
    try {
      await _db.collection("daily_sales").doc(saleId).delete();
      await loadDailySales();
    } catch (e) {
    }
  }

  // 8. FORMAT PAYMENT METHOD (Utility Method)
  String formatPaymentMethod(dynamic pm) {
    if (pm == null) return "CREDIT";
    if (pm is String) return pm.toUpperCase();
    if (pm is Map) {
      String type = (pm["type"] ?? "").toString().toUpperCase();
      if (type == "BANK") return "BANK: ${pm["bankName"] ?? ""}";
      if (type == "BKASH") return "BKASH: ${pm["number"] ?? ""}";
      return type;
    }
    return pm.toString();
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
              // SUMMARY BOX
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

              // SALES TABLE
              pw.Table.fromTextArray(
                headers: [
                  "Customer",
                  "Type",
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
                            s.customerType.toUpperCase(),
                            formatPaymentMethod(s.paymentMethod),
                            s.amount.toStringAsFixed(2),
                            s.paid.toStringAsFixed(2),
                            s.pending.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Text(
                  "--- End of Report ---",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
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
}
