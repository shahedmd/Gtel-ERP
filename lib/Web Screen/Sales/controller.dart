// ignore_for_file: deprecated_member_use, empty_catches, avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
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
      String query = filterQuery.value.toLowerCase();
      filteredList.assignAll(
        salesList.where((sale) {
          final name = sale.name.toLowerCase();
          final trxId = (sale.transactionId ?? "").toLowerCase();
          return name.contains(query) || trxId.contains(query);
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
  // 2. ADD SALE
  // ==========================================
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

      if (paidPart > 0 && paymentMethod != null) {
        Map<String, dynamic> historyEntry = {
          'type': paymentMethod['type'] ?? 'cash',
          'amount': paidPart,
          'timestamp': Timestamp.fromDate(date),
        };

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
  // 3. APPLY DEBTOR PAYMENT
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
        final double due = _round(amt - alreadyPaid);

        if (due > 0) {
          final double toApply = remaining >= due ? due : remaining;
          List applied = List.from(data['appliedDebits'] ?? []);

          if (transactionId != null) {
            applied.add({"id": transactionId, "amount": toApply});
          }

          final newHistoryEntry = {
            'type': paymentMethod['type'] ?? 'cash',
            'amount': toApply,
            'paidAt': Timestamp.now(),
            'appliedTo': doc.id,
            'number': paymentMethod['number'],
            'bankName': paymentMethod['bankName'],
            'accountNumber': paymentMethod['accountNumber'],
          };
          newHistoryEntry.removeWhere((key, value) => value == null);

          batch.update(doc.reference, {
            "paid": _round(alreadyPaid + toApply),
            "paymentMethod": paymentMethod,
            "lastPaymentAt": FieldValue.serverTimestamp(),
            "appliedDebits": applied,
            "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
          });
          remaining = _round(remaining - toApply);
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
  // 6. FORMATTING HELPER (FIXED FOR DEBTOR PAYMENTS)
  // ==========================================
  /// Now accepts [totalAmount] to handle Debtor payments where amount
  /// isn't nested inside the map.
  String formatPaymentMethod(dynamic pm, [double? totalAmount]) {
    if (pm == null || pm == "") return "CREDIT/DUE";
    if (pm is! Map) return pm.toString().toUpperCase();

    // Helper to format currency
    String toMoney(dynamic val) =>
        double.parse(val.toString()).toStringAsFixed(0);

    // 1. Extract Amounts (Normal Sales)
    double cash = double.tryParse(pm['cash'].toString()) ?? 0;
    double bkash = double.tryParse(pm['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(pm['nagad'].toString()) ?? 0;
    double bank = double.tryParse(pm['bank'].toString()) ?? 0;

    // 2. Fallback Logic (Debtor Payments / Single Method)
    // If specific breakdowns are 0, but we have a totalAmount and a type, assign it.
    if (cash == 0 &&
        bank == 0 &&
        bkash == 0 &&
        nagad == 0 &&
        totalAmount != null &&
        totalAmount > 0) {
      String type = (pm['type'] ?? '').toString().toLowerCase();
      if (type.contains('bank')) {
        bank = totalAmount;
      }
      if (type.contains('bkash')) {
        bkash = totalAmount;
      }
      if (type.contains('nagad')) {
        nagad = totalAmount;
      }
      if (type == 'cash') {
        cash = totalAmount;
      }
    }

    List<String> parts = [];

    // --- CASH ---
    if (cash > 0) {
      parts.add("Cash: ${toMoney(cash)}");
    }

    // --- BKASH ---
    if (bkash > 0) {
      String num = (pm['bkashNumber'] ?? pm['number'] ?? "").toString();
      String line = "Bkash: ${toMoney(bkash)}";
      if (num.isNotEmpty) line += "\n($num)";
      parts.add(line);
    }

    // --- NAGAD ---
    if (nagad > 0) {
      String num = (pm['nagadNumber'] ?? pm['number'] ?? "").toString();
      String line = "Nagad: ${toMoney(nagad)}";
      if (num.isNotEmpty) line += "\n($num)";
      parts.add(line);
    }

    // --- BANK (Fixed for Debtor Structure) ---
    if (bank > 0) {
      String myBankName = (pm['bankName'] ?? "Bank").toString();

      // Check both keys: 'accountNumber' (Sales) and 'accountNo' (Debtor)
      String custTrxInfo =
          (pm['accountNumber'] ?? pm['accountNo'] ?? "").toString();

      String line = "$myBankName: ${toMoney(bank)}";
      if (custTrxInfo.isNotEmpty) {
        line += "\nInfo: $custTrxInfo";
      }
      parts.add(line);
    }

    // If still empty but type exists (e.g., pure legacy data)
    if (parts.isEmpty && pm['type'] != null) {
      String type = pm['type'].toString().toUpperCase();
      if (type == "BANK") {
        String myBankName = (pm['bankName'] ?? "BANK").toString();
        String acc = (pm['accountNumber'] ?? pm['accountNo'] ?? "").toString();
        return acc.isNotEmpty ? "$myBankName\n$acc" : myBankName;
      }
      return type;
    }

    return parts.isEmpty ? "MULTI-PAY" : parts.join("\n\n");
  }

  // ==========================================
  // 7. REPRINT LOGIC (PRESERVED)
  // ==========================================
  Future<void> reprintInvoice(String invoiceId) async {
    isLoading.value = true;
    try {
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Error", "Invoice not found in master records.");
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Extract Data for Reprint
      String name = data['customerName'] ?? "";
      String phone = data['customerPhone'] ?? "";
      String shop = data['shopName'] ?? "";
      String address = data['deliveryAddress'] ?? "";
      String? courier = data['courierName'];
      int cartons = data['cartons'] ?? 0;
      bool isCond = data['isCondition'] ?? false;
      String challan = data['challanNo'] ?? "";
      String packagername = data['packagerName'] ?? '';
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        data['items'] ?? [],
      );
      Map<String, dynamic> payMap = data['paymentDetails'] ?? {};

      double snapOld = (data['snapshotOldDue'] as num?)?.toDouble() ?? 0.0;
      double snapRun = (data['snapshotRunningDue'] as num?)?.toDouble() ?? 0.0;
      double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;

      await _generatePdf(
        invoiceId,
        name,
        phone,
        payMap,
        items,
        isCondition: isCond,
        challan: challan,
        address: address,
        courier: courier,
        cartons: cartons,
        shopName: shop,
        oldDueSnap: snapOld,
        runningDueSnap: snapRun,
        authorizedName: "Joynal Abedin",
        authorizedPhone: "01720677206",
        discount: discountVal,
        packager: packagername,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not reprint: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items, {
    bool isCondition = false,
    String challan = "",
    String address = "",
    String? courier,
    int? cartons,
    String shopName = "",
    double oldDueSnap = 0.0,
    double runningDueSnap = 0.0,
    required String authorizedName,
    required String authorizedPhone,
    double discount = 0.0,
    String packager = '',
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidInv =
        double.tryParse(payMap['paidForInvoice'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );

    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;
    double netTotalDue = remainingOldDue + runningDueSnap + invDue;
    double totalPaidCurrent = paidOld + paidInv;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(20),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) {
          return [
            _buildCompanyHeader(boldFont, regularFont),
            pw.SizedBox(height: 15),
            _buildInvoiceInfo(
              boldFont,
              regularFont,
              invId,
              name,
              phone,
              isCondition,
              address,
              courier,
              shopName,
              packager,
            ),
            pw.SizedBox(height: 15),
            _buildProfessionalTable(boldFont, regularFont, italicFont, items),
            pw.SizedBox(height: 10),
            _buildDetailedSummary(
              boldFont,
              regularFont,
              payMap,
              isCondition,
              cartons,
              totalPreviousBalance,
              totalPaidCurrent,
              netTotalDue,
              subTotal,
              discount,
            ),
            pw.SizedBox(height: 25),
            _buildSignatures(
              regularFont,
              boldFont,
              authorizedName,
              authorizedPhone,
            ),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          build: (context) {
            return [
              _buildCompanyHeader(boldFont, regularFont),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                color: PdfColors.grey200,
                child: pw.Center(
                  child: pw.Text(
                    "DELIVERY CHALLAN",
                    style: pw.TextStyle(fontSize: 14, letterSpacing: 2),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              _buildChallanInfo(
                boldFont,
                regularFont,
                invId,
                name,
                phone,
                challan,
                address,
                courier,
                cartons,
                shopName,
              ),
              pw.SizedBox(height: 10),
              pw.Spacer(),
              _buildConditionBox(boldFont, regularFont, payMap),
              pw.SizedBox(height: 30),
              _buildSignatures(
                regularFont,
                boldFont,
                authorizedName,
                authorizedPhone,
              ),
            ];
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildCompanyHeader(pw.Font bold, pw.Font reg) {
    return pw.Center(
      child: pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 2)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              "G TEL JOY EXPRESS",
              style: pw.TextStyle(font: bold, fontSize: 24, letterSpacing: 1),
            ),
            pw.Text(
              "Mobile Parts Wholesaler",
              style: pw.TextStyle(font: reg, fontSize: 10, letterSpacing: 3),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Gulistan Shopping Complex (Hall Market), 2 Bangabandu Avenue, Dhaka 1000",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "Hotline: 01720677206, 01911026222 | Email: gtel01720677206@gmail.com",
              style: pw.TextStyle(font: bold, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInvoiceInfo(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    bool isCond,
    String addr,
    String? courier,
    String shopName,
    String packager,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionHeader("INVOICE DETAILS", bold),
              pw.SizedBox(height: 5),
              _infoRow("Invoice #", invId, bold, reg),
              _infoRow(
                "Date",
                DateFormat('dd-MMM-yyyy').format(DateTime.now()),
                bold,
                reg,
              ),
              _infoRow("Type", isCond ? "Condition" : "Cash/Credit", bold, reg),
              if (isCond && courier != null)
                _infoRow("Courier", courier, bold, reg),

              _infoRow("Packed By", packager, bold, reg),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionHeader("BILL TO", bold),
              pw.SizedBox(height: 5),
              pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11)),
              if (shopName.isNotEmpty)
                pw.Text(shopName, style: pw.TextStyle(font: reg, fontSize: 10)),
              pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 10)),
              if (addr.isNotEmpty)
                pw.Text(addr, style: pw.TextStyle(font: reg, fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionHeader(String title, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
      color: PdfColors.grey300,
      child: pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  pw.Widget _infoRow(String label, String value, pw.Font bold, pw.Font reg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 50,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(font: bold, fontSize: 9),
            ),
          ),
          pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalTable(
    pw.Font bold,
    pw.Font reg,
    pw.Font italic,
    List<Map<String, dynamic>> items,
  ) {
    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey),
        horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(45),
        3: const pw.FixedColumnWidth(30),
        4: const pw.FixedColumnWidth(50),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th("SL", bold),
            _th("DESCRIPTION", bold, align: pw.TextAlign.left),
            _th("RATE", bold, align: pw.TextAlign.right),
            _th("QTY", bold, align: pw.TextAlign.center),
            _th("TOTAL", bold, align: pw.TextAlign.right),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item['name'],
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    if (item['model'] != null)
                      pw.Text(
                        "${item['model'] ?? ''}",
                        style: pw.TextStyle(
                          font: italic,
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              _td(item['saleRate'].toString(), reg, align: pw.TextAlign.right),
              _td(item['qty'].toString(), bold, align: pw.TextAlign.center),
              _td(item['subtotal'].toString(), bold, align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _buildDetailedSummary(
    pw.Font bold,
    pw.Font reg,
    Map payMap,
    bool isCond,
    int? cartons,
    double prevDue,
    double totalPaid,
    double netDue,
    double subTotal,
    double discount,
  ) {
    double currentInvTotal = subTotal - discount;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "PAYMENT METHOD",
                  style: pw.TextStyle(font: bold, fontSize: 8),
                ),
                pw.Divider(thickness: 0.5),
                _buildCompactPaymentLines(payMap, reg),
                if (cartons != null && cartons > 0) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Packaged: $cartons Cartons",
                    style: pw.TextStyle(font: bold, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              _summaryRow("Subtotal", subTotal.toStringAsFixed(2), reg),
              if (discount > 0)
                _summaryRow(
                  "Discount",
                  "- ${discount.toStringAsFixed(2)}",
                  reg,
                ),
              pw.Divider(),
              _summaryRow(
                "INVOICE TOTAL",
                currentInvTotal.toStringAsFixed(2),
                bold,
                size: 10,
              ),
              if (!isCond) ...[
                pw.SizedBox(height: 5),
                _summaryRow("Prev. Balance", prevDue.toStringAsFixed(2), reg),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                _summaryRow(
                  "TOTAL PAYABLE",
                  (prevDue + currentInvTotal).toStringAsFixed(2),
                  bold,
                ),
                if (totalPaid > 0)
                  _summaryRow(
                    "Less Paid",
                    "(${totalPaid.toStringAsFixed(2)})",
                    reg,
                  ),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 5),
                  padding: const pw.EdgeInsets.all(5),
                  color: PdfColors.black,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "NET DUE",
                        style: pw.TextStyle(
                          font: bold,
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        netDue.toStringAsFixed(2),
                        style: pw.TextStyle(
                          font: bold,
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _summaryRow("Paid", totalPaid.toStringAsFixed(2), reg),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: _summaryRow(
                    "COLLECTABLE",
                    double.parse(payMap['due'].toString()).toStringAsFixed(2),
                    bold,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font font, {
    double size = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(
    pw.Font reg,
    pw.Font bold,
    String authName,
    String authPhone,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(authName, style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(authPhone, style: pw.TextStyle(font: reg, fontSize: 9)),
            pw.Container(
              width: 120,
              height: 1,
              color: PdfColors.black,
              margin: const pw.EdgeInsets.only(top: 2),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "Authorized Signature",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text(
              "Receiver Signature",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCompactPaymentLines(Map payMap, pw.Font reg) {
    List<String> lines = [];
    double cash = double.tryParse(payMap['cash'].toString()) ?? 0;
    double bkash = double.tryParse(payMap['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(payMap['nagad'].toString()) ?? 0;
    double bank = double.tryParse(payMap['bank'].toString()) ?? 0;

    if (cash > 0) lines.add("Cash: $cash");
    if (bkash > 0) lines.add("Bkash: $bkash");
    if (nagad > 0) lines.add("Nagad: $nagad");
    if (bank > 0) lines.add("Bank: $bank");

    if (lines.isEmpty) {
      return pw.Text(
        "Unpaid / Due",
        style: pw.TextStyle(font: reg, fontSize: 8),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children:
          lines
              .map(
                (l) => pw.Text(l, style: pw.TextStyle(font: reg, fontSize: 8)),
              )
              .toList(),
    );
  }

  pw.Widget _buildChallanInfo(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    String challan,
    String addr,
    String? courier,
    int? cartons,
    String shopName,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "LOGISTICS / COURIER",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                pw.Divider(thickness: 0.5),
                pw.Text(
                  "Name: ${courier ?? 'N/A'}",
                  style: pw.TextStyle(font: reg, fontSize: 9),
                ),
                pw.Text(
                  "Challan: $challan",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                if (cartons != null)
                  pw.Text(
                    "Total Cartons: $cartons",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "DELIVER TO",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                pw.Divider(thickness: 0.5),
                pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 10)),
                pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 9)),
                pw.Text(
                  addr,
                  style: pw.TextStyle(font: reg, fontSize: 8),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildConditionBox(pw.Font bold, pw.Font reg, Map payMap) {
    double due = double.parse(payMap['due'].toString());
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "CONDITION PAYMENT INSTRUCTION",
            style: pw.TextStyle(font: reg, fontSize: 8),
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                "PLEASE COLLECT:  ",
                style: pw.TextStyle(font: bold, fontSize: 12),
              ),
              pw.Text(
                "Tk ${due.toStringAsFixed(0)} /=",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
              pw.Text(
                "+ Charges",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
