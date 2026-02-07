// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controller.dart'; 

class ProfitView extends StatelessWidget {
  final ProfitController controller = Get.put(ProfitController());

  ProfitView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          "Financial Performance",
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.redAccent,
            ),
            tooltip: "Download Report",
            onPressed: controller.generateProfitLossPDF,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4318FF)),
            onPressed: controller.refreshData,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4318FF)),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // FILTERS
              // ------------------------------------------------
              _buildFilterChips(),
              const SizedBox(height: 25),

              // ------------------------------------------------
              // YEARLY CHART (Only visible if 'This Year' selected)
              // ------------------------------------------------
              if (controller.selectedFilterLabel.value == 'This Year') ...[
                _buildYearlyChart(),
                const SizedBox(height: 25),
              ],

              // ============================================================
              // SECTION 1: SALES OVERVIEW (INVOICED)
              // ============================================================
              _buildSectionHeader("1. SALES OVERVIEW", "Invoiced Amount"),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      "Daily Customer",
                      controller.saleDailyCustomer.value,
                      Colors.blueGrey,
                      Icons.storefront,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Debtor Sales",
                      controller.saleDebtor.value,
                      Colors.orange,
                      Icons.person,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Condition Sales",
                      controller.saleCondition.value,
                      Colors.purple,
                      Icons.local_shipping,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Total Revenue Tile
              _buildHighlightTile(
                "TOTAL REVENUE",
                controller.totalRevenue.value,
                const Color(0xFF4318FF), // Brand Blue
                Icons.bar_chart,
              ),

              const SizedBox(height: 30),

              // ============================================================
              // SECTION 2: COLLECTIONS OVERVIEW (CASH IN)
              // ============================================================
              _buildSectionHeader(
                "2. COLLECTIONS & CASHFLOW",
                "Actual Cash Received",
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      "Cash Coll.",
                      controller.collectionCustomer.value,
                      Colors.blue[700]!,
                      Icons.money,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Debtor Coll.",
                      controller.collectionDebtor.value,
                      Colors.orange[700]!,
                      Icons.account_balance_wallet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Courier Coll.",
                      controller.collectionCondition.value,
                      Colors.purple[700]!,
                      Icons.assignment_turned_in,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Breakdown Bar: Revenue vs Collected vs Pending
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 15,
                ),
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
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildTextStat(
                        "Total Revenue",
                        controller.totalRevenue.value,
                        Colors.black87,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(
                      child: _buildTextStat(
                        "Total Collected",
                        controller.totalCollected.value,
                        const Color(0xFF05CD99), // Green
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(
                      child: _buildTextStat(
                        "Pending (Due)",
                        controller.totalPendingGenerated.value,
                        Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ============================================================
              // SECTION 3: PROFIT & LOSS ANALYSIS
              // ============================================================
              _buildSectionHeader("3. PROFITABILITY", "Net Results"),
              const SizedBox(height: 10),

              Row(
                children: [
                  // 1. Profit on Revenue (Paper Profit)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4318FF).withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Profit on Revenue",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              NumberFormat(
                                '#,##0',
                              ).format(controller.profitOnRevenue.value),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4318FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "(Rev - COGS)",
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),

                  // 2. Net Realized Profit (Actual Cash Profit)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF05CD99), Color(0xFF02A378)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF05CD99).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "NET REALIZED PROFIT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              NumberFormat(
                                '#,##0',
                              ).format(controller.netRealizedProfit.value),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "(Cash Profit - Exp)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Expenses Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Operating Expenses Deducted:",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "- Tk ${NumberFormat('#,##0').format(controller.totalOperatingExpenses.value)}",
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ============================================================
              // SECTION 4: TRANSACTION LIST
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader("4. TRANSACTIONS", "Details"),

                  // SORT DROPDOWN
                  Container(
                    height: 35,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.sortOption.value,
                        icon: const Icon(Icons.sort, size: 16),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        items:
                            [
                              'Date (Newest)',
                              'Profit (High > Low)',
                              'Loss (High > Low)',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            controller.sortTransactions(newValue);
                          }
                        },
                      ),
                    ),
                  ),
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

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightTile(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Tk ${NumberFormat('#,##0').format(value)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              NumberFormat('#,##0').format(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextStat(String label, double value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            NumberFormat('#,##0').format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

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
            selectedColor: const Color(0xFF4318FF),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade200),
            onSelected: (_) => controller.setDateRange(filters[index]),
          );
        },
      ),
    );
  }

  Widget _buildYearlyChart() {
    double maxProfit = 0;
    if (controller.monthlyStats.isNotEmpty) {
      maxProfit = controller.monthlyStats
          .map((e) => e['profit'] as double)
          .reduce((a, b) => a > b ? a : b);
    }
    if (maxProfit == 0) maxProfit = 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2559),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Yearly Trend",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children:
                controller.monthlyStats.map((stat) {
                  double heightPct = (stat['profit'] as double) / maxProfit;
                  if (heightPct < 0.05 && (stat['profit'] as double) > 0) {
                    heightPct = 0.05;
                  }
                  return Column(
                    children: [
                      Container(
                        width: 10,
                        height: 80 * heightPct,
                        decoration: BoxDecoration(
                          color: const Color(0xFF05CD99),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat['month'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (controller.transactionList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: Text("No transactions in this period")),
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
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLoss ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLoss ? Icons.trending_down : Icons.trending_up,
                  color: isLoss ? Colors.red : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Name & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat('dd MMM - hh:mm a').format(item['date']),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Amounts
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Sale: ${NumberFormat('#,##0').format(item['total'])}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        "P: ",
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                      Text(
                        NumberFormat('#,##0').format(item['profit']),
                        style: TextStyle(
                          color: isLoss ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
