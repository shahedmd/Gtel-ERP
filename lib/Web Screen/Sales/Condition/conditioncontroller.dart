// ignore_for_file: deprecated_member_use, avoid_print, empty_catches

import 'dart:async';
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

  // Search Debouncer
  Timer? _debounce;

  // Custom Date Range
  final Rxn<DateTimeRange> customDateRange = Rxn<DateTimeRange>();

  @override
  void onInit() {
    super.onInit();
    loadConditionSales();

    ever(selectedFilter, (_) => _handleFilterChange());
    ever(searchQuery, (val) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (val.isNotEmpty) {
          _performServerSideSearch(val);
        } else {
          loadConditionSales();
        }
      });
    });
    ever(customDateRange, (_) => _handleFilterChange());
  }

  // ==============================================================================
  // 1. DATA LOADING & FILTERS
  // ==============================================================================

  void _handleFilterChange() {
    if (searchQuery.value.isNotEmpty) return;
    if (selectedFilter.value == "All Time") {
      loadConditionSales();
    } else {
      fetchReportData();
    }
  }

  Future<void> _performServerSideSearch(String query) async {
    isLoading.value = true;
    allOrders.clear();
    filteredOrders.clear();
    hasMore.value = false;

    try {
      QuerySnapshot snap;
      snap =
          await _db
              .collection('sales_orders')
              .where('invoiceId', isEqualTo: query.trim())
              .where('isCondition', isEqualTo: true)
              .get();

      if (snap.docs.isEmpty) {
        snap =
            await _db
                .collection('sales_orders')
                .where('customerPhone', isEqualTo: query.trim())
                .where('isCondition', isEqualTo: true)
                .orderBy('timestamp', descending: true)
                .limit(20)
                .get();
      }

      if (snap.docs.isEmpty) {
        snap =
            await _db
                .collection('sales_orders')
                .where('challanNo', isEqualTo: query.trim())
                .where('isCondition', isEqualTo: true)
                .get();
      }

      allOrders.value =
          snap.docs
              .map((doc) => ConditionOrderModel.fromFirestore(doc))
              .toList();
      filteredOrders.value = allOrders;
      _calculateStats();
    } catch (e) {
      print("Search Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadConditionSales({bool loadMore = false}) async {
    if (searchQuery.value.isNotEmpty) return;
    if (selectedFilter.value != "All Time") return;

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

  Future<void> fetchReportData() async {
    isLoading.value = true;
    allOrders.clear();
    DateTime now = DateTime.now();
    DateTime start = now;
    DateTime end = now;

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
    } finally {
      isLoading.value = false;
    }
  }

  void _applyClientSideFilters() {
    List<ConditionOrderModel> temp = List.from(allOrders);
    if (selectedCourierFilter.value != "All") {
      temp =
          temp
              .where((o) => o.courierName == selectedCourierFilter.value)
              .toList();
    }
    filteredOrders.value = temp;
    _calculateStats();
  }

  void _calculateStats() {
    double total = 0.0;
    Map<String, double> cBalances = {};
    for (var order in filteredOrders) {
      if (order.courierDue > 0) {
        total += order.courierDue;
        double due = double.parse(order.courierDue.toStringAsFixed(2));
        if (cBalances.containsKey(order.courierName)) {
          cBalances[order.courierName] = cBalances[order.courierName]! + due;
        } else {
          cBalances[order.courierName] = due;
        }
      }
    }
    totalPendingAmount.value = total;
    courierBalances.value = cBalances;
  }

  // ==============================================================================
  // 2. PAYMENT RECEIVING (FIXED OVERWRITE BUG)
  // ==============================================================================
  Future<void> receiveConditionPayment({
    required ConditionOrderModel order,
    required double receivedAmount,
    required String method,
    String? refNumber,
  }) async {
    if (receivedAmount <= 0) return;
    receivedAmount = double.parse(receivedAmount.toStringAsFixed(2));

    if (receivedAmount > order.courierDue + 1) {
      // +1 tolerance
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

      // FIX: Check 'actualReceived' first, if null/0, fallback to 'paidForInvoice' (Initial Advance)
      double currentPaid =
          double.tryParse(paymentDetails['actualReceived'].toString()) ?? 0.0;
      if (currentPaid == 0) {
        currentPaid =
            double.tryParse(paymentDetails['paidForInvoice'].toString()) ?? 0.0;
      }

      double newPaidTotal = currentPaid + receivedAmount;
      double newDue =
          double.parse(data['courierDue'].toString()) - receivedAmount;
      if (newDue < 0) newDue = 0;

      batch.update(orderRef, {
        "courierDue": newDue,
        "paymentDetails.actualReceived": newPaidTotal,
        "lastPaymentDate": FieldValue.serverTimestamp(),
        "status": newDue <= 1 ? "completed" : "on_delivery",
        "isFullyPaid": newDue <= 1,
        "collectionHistory": FieldValue.arrayUnion([
          {
            "amount": receivedAmount,
            "date": Timestamp.now(),
            "method": method.toLowerCase(),
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
  // 3. PRINT INVOICE (FIXED PDF OVERWRITE LOGIC)
  // ==============================================================================

  Future<void> printInvoice(ConditionOrderModel order) async {
    isLoading.value = true;
    try {
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(order.invoiceId).get();
      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> rawItems = data['items'] ?? [];
      List<Map<String, dynamic>> items =
          rawItems.map((e) => e as Map<String, dynamic>).toList();

      // 1. Get Initial Payment Details (Initial Advance)
      Map<String, dynamic> paymentMap = Map<String, dynamic>.from(
        data['paymentDetails'] ?? {},
      );

      // 2. Get Collection History (Payments made LATER)
      List<dynamic> history = data['collectionHistory'] ?? [];
      double historyTotal = 0.0;

      // 3. MERGE: Add history breakdown to the initial paymentMap
      for (var h in history) {
        if (h is Map) {
          String method = h['method']?.toString().toLowerCase() ?? 'cash';
          double amount = double.tryParse(h['amount'].toString()) ?? 0.0;
          historyTotal += amount;

          // Add to the existing method bucket (e.g., if initial was 500 cash and new is 1000 cash -> total 1500)
          double existing =
              double.tryParse(paymentMap[method]?.toString() ?? '0') ?? 0.0;
          paymentMap[method] = existing + amount;
        }
      }

      // 4. Calculate Correct Total Paid (Initial Advance + History)
      double initialPaid =
          double.tryParse(paymentMap['paidForInvoice'].toString()) ?? 0.0;
      double totalPaidNow = initialPaid + historyTotal;

      // Update map to show full total
      paymentMap['paidForInvoice'] = totalPaidNow;

      // 5. Use Current Database Due
      double realDue = double.tryParse(data['courierDue'].toString()) ?? 0.0;
      paymentMap['due'] = realDue;

      // --- Other Info ---
      double oldDueSnap =
          double.tryParse(data['snapshotOldDue']?.toString() ?? "0") ?? 0.0;
      double runningDueSnap =
          double.tryParse(data['snapshotRunningDue']?.toString() ?? "0") ?? 0.0;
      int cartons = int.tryParse(data['cartons']?.toString() ?? "0") ?? 0;
      String address = data['deliveryAddress'] ?? "";
      String shop = data['shopName'] ?? "";
      String packagerName = data['packagerName'] ?? '';
      String sellerName = "Joynal Abedin";
      String sellerPhone = "01720677206";

      if (data['soldBy'] != null) {
        var soldByData = data['soldBy'];
        if (soldByData is Map) {
          sellerName = soldByData['name'] ?? sellerName;
          sellerPhone = soldByData['phone'] ?? sellerPhone;
        }  if (soldByData is String) {
          sellerName = soldByData;
        }
      }

      await _generatePdf(
        order.invoiceId,
        order.customerName,
        order.customerPhone,
        paymentMap, // Contains MERGED amounts now
        items,
        isCondition: true,
        challan: order.challanNo,
        address: address,
        courier: order.courierName,
        cartons: cartons,
        shopName: shop,
        oldDueSnap: oldDueSnap,
        runningDueSnap: runningDueSnap,
        authorizedName: sellerName,
        authorizedPhone: sellerPhone,
        packagerName: packagerName,
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
    String? packagerName,
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    // This value is now the MERGED total (Initial + Collections)
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
              packagerName,
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

  // ... (Keep existing _buildCompanyHeader, _buildInvoiceInfo, _sectionHeader, _infoRow, _buildProfessionalTable, _th, _td, _buildDetailedSummary, _summaryRow, _buildSignatures, _buildCompactPaymentLines, _buildChallanInfo, _buildConditionBox, updateChallanNumber as they were) ...

  // PDF WIDGETS SECTION (Compulsory for the controller to work)
  // I've included the key widgets below to ensure no missing references.

  pw.Widget _buildCompanyHeader(pw.Font bold, pw.Font reg) {
    return pw.Center(
      child: pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 2)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
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
    String? packagerName,
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
              if (packagerName != null && packagerName.isNotEmpty)
                _infoRow("Packed By", packagerName, bold, reg),
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
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: 8),
    ),
  );
  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: 9),
    ),
  );

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
              if (isCond) ...[
                _summaryRow(
                  "Paid / Collected",
                  totalPaid.toStringAsFixed(2),
                  reg,
                ),
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

  pw.Widget _buildCompactPaymentLines(Map payMap, pw.Font reg) {
    List<String> lines = [];
    double cash = double.tryParse(payMap['cash'].toString()) ?? 0;
    double bkash = double.tryParse(payMap['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(payMap['nagad'].toString()) ?? 0;
    double bank = double.tryParse(payMap['bank'].toString()) ?? 0;
    double totalPaid =
        double.tryParse(payMap['paidForInvoice'].toString()) ?? 0;

    if (cash > 0) lines.add("Cash: ${cash.toStringAsFixed(2)}");
    if (bkash > 0) lines.add("Bkash: ${bkash.toStringAsFixed(2)}");
    if (nagad > 0) lines.add("Nagad: ${nagad.toStringAsFixed(2)}");
    if (bank > 0) lines.add("Bank: ${bank.toStringAsFixed(2)}");

    if (lines.isEmpty) {
      if (totalPaid > 0) {
        return pw.Text(
          "Collected: ${totalPaid.toStringAsFixed(2)}",
          style: pw.TextStyle(font: reg, fontSize: 8),
        );
      }
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
    if (due <= 0) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          color: PdfColors.grey100,
        ),
        child: pw.Column(
          children: [
            pw.Text(
              "STATUS: COMPLETED",
              style: pw.TextStyle(font: bold, fontSize: 12),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "Fully Paid via Courier Collection/Advance",
              style: pw.TextStyle(font: reg, fontSize: 10),
            ),
          ],
        ),
      );
    }
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

  // ==============================================================================
  // 4. HELPER ACTIONS (UPDATE CHALLAN)
  // ==============================================================================

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
}
