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
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "P&L Analysis",
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
          const SizedBox(width: 10),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: brandBlue),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- FILTERS (UPDATED) ---
              _buildFilterChips(context), // Pass context here
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
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildMetricCard(
                      title: "ACTUAL CASH IN",
                      subtitle: "(Total Collected)",
                      value: controller.totalCollected.value,
                      color: brandGreen,
                      icon: Icons.savings_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ============================================================
              // 2. NET RECEIVABLES GAP
              // ============================================================
              _buildNetPendingGapCard(), // Renamed for clarity

              const SizedBox(height: 30),

              // ============================================================
              // 3. PROFITABILITY
              // ============================================================
              _buildSectionHeader("PROFITABILITY ANALYSIS"),
              const SizedBox(height: 15),

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
                    ),
                  ),
                  const SizedBox(width: 15),
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
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Average Margin
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
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
                      size: 14,
                      color: brandBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Average Profit Margin: ",
                      style: TextStyle(
                        fontSize: 12,
                        color: darkBlue.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      "${(controller.effectiveProfitMargin.value * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 13,
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
              _buildSectionHeader("SOURCE BREAKDOWN"),
              const SizedBox(height: 15),

              // Sales Breakdown
              const Text(
                "Sales Volume (By Type)",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniStat(
                    "Daily/Retail",
                    controller.saleDailyCustomer.value,
                    Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Debtor Credit",
                    controller.saleDebtor.value,
                    brandOrange,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Courier Cond.",
                    controller.saleCondition.value,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Collection Breakdown
              const Text(
                "Cash Received (By Source)",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniStat(
                    "Direct Cash",
                    controller.collectionCustomer.value,
                    brandBlue,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Old Due Paid",
                    controller.collectionDebtor.value,
                    Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Condition Paid",
                    controller.collectionCondition.value,
                    Colors.indigo,
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
                  _buildSectionHeader("RECENT INVOICES"),
                  _buildSortDropdown(),
                ],
              ),
              const SizedBox(height: 15),
              _buildTransactionList(),
              const SizedBox(height: 50),
            ],
          ),
        );
      }),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET HELPERS
  // --------------------------------------------------------------------------

  // --- 1. UPDATED FILTER CHIPS WITH CUSTOM DATE ---
  Widget _buildFilterChips(BuildContext context) {
    List<String> presets = ['Today', 'This Month', 'Last 30 Days', 'This Year'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
                    fontSize: 12,
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

            // Format label if custom is selected (e.g. "12 Feb - 15 Feb")
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
                fontSize: 12,
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
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: darkBlue.withOpacity(0.6),
              fontSize: 10,
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
                fontSize: 18,
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
  Widget _buildNetPendingGapCard() {
    return Obx(() {
      double pendingChange = controller.netPendingChange.value;
      // Positive = Sales > Collection (Bad/Neutral - Market Debt Grew)
      // Negative = Collection > Sales (Good - Recovered Money)

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
                      Icon(icon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        mainText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "Tk ${NumberFormat('#,##0').format(pendingChange.abs())}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: statusColor,
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
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              fontSize: 10,
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
                fontSize: 22,
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
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // --- MINI STAT ---
  Widget _buildMiniStat(String label, double value, Color color) {
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
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.compact().format(value),
                style: TextStyle(
                  fontSize: 14,
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
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: darkBlue,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  // --- SORT DROPDOWN ---
  Widget _buildSortDropdown() {
    return Obx(
      () => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.sortOption.value,
            icon: const Icon(Icons.arrow_drop_down, size: 16),
            style: const TextStyle(fontSize: 11, color: darkBlue),
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
  Widget _buildTransactionList() {
    return Obx(() {
      if (controller.transactionList.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              "No sales records for this period",
              style: TextStyle(color: Colors.grey),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: darkBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM • hh:mm a').format(item['date']),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Tk ${NumberFormat('#,##0').format(item['total'])}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: darkBlue,
                      ),
                    ),
                    Text(
                      "Profit: ${NumberFormat('#,##0').format(item['profit'])}",
                      style: TextStyle(
                        color: isLoss ? brandRed : brandGreen,
                        fontSize: 11,
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