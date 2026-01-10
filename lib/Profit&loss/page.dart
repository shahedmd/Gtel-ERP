// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Profit&loss/controller.dart';
import 'package:intl/intl.dart';

class ProfitLossPage extends StatelessWidget {
  // Use Get.put to initialize the controller if not already in memory
  final controller = Get.put(ProfitController());

  // Professional Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  ProfitLossPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: darkSlate,
        elevation: 0,
        title: const Text(
          "FINANCIAL & PERFORMANCE REPORT",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.fetchProfitAndLoss(),
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Data",
          ),
          IconButton(
            onPressed: () => controller.generatePdfReport(),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: "Download PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateFilterBar(context),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. FINANCIAL SUMMARY CARDS
                    _buildSummaryCards(),

                    const SizedBox(height: 24),

                    // 2. DETAILED BREAKDOWN
                    _buildSectionHeader("Financial Breakdown"),
                    _buildFinancialRow(
                      "Total Revenue (Sales)",
                      controller.totalRevenue.value,
                      isPositive: true,
                    ),
                    _buildFinancialRow(
                      "(-) Cost of Goods Sold",
                      controller.totalCostOfGoods.value,
                      isNegative: true,
                    ),
                    _buildDivider(),
                    _buildFinancialRow(
                      "GROSS PROFIT",
                      controller.grossProfit.value,
                      isBold: true,
                      color: activeAccent,
                    ),
                    const SizedBox(height: 10),

                    // REMOVED EXPENSES ROW FROM HERE
                    _buildFinancialRow(
                      "(-) Discounts Given",
                      controller.totalDiscounts.value,
                      isNegative: true,
                    ),
                    _buildDivider(),
                    _buildFinancialRow(
                      "NET PROFIT / (LOSS)",
                      controller.netProfit.value,
                      isBold: true,
                      fontSize: 18,
                      color:
                          controller.netProfit.value >= 0
                              ? successGreen
                              : dangerRed,
                    ),

                    const SizedBox(height: 30),

                    // 3. CUSTOMER PROFITABILITY
                    _buildSectionHeader("Customer Profitability Analysis"),
                    _buildCustomerPerformanceTable(),

                    const SizedBox(height: 30),

                    // 4. RECENT SALES
                    _buildSectionHeader("Recent Sales Logs"),
                    _buildSalesTable(),

                    const SizedBox(height: 50),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildDateFilterBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: textMuted),
          const SizedBox(width: 10),

          // Dropdown for Quick Select
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: null,
              hint: Obx(
                () => Text(
                  "${DateFormat('dd MMM').format(controller.startDate.value)} - ${DateFormat('dd MMM').format(controller.endDate.value)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: activeAccent),
              items:
                  ['Today', 'Yesterday', 'This Month', 'Last 30 Days'].map((
                    String val,
                  ) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
              onChanged: (val) {
                if (val != null) controller.setDateRange(val);
              },
            ),
          ),

          const Spacer(),

          OutlinedButton.icon(
            onPressed: () => controller.pickCustomDateRange(context),
            icon: const Icon(Icons.date_range, size: 16),
            label: const Text("Custom Range"),
            style: OutlinedButton.styleFrom(
              foregroundColor: darkSlate,
              side: const BorderSide(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 3, // Changed from 2 to 3 since one card is removed
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8, // Adjusted ratio for 3 columns
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _summaryCard(
          "Total Revenue",
          controller.totalRevenue.value,
          Colors.blue,
          Icons.attach_money,
        ),
        _summaryCard(
          "Gross Profit",
          controller.grossProfit.value,
          Colors.orange,
          Icons.trending_up,
        ),
        // EXPENSES CARD REMOVED FROM HERE
        _summaryCard(
          "Net Profit",
          controller.netProfit.value,
          controller.netProfit.value >= 0 ? successGreen : dangerRed,
          Icons.account_balance_wallet,
        ),
      ],
    );
  }

  Widget _summaryCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        // Changed to Column for better fit in 3-grid layout
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "৳${value.toStringAsFixed(0)}",
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    double value, {
    bool isNegative = false,
    bool isPositive = false,
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    Color finalColor = color ?? darkSlate;
    String prefix = "";
    if (isNegative) {
      finalColor = dangerRed;
      prefix = "- ";
    } else if (isPositive) {
      prefix = "+ ";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: darkSlate,
            ),
          ),
          Text(
            "$prefix৳${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: finalColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(thickness: 1, color: Colors.grey),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // --- CUSTOMER TABLE ---
  Widget _buildCustomerPerformanceTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Obx(() {
        if (controller.customerPerformanceList.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text("No customer data for this period")),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Text(
                  "Customer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Type",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Orders",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Revenue",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Profit",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: successGreen,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Margin %",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                controller.customerPerformanceList.take(20).map((item) {
                  double profit = item['profit'];
                  double rev = item['revenue'];
                  double margin = rev > 0 ? (profit / rev * 100) : 0.0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                item['type'] == 'Debtor'
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['type'],
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  item['type'] == 'Debtor'
                                      ? Colors.deepOrange
                                      : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(item['count'].toString())),
                      DataCell(Text(item['revenue'].toStringAsFixed(0))),
                      DataCell(
                        Text(
                          "৳${profit.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: successGreen,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "${margin.toStringAsFixed(1)}%",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        );
      }),
    );
  }

  // --- SALES TABLE ---
  Widget _buildSalesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Obx(() {
        if (controller.salesReportList.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text("No sales data for this period")),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columnSpacing: 20,
            columns: const [
              DataColumn(
                label: Text(
                  "Date",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Invoice",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Customer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Revenue",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Profit",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                controller.salesReportList.take(50).map((sale) {
                  // SAFE DATE PARSING
                  String dateStr = sale['date'] ?? '';
                  String formattedDate = dateStr;
                  if (dateStr.length >= 10) {
                    formattedDate = dateStr.substring(0, 10);
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(formattedDate)),
                      DataCell(Text(sale['invoiceId'] ?? '-')),
                      DataCell(
                        Text(
                          sale['customer'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(Text(sale['revenue'].toStringAsFixed(0))),
                      DataCell(
                        Text(
                          sale['profit'].toStringAsFixed(0),
                          style: const TextStyle(
                            color: successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        );
      }),
    );
  }
}
