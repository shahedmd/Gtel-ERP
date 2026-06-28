// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/model.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Staff/controller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';

// ─────────────────────────────────────────────────────────────
// MODEL: Closed (Archived) Financial Report
// ─────────────────────────────────────────────────────────────
class ClosedYearReport {
  final String id;
  final int year;
  final DateTime closedAt;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double cash;
  // ── Individual cash breakdown ──
  final double cashDrawer;
  final double bank;
  final double bkash;
  final double nagad;
  // ──────────────────────────────
  final double stockValuation;
  final double shipmentValuation;
  final double debtorReceivables;
  final double employeeDebt;
  final double fixedAssets;
  final double vendorDue;
  final double debtorPayable;
  final double monthlyPayroll;
  final List<Map<String, dynamic>> fixedAssetsList;
  final List<Map<String, dynamic>> payrollList;

  ClosedYearReport({
    required this.id,
    required this.year,
    required this.closedAt,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.cash,
    required this.cashDrawer,
    required this.bank,
    required this.bkash,
    required this.nagad,
    required this.stockValuation,
    required this.shipmentValuation,
    required this.debtorReceivables,
    required this.employeeDebt,
    required this.fixedAssets,
    required this.vendorDue,
    required this.debtorPayable,
    required this.monthlyPayroll,
    required this.fixedAssetsList,
    required this.payrollList,
  });

  factory ClosedYearReport.fromSnapshot(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClosedYearReport(
      id: doc.id,
      year: d['year'] ?? 0,
      closedAt: (d['closedAt'] as Timestamp).toDate(),
      totalAssets: (d['totalAssets'] ?? 0).toDouble(),
      totalLiabilities: (d['totalLiabilities'] ?? 0).toDouble(),
      netWorth: (d['netWorth'] ?? 0).toDouble(),
      cash: (d['cash'] ?? 0).toDouble(),
      // Falls back to 0 for old snapshots that didn't save these fields
      cashDrawer: (d['cashDrawer'] ?? 0).toDouble(),
      bank: (d['bank'] ?? 0).toDouble(),
      bkash: (d['bkash'] ?? 0).toDouble(),
      nagad: (d['nagad'] ?? 0).toDouble(),
      stockValuation: (d['stockValuation'] ?? 0).toDouble(),
      shipmentValuation: (d['shipmentValuation'] ?? 0).toDouble(),
      debtorReceivables: (d['debtorReceivables'] ?? 0).toDouble(),
      employeeDebt: (d['employeeDebt'] ?? 0).toDouble(),
      fixedAssets: (d['fixedAssets'] ?? 0).toDouble(),
      vendorDue: (d['vendorDue'] ?? 0).toDouble(),
      debtorPayable: (d['debtorPayable'] ?? 0).toDouble(),
      monthlyPayroll: (d['monthlyPayroll'] ?? 0).toDouble(),
      fixedAssetsList: List<Map<String, dynamic>>.from(
        d['fixedAssetsList'] ?? [],
      ),
      payrollList: List<Map<String, dynamic>>.from(d['payrollList'] ?? []),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────
class FinancialController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Observables ──
  RxList<FixedAssetModel> fixedAssets = <FixedAssetModel>[].obs;
  RxList<RecurringExpenseModel> recurringExpenses =
      <RecurringExpenseModel>[].obs;
  RxList<ClosedYearReport> closedYearReports = <ClosedYearReport>[].obs;

  RxDouble globalDebtorPurchasePayable = 0.0.obs;

  /// True while initial data fetch is in progress — drives shimmer skeleton
  RxBool isLoading = true.obs;

  /// Currently selected closed year for comparison (null = no comparison active)
  Rx<ClosedYearReport?> comparisonReport = Rx<ClosedYearReport?>(null);

  // ── Getters: Injected Controllers ──
  CashDrawerController get _cashCtrl => Get.find<CashDrawerController>();
  DebatorController get _debtorCtrl => Get.find<DebatorController>();
  ProductController get _stockCtrl => Get.find<ProductController>();
  ShipmentController get _shipmentCtrl => Get.find<ShipmentController>();
  StaffController get _staffCtrl => Get.find<StaffController>();
  VendorController get _vendorCtrl => Get.find<VendorController>();

  // ─────────────────────────────────────────────────────────────
  // ASSET GETTERS
  // ─────────────────────────────────────────────────────────────
  double get totalCash => _cashCtrl.grandTotal.value;
  double get totalFixedAssets => fixedAssets.fold(0.0, (s, i) => s + i.value);
  double get totalStockValuation => _stockCtrl.overallTotalValuation.value;
  double get totalShipmentValuation => _shipmentCtrl.totalOnWayValue;
  double get totalDebtorReceivables => _debtorCtrl.totalMarketOutstanding.value;

  double get totalEmployeeDebt {
    if (Get.isRegistered<StaffController>()) {
      return _staffCtrl.staffList.fold(0.0, (s, i) => s + i.currentDebt);
    }
    return 0.0;
  }

  double get grandTotalAssets =>
      totalCash +
      totalFixedAssets +
      totalStockValuation +
      totalShipmentValuation +
      totalDebtorReceivables +
      totalEmployeeDebt;

  // ─────────────────────────────────────────────────────────────
  // LIABILITY GETTERS
  // ─────────────────────────────────────────────────────────────
  double get totalVendorDue {
    if (Get.isRegistered<VendorController>()) {
      return _vendorCtrl.vendors.fold(0.0, (s, v) => s + v.totalDue);
    }
    return 0.0;
  }

  double get totalDebtorPayable => globalDebtorPurchasePayable.value;

  double get totalMonthlyPayroll =>
      recurringExpenses.fold(0.0, (s, i) => s + i.monthlyAmount);

  double get grandTotalLiabilities =>
      totalVendorDue + totalDebtorPayable + totalMonthlyPayroll;

  double get netWorth => grandTotalAssets - grandTotalLiabilities;

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _bindLocalStreams();
    _bindDebtorPayableStream();
    _bindClosedYearStream();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    await refreshExternalData();
    isLoading.value = false;
  }

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

  void _bindDebtorPayableStream() {
    _db.collection('debatorbody').snapshots().listen((snap) {
      double total = 0.0;
      for (var doc in snap.docs) {
        final data = doc.data();
        double due =
            double.tryParse((data['purchaseDue'] ?? 0).toString()) ?? 0.0;
        total += due;
      }
      globalDebtorPurchasePayable.value = total;
    });
  }

  void _bindClosedYearStream() {
    _db
        .collection('closed_year_reports')
        .orderBy('year', descending: true)
        .snapshots()
        .listen((snap) {
          closedYearReports.value =
              snap.docs.map((e) => ClosedYearReport.fromSnapshot(e)).toList();
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

  // ─────────────────────────────────────────────────────────────
  // CRUD: Assets & Expenses
  // ─────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // YEAR-END CLOSE
  // ─────────────────────────────────────────────────────────────

  /// Closes (snapshots) the current financial state for [year].
  /// Returns the document ID of the saved snapshot so it can be
  /// displayed / confirmed to the user.
  Future<String> closeYear(int year) async {
    final docRef = await _db.collection('closed_year_reports').add({
      'year': year,
      'closedAt': Timestamp.now(),
      'totalAssets': grandTotalAssets,
      'totalLiabilities': grandTotalLiabilities,
      'netWorth': netWorth,
      'cash': totalCash,
      // ── Individual cash breakdown ──
      'cashDrawer': _cashCtrl.netCash.value,
      'bank': _cashCtrl.netBank.value,
      'bkash': _cashCtrl.netBkash.value,
      'nagad': _cashCtrl.netNagad.value,
      // ──────────────────────────────
      'stockValuation': totalStockValuation,
      'shipmentValuation': totalShipmentValuation,
      'debtorReceivables': totalDebtorReceivables,
      'employeeDebt': totalEmployeeDebt,
      'fixedAssets': totalFixedAssets,
      'vendorDue': totalVendorDue,
      'debtorPayable': totalDebtorPayable,
      'monthlyPayroll': totalMonthlyPayroll,
      'fixedAssetsList':
          fixedAssets
              .map(
                (a) => {
                  'name': a.name,
                  'category': a.category,
                  'value': a.value,
                },
              )
              .toList(),
      'payrollList':
          recurringExpenses
              .map((e) => {'title': e.title, 'monthlyAmount': e.monthlyAmount})
              .toList(),
    });
    return docRef.id;
  }

  /// Restores (deletes) a previously closed report.
  Future<void> restoreClosedYear(String docId) async {
    await _db.collection('closed_year_reports').doc(docId).delete();
    if (comparisonReport.value?.id == docId) {
      comparisonReport.value = null;
    }
  }

  /// Set which closed year to compare against the live data.
  void setComparison(ClosedYearReport? report) {
    comparisonReport.value = report;
  }

  // ─────────────────────────────────────────────────────────────
  // PROFESSIONAL PDF — matches UI detail level
  //
  // [printSnapshot] — when set, the PDF prints that closed year's
  //   saved numbers instead of the live controller values.
  //   Used when reprinting an archived report from the history sheet.
  // [compareWith]   — when set alongside live data (printSnapshot=null),
  //   adds a side-by-side comparison column to every table.
  // ─────────────────────────────────────────────────────────────
  Future<void> generateAndPrintPDF({
    ClosedYearReport? compareWith,
    ClosedYearReport? printSnapshot,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final fmt = NumberFormat.currency(
      locale: 'en_BD',
      symbol: 'BDT ',
      decimalDigits: 0,
    );
    final fmtCompact = NumberFormat.compactCurrency(
      locale: 'en_BD',
      symbol: 'BDT ',
      decimalDigits: 1,
    );
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(now);

    // ── Decide which numbers to print ──
    // If we are printing an archived snapshot, use its values.
    // If we are printing the live report, use the controller's live getters.
    final bool isSnapshot = printSnapshot != null;
    final double pTotalCash = isSnapshot ? printSnapshot.cash : totalCash;
    final double pCashDrawer =
        isSnapshot ? printSnapshot.cashDrawer : _cashCtrl.netCash.value;
    final double pBank =
        isSnapshot ? printSnapshot.bank : _cashCtrl.netBank.value;
    final double pBkash =
        isSnapshot ? printSnapshot.bkash : _cashCtrl.netBkash.value;
    final double pNagad =
        isSnapshot ? printSnapshot.nagad : _cashCtrl.netNagad.value;
    final double pStockValuation =
        isSnapshot ? printSnapshot.stockValuation : totalStockValuation;
    final double pShipmentValuation =
        isSnapshot ? printSnapshot.shipmentValuation : totalShipmentValuation;
    final double pDebtorReceivables =
        isSnapshot ? printSnapshot.debtorReceivables : totalDebtorReceivables;
    final double pEmployeeDebt =
        isSnapshot ? printSnapshot.employeeDebt : totalEmployeeDebt;
    final double pFixedAssets =
        isSnapshot ? printSnapshot.fixedAssets : totalFixedAssets;
    final double pGrandTotalAssets =
        isSnapshot ? printSnapshot.totalAssets : grandTotalAssets;
    final double pVendorDue =
        isSnapshot ? printSnapshot.vendorDue : totalVendorDue;
    final double pDebtorPayable =
        isSnapshot ? printSnapshot.debtorPayable : totalDebtorPayable;
    final double pMonthlyPayroll =
        isSnapshot ? printSnapshot.monthlyPayroll : totalMonthlyPayroll;
    final double pGrandTotalLiab =
        isSnapshot ? printSnapshot.totalLiabilities : grandTotalLiabilities;
    final double pNetWorth = isSnapshot ? printSnapshot.netWorth : netWorth;
    final List<Map<String, dynamic>> pFixedAssetsList =
        isSnapshot
            ? printSnapshot.fixedAssetsList
            : fixedAssets
                .map(
                  (a) => {
                    'name': a.name,
                    'category': a.category,
                    'value': a.value,
                  },
                )
                .toList();
    final List<Map<String, dynamic>> pPayrollList =
        isSnapshot
            ? printSnapshot.payrollList
            : recurringExpenses
                .map(
                  (e) => {
                    'title': e.title,
                    'type': e.type,
                    'monthlyAmount': e.monthlyAmount,
                  },
                )
                .toList();

    final int reportYear = isSnapshot ? printSnapshot.year : now.year;
    final String yearStr = reportYear.toString();

    // ── Palette ──
    const headerBg = PdfColor.fromInt(0xFF1E293B);
    const assetGreen = PdfColor.fromInt(0xFF059669);
    const liabRed = PdfColor.fromInt(0xFFDC2626);
    const netBlue = PdfColor.fromInt(0xFF2563EB);
    const sectionGrey = PdfColor.fromInt(0xFF475569);
    const rowEven = PdfColor.fromInt(0xFFF8FAFC);
    const divider = PdfColor.fromInt(0xFFE2E8F0);

    // ── Helpers ──
    pw.Widget hline() => pw.Container(
      height: 0.5,
      color: divider,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
    );

    pw.Widget kpiBox(
      String label,
      double amount,
      PdfColor color, {
      double? prev,
    }) {
      final diff = prev != null ? amount - prev : null;
      final isUp = diff != null && diff >= 0;
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: divider),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                fmt.format(amount),
                style: pw.TextStyle(font: fontBold, fontSize: 13, color: color),
              ),
              if (diff != null)
                pw.Text(
                  '${isUp ? '▲' : '▼'} ${fmtCompact.format(diff.abs())} vs prev year',
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 7,
                    color: isUp ? assetGreen : liabRed,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String text, PdfColor accent) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(width: 3, height: 14, color: accent),
          pw.SizedBox(width: 6),
          pw.Text(
            text,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: sectionGrey,
            ),
          ),
        ],
      ),
    );

    pw.Widget tableRow(
      List<String> cells, {
      bool isHeader = false,
      bool isTotal = false,
      bool isSubtotal = false,
      PdfColor? rowBg,
    }) {
      final bg =
          isHeader
              ? headerBg
              : isTotal
              ? const PdfColor.fromInt(0xFFEFF6FF)
              : isSubtotal
              ? const PdfColor.fromInt(0xFFE8F5E9)
              : (rowBg ?? PdfColors.white);
      final txtColor = isHeader ? PdfColors.white : PdfColors.black;
      final txtFont = (isHeader || isTotal || isSubtotal) ? fontBold : font;
      final sizes = [3, 4, 2];

      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(
          children:
              cells.asMap().entries.map((e) {
                final isLast = e.key == cells.length - 1;
                return pw.Expanded(
                  flex: sizes[e.key],
                  child: pw.Text(
                    e.value,
                    textAlign: isLast ? pw.TextAlign.right : pw.TextAlign.left,
                    style: pw.TextStyle(
                      font: txtFont,
                      fontSize: 9,
                      color:
                          isSubtotal
                              ? const PdfColor.fromInt(0xFF059669)
                              : txtColor,
                    ),
                  ),
                );
              }).toList(),
        ),
      );
    }

    pw.Widget compRow(
      String label,
      double current,
      double? prev, {
      bool isTotal = false,
      bool isSubtotal = false,
    }) {
      final diff = prev != null ? current - prev : null;
      final isUp = diff != null && diff >= 0;
      final txtFont = (isTotal || isSubtotal) ? fontBold : font;
      const sizes = [3, 2, 2, 2];
      final cells = [
        label,
        fmt.format(current),
        prev != null ? fmt.format(prev) : '—',
        diff != null ? '${isUp ? '+' : ''}${fmtCompact.format(diff)}' : '—',
      ];
      final rowColor =
          isTotal
              ? const PdfColor.fromInt(0xFFEFF6FF)
              : isSubtotal
              ? const PdfColor.fromInt(0xFFE8F5E9)
              : PdfColors.white;
      return pw.Container(
        color: rowColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(
          children:
              cells.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                PdfColor? cellColor;
                if (isSubtotal) {
                  cellColor = const PdfColor.fromInt(0xFF059669);
                } else if (e.key == 3 && diff != null) {
                  cellColor = isUp ? assetGreen : liabRed;
                }
                return pw.Expanded(
                  flex: sizes[e.key],
                  child: pw.Text(
                    e.value,
                    textAlign: isFirst ? pw.TextAlign.left : pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: txtFont,
                      fontSize: 9,
                      color: cellColor ?? PdfColors.black,
                    ),
                  ),
                );
              }).toList(),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // PAGE BUILD
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header:
            (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  color: headerBg,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'COMPANY FINANCIAL STATEMENT',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Official Balance Sheet · Fiscal Year $yearStr',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Generated: $dateStr',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            ),
        footer:
            (ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential · System-Generated Report',
                    style: pw.TextStyle(
                      font: fontItalic,
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ),
        build:
            (ctx) => [
              // ── KPI Summary Row ──
              pw.Row(
                children: [
                  kpiBox(
                    'Total Business Value (Assets)',
                    pGrandTotalAssets,
                    assetGreen,
                    prev: compareWith?.totalAssets,
                  ),
                  kpiBox(
                    'Total Debt (Liabilities)',
                    pGrandTotalLiab,
                    liabRed,
                    prev: compareWith?.totalLiabilities,
                  ),
                  kpiBox(
                    'Real Value (Net Worth)',
                    pNetWorth,
                    netBlue,
                    prev: compareWith?.netWorth,
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // ── ASSETS SECTION ──
              sectionTitle('ASSETS — WHAT YOU OWN', assetGreen),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: divider),
                ),
                child: pw.Column(
                  children: [
                    tableRow(
                      compareWith != null
                          ? [
                            'Category',
                            'FY $yearStr',
                            'FY ${compareWith.year}',
                            'Change',
                          ]
                          : ['Category', 'Description', 'Valuation (BDT)'],
                      isHeader: true,
                    ),
                    if (compareWith != null) ...[
                      compRow(
                        'Cash Drawer',
                        pCashDrawer,
                        compareWith.cashDrawer,
                      ),
                      compRow('Bank Accounts', pBank, compareWith.bank),
                      compRow('bKash Wallet', pBkash, compareWith.bkash),
                      compRow('Nagad Wallet', pNagad, compareWith.nagad),
                      compRow(
                        '  ↳ Total Liquid Cash',
                        pTotalCash,
                        compareWith.cash,
                        isSubtotal: true,
                      ),
                      compRow(
                        'Stock Inventory',
                        pStockValuation,
                        compareWith.stockValuation,
                      ),
                      compRow(
                        'Incoming Shipments',
                        pShipmentValuation,
                        compareWith.shipmentValuation,
                      ),
                      compRow(
                        'Customer Receivables',
                        pDebtorReceivables,
                        compareWith.debtorReceivables,
                      ),
                      compRow(
                        'Staff Loans / Advances',
                        pEmployeeDebt,
                        compareWith.employeeDebt,
                      ),
                      compRow(
                        'Fixed Assets (Equipment)',
                        pFixedAssets,
                        compareWith.fixedAssets,
                      ),
                      hline(),
                      compRow(
                        'TOTAL ASSETS',
                        pGrandTotalAssets,
                        compareWith.totalAssets,
                        isTotal: true,
                      ),
                    ] else ...[
                      tableRow([
                        'Cash Drawer',
                        'Physical Cash on Hand',
                        fmt.format(pCashDrawer),
                      ], rowBg: rowEven),
                      tableRow([
                        'Bank Accounts',
                        'Bank Balance',
                        fmt.format(pBank),
                      ]),
                      tableRow([
                        'bKash Wallet',
                        'Mobile Banking',
                        fmt.format(pBkash),
                      ], rowBg: rowEven),
                      tableRow([
                        'Nagad Wallet',
                        'Mobile Banking',
                        fmt.format(pNagad),
                      ]),
                      tableRow([
                        '  ↳ Total Liquid Cash',
                        '',
                        fmt.format(pTotalCash),
                      ], isSubtotal: true),
                      tableRow([
                        'Stock Inventory',
                        'Warehouse Valuation',
                        fmt.format(pStockValuation),
                      ], rowBg: rowEven),
                      tableRow([
                        'Incoming Shipments',
                        'On-The-Way Inventory',
                        fmt.format(pShipmentValuation),
                      ]),
                      tableRow([
                        'Customer Receivables',
                        'Debtor Sales Outstanding',
                        fmt.format(pDebtorReceivables),
                      ], rowBg: rowEven),
                      tableRow([
                        'Staff Loans / Advances',
                        'Employee Credit',
                        fmt.format(pEmployeeDebt),
                      ]),
                      tableRow([
                        'Fixed Assets',
                        'Equipment & Furniture',
                        fmt.format(pFixedAssets),
                      ], rowBg: rowEven),
                      tableRow([
                        'TOTAL ASSETS',
                        '',
                        fmt.format(pGrandTotalAssets),
                      ], isTotal: true),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── LIABILITIES SECTION ──
              sectionTitle('LIABILITIES — WHAT YOU OWE', liabRed),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: divider),
                ),
                child: pw.Column(
                  children: [
                    tableRow(
                      compareWith != null
                          ? [
                            'Category',
                            'FY $yearStr',
                            'FY ${compareWith.year}',
                            'Change',
                          ]
                          : ['Category', 'Description', 'Amount (BDT)'],
                      isHeader: true,
                    ),
                    if (compareWith != null) ...[
                      compRow(
                        'Vendor / Supplier Dues',
                        pVendorDue,
                        compareWith.vendorDue,
                      ),
                      compRow(
                        'Customer Payables (Purchases)',
                        pDebtorPayable,
                        compareWith.debtorPayable,
                      ),
                      compRow(
                        'Monthly Payroll & OpEx',
                        pMonthlyPayroll,
                        compareWith.monthlyPayroll,
                      ),
                      hline(),
                      compRow(
                        'TOTAL LIABILITIES',
                        pGrandTotalLiab,
                        compareWith.totalLiabilities,
                        isTotal: true,
                      ),
                    ] else ...[
                      tableRow([
                        'Vendor / Supplier Dues',
                        'Amounts Owed to Suppliers',
                        fmt.format(pVendorDue),
                      ], rowBg: rowEven),
                      tableRow([
                        'Customer Payables',
                        'Purchase Returns / Dues',
                        fmt.format(pDebtorPayable),
                      ]),
                      tableRow([
                        'Monthly Payroll & OpEx',
                        'Salaries & Operating Costs',
                        fmt.format(pMonthlyPayroll),
                      ], rowBg: rowEven),
                      tableRow([
                        'TOTAL LIABILITIES',
                        '',
                        fmt.format(pGrandTotalLiab),
                      ], isTotal: true),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── NET WORTH BOX ──
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0F172A),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FINAL EQUATION',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${fmt.format(pGrandTotalAssets)}  −  ${fmt.format(pGrandTotalLiab)}  =  NET WORTH',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'REAL VALUE',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 8,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          fmt.format(pNetWorth),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color: PdfColors.white,
                          ),
                        ),
                        if (compareWith != null) ...[
                          pw.Text(
                            'FY ${compareWith.year}: ${fmt.format(compareWith.netWorth)}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            '${pNetWorth >= compareWith.netWorth ? '▲' : '▼'} '
                            '${fmtCompact.format((pNetWorth - compareWith.netWorth).abs())} difference',
                            style: pw.TextStyle(
                              font: fontItalic,
                              fontSize: 8,
                              color:
                                  pNetWorth >= compareWith.netWorth
                                      ? assetGreen
                                      : const PdfColor.fromInt(0xFFFC8181),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ── FIXED ASSETS DETAIL ──
              if (pFixedAssetsList.isNotEmpty) ...[
                sectionTitle('FIXED ASSETS — ITEMIZED LIST', sectionGrey),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: divider),
                  ),
                  child: pw.Column(
                    children: [
                      tableRow([
                        'Asset Name',
                        'Category',
                        'Value (BDT)',
                      ], isHeader: true),
                      ...pFixedAssetsList.asMap().entries.map(
                        (e) => tableRow([
                          e.value['name']?.toString() ?? '',
                          e.value['category']?.toString() ?? '',
                          fmt.format((e.value['value'] ?? 0).toDouble()),
                        ], rowBg: e.key.isEven ? rowEven : PdfColors.white),
                      ),
                      tableRow([
                        'TOTAL FIXED ASSETS',
                        '',
                        fmt.format(pFixedAssets),
                      ], isTotal: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // ── PAYROLL / OPEX DETAIL ──
              if (pPayrollList.isNotEmpty) ...[
                sectionTitle('MONTHLY FIXED COSTS — ITEMIZED', sectionGrey),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: divider),
                  ),
                  child: pw.Column(
                    children: [
                      tableRow([
                        'Cost Title',
                        'Type',
                        'Monthly Amount (BDT)',
                      ], isHeader: true),
                      ...pPayrollList.asMap().entries.map(
                        (e) => tableRow([
                          e.value['title']?.toString() ?? '',
                          e.value['type']?.toString() ?? 'Monthly',
                          fmt.format(
                            (e.value['monthlyAmount'] ?? 0).toDouble(),
                          ),
                        ], rowBg: e.key.isEven ? rowEven : PdfColors.white),
                      ),
                      tableRow([
                        'TOTAL MONTHLY BURN',
                        '',
                        fmt.format(pMonthlyPayroll),
                      ], isTotal: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // ── PRIOR YEAR FIXED ASSETS (if comparison) ──
              if (compareWith != null &&
                  compareWith.fixedAssetsList.isNotEmpty) ...[
                sectionTitle(
                  'FY ${compareWith.year} — FIXED ASSETS DETAIL',
                  sectionGrey,
                ),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: divider),
                  ),
                  child: pw.Column(
                    children: [
                      tableRow([
                        'Asset Name',
                        'Category',
                        'Value (BDT)',
                      ], isHeader: true),
                      ...compareWith.fixedAssetsList.asMap().entries.map(
                        (e) => tableRow([
                          e.value['name']?.toString() ?? '',
                          e.value['category']?.toString() ?? '',
                          fmt.format((e.value['value'] ?? 0).toDouble()),
                        ], rowBg: e.key.isEven ? rowEven : PdfColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Financial_Report_${DateFormat('yyyyMMdd').format(now)}',
    );
  }
}
