// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'controller.dart';
// Ensure this path matches your project structure
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditioncontroller.dart';
import 'model.dart';

class DailySalesPage extends StatelessWidget {
  final DailySalesController dailyCtrl = Get.put(DailySalesController());
  final ConditionSalesController conditionCtrl = Get.put(
    ConditionSalesController(),
  );

  // Color Palette
  static const Color bgSlate = Color(0xFFF1F5F9);
  static const Color darkText = Color(0xFF0F172A);
  static const Color primaryBlue = Color(0xFF2563EB); // Revenue Color
  static const Color successGreen = Color(0xFF059669); // Collection Color
  static const Color alertRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color purpleDebtor = Color(0xFF7C3AED);

  DailySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Ensure Condition Data is Loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conditionCtrl.allOrders.isEmpty) {
        conditionCtrl.loadConditionSales();
      }
    });

    return Scaffold(
      backgroundColor: bgSlate,
      body: Obx(() {
        if (dailyCtrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: primaryBlue),
          );
        }

        // =================================================================
        // 📊 1. DATA CALCULATIONS (Always based on FULL LIST for Totals)
        // =================================================================
        DateTime selectedDate = dailyCtrl.selectedDate.value;

        // We use the FULL list for the Summary Cards
        final fullDailyList = dailyCtrl.salesList;

        // We use the FILTERED list for the Table (Search results)
        final tableList = dailyCtrl.filteredList;

        // --- A. CONDITION REVENUE (Unpaid/New Condition Sales) ---
        final todayConditionOrders =
            conditionCtrl.allOrders.where((order) {
              return order.date.year == selectedDate.year &&
                  order.date.month == selectedDate.month &&
                  order.date.day == selectedDate.day;
            }).toList();

        double revenueCondition = 0;
        for (var o in todayConditionOrders) {
          revenueCondition += o.grandTotal;
        }

        // --- B. DAILY SALES & COLLECTIONS (From Daily Ledger) ---
        double revenueNormal = 0;
        double revenueDebtor = 0;

        double collectedNormal = 0;
        double collectedDebtor = 0;
        double collectedCondition = 0;

        // Iterate over FULL LIST for accurate summary
        for (var sale in fullDailyList) {
          String type = (sale.customerType).toLowerCase();
          String source = (sale.source).toLowerCase();

          // Identify if this is a "Recovery" (Collection Only) or "New Sale"
          bool isRecovery =
              source.contains('condition') ||
              source.contains('recovery') ||
              type.contains('courier') ||
              source.contains('payment');

          // --- REVENUE LOGIC (Goods sold today) ---
          if (!isRecovery) {
            if (type.contains('debtor')) {
              revenueDebtor += sale.amount;
              collectedDebtor += sale.paid;
            } else {
              revenueNormal += sale.amount;
              collectedNormal += sale.paid;
            }
          }

          // --- COLLECTION LOGIC (Cash received today) ---
          if (isRecovery) {
            if (source.contains('condition') || type.contains('courier')) {
              collectedCondition += sale.paid;
            } else if (type.contains('debtor') || source.contains('payment')) {
              collectedDebtor += sale.paid;
            }
          }
        }

        double totalRevenue = revenueNormal + revenueDebtor + revenueCondition;
        double totalCollection =
            collectedNormal + collectedDebtor + collectedCondition;

        // =================================================================
        // 🖥️ UI CONSTRUCTION
        // =================================================================

        return Column(
          children: [
            // HEADER
            _buildHeader(
              context,
              revenueNormal,
              revenueDebtor,
              revenueCondition,
              collectedNormal,
              collectedDebtor,
              collectedCondition,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // --- SECTION 1: REVENUE VS COLLECTION BLOCKS ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Revenue Block
                        Expanded(
                          child: _buildDetailedBlock(
                            "REVENUE (INVOICED)",
                            "Total value of goods sold today",
                            totalRevenue,
                            primaryBlue,
                            Icons.receipt_long,
                            [
                              _detailRow("Normal Sales", revenueNormal),
                              _detailRow("Debtor Sales", revenueDebtor),
                              _detailRow("Condition Sales", revenueCondition),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Collection Block
                        Expanded(
                          child: _buildDetailedBlock(
                            "CASH COLLECTION",
                            "Actual money received today",
                            totalCollection,
                            successGreen,
                            Icons.savings_outlined,
                            [
                              _detailRow("Cash Sales", collectedNormal),
                              _detailRow("Debtor Recv.", collectedDebtor),
                              _detailRow("Condition Recv.", collectedCondition),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- SECTION 2: TRANSACTION LEDGER WITH SEARCH ---
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ledger Header + Search Bar
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                const Text(
                                  "TRANSACTION LEDGER",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkText,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),

                                // --- SEARCH BAR ---
                                SizedBox(
                                  width: 250,
                                  height: 40,
                                  child: TextField(
                                    onChanged:
                                        (val) =>
                                            dailyCtrl.filterQuery.value = val,
                                    decoration: InputDecoration(
                                      hintText: "Search Invoice (Last 4)...",
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 16,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 15),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgSlate,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "${tableList.length} Transactions",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Ledger Table Header & List
                          _buildTableHead(),
                          // Pass filtered list here for search to work
                          _buildTransactionList(tableList),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ==========================================================
  // 🧱 WIDGET COMPONENTS
  // ==========================================================

  Widget _buildHeader(
    BuildContext context,
    double rN,
    double rD,
    double rC,
    double cN,
    double cD,
    double cC,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const FaIcon(
              FontAwesomeIcons.cashRegister,
              color: primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daily Sales Ledger",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              Obx(
                () => Text(
                  DateFormat(
                    'EEEE, dd MMMM yyyy',
                  ).format(dailyCtrl.selectedDate.value),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Refresh
          IconButton(
            onPressed: () {
              dailyCtrl.loadDailySales();
              conditionCtrl.loadConditionSales();
            },
            icon: const Icon(Icons.refresh, color: primaryBlue),
            tooltip: "Refresh Data",
          ),
          const SizedBox(width: 8),

          // Date Picker
          OutlinedButton.icon(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: dailyCtrl.selectedDate.value,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (p != null) dailyCtrl.changeDate(p);
            },
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text("Select Date"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Daily Report PDF Button
          ElevatedButton.icon(
            onPressed: () => _generateDailyReportPDF(rN, rD, rC, cN, cD, cC),
            icon: const Icon(Icons.print, size: 16),
            label: const Text("Daily Report"),
            style: ElevatedButton.styleFrom(
              backgroundColor: darkText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBlock(
    String title,
    String subtitle,
    double total,
    Color color,
    IconData icon,
    List<Widget> details,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          ...details,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TOTAL",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: darkText,
                  fontSize: 14,
                ),
              ),
              Text(
                "৳ ${NumberFormat('#,##0').format(total)}",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "৳ ${NumberFormat('#,##0').format(amount)}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: darkText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 📋 LEDGER TABLE (Updated with Delete)
  // ==========================================================

  Widget _buildTableHead() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "DETAILS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "TYPE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3, // Increased flex for better multi-line method display
            child: Text(
              "METHOD",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "AMOUNT",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "PAID",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          // Action Column Header
          SizedBox(
            width: 90,
            child: Center(
              child: Text(
                "ACTIONS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<SaleModel> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: Text("No transactions found.")),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
      itemBuilder: (context, index) {
        final sale = list[index];
        bool isDebtor = (sale.customerType).toLowerCase().contains("debtor");
        String source = (sale.source).toLowerCase();

        bool isRecovery =
            source.contains("condition") ||
            source.contains("payment") ||
            source.contains("recovery");
        String badgeText = "NORMAL";
        Color badgeColor = primaryBlue;

        if (isRecovery) {
          badgeText = "COLLECTION";
          badgeColor = successGreen;
        } else if (isDebtor) {
          badgeText = "DEBTOR SALE";
          badgeColor = purpleDebtor;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align top for multi-line
            children: [
              // 1. Details
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: darkText,
                      ),
                    ),
                    if (sale.transactionId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sale.transactionId!,
                          style: TextStyle(
                            fontSize: 11, // Slightly larger for readability
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 2. Type Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ),
              ),
              // 3. Method (Updated for Bank Info / Multi-Line)
              Expanded(
                flex: 3, // Increased flex
                child: Text(
                  dailyCtrl.formatPaymentMethod(sale.paymentMethod),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3, // Better line spacing for bank info
                    color: Color(0xFF475569),
                  ),
                  maxLines: 4, // Allow more lines for Bank+Info
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 4. Amount
              Expanded(
                flex: 2,
                child: Text(
                  "৳${NumberFormat('#,##0').format(sale.amount)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: darkText,
                  ),
                ),
              ),
              // 5. Paid
              Expanded(
                flex: 2,
                child: Text(
                  "৳${NumberFormat('#,##0').format(sale.paid)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: successGreen,
                    fontSize: 13,
                  ),
                ),
              ),
              // 6. ACTIONS (Print & Delete)
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PRINT
                    IconButton(
                      icon: const Icon(
                        Icons.print_outlined,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      tooltip: "Reprint Invoice",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed:
                          () => dailyCtrl.reprintInvoice(
                            sale.transactionId ?? "",
                          ),
                    ),
                    const SizedBox(width: 15),
                    // DELETE
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: alertRed,
                      ),
                      tooltip: "Delete Sale",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed:
                          () => _confirmDelete(context, sale.id, sale.name),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String saleId, String name) {
    Get.defaultDialog(
      title: "Confirm Delete",
      middleText:
          "Are you sure you want to delete the sale for '$name'?\n\nStock will be restored automatically.",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: alertRed,
      onConfirm: () {
        Get.back();
        dailyCtrl.deleteSale(saleId);
      },
    );
  }

  // =================================================================
  // 🖨️ PDF GENERATION (Daily Report)
  // =================================================================
  Future<void> _generateDailyReportPDF(
    double rN,
    double rD,
    double rC,
    double cN,
    double cD,
    double cC,
  ) async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final dateStr = DateFormat(
      'dd MMMM yyyy',
    ).format(dailyCtrl.selectedDate.value);

    double totalRev = rN + rD + rC;
    double totalCol = cN + cD + cC;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "DAILY SALES & COLLECTION REPORT",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(font: fontRegular, fontSize: 12),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.blue900),
              pw.SizedBox(height: 20),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.grey50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfSummaryItem(
                      "TOTAL REVENUE",
                      totalRev,
                      PdfColors.blue900,
                      fontBold,
                    ),
                    pw.Container(
                      width: 1,
                      height: 40,
                      color: PdfColors.grey300,
                    ),
                    _pdfSummaryItem(
                      "TOTAL COLLECTION",
                      totalCol,
                      PdfColors.green800,
                      fontBold,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Details Sections
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Revenue Column
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue100),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "REVENUE BREAKDOWN",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _pdfRow("Normal Sales", rN, fontRegular),
                          _pdfRow("Debtor Sales", rD, fontRegular),
                          _pdfRow("Condition Sales", rC, fontRegular),
                          pw.Divider(),
                          _pdfRow("TOTAL", totalRev, fontBold),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Collection Column
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.green100),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "COLLECTION BREAKDOWN",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: PdfColors.green900,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _pdfRow("Cash Sales", cN, fontRegular),
                          _pdfRow("Debtor Recv.", cD, fontRegular),
                          _pdfRow("Condition Recv.", cC, fontRegular),
                          pw.Divider(),
                          _pdfRow("TOTAL", totalCol, fontBold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Generated by G-TEL ERP",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    "Page 1 of 1",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _pdfSummaryItem(
    String label,
    double val,
    PdfColor color,
    pw.Font font,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          "Tk ${val.toStringAsFixed(0)}",
          style: pw.TextStyle(fontSize: 18, font: font, color: color),
        ),
      ],
    );
  }

  pw.Widget _pdfRow(String label, double val, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(
            val.toStringAsFixed(0),
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
