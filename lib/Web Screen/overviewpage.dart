// ignore_for_file: deprecated_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'overviewcontroller.dart';

class DailyOverviewPage extends StatelessWidget {
  DailyOverviewPage({super.key});

  final ctrl = Get.put(OverviewController());

  // ERP Color Palette
  static const Color primaryBlue = Color(0xFF1E293B); // Slate 800
  static const Color accentGreen = Color(0xFF10B981); // Emerald 500
  static const Color accentRed = Color(0xFFEF4444); // Red 500
  static const Color bgLight = Color(0xFFF1F5F9); // Slate 100
  static const Color cardColor = Colors.white;

  // Chart Colors
  static const Color chartCash = Color(0xFF0F766E);
  static const Color chartBkash = Color(0xFFBE185D);
  static const Color chartNagad = Color(0xFFC2410C);
  static const Color chartBank = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (ctrl.salesCtrl.isLoading.value ||
            ctrl.expenseCtrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 1. Top Section: The Two Main Numbers
              _buildSummaryRow(),

              const SizedBox(height: 20),

              // 2. Bottom Section: Distribution & Breakdown
              LayoutBuilder(
                builder: (context, constraints) {
                  // Tablet/Desktop Layout
                  if (constraints.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildDistributionChart()),
                        const SizedBox(width: 20),
                        Expanded(flex: 3, child: _buildDetailedTable()),
                      ],
                    );
                  }
                  // Mobile Layout
                  return Column(
                    children: [
                      _buildDistributionChart(),
                      const SizedBox(height: 20),
                      _buildDetailedTable(),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  // inside DailyOverviewPage

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: DailyOverviewPage.cardColor,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: DailyOverviewPage.primaryBlue,
        ),
        onPressed: () => Get.back(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daily Cash Distribution", // Shortened for mobile fit
            style: TextStyle(
              color: DailyOverviewPage.primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Obx(
            () => Text(
              DateFormat('EEEE, dd MMM').format(ctrl.selectedDate.value),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        // --- NEW REFRESH BUTTON ---
        IconButton(
          onPressed: () => ctrl.refreshData(),
          icon: const Icon(
            Icons.refresh_rounded,
            color: DailyOverviewPage.primaryBlue,
          ),
          tooltip: "Refresh Data",
        ),

        // Date Picker
        IconButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: ctrl.selectedDate.value,
              firstDate: DateTime(2022),
              lastDate: DateTime.now(),
            );
            if (date != null) ctrl.selectDate(date);
          },
          icon: const Icon(
            Icons.calendar_month_outlined,
            color: DailyOverviewPage.primaryBlue,
          ),
        ),

        // PDF Export
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 4.0),
          child: IconButton(
            onPressed: () => ctrl.generateAndPrintPdf(),
            icon: const Icon(
              Icons.print_rounded,
              color: DailyOverviewPage.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        // Collected Cash
        Expanded(
          child: _erpStatCard(
            "Collected Cash",
            ctrl.totalCollected.value,
            FontAwesomeIcons.arrowTrendUp,
            accentGreen,
            isIncome: true,
          ),
        ),
        const SizedBox(width: 16),
        // Expenses
        Expanded(
          child: _erpStatCard(
            "Daily Expenses",
            ctrl.totalExpenses.value,
            FontAwesomeIcons.arrowTrendDown,
            accentRed,
            isIncome: false,
          ),
        ),
      ],
    );
  }

  Widget _erpStatCard(
    String title,
    double amount,
    IconData icon,
    Color color, {
    required bool isIncome,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (isIncome)
                const Text(
                  "+ Income",
                  style: TextStyle(
                    color: accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                )
              else
                const Text(
                  "- Outflow",
                  style: TextStyle(
                    color: accentRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              "৳${NumberFormat("#,##0").format(amount)}",
              style: TextStyle(
                color: primaryBlue,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Source Breakdown",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Obx(() {
              double total = ctrl.paymentMethods.values.reduce((a, b) => a + b);
              if (total == 0) return const Center(child: Text("No Data"));

              return PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 50,
                  sections: [
                    _chartSection(ctrl.paymentMethods['cash']!, chartCash),
                    _chartSection(ctrl.paymentMethods['bkash']!, chartBkash),
                    _chartSection(ctrl.paymentMethods['nagad']!, chartNagad),
                    _chartSection(ctrl.paymentMethods['bank']!, chartBank),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Simple Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _simpleLegend("Cash", chartCash),
              _simpleLegend("MFS", chartBkash), // Grouping Bkash/Nagad visually
              _simpleLegend("Bank", chartBank),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _chartSection(double value, Color color) {
    // If 0, hide it to prevent chart errors/ugliness
    if (value <= 0) {
      return PieChartSectionData(
        value: 0,
        radius: 0,
        showTitle: false,
        color: Colors.transparent,
      );
    }
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 30,
      showTitle: false,
    );
  }

  Widget _simpleLegend(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailedTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Distribution Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              // Net Balance Badge (Collected - Expenses)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      ctrl.netProfit.value >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Net: ৳${ctrl.netProfit.value.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color:
                        ctrl.netProfit.value >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _listTile("Hand Cash", ctrl.paymentMethods['cash']!, chartCash),
          const Divider(),
          _listTile("bKash", ctrl.paymentMethods['bkash']!, chartBkash),
          const Divider(),
          _listTile("Nagad", ctrl.paymentMethods['nagad']!, chartNagad),
          const Divider(),
          _listTile("Bank Transfer", ctrl.paymentMethods['bank']!, chartBank),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Collected",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "৳${NumberFormat("#,##0").format(ctrl.totalCollected.value)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listTile(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            "৳${NumberFormat("#,##0").format(amount)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
