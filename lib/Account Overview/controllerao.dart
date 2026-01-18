// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/model.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Staff/controller.dart';
import 'package:intl/intl.dart';

// PDF & PRINTING
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// EXTERNAL CONTROLLERS
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';


class FinancialController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================
  // 1. STATE VARIABLES
  // =========================================================

  // Local Lists
  RxList<FixedAssetModel> fixedAssets = <FixedAssetModel>[].obs;
  RxList<RecurringExpenseModel> recurringExpenses =
      <RecurringExpenseModel>[].obs;

  // Calculated Debtor Payable (Global)
  RxDouble globalDebtorPurchasePayable = 0.0.obs;

  // =========================================================
  // 2. DEPENDENCIES (Safe Getters)
  // =========================================================
  CashDrawerController get _cashCtrl => Get.find<CashDrawerController>();
  DebatorController get _debtorCtrl => Get.find<DebatorController>();
  ProductController get _stockCtrl => Get.find<ProductController>();
  ShipmentController get _shipmentCtrl => Get.find<ShipmentController>();
  StaffController get _staffCtrl => Get.find<StaffController>();
  VendorController get _vendorCtrl => Get.find<VendorController>();

  // =========================================================
  // 3. ASSET CALCULATIONS
  // =========================================================

  // 1. Total Liquid Cash
  double get totalCash => _cashCtrl.grandTotal.value;

  // 2. Fixed Assets (Manual)
  double get totalFixedAssets =>
      fixedAssets.fold(0.0, (sumv, item) => sumv + item.value);

  // 3. Stock Inventory
  double get totalStockValuation => _stockCtrl.overallTotalValuation.value;

  // 4. Shipments On Way
  double get totalShipmentValuation => _shipmentCtrl.totalOnWayValue;

  // 5. Receivables (Money Debtors Owe Us from Sales)
  double get totalDebtorReceivables => _debtorCtrl.totalMarketOutstanding.value;

  // 6. Staff Loans (Money Employees Owe Us)
  double get totalEmployeeDebt {
    if (Get.isRegistered<StaffController>()) {
      return _staffCtrl.staffList.fold(
        0.0,
        (sumv, item) => sumv + item.currentDebt,
      );
    }
    return 0.0;
  }

  // >>> TOTAL ASSETS <<<
  double get grandTotalAssets =>
      totalCash +
      totalFixedAssets +
      totalStockValuation +
      totalShipmentValuation +
      totalDebtorReceivables +
      totalEmployeeDebt;

  // =========================================================
  // 4. LIABILITY CALCULATIONS
  // =========================================================

  // 1. Vendor Payables (Money we owe Vendors)
  double get totalVendorDue {
    if (Get.isRegistered<VendorController>()) {
      return _vendorCtrl.vendors.fold(
        0.0,
        (sumv, vendor) => sumv + vendor.totalDue,
      );
    }
    return 0.0;
  }

  // 2. Debtor Payables (Money we owe Debtors from Purchases)
  // This is streamed directly from 'debatorbody' where 'purchaseDue' > 0
  double get totalDebtorPayable => globalDebtorPurchasePayable.value;

  // 3. Monthly Payroll (Recurring Commitment)
  double get totalMonthlyPayroll =>
      recurringExpenses.fold(0.0, (sumv, item) => sumv + item.monthlyAmount);

  // >>> TOTAL LIABILITIES <<<
  // (Vendor Due + Debtor Payable + Payroll)
  double get grandTotalLiabilities =>
      totalVendorDue + totalDebtorPayable + totalMonthlyPayroll;

  // =========================================================
  // 5. NET WORTH & LEFTOVER
  // =========================================================

  double get netWorth => grandTotalAssets - grandTotalLiabilities;

  // =========================================================
  // 6. INITIALIZATION
  // =========================================================
  @override
  void onInit() {
    super.onInit();
    _bindLocalStreams();
    _bindDebtorPayableStream(); // Dedicated stream for purchase liability
    refreshExternalData();
  }

  // Bind Manual Assets & Payroll
  void _bindLocalStreams() {
    _db.collection('company_assets').snapshots().listen((snap) {
      fixedAssets.value =
          snap.docs.map((e) => FixedAssetModel.fromSnapshot(e)).toList();
    });
    _db.collection('company_payroll_setup').snapshots().listen((snap) {
      recurringExpenses.value =
          snap.docs.map((e) => RecurringExpenseModel.fromSnapshot(e)).toList();
    });
  }

  // Bind Global Debtor Payable (Aggregation)
  void _bindDebtorPayableStream() {
    // We listen to all debtors. If they have a 'purchaseDue' field, we sum it up.
    // Ensure your DebtorPurchaseController updates this field on the main doc!
    _db.collection('debatorbody').snapshots().listen((snap) {
      double total = 0.0;
      for (var doc in snap.docs) {
        final data = doc.data();
        // Look for purchaseDue, payableBalance, or similar
        double due =
            double.tryParse((data['purchaseDue'] ?? 0).toString()) ?? 0.0;
        total += due;
      }
      globalDebtorPurchasePayable.value = total;
    });
  }

  Future<void> refreshExternalData() async {
    try {
      if (Get.isRegistered<CashDrawerController>()) await _cashCtrl.fetchData();
      if (Get.isRegistered<DebatorController>()) await _debtorCtrl.loadBodies();
      if (Get.isRegistered<ProductController>()) {
        await _stockCtrl.fetchProducts();
      }
      if (Get.isRegistered<StaffController>()) await _staffCtrl.loadStaff();
      if (Get.isRegistered<VendorController>()) _vendorCtrl.bindVendors();
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  // =========================================================
  // 7. CRUD OPERATIONS
  // =========================================================

  Future<void> addAsset(String name, double value, String category) async {
    await _db.collection('company_assets').add({
      'name': name,
      'value': value,
      'category': category,
      'date': Timestamp.now(),
    });
    Get.back();
  }

  Future<void> deleteAsset(String id) async =>
      await _db.collection('company_assets').doc(id).delete();

  Future<void> addRecurringExpense(
    String title,
    double amount,
    String type,
  ) async {
    await _db.collection('company_payroll_setup').add({
      'title': title,
      'monthlyAmount': amount,
      'type': type,
    });
    Get.back();
  }

  Future<void> deleteRecurringExpense(String id) async =>
      await _db.collection('company_payroll_setup').doc(id).delete();

  // =========================================================
  // 8. PDF REPORT GENERATOR (MULTI-PAGE)
  // =========================================================
  Future<void> generateAndPrintPDF() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final currencyFmt = NumberFormat.currency(
      locale: 'en_BD',
      symbol: '',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // HEADER
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "COMPANY FINANCIAL STATEMENT",
                          style: pw.TextStyle(font: fontBold, fontSize: 20),
                        ),
                        pw.Text(
                          "Official Financial Position",
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      date,
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // SUMMARY BOX
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  color: PdfColors.grey50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSummaryItem(
                      "Total Assets",
                      grandTotalAssets,
                      fontBold,
                      PdfColors.green800,
                      currencyFmt,
                    ),
                    _pdfSummaryItem(
                      "Total Liabilities",
                      grandTotalLiabilities,
                      fontBold,
                      PdfColors.red800,
                      currencyFmt,
                    ),
                    _pdfSummaryItem(
                      "NET WORTH",
                      netWorth,
                      fontBold,
                      PdfColors.blue900,
                      currencyFmt,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // 1. ASSETS DETAILED TABLE
              pw.Text(
                "ASSETS BREAKDOWN",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.Divider(thickness: 0.5),
              pw.Table.fromTextArray(
                headers: ['Category', 'Description', 'Valuation (BDT)'],
                data: [
                  [
                    'Liquid Cash',
                    'Cash, Bank, Mobile Wallets',
                    currencyFmt.format(totalCash),
                  ],
                  [
                    'Inventory',
                    'Stock at Warehouse',
                    currencyFmt.format(totalStockValuation),
                  ],
                  [
                    'Shipments',
                    'Inventory On-The-Way',
                    currencyFmt.format(totalShipmentValuation),
                  ],
                  [
                    'Receivables',
                    'Debtor Sales Dues',
                    currencyFmt.format(totalDebtorReceivables),
                  ],
                  [
                    'Staff Loans',
                    'Employee Advances',
                    currencyFmt.format(totalEmployeeDebt),
                  ],
                  [
                    'Fixed Assets',
                    'Manual Assets (Equipment)',
                    currencyFmt.format(totalFixedAssets),
                  ],
                ],
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
              ),

              pw.SizedBox(height: 20),

              // 2. LIABILITIES DETAILED TABLE
              pw.Text(
                "LIABILITIES BREAKDOWN",
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.Divider(thickness: 0.5),
              pw.Table.fromTextArray(
                headers: ['Category', 'Description', 'Amount (BDT)'],
                data: [
                  [
                    'Vendor Payables',
                    'Due to Suppliers',
                    currencyFmt.format(totalVendorDue),
                  ],
                  [
                    'Debtor Payables',
                    'Purchase Dues / Returns',
                    currencyFmt.format(totalDebtorPayable),
                  ],
                  [
                    'Monthly Payroll',
                    'Salaries & OpEx',
                    currencyFmt.format(totalMonthlyPayroll),
                  ],
                ],
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.red800,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
              ),

              pw.SizedBox(height: 30),

              // 3. FIXED ASSETS LIST (If any)
              if (fixedAssets.isNotEmpty) ...[
                pw.Text(
                  "FIXED ASSETS DETAIL",
                  style: pw.TextStyle(font: fontBold, fontSize: 12),
                ),
                pw.Divider(thickness: 0.5),
                pw.Table.fromTextArray(
                  headers: ['Asset Name', 'Category', 'Value'],
                  data:
                      fixedAssets
                          .map(
                            (e) => [
                              e.name,
                              e.category,
                              currencyFmt.format(e.value),
                            ],
                          )
                          .toList(),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    color: PdfColors.black,
                    fontSize: 9,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.SizedBox(height: 20),
              ],

              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "System Generated Report",
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    "Page 1",
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Financial_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  pw.Widget _pdfSummaryItem(
    String title,
    double amount,
    pw.Font font,
    PdfColor color,
    NumberFormat fmt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          fmt.format(amount),
          style: pw.TextStyle(font: font, fontSize: 16, color: color),
        ),
      ],
    );
  }
}
