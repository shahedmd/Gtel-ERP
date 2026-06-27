// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'controller.dart';
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
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF059669);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color purpleDebtor = Color(0xFF7C3AED);

  DailySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure Condition Data is Loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conditionCtrl.allOrders.isEmpty) {
        conditionCtrl.loadConditionSales();
      }
    });

    // --- RESPONSIVE BREAKPOINTS & TYPOGRAPHY ---
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = screenWidth < 800;
    final double baseFont = isMobile ? 13.0 : 14.0;

    return Scaffold(
      backgroundColor: bgSlate,
      body: Obx(() {
        if (dailyCtrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: primaryBlue),
          );
        }

        DateTime selectedDate = dailyCtrl.selectedDate.value;
        final fullDailyList = dailyCtrl.salesList;
        final tableList = dailyCtrl.filteredList;

        final todayConditionOrders =
            conditionCtrl.allOrders.where((order) {
              return order.date.year == selectedDate.year &&
                  order.date.month == selectedDate.month &&
                  order.date.day == selectedDate.day;
            }).toList();

        // 1. Raw Revenue & Collection Variables
        double revCondition = 0;
        for (var o in todayConditionOrders) {
          revCondition += o.grandTotal;
        }

        double revNormalAgent = 0;
        double colNormalAgent = 0;
        double colCondition = 0;

        for (var sale in fullDailyList) {
          String type = (sale.customerType).toLowerCase();
          String source = (sale.source).toLowerCase();

          bool isConditionRelated =
              type.contains('condition') ||
              source.contains('condition') ||
              type.contains('courier');

          if (isConditionRelated) {
            colCondition += sale.paid;
          } else {
            colNormalAgent += sale.paid;
            if (source == 'pos_sale' || source == 'direct') {
              revNormalAgent += sale.amount;
            }
          }
        }

        // 2. Professional Due & Recovery Logic
        double dueNormalAgent = revNormalAgent - colNormalAgent;
        double extraNormalAgent = 0;
        if (dueNormalAgent < 0) {
          extraNormalAgent = dueNormalAgent.abs();
          dueNormalAgent = 0;
        }

        double dueCondition = revCondition - colCondition;
        double extraCondition = 0;
        if (dueCondition < 0) {
          extraCondition = dueCondition.abs();
          dueCondition = 0;
        }

        double totalRevenue = revNormalAgent + revCondition;
        double totalCollection = colNormalAgent + colCondition;
        double totalDue = dueNormalAgent + dueCondition;

        return Column(
          children: [
            _buildHeader(
              context,
              isMobile,
              baseFont,
              revNormalAgent,
              revCondition,
              colNormalAgent,
              colCondition,
              dueNormalAgent,
              dueCondition,
              extraNormalAgent,
              extraCondition,
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1200,
                    ), // Desktop Ultra-wide protection
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                      child: Column(
                        children: [
                          // --- METRIC BLOCKS ---
                          Flex(
                            direction:
                                isMobile ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: _buildDetailedBlock(
                                  "REVENUE",
                                  "Invoiced today",
                                  totalRevenue,
                                  primaryBlue,
                                  Icons.receipt_long,
                                  [
                                    _detailRow(
                                      "Normal/Agent",
                                      revNormalAgent,
                                      baseFont,
                                    ),
                                    _detailRow(
                                      "Condition",
                                      revCondition,
                                      baseFont,
                                    ),
                                  ],
                                  baseFont,
                                ),
                              ),
                              SizedBox(
                                width: isMobile ? 0 : 12,
                                height: isMobile ? 12 : 0,
                              ),
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: _buildDetailedBlock(
                                  "COLLECTION",
                                  "Cash/Bank today",
                                  totalCollection,
                                  successGreen,
                                  Icons.savings_outlined,
                                  [
                                    _detailRow(
                                      "Normal/Agent",
                                      colNormalAgent,
                                      baseFont,
                                    ),
                                    _detailRow(
                                      "Condition",
                                      colCondition,
                                      baseFont,
                                    ),
                                  ],
                                  baseFont,
                                ),
                              ),
                              SizedBox(
                                width: isMobile ? 0 : 12,
                                height: isMobile ? 12 : 0,
                              ),
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: _buildDetailedBlock(
                                  "TODAY'S DUE",
                                  "Unpaid from today",
                                  totalDue,
                                  alertRed,
                                  Icons.money_off,
                                  [
                                    _detailRow(
                                      "Normal/Agent",
                                      dueNormalAgent,
                                      baseFont,
                                    ),
                                    _detailRow(
                                      "Condition",
                                      dueCondition,
                                      baseFont,
                                    ),
                                  ],
                                  baseFont,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // --- TRANSACTION LEDGER ---
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
                                Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Flex(
                                    direction:
                                        isMobile
                                            ? Axis.vertical
                                            : Axis.horizontal,
                                    crossAxisAlignment:
                                        isMobile
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "TRANSACTION LEDGER",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: darkText,
                                          fontSize: baseFont + 1,
                                        ),
                                      ),
                                      if (!isMobile) const Spacer(),
                                      if (isMobile) const SizedBox(height: 12),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 250,
                                        height: 40,
                                        child: TextField(
                                          onChanged:
                                              (val) =>
                                                  dailyCtrl.filterQuery.value =
                                                      val,
                                          decoration: InputDecoration(
                                            hintText: "Search Invoice...",
                                            hintStyle: TextStyle(
                                              fontSize: baseFont - 1,
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                          ),
                                          style: TextStyle(fontSize: baseFont),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? 0 : 15,
                                        height: isMobile ? 12 : 0,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bgSlate,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          "${tableList.length} Transactions",
                                          style: TextStyle(
                                            fontSize: baseFont - 2,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),

                                // Wrapping the table in horizontal scroll on mobile prevents squishing
                                isMobile
                                    ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: SizedBox(
                                        width:
                                            850, // Minimum width to keep ERP table formatting clean
                                        child: Column(
                                          children: [
                                            _buildTableHead(baseFont),
                                            _buildTransactionList(
                                              context,
                                              tableList,
                                              baseFont,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : Column(
                                      children: [
                                        _buildTableHead(baseFont),
                                        _buildTransactionList(
                                          context,
                                          tableList,
                                          baseFont,
                                        ),
                                      ],
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    bool isMobile,
    double baseFont,
    double rNA,
    double rC,
    double cNA,
    double cC,
    double dNA,
    double dC,
    double eNA,
    double eC,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 20,
      ),
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
      child: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment:
            isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Row(
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
                  Text(
                    "Daily Sales Ledger",
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                  Obx(
                    () => Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                      ).format(dailyCtrl.selectedDate.value),
                      style: TextStyle(
                        fontSize: baseFont,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!isMobile) const Spacer(),
          if (isMobile) const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton(
                onPressed: () {
                  dailyCtrl.loadDailySales();
                  conditionCtrl.loadConditionSales();
                },
                icon: const Icon(Icons.refresh, color: primaryBlue),
                tooltip: "Refresh Data",
              ),
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
                label: Text("Date", style: TextStyle(fontSize: baseFont)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    () => _generateDailyReportPDF(
                      rNA,
                      rC,
                      cNA,
                      cC,
                      dNA,
                      dC,
                      eNA,
                      eC,
                    ),
                icon: const Icon(Icons.print, size: 16),
                label: Text("Report", style: TextStyle(fontSize: baseFont)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
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
    double baseFont,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: baseFont - 1,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: baseFont - 3,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...details,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: darkText,
                  fontSize: baseFont,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "৳ ${NumberFormat('#,##0').format(total)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: baseFont + 4,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, double amount, double baseFont) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: baseFont - 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "৳ ${NumberFormat('#,##0').format(amount)}",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: darkText,
              fontSize: baseFont - 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHead(double baseFont) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "DETAILS",
              style: TextStyle(
                fontSize: baseFont - 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "TYPE",
              style: TextStyle(
                fontSize: baseFont - 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "METHOD",
              style: TextStyle(
                fontSize: baseFont - 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "AMOUNT",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: baseFont - 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "PAID",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: baseFont - 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: Text(
                "ACTIONS",
                style: TextStyle(
                  fontSize: baseFont - 2,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    List<SaleModel> list,
    double baseFont,
  ) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            "No transactions found.",
            style: TextStyle(fontSize: baseFont),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5),
      itemBuilder: (context, index) {
        final sale = list[index];
        bool isDebtor =
            sale.customerType.toLowerCase().contains("debtor") ||
            sale.customerType.toLowerCase().contains("agent");
        String source = sale.source.toLowerCase();
        bool isConditionAdvance =
            sale.customerType.toLowerCase() == "condition_advance";
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
          badgeText = "AGENT SALE";
          badgeColor = purpleDebtor;
        }

        bool hasPending = sale.pending > 0.5;
        bool canCollectDue = hasPending && !isDebtor && !isConditionAdvance;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.name,
                      style: TextStyle(
                        fontSize: baseFont,
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
                            fontSize: baseFont - 2,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                        fontSize: baseFont - 3,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  dailyCtrl.formatPaymentMethod(sale.paymentMethod, sale.paid),
                  style: TextStyle(
                    fontSize: baseFont - 2,
                    height: 1.4,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "৳${NumberFormat('#,##0').format(sale.amount)}",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: baseFont,
                    color: darkText,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "৳${NumberFormat('#,##0').format(sale.paid)}",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: successGreen,
                        fontSize: baseFont,
                      ),
                    ),
                    if (hasPending)
                      Text(
                        "Due: ৳${NumberFormat('#,##0').format(sale.pending)}",
                        style: TextStyle(
                          fontSize: baseFont - 3,
                          color: alertRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canCollectDue) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.payments_outlined,
                          size: 20,
                          color: successGreen,
                        ),
                        tooltip: "Collect Due Payment",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:
                            () => _showCollectDueDialog(
                              context,
                              dailyCtrl,
                              sale,
                              baseFont,
                            ),
                      ),
                      const SizedBox(width: 12),
                    ],
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
                    const SizedBox(width: 12),
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

  // --- DIALOG (Zero setState, strictly Obx and Rx Variables) ---
  void _showCollectDueDialog(
    BuildContext context,
    DailySalesController ctrl,
    SaleModel sale,
    double baseFont,
  ) {
    if (sale.customerType == 'agent' || sale.customerType == 'debtor') {
      Get.snackbar(
        "Notice",
        "Please collect Agent dues from the Debtor Ledger.",
      );
      return;
    }
    if (sale.customerType == 'condition_advance') {
      Get.snackbar(
        "Notice",
        "Please collect Condition dues from the Condition Sales page.",
      );
      return;
    }

    final amountC = TextEditingController(
      text: sale.pending.toStringAsFixed(0),
    );
    final refC = TextEditingController();
    final bankNameC = TextEditingController();

    // Reactive Variable for the dropdown Method
    final RxString selectedMethod = "Cash".obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Collect Pending Due",
                  style: TextStyle(
                    fontSize: baseFont + 5,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Customer: ${sale.name}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkText,
                            fontSize: baseFont,
                          ),
                        ),
                      ),
                      Text(
                        "Due: ৳${sale.pending.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: alertRed,
                          fontWeight: FontWeight.bold,
                          fontSize: baseFont,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Received Amount",
                    prefixText: "৳ ",
                    border: const OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: baseFont),
                  ),
                  style: TextStyle(fontSize: baseFont),
                ),
                const SizedBox(height: 16),

                // Reactive UI Block
                Obx(() {
                  String method = selectedMethod.value;
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: method,
                        items:
                            ["Cash", "Bank", "Bkash", "Nagad"]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            selectedMethod.value = v;
                            refC.clear();
                            bankNameC.clear();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: "Payment Method",
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: baseFont),
                        ),
                        style: TextStyle(
                          fontSize: baseFont,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (method == "Bank") ...[
                        TextField(
                          controller: bankNameC,
                          decoration: InputDecoration(
                            labelText: "Bank Name (e.g., BRAC)",
                            hintText: "Required",
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: baseFont),
                          ),
                          style: TextStyle(fontSize: baseFont),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: refC,
                          decoration: InputDecoration(
                            labelText: "Account / Trx ID",
                            hintText: "Required",
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: baseFont),
                          ),
                          style: TextStyle(fontSize: baseFont),
                        ),
                      ] else if (method != "Cash") ...[
                        TextField(
                          controller: refC,
                          decoration: InputDecoration(
                            labelText: "$method Number / TrxID",
                            hintText: "Required",
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: baseFont),
                          ),
                          style: TextStyle(fontSize: baseFont),
                        ),
                      ],
                    ],
                  );
                }),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed:
                          ctrl.isLoading.value
                              ? null
                              : () {
                                double amt = double.tryParse(amountC.text) ?? 0;
                                if (amt <= 0) {
                                  Get.snackbar(
                                    "Error",
                                    "Valid amount required",
                                  );
                                  return;
                                }

                                String currentMethod = selectedMethod.value;
                                String finalRef = refC.text.trim();

                                if (currentMethod == "Bank") {
                                  if (bankNameC.text.trim().isEmpty ||
                                      refC.text.trim().isEmpty) {
                                    Get.snackbar(
                                      "Error",
                                      "Both Bank Name and Account Number are required",
                                    );
                                    return;
                                  }
                                  finalRef =
                                      "${bankNameC.text.trim()} - ${refC.text.trim()}";
                                } else if (currentMethod != "Cash") {
                                  if (refC.text.trim().isEmpty) {
                                    Get.snackbar(
                                      "Error",
                                      "$currentMethod Number is required",
                                    );
                                    return;
                                  }
                                }

                                ctrl.collectNormalCustomerDue(
                                  transactionId: sale.transactionId ?? '',
                                  currentPending: sale.pending,
                                  collectedAmount: amt,
                                  method: currentMethod,
                                  refNumber:
                                      currentMethod == "Cash" ? null : finalRef,
                                );
                                Get.back(); // Close Dialog
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          ctrl.isLoading.value
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                "CONFIRM PAYMENT",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  fontSize: baseFont,
                                ),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  // ==========================================================
  // 🖨️ PDF GENERATOR (Untouched Logic)
  // ==========================================================
  Future<void> _generateDailyReportPDF(
    double rNA,
    double rC,
    double cNA,
    double cC,
    double dNA,
    double dC,
    double eNA,
    double eC,
  ) async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final dateStr = DateFormat(
      'dd MMMM yyyy',
    ).format(dailyCtrl.selectedDate.value);

    double totalRev = rNA + rC;
    double totalCol = cNA + cC;
    double totalDue = dNA + dC;
    double totalExtra = eNA + eC;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "DAILY SALES & AR REPORT",
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
                      "REVENUE",
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
                      "COLLECTION",
                      totalCol,
                      PdfColors.green800,
                      fontBold,
                    ),
                    pw.Container(
                      width: 1,
                      height: 40,
                      color: PdfColors.grey300,
                    ),
                    _pdfSummaryItem(
                      "TODAY'S DUE",
                      totalDue,
                      PdfColors.red800,
                      fontBold,
                    ),
                    pw.Container(
                      width: 1,
                      height: 40,
                      color: PdfColors.grey300,
                    ),
                    _pdfSummaryItem(
                      "OLD RECOVERY",
                      totalExtra,
                      PdfColors.purple800,
                      fontBold,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfCol(
                    "REVENUE",
                    "Normal/Agent",
                    rNA,
                    "Condition",
                    rC,
                    totalRev,
                    PdfColors.blue100,
                    PdfColors.blue900,
                    fontBold,
                    fontRegular,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfCol(
                    "COLLECTION",
                    "Normal/Agent",
                    cNA,
                    "Condition",
                    cC,
                    totalCol,
                    PdfColors.green100,
                    PdfColors.green900,
                    fontBold,
                    fontRegular,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfCol(
                    "TODAY'S DUE",
                    "Normal/Agent",
                    dNA,
                    "Condition",
                    dC,
                    totalDue,
                    PdfColors.red100,
                    PdfColors.red900,
                    fontBold,
                    fontRegular,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfCol(
                    "OLD RECOVERY",
                    "Normal/Agent",
                    eNA,
                    "Condition",
                    eC,
                    totalExtra,
                    PdfColors.purple100,
                    PdfColors.purple900,
                    fontBold,
                    fontRegular,
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
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          "Tk ${val.toStringAsFixed(0)}",
          style: pw.TextStyle(fontSize: 14, font: font, color: color),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCol(
    String title,
    String l1,
    double v1,
    String l2,
    double v2,
    double total,
    PdfColor bg,
    PdfColor textCol,
    pw.Font fBold,
    pw.Font fReg,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: bg),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(font: fBold, fontSize: 10, color: textCol),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(l1, style: pw.TextStyle(font: fReg, fontSize: 9)),
                pw.Text(
                  v1.toStringAsFixed(0),
                  style: pw.TextStyle(font: fReg, fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(l2, style: pw.TextStyle(font: fReg, fontSize: 9)),
                pw.Text(
                  v2.toStringAsFixed(0),
                  style: pw.TextStyle(font: fReg, fontSize: 9),
                ),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("TOTAL", style: pw.TextStyle(font: fBold, fontSize: 9)),
                pw.Text(
                  total.toStringAsFixed(0),
                  style: pw.TextStyle(font: fBold, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}