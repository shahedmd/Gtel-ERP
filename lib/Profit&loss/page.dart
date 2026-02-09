// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
// Ensure this points to your updated ProfitController file
import 'controller.dart';

class ProfitView extends StatelessWidget {
  final ProfitController controller = Get.put(ProfitController());

  ProfitView({super.key});

  // Theme Colors
  static const Color darkBlue = Color(0xFF1B2559);
  static const Color brandBlue = Color(0xFF4318FF);
  static const Color brandGreen = Color(0xFF05CD99);
  static const Color brandRed = Color(0xFFEE5D50);
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
              // --- FILTERS ---
              _buildFilterChips(),
              const SizedBox(height: 20),

              // ============================================================
              // 1. HIGH LEVEL METRICS (REVENUE vs CASH)
              // ============================================================
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "TOTAL INVOICED",
                      "(Sales Revenue)",
                      controller.totalRevenue.value,
                      brandBlue,
                      Icons.receipt_long,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildMetricCard(
                      "ACTUAL CASH IN",
                      "(Total Collected)",
                      controller.totalCollected.value,
                      brandGreen,
                      Icons.savings,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ============================================================
              // 2. NET RECEIVABLES CHANGE (THE NEW LOGIC)
              // ============================================================
              _buildNetPendingCard(),

              const SizedBox(height: 30),

              // ============================================================
              // 3. PROFITABILITY ANALYSIS
              // ============================================================
              _buildSectionHeader("PROFITABILITY & CASH FLOW"),
              const SizedBox(height: 15),

              // A. PROFIT CARDS
              Row(
                children: [
                  // Paper Profit
                  Expanded(
                    child: _buildProfitDetailCard(
                      label: "Paper Profit",
                      subLabel: "Based on Invoices",
                      amount: controller.profitOnRevenue.value,
                      color: Colors.grey.shade700,
                      bgColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Realized Profit (Main Focus)
                  Expanded(
                    child: _buildProfitDetailCard(
                      label: "NET REALIZED PROFIT",
                      subLabel: "Cash Profit - Expenses",
                      amount: controller.netRealizedProfit.value,
                      color: Colors.white,
                      bgColor: brandGreen,
                      isHighlighted: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // B. EXPENSES & MARGIN STRIP
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Operating Expenses",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          "- Tk ${NumberFormat('#,##0').format(controller.totalOperatingExpenses.value)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: brandRed,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Est. Cash Margin",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          "${(controller.effectiveProfitMargin.value * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ============================================================
              // 4. BREAKDOWNS (Mini Stats)
              // ============================================================
              _buildSectionHeader("SOURCE BREAKDOWN"),
              const SizedBox(height: 15),

              const Text(
                "Sales Sources (Invoiced)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniStat(
                    "Daily",
                    controller.saleDailyCustomer.value,
                    Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Debtor",
                    controller.saleDebtor.value,
                    Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Courier",
                    controller.saleCondition.value,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const Text(
                "Collection Sources (Cash In)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniStat(
                    "Cash",
                    controller.collectionCustomer.value,
                    brandBlue,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Debtor Pay",
                    controller.collectionDebtor.value,
                    Colors.orange.shade700,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    "Condition",
                    controller.collectionCondition.value,
                    Colors.purple.shade700,
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
                  _buildSectionHeader("RECENT TRANSACTIONS"),
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

  // --- FILTERS ---
  Widget _buildFilterChips() {
    List<String> filters = ['Today', 'This Month', 'Last 30 Days', 'This Year'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          bool isSelected =
              controller.selectedFilterLabel.value == filters[index];
          return ChoiceChip(
            label: Text(filters[index]),
            selected: isSelected,
            selectedColor: brandBlue,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : darkBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade200),
            onSelected: (_) => controller.setDateRange(filters[index]),
          );
        },
      ),
    );
  }

  // --- TOP METRIC CARDS ---
  Widget _buildMetricCard(
    String title,
    String sub,
    double value,
    Color color,
    IconData icon,
  ) {
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
              Icon(icon, color: color.withOpacity(0.8), size: 20),
              Text(
                sub,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: darkBlue.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              "Tk ${NumberFormat('#,##0').format(value)}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NET PENDING CARD (The new Logic) ---
  Widget _buildNetPendingCard() {
    double pendingChange = controller.netPendingChange.value;
    bool isPositive = pendingChange > 0; // Sales > Collection (Debt Increased)

    // If Positive: Bad (Market owes you more). Color: Orange/Red
    // If Negative: Good (You collected old debt). Color: Green
    Color statusColor = isPositive ? Colors.orange.shade800 : brandGreen;
    Color bgColor = isPositive ? Colors.orange.shade50 : Colors.green.shade50;
    String statusText = isPositive ? "MARKET DEBT INCREASED" : "DEBT RECOVERED";
    String descText =
        isPositive
            ? "Sales exceeded collections by:"
            : "Collections exceeded sales by:";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descText,
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
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
  }

  // --- PROFIT CARDS ---
  Widget _buildProfitDetailCard({
    required String label,
    required String subLabel,
    required double amount,
    required Color color,
    required Color bgColor,
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
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
        border: isHighlighted ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color:
                  isHighlighted ? Colors.white.withOpacity(0.9) : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              NumberFormat('#,##0').format(amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subLabel,
            style: TextStyle(
              color:
                  isHighlighted ? Colors.white.withOpacity(0.7) : Colors.grey,
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
            ),
            const SizedBox(height: 4),
            FittedBox(
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

  // --- TRANSACTION LIST & SORT ---
  Widget _buildSortDropdown() {
    return Container(
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
    );
  }

  Widget _buildTransactionList() {
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
            "No data available for this period",
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
                    Text(
                      DateFormat('dd MMM • hh:mm a').format(item['date']),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                    ),
                  ),
                  Text(
                    "P: ${NumberFormat('#,##0').format(item['profit'])}",
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
  }
}