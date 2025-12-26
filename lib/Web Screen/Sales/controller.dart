// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class DailySalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Rx<DateTime> selectedDate = DateTime.now().obs;
  RxList<Map<String, dynamic>> salesList = <Map<String, dynamic>>[].obs;

  RxDouble totalSales = 0.0.obs;
  RxDouble paidAmount = 0.0.obs;
  RxDouble debtorPending = 0.0.obs;

  RxBool isLoading = false.obs;
  RxString filterQuery = "".obs;

  @override
  void onInit() {
    super.onInit();
    loadDailySales();
    ever(selectedDate, (_) => loadDailySales());
  }

  /// Change selected date
  void changeDate(DateTime date) {
    selectedDate.value = date;
  }

  Future<void> loadDailySales() async {
    isLoading.value = true;
    try {
      final start = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );
      final end = start.add(const Duration(days: 1));

      final riyad =
          await _db
              .collection("daily_sales")
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(end))
              .orderBy("timestamp")
              .get();

      salesList.value =
          riyad.docs.map((d) {
            final data = d.data();
            return {"id": d.id, ...data};
          }).toList();

      _computeTotals();
    } catch (e) {
      // For debugging: keep it visible in console
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reverseDebtorPayment(
    String debtorName,
    double amount,
    DateTime date,
  ) async {
    final salesSnap =
        await _db
            .collection('daily_sales')
            .where('customerName', isEqualTo: debtorName)
            .where('isPaid', isEqualTo: true)
            .orderBy('date')
            .get();

    double remaining = amount;

    for (var doc in salesSnap.docs) {
      final sale = doc.data();
      double paidAmount = (sale['amount'] as num?)?.toDouble() ?? 0.0;

      if (remaining <= 0) break;

      if (paidAmount <= remaining) {
        // Fully reverse this payment
        await _db.collection('daily_sales').doc(doc.id).update({
          'isPaid': false,
          'paidAmount': 0,
        });
        remaining -= paidAmount;
      } else {
        await _db.collection('daily_sales').doc(doc.id).update({
          'isPaid': true,
          'paidAmount': paidAmount - remaining,
        });
        remaining = 0;
        break;
      }
    }
  }

  void _computeTotals() {
    double total = 0.0;
    double paid = 0.0;
    double debtor = 0.0;

    for (var s in salesList) {
      final amount = (s['amount'] as num?)?.toDouble() ?? 0.0;
      final paidPart = (s['paid'] as num?)?.toDouble() ?? 0.0;
      final isDebtor = (s['customerType'] ?? '') == "debtor";

      total += amount;
      if (isDebtor) {
        paid += paidPart;
        debtor += (amount - paidPart);
      } else {
        paid += amount;
      }
    }

    totalSales.value = total;
    paidAmount.value = paid;
    debtorPending.value = debtor;
  }

Future<void> addSale({
  required String name,
  required double amount,
  required String customerType,
  required DateTime date,
  String source = "debit",
  bool isPaid = false,
  Map<String, dynamic>? paymentMethod,
  List<Map<String, dynamic>>? appliedDebits,
  String? transactionId,
}) async {
  final paidPart = (customerType == "debtor" && !isPaid) ? 0.0 : amount;

  final entry = {
    "name": name,
    "amount": amount,
    "paid": paidPart,
    "customerType": customerType,
    "timestamp": Timestamp.fromDate(date),
    "paymentMethod": paymentMethod,
    "createdAt": Timestamp.now(),
    "source": source,
    "appliedDebits": appliedDebits ?? [],
    "transactionId": transactionId,
  };

  final doc = await _db.collection("daily_sales").add(entry);

  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
      date.isBefore(end)) {
    salesList.add({"id": doc.id, ...entry});
    _computeTotals();
  }
}


Future<void> applyDebtorPayment(
  String debtorName,
  double paymentAmount,
  Map<String, dynamic> paymentMethod, {
  required DateTime date,
  String? transactionId,
}) async {
  double remaining = paymentAmount;

  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));

  final snap = await _db
      .collection("daily_sales")
      .where("customerType", isEqualTo: "debtor")
      .where("name", isEqualTo: debtorName)
      .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where("timestamp", isLessThan: Timestamp.fromDate(end))
      .orderBy("timestamp")
      .get();

  final unpaidDocs = snap.docs.where((doc) {
    final data = doc.data();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final paid = (data['paid'] as num?)?.toDouble() ?? 0;
    return paid < amount;
  }).toList();

  final batch = _db.batch();

  for (var doc in unpaidDocs) {
    if (remaining <= 0) break;

    final data = doc.data();
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final double paid = (data['paid'] as num?)?.toDouble() ?? 0;
    final double pending = amount - paid;

    final double toApply = remaining >= pending ? pending : remaining;
    final double newPaid = paid + toApply;
    remaining -= toApply;

    // Track applied debit
    final List<Map<String, dynamic>> existingApplied =
        List<Map<String, dynamic>>.from(data['appliedDebits'] ?? []);

    if (transactionId != null) {
      existingApplied.add({"id": transactionId, "amount": toApply});
    }

    batch.update(doc.reference, {
      "paid": newPaid,
      "paymentMethod": paymentMethod,
      "lastPaymentAt": Timestamp.fromDate(date),
      "appliedDebits": existingApplied,
    });

    // Update local salesList optimistically
    final idx = salesList.indexWhere((s) => s["id"] == doc.id);
    if (idx != -1) {
      salesList[idx]["paid"] = newPaid;
      salesList[idx]["paymentMethod"] = paymentMethod;
      salesList[idx]["appliedDebits"] = existingApplied;
    }
  }

  // If some amount is left (extra payment), create fully-paid extra sale
  if (remaining > 0) {
    await addSale(
      name: debtorName,
      amount: remaining,
      customerType: "debtor",
      isPaid: true,
      date: date,
      paymentMethod: paymentMethod,
      source: "debit",
      appliedDebits: transactionId != null
          ? [
              {"id": transactionId, "amount": remaining}
            ]
          : null,
      transactionId: transactionId,
    );
  }

  await batch.commit();
  await loadDailySales();
}



 
  /// Delete a daily sale by its document id.
  /// Use this when you want to remove a daily sale record (for example when reversing an action).
  Future<void> deleteSale(String saleId) async {
    try {
      await _db.collection("daily_sales").doc(saleId).delete();
    // ignore: empty_catches
    } catch (e) {
    }
    // Refresh local list and totals
    await loadDailySales();
  }

  /// Format payment method for UI and PDF
  String formatPaymentMethod(dynamic pm) {
    if (pm == null) return "";
    if (pm is String) return pm;
    if (pm is Map) {
      switch ((pm["type"] ?? "").toString().toLowerCase()) {
        case "bank":
          return "Bank: ${pm["bankName"] ?? ""}, ${pm["branch"] ?? ""}, A/C: ${pm["accountNumber"] ?? ""}";
        case "bkash":
          return "Bkash: ${pm["number"] ?? ""}";
        case "cash":
          return "Cash";
        default:
          return pm["type"] ?? "";
      }
    }
    return pm.toString();
  }

  /// Generate PDF report
  Future<Uint8List> generatePDF() async {
    final pdf = pw.Document();
    final dateStr = DateFormat("dd MMM yyyy").format(selectedDate.value);

    final headerStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final rowStyle = pw.TextStyle(fontSize: 12);

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    "DAILY SALES REPORT",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromInt(0xFF555555),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFEFEFEF),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Name", style: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Type", style: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Amount", style: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Paid", style: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Pending", style: headerStyle),
                    ),
                  ],
                ),
              ],
            ),
            pw.Table(
              border: pw.TableBorder(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                bottom: pw.BorderSide(),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                for (var s in salesList)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(s["name"] ?? "", style: rowStyle),
                            if (s["paymentMethod"] != null)
                              pw.Text(
                                formatPaymentMethod(s["paymentMethod"]),
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColor.fromInt(0xFF777777),
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("${s["customerType"]}", style: rowStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          ((s["amount"] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(2),
                          style: rowStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          ((s["paid"] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(2),
                          style: rowStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          ((((s["amount"] as num?)?.toDouble() ?? 0) -
                                  ((s["paid"] as num?)?.toDouble() ?? 0)))
                              .toStringAsFixed(2),
                          style: rowStyle,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColor.fromInt(0xFFEFEFEF),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "SUMMARY",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Total Sales:  ${totalSales.value.toStringAsFixed(2)}",
                    style: rowStyle,
                  ),
                  pw.Text(
                    "Total Paid:   ${paidAmount.value.toStringAsFixed(2)}",
                    style: rowStyle,
                  ),
                  pw.Text(
                    "Debtor Pending: ${debtorPending.value.toStringAsFixed(2)}",
                    style: rowStyle.copyWith(
                      color: PdfColor.fromInt(0xFFB00020),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text(
                "Generated by Gtel POS System",
                style: pw.TextStyle(fontSize: 10, color: PdfColor(0, 0, 0)),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
