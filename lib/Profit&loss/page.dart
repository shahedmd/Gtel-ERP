// ignore_for_file: deprecated_member_use, non_constant_identifier_names

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
      backgroundColor: const Color(0xFFF4F7FE), // Soft modern background
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
          // 1. PDF DOWNLOAD BUTTON (NEW)
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.redAccent,
            ),
            tooltip: "Download P&L Report",
            onPressed: controller.generateProfitLossPDF,
          ),
          // 2. REFRESH BUTTON
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4318FF)),
            tooltip: "Refresh Data",
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
              // 1. Filter Section
              _buildFilterChips(),
              const SizedBox(height: 25),

              // 2. YEARLY CHART (Conditional)
              if (controller.selectedFilterLabel.value == 'This Year') ...[
                _buildYearlyChart(),
                const SizedBox(height: 25),
              ],

              // ============================================================
              // 3. NET PROFIT CARD (NEW - The Bottom Line)
              // ============================================================
              const Text(
                "NET BUSINESS PROFIT",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2559), Color(0xFF2B3674)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B2559).withOpacity(0.3),
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
                        const Text(
                          "Net Profit (Accrual)",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tk ${NumberFormat('#,##0').format(controller.netProfitAccrual.value)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "(Gross Profit - Expenses)",
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total Expenses",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "-${CompactNumberFormat(controller.totalOperatingExpenses.value)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 4. MAIN KPI CARDS (Realized Profit)
              const Text(
                "REALIZED PROFIT (Cash In Hand)",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Net Realized Profit",
                      controller.realizedProfitTotal.value,
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFF05CD99), // Green
                      isCurrency: true,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildMetricCard(
                      "Total Collected",
                      controller.totalCashCollected.value,
                      icon: Icons.savings,
                      color: const Color(0xFF4318FF), // Blue
                      isCurrency: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // Cash Flow Breakdown Row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      "Cash Sales",
                      controller.cashSales.value,
                      Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Debtor Recv.",
                      controller.debtorCollections.value,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      "Courier Recv.",
                      controller.courierCollections.value,
                      Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 5. SECONDARY METRICS (Invoiced/Accrual)
              const Text(
                "SALES PERFORMANCE (Invoiced)",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
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
                    _buildTextStat(
                      "Revenue",
                      controller.totalInvoiceRevenue.value,
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    _buildTextStat(
                      "COGS (Cost)",
                      controller.totalInvoiceCost.value,
                      color: Colors.redAccent,
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    _buildTextStat(
                      "Gross Profit",
                      controller.totalGrossProfit.value,
                      color: Colors.blue[800],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 6. TRANSACTION HISTORY
              const Text(
                "RECENT COLLECTIONS",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              _buildTransactionList(),
            ],
          ),
        );
      }),
    );
  }

  // --- WIDGETS ---

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
        color: const Color(0xFF1B2559), // Dark Blue Theme
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Yearly Profit Trends",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Net Realized Profit by Month",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children:
                controller.monthlyStats.map((stat) {
                  double heightPct = (stat['profit'] as double) / maxProfit;
                  if (heightPct < 0.05 && (stat['profit'] as double) > 0) {
                    heightPct = 0.05; // min height
                  }

                  return Column(
                    children: [
                      Text(
                        CompactNumberFormat(stat['profit']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 12,
                        height: 100 * heightPct,
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
                          fontSize: 10,
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

  Widget _buildMetricCard(
    String title,
    double value, {
    required IconData icon,
    required Color color,
    bool isCurrency = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              isCurrency
                  ? "Tk ${NumberFormat('#,##0').format(value)}"
                  : value.toString(),
              style: TextStyle(
                color: const Color(0xFF1B2559),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
    );
  }

  Widget _buildTextStat(String label, double value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.compact().format(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.collectionBreakdown.take(8).length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var item = controller.collectionBreakdown[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF4F7FE),
              child: Icon(
                item['type'] == 'Courier'
                    ? Icons.local_shipping
                    : (item['type'] == 'Debtor' ? Icons.person : Icons.store),
                color: const Color(0xFF4318FF),
                size: 18,
              ),
            ),
            title: Text(
              item['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              DateFormat('dd MMM - hh:mm a').format(item['date']),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "+${NumberFormat('#,##0').format(item['amount'])}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF05CD99),
                  ),
                ),
                Text(
                  "Profit: ${NumberFormat('#,##0').format(item['profit'])}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for small chart numbers
  String CompactNumberFormat(double n) {
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}k";
    return n.toStringAsFixed(0);
  }
}
