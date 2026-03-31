// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// REPLACE with your actual path to the controller file
import 'controller.dart';

class ProfitView extends StatelessWidget {
  final ProfitController controller = Get.put(ProfitController());

  ProfitView({super.key});

  // --- THEME COLORS ---
  static const Color darkBlue = Color(0xFF1B2559);
  static const Color brandBlue = Color(0xFF4318FF);
  static const Color brandGreen = Color(0xFF05CD99);
  static const Color brandRed = Color(0xFFEE5D50);
  static const Color brandOrange = Color(0xFFFFB547);
  static const Color bgLight = Color(0xFFF4F7FE);

  @override
  Widget build(BuildContext context) {
    // --- RESPONSIVE BREAKPOINTS & TYPOGRAPHY ---
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = screenWidth < 600;

    // Set base font to 13 for mobile, 14 for larger screens as requested
    final double baseFont = isMobile ? 13.0 : 14.0;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text(
          "P&L Analysis",
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkBlue),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: brandRed),
            tooltip: "Download Report",
            onPressed: controller.generateProfitLossPDF,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: brandBlue),
            onPressed: controller.refreshData,
          ),
          SizedBox(width: isMobile ? 10 : 20),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: brandBlue),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ), // Protects ultra-wide desktop monitors
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- FILTERS ---
                    _buildFilterChips(context, baseFont),
                    const SizedBox(height: 20),

                    // ============================================================
                    // 1. REVENUE VS CASH (The Big Picture)
                    // ============================================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: "TOTAL INVOICED",
                            subtitle: "(Sales Revenue)",
                            value: controller.totalRevenue.value,
                            color: brandBlue,
                            icon: Icons.receipt_long_rounded,
                            baseFont: baseFont,
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: "ACTUAL CASH IN",
                            subtitle: "(Total Collected)",
                            value: controller.totalCollected.value,
                            color: brandGreen,
                            icon: Icons.savings_rounded,
                            baseFont: baseFont,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ============================================================
                    // 2. NET RECEIVABLES GAP
                    // ============================================================
                    _buildNetPendingGapCard(baseFont, isMobile),

                    const SizedBox(height: 30),

                    // ============================================================
                    // 3. PROFITABILITY
                    // ============================================================
                    _buildSectionHeader("PROFITABILITY ANALYSIS", baseFont),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // PAPER PROFIT
                        Expanded(
                          child: _buildProfitCard(
                            label: "Paper Profit",
                            subLabel: "Based on Invoices",
                            amount: controller.profitOnRevenue.value,
                            textColor: darkBlue,
                            bgColor: Colors.white,
                            borderColor: Colors.grey.shade200,
                            baseFont: baseFont,
                            isMobile: isMobile,
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        // CASH PROFIT
                        Expanded(
                          child: _buildProfitCard(
                            label: "CASH PROFIT",
                            subLabel: "Realized in Hand",
                            amount: controller.netRealizedProfit.value,
                            textColor: Colors.white,
                            bgColor: brandGreen,
                            borderColor: brandGreen,
                            isHighlighted: true,
                            baseFont: baseFont,
                            isMobile: isMobile,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Average Margin
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 10 : 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: brandBlue.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.pie_chart_outline,
                            size: 16,
                            color: brandBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Average Profit Margin: ",
                            style: TextStyle(
                              fontSize: baseFont - 1,
                              color: darkBlue.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            "${(controller.effectiveProfitMargin.value * 100).toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: baseFont + 1,
                              fontWeight: FontWeight.bold,
                              color: brandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ============================================================
                    // 4. BREAKDOWNS
                    // ============================================================
                    _buildSectionHeader("SOURCE BREAKDOWN", baseFont),
                    const SizedBox(height: 16),

                    // Sales Breakdown
                    Text(
                      "Sales Volume (By Type)",
                      style: TextStyle(
                        fontSize: baseFont - 2,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniStat(
                          "Daily/Retail",
                          controller.saleDailyCustomer.value,
                          Colors.blueGrey,
                          baseFont,
                        ),
                        const SizedBox(width: 10),
                        _buildMiniStat(
                          "Debtor Credit",
                          controller.saleDebtor.value,
                          brandOrange,
                          baseFont,
                        ),
                        const SizedBox(width: 10),
                        _buildMiniStat(
                          "Courier Cond.",
                          controller.saleCondition.value,
                          Colors.purple,
                          baseFont,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Collection Breakdown
                    Text(
                      "Cash Received (By Source)",
                      style: TextStyle(
                        fontSize: baseFont - 2,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniStat(
                          "Direct Cash",
                          controller.collectionCustomer.value,
                          brandBlue,
                          baseFont,
                        ),
                        const SizedBox(width: 10),
                        _buildMiniStat(
                          "Old Due Paid",
                          controller.collectionDebtor.value,
                          Colors.teal,
                          baseFont,
                        ),
                        const SizedBox(width: 10),
                        _buildMiniStat(
                          "Condition Paid",
                          controller.collectionCondition.value,
                          Colors.indigo,
                          baseFont,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ============================================================
                    // 5. TRANSACTION LIST
                    // ============================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader("RECENT INVOICES", baseFont),
                        _buildSortDropdown(baseFont),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTransactionList(baseFont),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET HELPERS
  // --------------------------------------------------------------------------

  // --- 1. FILTER CHIPS WITH CUSTOM DATE ---
  Widget _buildFilterChips(BuildContext context, double baseFont) {
    List<String> presets = ['Today', 'This Month', 'Last 30 Days', 'This Year'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Standard Presets
          ...presets.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Obx(() {
                bool isSelected =
                    controller.selectedFilterLabel.value == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: brandBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : darkBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: baseFont - 1,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade200),
                  onSelected: (_) => controller.setDateRange(filter),
                );
              }),
            );
          }),

          // Custom Date Button
          Obx(() {
            bool isCustom = controller.selectedFilterLabel.value == 'Custom';

            // Format label if custom is selected
            String label =
                isCustom
                    ? "${DateFormat('dd MMM').format(controller.startDate.value)} - ${DateFormat('dd MMM').format(controller.endDate.value)}"
                    : "Custom Range";

            return ActionChip(
              avatar: Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: isCustom ? Colors.white : darkBlue,
              ),
              label: Text(label),
              backgroundColor: isCustom ? brandBlue : Colors.white,
              labelStyle: TextStyle(
                color: isCustom ? Colors.white : darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: baseFont - 1,
              ),
              side: BorderSide(
                color: isCustom ? brandBlue : Colors.grey.shade200,
              ),
              onPressed: () => controller.pickDateRange(context),
            );
          }),
        ],
      ),
    );
  }

  // --- TOP METRIC CARDS ---
  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required double value,
    required Color color,
    required IconData icon,
    required double baseFont,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: baseFont - 4, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: darkBlue.withOpacity(0.6),
              fontSize: baseFont - 3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              "Tk ${NumberFormat('#,##0').format(value)}",
              style: TextStyle(
                fontSize: baseFont + 6,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NET PENDING GAP CARD ---
  Widget _buildNetPendingGapCard(double baseFont, bool isMobile) {
    return Obx(() {
      double pendingChange = controller.netPendingChange.value;
      bool debtIncreased = pendingChange > 0;

      Color statusColor = debtIncreased ? Colors.orange.shade800 : brandGreen;
      Color bgColor =
          debtIncreased ? Colors.orange.shade50 : Colors.green.shade50;
      IconData icon = debtIncreased ? Icons.trending_up : Icons.trending_down;

      String mainText =
          debtIncreased ? "MARKET DEBT INCREASED" : "DEBT RECOVERED";
      String subText =
          debtIncreased
              ? "Sales exceeded Collections by:"
              : "Collections exceeded Sales by:";

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mainText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: baseFont - 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: baseFont - 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Tk ${NumberFormat('#,##0').format(pendingChange.abs())}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // --- PROFIT CARDS ---
  Widget _buildProfitCard({
    required String label,
    required String subLabel,
    required double amount,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
    required double baseFont,
    required bool isMobile,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            isHighlighted
                ? [
                  BoxShadow(
                    color: bgColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color:
                  isHighlighted ? Colors.white.withOpacity(0.9) : Colors.grey,
              fontSize: baseFont - 3,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat('#,##0').format(amount),
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subLabel,
            style: TextStyle(
              color:
                  isHighlighted ? Colors.white.withOpacity(0.8) : Colors.grey,
              fontSize: baseFont - 4,
            ),
          ),
        ],
      ),
    );
  }

  // --- MINI STAT ---
  Widget _buildMiniStat(
    String label,
    double value,
    Color color,
    double baseFont,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: baseFont - 3, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.compact().format(value),
                style: TextStyle(
                  fontSize: baseFont + 2,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader(String title, double baseFont) {
    return Text(
      title,
      style: TextStyle(
        color: darkBlue,
        fontSize: baseFont + 2,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  // --- SORT DROPDOWN ---
  Widget _buildSortDropdown(double baseFont) {
    return Obx(
      () => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.sortOption.value,
            icon: const Icon(Icons.arrow_drop_down, size: 18),
            style: TextStyle(
              fontSize: baseFont - 2,
              color: darkBlue,
              fontWeight: FontWeight.w600,
            ),
            items:
                ['Date (Newest)', 'Profit (High > Low)', 'Loss (High > Low)']
                    .map(
                      (String value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (val) => controller.sortTransactions(val),
          ),
        ),
      ),
    );
  }

  // --- TRANSACTION LIST ---
  Widget _buildTransactionList(double baseFont) {
    return Obx(() {
      if (controller.transactionList.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "No sales records for this period",
              style: TextStyle(color: Colors.grey, fontSize: baseFont),
            ),
          ),
        );
      }

      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: controller.transactionList.length,
        itemBuilder: (context, index) {
          final item = controller.transactionList[index];
          bool isLoss = (item['profit'] as double) < 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLoss ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLoss ? Icons.trending_down : Icons.trending_up,
                    color: isLoss ? brandRed : brandGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: baseFont,
                          color: darkBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM • hh:mm a').format(item['date']),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: baseFont - 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Tk ${NumberFormat('#,##0').format(item['total'])}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: baseFont,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Profit: ${NumberFormat('#,##0').format(item['profit'])}",
                      style: TextStyle(
                        color: isLoss ? brandRed : brandGreen,
                        fontSize: baseFont - 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }
}