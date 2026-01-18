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

  // Professional Color Palette
  static const Color brandPrimary = Color(0xFF2563EB);
  static const Color surface = Colors.white;
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Specific Payment Brand Colors
  static const Color colorCash = Color(0xFF10B981);
  static const Color colorBkash = Color(0xFFE2136E);
  static const Color colorNagad = Color(0xFFF6921E);
  static const Color colorBank = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (ctrl.salesCtrl.isLoading.value ||
            ctrl.expenseCtrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: brandPrimary),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopStatsGrid(),
              const SizedBox(height: 24),
              // Responsive Layout check (Column on mobile, Row on desktop)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        _buildMainPerformanceCard(),
                        const SizedBox(height: 24),
                        _buildPaymentBreakdownCard(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildMainPerformanceCard()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildPaymentBreakdownCard()),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Executive Dashboard",
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Obx(
            () => Text(
              DateFormat('EEEE, dd MMMM yyyy').format(ctrl.selectedDate.value),
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: ctrl.selectedDate.value,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) ctrl.selectDate(date);
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text("Change Date"),
          style: OutlinedButton.styleFrom(
            foregroundColor: brandPrimary,
            side: const BorderSide(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildTopStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 20,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _statCard(
          "Gross Sales",
          ctrl.grossSales.value,
          FontAwesomeIcons.chartLine,
          brandPrimary,
        ),
        _statCard(
          "Collected",
          ctrl.totalCollected.value,
          FontAwesomeIcons.handHoldingDollar,
          colorCash,
        ),
        _statCard(
          "Daily Expenses",
          ctrl.totalExpenses.value,
          FontAwesomeIcons.fileInvoiceDollar,
          Colors.pinkAccent,
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    double val,
    IconData icon,
    Color color, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? color : surface,
        borderRadius: BorderRadius.circular(16),
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
          CircleAvatar(
            backgroundColor:
                isHighlight ? Colors.white24 : color.withOpacity(0.1),
            child: Icon(
              icon,
              color: isHighlight ? Colors.white : color,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isHighlight ? Colors.white70 : textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    "৳${val.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isHighlight ? Colors.white : textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance Overview",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),
          _performanceTile(
            "Total Orders",
            "${ctrl.salesCtrl.salesList.length}",
            FontAwesomeIcons.receipt,
          ),
          _performanceTile(
            "Outstanding Debt (Due)",
            "৳${ctrl.outstandingDebt.value.toStringAsFixed(0)}",
            FontAwesomeIcons.clockRotateLeft,
          ),
        ],
      ),
    );
  }

  Widget _performanceTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textMuted),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: textMuted)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPaymentBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: textDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Revenue by Source",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 200,
            child: Obx(() {
              // Verify if we have data, otherwise show empty state
              double total = ctrl.paymentMethods.values.reduce((a, b) => a + b);
              if (total <= 0) {
                return const Center(
                  child: Text(
                    "No Data",
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _getSections(),
                  borderData: FlBorderData(show: false),
                ),
              );
            }),
          ),
          const SizedBox(height: 30),
          _legendItem("Cash", ctrl.paymentMethods['cash']!, colorCash),
          _legendItem("bKash", ctrl.paymentMethods['bkash']!, colorBkash),
          _legendItem("Nagad", ctrl.paymentMethods['nagad']!, colorNagad),
          _legendItem("Bank", ctrl.paymentMethods['bank']!, colorBank),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    final Map<String, Color> typeColors = {
      "cash": colorCash,
      "bkash": colorBkash,
      "nagad": colorNagad,
      "bank": colorBank,
    };

    return ctrl.paymentMethods.entries.map((entry) {
      double val = entry.value;
      // Chart crashes if value is 0, so we hide it or give minimal value
      if (val <= 0) {
        return PieChartSectionData(
          value: 0,
          radius: 0,
          showTitle: false,
          color: Colors.transparent,
        );
      }
      return PieChartSectionData(
        value: val,
        color: typeColors[entry.key] ?? Colors.grey,
        radius: 25,
        showTitle: false,
      );
    }).toList();
  }

  Widget _legendItem(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),
          Text(
            "৳${amount.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
