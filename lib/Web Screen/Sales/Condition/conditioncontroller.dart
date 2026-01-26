// ignore_for_file: deprecated_member_use, avoid_print, empty_catches
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ConditionSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Dependencies
  final DailySalesController dailyCtrl = Get.find<DailySalesController>();
  final ProductController productCtrl = Get.find<ProductController>();

  // --- OBSERVABLES ---
  final RxList<ConditionOrderModel> allOrders = <ConditionOrderModel>[].obs;
  final RxList<ConditionOrderModel> filteredOrders =
      <ConditionOrderModel>[].obs;
  final RxBool isLoading = false.obs;

  // --- PAGINATION & FILTER STATE ---
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  final RxBool hasMore = true.obs;
  final RxBool isMoreLoading = false.obs;

  // Stats
  final RxDouble totalPendingAmount = 0.0.obs;
  final RxMap<String, double> courierBalances = <String, double>{}.obs;

  // Filters
  final RxString selectedFilter = "All Time".obs;
  final RxString searchQuery = "".obs;
  final RxString selectedCourierFilter = "All".obs;

  // Custom Date Range
  final Rxn<DateTimeRange> customDateRange = Rxn<DateTimeRange>();

  // --- RETURN LOGIC STATE ---
  final returnSearchCtrl = TextEditingController();
  final Rxn<Map<String, dynamic>> returnOrderData = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> returnOrderItems =
      <Map<String, dynamic>>[].obs;
  final RxMap<String, int> returnQuantities = <String, int>{}.obs;
  final RxMap<String, String> returnDestinations = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadConditionSales();

    ever(selectedFilter, (_) => _handleFilterChange());
    ever(searchQuery, (_) => _applyClientSideFilters());
    ever(customDateRange, (_) => _handleFilterChange());
  }

  // --- DATA LOADING LOGIC ---

  void _handleFilterChange() {
    // If filter is All Time, we use pagination logic.
    // If filter is specific (Today, Last Month, Custom), we fetch ALL data for that range for accurate reports.
    if (selectedFilter.value == "All Time" && searchQuery.value.isEmpty) {
      loadConditionSales();
    } else {
      fetchReportData();
    }
  }

  // 1. Standard Pagination (For "All Time")
  Future<void> loadConditionSales({bool loadMore = false}) async {
    if (selectedFilter.value != "All Time") {
      return; // Don't use this for reports
    }

    if (loadMore) {
      if (isMoreLoading.value || !hasMore.value) return;
      isMoreLoading.value = true;
    } else {
      isLoading.value = true;
      _lastDocument = null;
      hasMore.value = true;
      allOrders.clear();
    }

    try {
      Query query = _db
          .collection('sales_orders')
          .where('isCondition', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(_limit);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();

      if (snap.docs.length < _limit) hasMore.value = false;

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
        List<ConditionOrderModel> newOrders =
            snap.docs
                .map((doc) => ConditionOrderModel.fromFirestore(doc))
                .toList();

        if (loadMore) {
          allOrders.addAll(newOrders);
        } else {
          allOrders.value = newOrders;
        }
      }

      _applyClientSideFilters();
      _calculateStats();
    } catch (e) {
      print("Error loading sales: $e");
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  // 2. Report Fetching (For Specific Dates)
  Future<void> fetchReportData() async {
    isLoading.value = true;
    allOrders.clear();

    DateTime now = DateTime.now();
    DateTime start = now;
    DateTime end = now;

    // Determine Date Range
    if (selectedFilter.value == "Today") {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (selectedFilter.value == "This Month") {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (selectedFilter.value == "Last Month") {
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (selectedFilter.value == "This Year") {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31, 23, 59, 59);
    } else if (selectedFilter.value == "Custom" &&
        customDateRange.value != null) {
      start = customDateRange.value!.start;
      end = DateTime(
        customDateRange.value!.end.year,
        customDateRange.value!.end.month,
        customDateRange.value!.end.day,
        23,
        59,
        59,
      );
    } else {
      // Fallback for All Time in search mode
      loadConditionSales();
      return;
    }

    try {
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              .where('isCondition', isEqualTo: true)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .orderBy('timestamp', descending: true)
              .get();

      allOrders.value =
          snap.docs
              .map((doc) => ConditionOrderModel.fromFirestore(doc))
              .toList();

      _applyClientSideFilters();
      _calculateStats();
    } catch (e) {
      print("Report Error: $e");
      Get.snackbar(
        "Notice",
        "Make sure Firestore Index is enabled for Timestamp query",
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _applyClientSideFilters() {
    List<ConditionOrderModel> temp = List.from(allOrders);

    // Filter by Courier Name? (Currently not in UI, but logic ready)
    if (selectedCourierFilter.value != "All") {
      temp =
          temp
              .where((o) => o.courierName == selectedCourierFilter.value)
              .toList();
    }

    // Filter by Search Query
    if (searchQuery.value.isNotEmpty) {
      String q = searchQuery.value.toLowerCase();
      temp =
          temp
              .where(
                (o) =>
                    o.customerName.toLowerCase().contains(q) ||
                    o.invoiceId.toLowerCase().contains(q) ||
                    o.customerPhone.contains(q) ||
                    o.courierName.toLowerCase().contains(q) ||
                    o.challanNo.contains(q),
              )
              .toList();
    }

    filteredOrders.value = temp;
    _calculateStats(); // Recalculate stats based on filtered view
  }

  void _calculateStats() {
    double total = 0.0;
    Map<String, double> cBalances = {};

    for (var order in filteredOrders) {
      if (order.courierDue > 0) {
        total += order.courierDue;
        if (cBalances.containsKey(order.courierName)) {
          cBalances[order.courierName] =
              cBalances[order.courierName]! + order.courierDue;
        } else {
          cBalances[order.courierName] = order.courierDue;
        }
      }
    }
    totalPendingAmount.value = total;
    courierBalances.value = cBalances;
  }

  // ==============================================================================
  // 3. PAYMENT RECEIVING (Same as before)
  // ==============================================================================
  Future<void> receiveConditionPayment({
    required ConditionOrderModel order,
    required double receivedAmount,
    required String method,
    String? refNumber,
  }) async {
    if (receivedAmount <= 0) return;
    if (receivedAmount > order.courierDue) {
      Get.snackbar("Error", "Amount exceeds due balance");
      return;
    }

    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(order.invoiceId);

      DocumentSnapshot latestSnap = await orderRef.get();
      Map<String, dynamic> data = latestSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> paymentDetails = data['paymentDetails'] ?? {};

      double currentPaid =
          double.tryParse(paymentDetails['actualReceived'].toString()) ?? 0.0;
      double newPaidTotal = currentPaid + receivedAmount;
      double newDue = order.courierDue - receivedAmount;

      batch.update(orderRef, {
        "courierDue": newDue,
        "paymentDetails.actualReceived": newPaidTotal,
        "lastPaymentDate": FieldValue.serverTimestamp(),
        "status": newDue <= 0 ? "completed" : "on_delivery",
        "isFullyPaid": newDue <= 0,
        "collectionHistory": FieldValue.arrayUnion([
          {
            "amount": receivedAmount,
            "date": Timestamp.now(),
            "method": method,
            "ref": refNumber,
            "type": "courier_collection",
          },
        ]),
      });

      DocumentReference courierRef = _db
          .collection('courier_ledgers')
          .doc(order.courierName);
      batch.set(courierRef, {
        "totalDue": FieldValue.increment(-receivedAmount),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      DocumentReference custRef = _db
          .collection('condition_customers')
          .doc(order.customerPhone);
      batch.update(custRef, {
        "totalCourierDue": FieldValue.increment(-receivedAmount),
      });

      await batch.commit();

      await dailyCtrl.addSale(
        name: "${order.courierName} (Ref: ${order.invoiceId})",
        amount: receivedAmount,
        customerType: "courier_payment",
        date: DateTime.now(),
        source: "condition_recovery",
        isPaid: true,
        paymentMethod: {
          "type": method.toLowerCase(),
          "details": refNumber ?? "Collection from ${order.courierName}",
          "courier": order.courierName,
        },
        transactionId: order.invoiceId,
      );

      // Refresh data intelligently
      if (selectedFilter.value == "All Time") {
        loadConditionSales(loadMore: false);
      } else {
        fetchReportData();
      }

      Get.back();
      Get.snackbar(
        "Success",
        "Payment Received",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Transaction failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==============================================================================
  // 4. PRINT INVOICE LOGIC (Ported from LiveSalesController)
  // ==============================================================================

  Future<void> printInvoice(ConditionOrderModel order) async {
    isLoading.value = true;
    try {
      // 1. Fetch Fresh Data to get exact snapshots and payment details
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(order.invoiceId).get();
      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      List<dynamic> rawItems = data['items'] ?? [];
      List<Map<String, dynamic>> items =
          rawItems.map((e) => e as Map<String, dynamic>).toList();
      Map<String, dynamic> paymentMap = data['paymentDetails'] ?? {};

      double oldDueSnap =
          double.tryParse(data['snapshotOldDue']?.toString() ?? "0") ?? 0.0;
      double runningDueSnap =
          double.tryParse(data['snapshotRunningDue']?.toString() ?? "0") ?? 0.0;
      int cartons = int.tryParse(data['cartons']?.toString() ?? "0") ?? 0;
      String address = data['deliveryAddress'] ?? "";
      String shop = data['shopName'] ?? "";

      // 2. Generate PDF
      await _generatePdf(
        order.invoiceId,
        order.customerName,
        order.customerPhone,
        paymentMap,
        items,
        isCondition: true,
        challan: order.challanNo,
        address: address,
        courier: order.courierName,
        cartons: cartons,
        shopName: shop,
        oldDueSnap: oldDueSnap,
        runningDueSnap: runningDueSnap,
        authorizedName: "Joynal Abedin",
        authorizedPhone: "01720677206",
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate invoice: $e");
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
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
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

  // --- PDF WIDGET HELPERS (Identical to LiveSalesController) ---
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
              _infoRow("Type", isCond ? "Condition" : "Cash/Credit", bold, reg),
              if (isCond && courier != null)
                _infoRow("Courier", courier, bold, reg),
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
                    if (item['brand'] != null || item['model'] != null)
                      pw.Text(
                        "${item['brand'] ?? ''} ${item['model'] ?? ''}",
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
  ) {
    double discount = 0.0;
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
              pw.Divider(),
              _summaryRow(
                "INVOICE TOTAL",
                currentInvTotal.toStringAsFixed(2),
                bold,
                size: 10,
              ),
              if (!isCond) ...[
                // Not needed for condition specific but kept for compatibility
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
                "+CHARGES",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Future<void> updateChallanNumber(
    String invoiceId,
    String phone,
    String newChallan,
  ) async {
    if (newChallan.isEmpty) {
      Get.snackbar("Error", "Challan number cannot be empty");
      return;
    }
    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      DocumentReference masterRef = _db
          .collection('sales_orders')
          .doc(invoiceId);
      batch.update(masterRef, {'challanNo': newChallan});
      DocumentReference subOrderRef = _db
          .collection('condition_customers')
          .doc(phone)
          .collection('orders')
          .doc(invoiceId);
      batch.update(subOrderRef, {'challanNo': newChallan});
      DocumentReference custRef = _db
          .collection('condition_customers')
          .doc(phone);
      batch.update(custRef, {'lastChallan': newChallan});
      await batch.commit();

      if (selectedFilter.value == "All Time") {
        loadConditionSales(loadMore: false);
      } else {
        fetchReportData();
      }

      Get.back();
      Get.snackbar(
        "Success",
        "Challan Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to update: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> findInvoiceForReturn(String invoiceId) async {
    if (invoiceId.isEmpty) return;
    isLoading.value = true;
    returnOrderData.value = null;
    returnOrderItems.clear();
    returnQuantities.clear();
    returnDestinations.clear();

    try {
      final doc =
          await _db.collection('sales_orders').doc(invoiceId.trim()).get();
      if (!doc.exists) {
        Get.snackbar("Not Found", "Invoice not found.");
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      if (data['isCondition'] != true) {
        Get.snackbar("Invalid Type", "This is not a Condition Sale invoice.");
        return;
      }
      returnOrderData.value = data;
      List<dynamic> rawItems = data['items'] ?? [];
      for (var item in rawItems) {
        if (item is Map) {
          Map<String, dynamic> safeItem = {
            "productId": item['productId'].toString(),
            "name": item['name'].toString(),
            "model": item['model']?.toString() ?? "",
            "qty": int.parse(item['qty'].toString()),
            "saleRate": double.parse(item['saleRate'].toString()),
            "costRate": double.parse(item['costRate'].toString()),
            "subtotal": double.parse(item['subtotal'].toString()),
          };
          returnOrderItems.add(safeItem);
          String pid = safeItem['productId'];
          returnQuantities[pid] = 0;
          returnDestinations[pid] = "Sea";
        }
      }
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void incrementReturn(String pid, int max) {
    int cur = returnQuantities[pid] ?? 0;
    if (cur < max) returnQuantities[pid] = cur + 1;
  }

  void decrementReturn(String pid) {
    int cur = returnQuantities[pid] ?? 0;
    if (cur > 0) returnQuantities[pid] = cur - 1;
  }

  double get totalRefundValue {
    double total = 0.0;
    for (var item in returnOrderItems) {
      String pid = item['productId'].toString();
      int qty = returnQuantities[pid] ?? 0;
      double rate = double.parse(item['saleRate'].toString());
      total += (qty * rate);
    }
    return total;
  }

  Future<void> processConditionReturn() async {
    if (totalRefundValue <= 0) return;
    if (returnOrderData.value == null) return;
    isLoading.value = true;
    String invoiceId = returnOrderData.value!['invoiceId'].toString();
    String courierName = returnOrderData.value!['courierName'].toString();
    String custPhone = returnOrderData.value!['customerPhone'].toString();

    try {
      await _db.runTransaction((transaction) async {
        DocumentReference orderRef = _db
            .collection('sales_orders')
            .doc(invoiceId);
        DocumentSnapshot orderSnap = await transaction.get(orderRef);
        Map<String, dynamic> currentData =
            orderSnap.data() as Map<String, dynamic>;

        List<dynamic> oldItems = currentData['items'] ?? [];
        List<Map<String, dynamic>> newItems = [];
        double refundAmt = 0.0;
        double profitReduce = 0.0;
        double costReduce = 0.0;

        for (var rawItem in oldItems) {
          String pid = rawItem['productId'].toString();
          int dbQty = int.parse(rawItem['qty'].toString());
          double sRate = double.parse(rawItem['saleRate'].toString());
          double cRate = double.parse(rawItem['costRate'].toString());
          int retQty = returnQuantities[pid] ?? 0;

          if (retQty > 0) {
            refundAmt += (retQty * sRate);
            costReduce += (retQty * cRate);
            profitReduce += (retQty * (sRate - cRate));
            dbQty -= retQty;
          }
          newItems.add({...rawItem, "qty": dbQty, "subtotal": dbQty * sRate});
        }

        double oldGT = double.parse(currentData['grandTotal'].toString());
        double newGT = oldGT - refundAmt;
        double oldDue = double.parse(currentData['courierDue'].toString());
        double newDue = oldDue - refundAmt;
        if (newDue < 0) newDue = 0;

        transaction.update(orderRef, {
          "items": newItems,
          "grandTotal": newGT,
          "courierDue": newDue,
          "profit":
              double.parse(currentData['profit'].toString()) - profitReduce,
          "totalCost":
              double.parse(currentData['totalCost'].toString()) - costReduce,
          "status": newDue <= 0 ? "returned_completed" : "returned_partial",
          "subtotal": newGT,
          "lastReturnDate": FieldValue.serverTimestamp(),
        });

        DocumentReference courierRef = _db
            .collection('courier_ledgers')
            .doc(courierName);
        transaction.update(courierRef, {
          "totalDue": FieldValue.increment(-refundAmt),
          "lastUpdated": FieldValue.serverTimestamp(),
        });

        DocumentReference custRef = _db
            .collection('condition_customers')
            .doc(custPhone);
        transaction.update(custRef, {
          "totalCourierDue": FieldValue.increment(-refundAmt),
        });

        // Also update subcollection if exists (best effort)
        DocumentReference custOrderRef = custRef
            .collection('orders')
            .doc(invoiceId);
        // We use set/merge because getting check might fail transaction if doc missing
        transaction.set(custOrderRef, {
          "grandTotal": newGT,
          "courierDue": newDue,
          "status": newDue <= 0 ? "returned_completed" : "pending_courier",
        }, SetOptions(merge: true));

        final dailyQuery =
            await _db
                .collection('daily_sales')
                .where('transactionId', isEqualTo: invoiceId)
                .limit(1)
                .get();
        if (dailyQuery.docs.isNotEmpty) {
          transaction.update(dailyQuery.docs.first.reference, {
            "amount": newGT,
            "pending": newDue,
            "note": "Adjusted via Return (-$refundAmt)",
          });
        }
      });

      List<Future<void>> stockUpdates = [];
      for (var pid in returnQuantities.keys) {
        int qty = returnQuantities[pid]!;
        if (qty > 0) {
          // Default return to Sea per requirement
          var itemInfo = returnOrderItems.firstWhere(
            (e) => e['productId'] == pid,
          );
          double originalCost = double.parse(itemInfo['costRate'].toString());
          int? parsedPid = int.tryParse(pid);
          if (parsedPid != null) {
            stockUpdates.add(
              productCtrl.addMixedStock(
                productId: parsedPid,
                localQty: 0,
                airQty: 0,
                seaQty: qty,
                localUnitPrice: originalCost,
              ),
            );
          }
        }
      }
      if (stockUpdates.isNotEmpty) await Future.wait(stockUpdates);

      if (selectedFilter.value == "All Time") {
        loadConditionSales(loadMore: false);
      } else {
        fetchReportData();
      }

      returnOrderData.value = null;
      returnOrderItems.clear();
      returnSearchCtrl.clear();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Return Complete",
        "Stock Restored to SEA & Ledgers Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Return Failed",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
