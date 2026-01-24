// ignore_for_file: deprecated_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'overviewcontroller.dart'; // Ensure this matches your file path

class DailyOverviewPage extends StatelessWidget {
  DailyOverviewPage({super.key});

  final OverviewController ctrl = Get.find<OverviewController>();

  // --- ERP THEME COLORS ---
  static const Color slateDark = Color(0xFF0F172A); // Primary Text / Headers
  static const Color slateMedium = Color(0xFF64748B); // Secondary Text
  static const Color slateLight = Color(0xFFF1F5F9); // Background
  static const Color surfaceWhite = Colors.white;
  static const Color borderGrey = Color(0xFFE2E8F0);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Chart Palette
  static const Color colCash = Color(0xFF1E293B); // Dark Slate
  static const Color colBkash = Color(0xFFBE185D); // Pink/Magenta
  static const Color colNagad = Color(0xFFEA580C); // Orange
  static const Color colBank = Color(0xFF2563EB); // Blue

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slateLight,
      appBar: _buildAppBar(context),
      body: Obx(() {
        // You can add an isLoading check here if your sub-controllers have one exposed
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP STATS CARDS
              _buildSummarySection(),

              const SizedBox(height: 16),

              // 2. CHART & BREAKDOWN SECTION
              _buildChartSection(),

              const SizedBox(height: 20),

              // 3. THE LEDGER (Two Columns)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TRANSACTION LEDGER",
                    style: TextStyle(
                      color: slateMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    "Sorted by Time",
                    style: TextStyle(color: slateMedium, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Responsive Ledger Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  // On very small screens, stack them. On tablets/phones, side-by-side.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: INCOME
                      Expanded(
                        child: _buildLedgerColumn(
                          title: "CASH IN / INCOME",
                          total: ctrl.totalCashIn.value,
                          items: ctrl.cashInList,
                          colorTheme: successGreen,
                          icon:
                              FontAwesomeIcons
                                  .arrowDown, // Money coming down into pocket
                        ),
                      ),
                      const SizedBox(width: 12),
                      // RIGHT COLUMN: EXPENSE
                      Expanded(
                        child: _buildLedgerColumn(
                          title: "CASH OUT / EXPENSE",
                          total: ctrl.totalCashOut.value,
                          items: ctrl.cashOutList,
                          colorTheme: errorRed,
                          icon: FontAwesomeIcons.arrowUp, // Money leaving
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      }),
    );
  }

  // =========================================
  // APP BAR
  // =========================================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: surfaceWhite,
      elevation: 0,
      titleSpacing: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: borderGrey, height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: slateDark),
        onPressed: () => Get.back(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daily Cash Ledger",
            style: TextStyle(
              color: slateDark,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Obx(
            () => Text(
              DateFormat('EEEE, dd MMMM yyyy').format(ctrl.selectedDate.value),
              style: const TextStyle(color: slateMedium, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => ctrl.refreshData(),
          icon: const Icon(Icons.refresh, color: slateMedium),
          tooltip: "Refresh Data",
        ),
        IconButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: ctrl.selectedDate.value,
              firstDate: DateTime(2022),
              lastDate: DateTime.now(),
            );
            if (date != null) ctrl.pickDate(date);
          },
          icon: const Icon(Icons.calendar_today_outlined, color: slateMedium),
          tooltip: "Select Date",
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: slateDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => ctrl.generateLedgerPdf(),
            icon: const Icon(Icons.print, size: 16),
            label: const Text("Print PDF"),
          ),
        ),
      ],
    );
  }

  // =========================================
  // 1. STATS SECTION
  // =========================================
  Widget _buildSummarySection() {
    return SizedBox(
      height: 110, // Fixed height for alignment
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              title: "TOTAL INCOME",
              amount: ctrl.totalCashIn.value,
              icon: FontAwesomeIcons.arrowTrendUp,
              color: successGreen,
              isNet: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              title: "TOTAL EXPENSE",
              amount: ctrl.totalCashOut.value,
              icon: FontAwesomeIcons.arrowTrendDown,
              color: errorRed,
              isNet: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              title: "NET BALANCE",
              amount: ctrl.netCashBalance.value,
              icon: FontAwesomeIcons.scaleBalanced,
              color: ctrl.netCashBalance.value >= 0 ? infoBlue : errorRed,
              isNet: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isNet,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: slateMedium,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              "৳${NumberFormat("#,##0").format(amount)}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isNet ? color : slateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // 2. CHART SECTION
  // =========================================
  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Source Breakdown",
                style: TextStyle(fontWeight: FontWeight.bold, color: slateDark),
              ),
              Text(
                "Includes Sales & Loans",
                style: TextStyle(fontSize: 10, color: slateMedium),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _generateChartData(),
                      ),
                    ),
                    Center(
                      child: Icon(
                        FontAwesomeIcons.wallet,
                        color: slateMedium.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              // Legend
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chartLegendItem(
                      "Cash",
                      ctrl.methodBreakdown['Cash'] ?? 0,
                      colCash,
                    ),
                    const SizedBox(height: 8),
                    _chartLegendItem(
                      "Bkash",
                      ctrl.methodBreakdown['Bkash'] ?? 0,
                      colBkash,
                    ),
                    const SizedBox(height: 8),
                    _chartLegendItem(
                      "Nagad",
                      ctrl.methodBreakdown['Nagad'] ?? 0,
                      colNagad,
                    ),
                    const SizedBox(height: 8),
                    _chartLegendItem(
                      "Bank",
                      ctrl.methodBreakdown['Bank'] ?? 0,
                      colBank,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateChartData() {
    double cash = ctrl.methodBreakdown['Cash'] ?? 0;
    double bkash = ctrl.methodBreakdown['Bkash'] ?? 0;
    double nagad = ctrl.methodBreakdown['Nagad'] ?? 0;
    double bank = ctrl.methodBreakdown['Bank'] ?? 0;
    double total = cash + bkash + nagad + bank;

    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: borderGrey,
          radius: 20,
          showTitle: false,
        ),
      ];
    }

    return [
      if (cash > 0)
        PieChartSectionData(
          value: cash,
          color: colCash,
          radius: 20,
          showTitle: false,
        ),
      if (bkash > 0)
        PieChartSectionData(
          value: bkash,
          color: colBkash,
          radius: 20,
          showTitle: false,
        ),
      if (nagad > 0)
        PieChartSectionData(
          value: nagad,
          color: colNagad,
          radius: 20,
          showTitle: false,
        ),
      if (bank > 0)
        PieChartSectionData(
          value: bank,
          color: colBank,
          radius: 20,
          showTitle: false,
        ),
    ];
  }

  Widget _chartLegendItem(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: slateMedium,
              ),
            ),
          ],
        ),
        Text(
          "৳${NumberFormat("#,##0").format(amount)}",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: slateDark,
          ),
        ),
      ],
    );
  }

  // =========================================
  // 3. LEDGER COLUMNS
  // =========================================
  Widget _buildLedgerColumn({
    required String title,
    required double total,
    required List<LedgerItem> items,
    required Color colorTheme,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorTheme.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: colorTheme.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: colorTheme),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: colorTheme,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  NumberFormat.compact().format(total),
                  style: TextStyle(
                    color: colorTheme,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // List
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  "- Empty -",
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder:
                  (c, i) =>
                      Divider(height: 1, color: borderGrey.withOpacity(0.5)),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: slateDark,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(item.time),
                        style: const TextStyle(
                          fontSize: 10,
                          color: slateMedium,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "•",
                        style: TextStyle(fontSize: 10, color: slateMedium),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorTheme.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    "৳${NumberFormat("#,##0").format(item.amount)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: slateDark,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
