// ignore_for_file: deprecated_member_use, avoid_print, empty_catches

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:intl/intl.dart';
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

      // --- NEW: EXTRACT INVOICE DATE ---
      DateTime invoiceDate = DateTime.now();
      if (data['timestamp'] is Timestamp) {
        invoiceDate = (data['timestamp'] as Timestamp).toDate();
      } else if (data['date'] != null) {
        try {
          invoiceDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(data['date']);
        } catch (e) {
          invoiceDate = DateTime.now();
        }
      }

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

          // Add to the existing method bucket
          double existing =
              double.tryParse(paymentMap[method]?.toString() ?? '0') ?? 0.0;
          paymentMap[method] = existing + amount;
        }
      }

      // 4. Calculate Correct Total Paid
      double initialPaid =
          double.tryParse(paymentMap['paidForInvoice'].toString()) ?? 0.0;
      double totalPaidNow = initialPaid + historyTotal;

      // Update map to show full total
      paymentMap['paidForInvoice'] = totalPaidNow;

      // 5. Use Current Database Due and Discount
      double realDue = double.tryParse(data['courierDue'].toString()) ?? 0.0;
      paymentMap['due'] = realDue;

      double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;

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
        } else if (soldByData is String) {
          sellerName = soldByData;
        }
      }

      // Generate PDF using the Finalized A4 Layout
      await _generatePdf(
        order.invoiceId,
        order.customerName,
        order.customerPhone,
        paymentMap,
        items,
        invoiceDate: invoiceDate, // Pass the extracted date here
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
        discount: discountVal,
        packagerName: packagerName,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not generate invoice: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // FINALIZED PDF GENERATOR (A4 Layout)
  // ==========================================
  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items, {
    required DateTime invoiceDate, // <--- Add invoiceDate parameter
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
    String? packagerName,
  }) async {
    final pdf = pw.Document();

    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    // Calculate Paid Amounts
    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidPrevRun =
        double.tryParse(payMap['paidForPrevRunning'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double totalPaidForInvoice =
        double.tryParse(payMap['paidForInvoice']?.toString() ?? '0') ?? 0.0;

    // Detect Payment Methods for String Generation
    List<String> methodsUsed = [];
    if ((double.tryParse(payMap['cash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Cash');
    }
    if ((double.tryParse(payMap['bkash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bkash');
    }
    if ((double.tryParse(payMap['nagad']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Nagad');
    }
    if ((double.tryParse(payMap['bank']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bank');
    }

    String paymentMethodsStr =
        methodsUsed.isNotEmpty ? methodsUsed.join(', ') : "None/Credit";

    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );

    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;

    double remainingPrevRunning = runningDueSnap - paidPrevRun;
    if (remainingPrevRunning < 0) remainingPrevRunning = 0;

    double netTotalDue = remainingOldDue + remainingPrevRunning + invDue;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;
    double currentInvTotal = subTotal - discount;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    // ---------------------------------------------------------
    // PAGE 1: MAIN INVOICE
    // ---------------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (pw.Context context) => _buildNewFooter(context, regularFont),
        build: (pw.Context context) {
          return [
            _buildNewHeader(
              boldFont,
              regularFont,
              invId,
              "Sales Invoice",
              packagerName,
              authorizedName,
              invDue,
              false,
              null,
              "",
              paymentMethodsStr,
              invoiceDate, // Pass original invoice date
            ),
            _buildNewCustomerBox(
              name,
              address,
              phone,
              shopName,
              regularFont,
              boldFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewTable(items, boldFont, regularFont),
            _buildNewSummary(
              subTotal,
              discount,
              currentInvTotal,
              totalPaidForInvoice,
              paymentMethodsStr,
              items,
              boldFont,
              regularFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewDues(totalPreviousBalance, netTotalDue, regularFont),
            if (invDue <= 0 && !isCondition)
              _buildPaidStamp(
                boldFont,
                regularFont,
                invoiceDate,
              ), // Pass original invoice date
            if (invDue > 0 || isCondition) pw.SizedBox(height: 15),
            _buildWordsBox(currentInvTotal, boldFont),
            pw.SizedBox(height: 40),
            _buildNewSignatures(regularFont),
          ];
        },
      ),
    );

    // ---------------------------------------------------------
    // PAGE 2: CONDITION CHALLAN (If Applicable)
    // ---------------------------------------------------------
    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: (pw.Context context) => _buildNewFooter(context, regularFont),
          build: (context) {
            return [
              _buildNewHeader(
                boldFont,
                regularFont,
                invId,
                "DELIVERY CHALLAN",
                packagerName,
                authorizedName,
                invDue,
                isCondition,
                courier,
                challan,
                paymentMethodsStr,
                invoiceDate, // Pass original invoice date
              ),
              _buildNewCustomerBox(
                name,
                address,
                phone,
                shopName,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 20),
              _buildCourierBox(
                courier,
                challan,
                cartons,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 60),
              _buildChallanCenterBox(boldFont, regularFont, invDue),
              pw.SizedBox(height: 100),
              _buildNewSignatures(regularFont),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  // --- COMPONENT: TOP HEADER ---
  pw.Widget _buildNewHeader(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String title,
    String? packager,
    String authorizedName,
    double invDue,
    bool isCondition,
    String? courier,
    String challan,
    String paymentMethodsStr,
    DateTime invoiceDate, // <--- Add this parameter
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Side: Company Info
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "G TEL",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "6/24A(7th Floor) Gulistan Shopping Complex (Hall Market)\n2 Bangabandu Avenue, Dhaka 1000",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "Cell : 01720677206, 01911026222",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "E-mail : gtel01720677206@gmail.com",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(right: 40),
                child: pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        // Right Side: Invoice Info Box
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              children: [
                _infoRow("Invoice No.", ": $invId", reg, bold),
                _infoRow(
                  "Date",
                  ": ${DateFormat('dd/MM/yyyy').format(invoiceDate)}", // <--- USE ORIGINAL INVOICE DATE
                  reg,
                  bold,
                ),
                _infoRow("Ref: No", ": ", reg, bold),
                _infoRow(
                  "Prepared/Packged By",
                  ": ${packager ?? 'Admin'}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Entry Time",
                  ": ${DateFormat('h:mm:ss a').format(invoiceDate)}", // <--- USE ORIGINAL INVOICE TIME
                  reg,
                  bold,
                ),
                _infoRow(
                  "Bill Type",
                  ": ${invDue <= 0 ? 'PAID' : 'DUE'}",
                  reg,
                  bold,
                ),
                _infoRow("Payment Via", ": $paymentMethodsStr", reg, bold),
                _infoRow("Sales Person", ": $authorizedName", reg, bold),
                if (isCondition) ...[
                  _infoRow("Courier", ": ${courier ?? 'N/A'}", reg, bold),
                  _infoRow("Challan No", ": $challan", reg, bold),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- COMPONENT: PAID STAMP ---
  pw.Widget _buildPaidStamp(pw.Font bold, pw.Font reg, DateTime invoiceDate) {
    // <--- Add this parameter
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 20),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              "P A I D",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              DateFormat(
                'dd MMM yyyy',
              ).format(invoiceDate), // <--- USE ORIGINAL INVOICE DATE
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 12,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "G TEL",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT: CUSTOMER BOX ---
  pw.Widget _buildNewCustomerBox(
    String name,
    String address,
    String phone,
    String shopName,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow("To", ": $name", reg, bold, col1Width: 60),
          _infoRow("Address", address, reg, bold, col1Width: 60),
          _infoRow("Contact No.", ": $phone", reg, bold, col1Width: 60),
        ],
      ),
    );
  }

  // --- COMPONENT: COURIER BOX (NEW FOR CHALLAN) ---
  pw.Widget _buildCourierBox(
    String? courier,
    String challan,
    int? cartons,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Courier Information",
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          _infoRow(
            "Courier Name",
            ": ${courier ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Booking/Challan No",
            ": $challan",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Total Cartons",
            ": ${cartons?.toString() ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
        ],
      ),
    );
  }

  // --- COMPONENT: ITEMS TABLE ---
  pw.Widget _buildNewTable(
    List<Map<String, dynamic>> items,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          children: [
            _th("SL", bold),
            _th("Product Description", bold, align: pw.TextAlign.left),
            _th("Qty", bold),
            _th("Unit Price", bold),
            _th("Amount", bold),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              _td(
                // ignore: prefer_interpolation_to_compose_strings
                "${item['name']}${item['model'] != null ? ' - ' + item['model'] : ''}",
                reg,
              ),
              _td(item['qty'].toString(), reg, align: pw.TextAlign.center),
              _td(
                double.parse(item['saleRate'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
              _td(
                double.parse(item['subtotal'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  // --- COMPONENT: SUMMARY CALCULATION ---
  pw.Widget _buildNewSummary(
    double subTotal,
    double discount,
    double currentInvTotal,
    double paidForInvoice,
    String paymentMethodsStr,
    List items,
    pw.Font bold,
    pw.Font reg,
  ) {
    int totalQty = items.fold(
      0,
      (sumv, item) => sumv + ((item['qty'] as num?)?.toInt() ?? 0),
    );
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Total Qty : $totalQty",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Narration:",
                    style: pw.TextStyle(font: reg, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                children: [
                  _sumRow(
                    "Total Amount",
                    subTotal.toStringAsFixed(2),
                    bold,
                    reg,
                  ),
                  _sumRow(
                    "Less Discount",
                    discount.toStringAsFixed(2),
                    reg,
                    reg,
                  ),
                  _sumRow("Add VAT", "0.00", reg, reg),
                  _sumRow("Add Extra Charges", "0.00", reg, reg),
                  pw.Divider(thickness: 0.5, height: 8),
                  _sumRow(
                    "Net Payable Amount",
                    currentInvTotal.toStringAsFixed(2),
                    bold,
                    bold,
                  ),
                  pw.SizedBox(height: 2),
                  _sumRow(
                    "Paid Amount",
                    paidForInvoice.toStringAsFixed(2),
                    reg,
                    bold,
                  ),
                  if (paymentMethodsStr != "None/Credit")
                    _sumRow("Payment Method", paymentMethodsStr, reg, reg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT: DUES SECTION ---
  pw.Widget _buildNewDues(double prevDue, double netDue, pw.Font reg) {
    return pw.Container(
      width: 200,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        children: [
          _sumRow(
            "Previous Due Amount :",
            prevDue.toStringAsFixed(2),
            reg,
            reg,
          ),
          pw.Divider(thickness: 0.5, height: 5),
          _sumRow("Present Due Amount :", netDue.toStringAsFixed(2), reg, reg),
        ],
      ),
    );
  }



  // --- COMPONENT: TAKA IN WORDS BOX ---
  pw.Widget _buildWordsBox(double currentInvTotal, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        "Taka in word : ${_numberToWords(currentInvTotal)} Only",
        style: pw.TextStyle(font: bold, fontSize: 9),
      ),
    );
  }

  String _numberToWords(double number) {
    if (number == 0) return "Zero";
    int num = number.floor();
    if (num < 0) return "Negative ${_numberToWords(-number)}";

    const units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen",
    ];
    const tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety",
    ];

    String convertLessThanOneThousand(int n) {
      String result = "";
      if (n >= 100) {
        result += "${units[n ~/ 100]} Hundred ";
        n %= 100;
      }
      if (n >= 20) {
        result += "${tens[n ~/ 10]} ";
        n %= 10;
      }
      if (n > 0) result += "${units[n]} ";
      return result;
    }

    String result = "";
    int crore = num ~/ 10000000;
    num %= 10000000;
    int lakh = num ~/ 100000;
    num %= 100000;
    int thousand = num ~/ 1000;
    num %= 1000;
    int remainder = num;

    if (crore > 0) result += "${convertLessThanOneThousand(crore)}Crore ";
    if (lakh > 0) result += "${convertLessThanOneThousand(lakh)}Lakh ";
    if (thousand > 0) {
      result += "${convertLessThanOneThousand(thousand)}Thousand ";
    }
    if (remainder > 0) result += convertLessThanOneThousand(remainder);

    return result.trim();
  }

  // --- COMPONENT: SIGNATURES ---
  pw.Widget _buildNewSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Client Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Goods Delivery/Prepare",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Authorized Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  // --- COMPONENT: FOOTER ---
  pw.Widget _buildNewFooter(pw.Context context, pw.Font reg) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            "Terms & Conditions: 1. Goods once sold will not be refunded and changed, 2. Warranty will be void if any sticker removed, physically damaged and burn case, 3. Please keep this invoice/bill for warranty support.",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Sales Billing Software By G TEL : 01720677206",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Print Date & Time : ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  // --- COMPONENT: NEW CHALLAN CENTER BOX (Replaces Condition Box) ---
  pw.Widget _buildChallanCenterBox(pw.Font bold, pw.Font reg, double due) {
    bool isPaid = due <= 0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isPaid ? PdfColors.green700 : PdfColors.deepOrange700,
          width: 2,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: isPaid ? PdfColors.green50 : PdfColors.deepOrange50,
      ),
      child: pw.Column(
        children: [
          if (isPaid) ...[
            pw.Text(
              "NON CONDITION",
              style: pw.TextStyle(
                font: bold,
                fontSize: 24,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "+ Courier Charges",
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: PdfColors.green800,
              ),
            ),
          ] else ...[
            pw.Text(
              "CONDITION PAYMENT INSTRUCTION FOR COURIER",
              style: pw.TextStyle(
                font: reg,
                fontSize: 11,
                color: PdfColors.deepOrange800,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "PLEASE COLLECT: ",
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                pw.Text(
                  "BDT ${due.toStringAsFixed(0)}",
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 24,
                    color: PdfColors.deepOrange900,
                  ),
                ),
                pw.Text(
                  " + Courier Charges",
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // HELPER FOR ROWS IN PDF
  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    double col1Width = 75,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: col1Width,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sumRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: valFont, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

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
