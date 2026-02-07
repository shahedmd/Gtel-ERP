// ignore_for_file: deprecated_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'overviewcontroller.dart'; // Ensure this import points to your controller file

class DailyOverviewPage extends StatelessWidget {
  DailyOverviewPage({super.key});

  final OverviewController ctrl = Get.find<OverviewController>();

  // --- ERP THEME COLORS ---
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMedium = Color(0xFF64748B);
  static const Color slateLight = Color(0xFFF1F5F9);
  static const Color surfaceWhite = Colors.white;
  static const Color borderGrey = Color(0xFFE2E8F0);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color warnOrange = Color(0xFFF59E0B);

  // Chart Palette
  static const Color colCash = Color(0xFF1E293B);
  static const Color colBkash = Color(0xFFBE185D);
  static const Color colNagad = Color(0xFFEA580C);
  static const Color colBank = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slateLight,
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (ctrl.isLoadingHistory.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Calculating Balance History..."),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. BALANCE SHEET
              _buildBalanceSheetSection(),

              const SizedBox(height: 20),

              // 1. TODAY'S STATS CARDS
              _buildSummarySection(),

              const SizedBox(height: 16),

              // 2. CHART & BREAKDOWN SECTION
              _buildChartSection(),

              const SizedBox(height: 20),

              // 3. THE LEDGER (Two Columns)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TRANSACTION LEDGER",
                    style: TextStyle(
                      color: slateMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    "Sorted by Time (Newest First)",
                    style: TextStyle(
                      color: slateMedium.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive switching
                  if (constraints.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildLedgerColumn(
                            title: "CASH IN / INCOME",
                            total: ctrl.totalCashIn.value,
                            items: ctrl.cashInList,
                            colorTheme: successGreen,
                            icon: FontAwesomeIcons.arrowDown,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildLedgerColumn(
                            title: "CASH OUT / EXPENSE",
                            total: ctrl.totalCashOut.value,
                            items: ctrl.cashOutList,
                            colorTheme: errorRed,
                            icon: FontAwesomeIcons.arrowUp,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildLedgerColumn(
                          title: "CASH IN / INCOME",
                          total: ctrl.totalCashIn.value,
                          items: ctrl.cashInList,
                          colorTheme: successGreen,
                          icon: FontAwesomeIcons.arrowDown,
                        ),
                        const SizedBox(height: 20),
                        _buildLedgerColumn(
                          title: "CASH OUT / EXPENSE",
                          total: ctrl.totalCashOut.value,
                          items: ctrl.cashOutList,
                          colorTheme: errorRed,
                          icon: FontAwesomeIcons.arrowUp,
                        ),
                      ],
                    );
                  }
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
            label: const Text("PDF"),
          ),
        ),
      ],
    );
  }

  // =========================================
  // 0. BALANCE SHEET SECTION
  // =========================================
  Widget _buildBalanceSheetSection() {
    final currency = NumberFormat("#,##0");
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50,
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.vault,
                size: 16,
                color: Colors.blue.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                "CASH POSITION",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Previous Balance",
                      style: TextStyle(
                        fontSize: 11,
                        color: slateMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "৳${currency.format(ctrl.previousCash.value)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: slateDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: borderGrey),
              // Today's Net
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Today's Net",
                      style: TextStyle(
                        fontSize: 11,
                        color: slateMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${ctrl.netCashBalance.value >= 0 ? '+' : ''}৳${currency.format(ctrl.netCashBalance.value)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color:
                            ctrl.netCashBalance.value >= 0
                                ? successGreen
                                : errorRed,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: borderGrey),
              // Total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Closing Cash",
                      style: TextStyle(
                        fontSize: 11,
                        color: slateMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "৳${currency.format(ctrl.closingCash.value)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Colors.blue.shade800,
                      ),
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

  // =========================================
  // 1. STATS SECTION
  // =========================================
  Widget _buildSummarySection() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              title: "TODAY'S INCOME",
              amount: ctrl.totalCashIn.value,
              icon: FontAwesomeIcons.arrowTrendUp,
              color: successGreen,
              bg: successGreen.withOpacity(0.05),
              border: successGreen.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              title: "TODAY'S EXPENSE",
              amount: ctrl.totalCashOut.value,
              icon: FontAwesomeIcons.arrowTrendDown,
              color: errorRed,
              bg: errorRed.withOpacity(0.05),
              border: errorRed.withOpacity(0.2),
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
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              "৳${NumberFormat("#,##0").format(amount)}",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Source Breakdown",
                style: TextStyle(fontWeight: FontWeight.bold, color: slateDark),
              ),
              Text(
                "Income Sources",
                style: TextStyle(fontSize: 11, color: slateMedium),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 130,
                width: 130,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: _generateChartData(),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Center(
                      child: Icon(
                        FontAwesomeIcons.wallet,
                        color: slateMedium.withOpacity(0.4),
                        size: 24,
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
                    const SizedBox(height: 10),
                    _chartLegendItem(
                      "Bkash",
                      ctrl.methodBreakdown['Bkash'] ?? 0,
                      colBkash,
                    ),
                    const SizedBox(height: 10),
                    _chartLegendItem(
                      "Nagad",
                      ctrl.methodBreakdown['Nagad'] ?? 0,
                      colNagad,
                    ),
                    const SizedBox(height: 10),
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

  // --- CHART DATA GENERATOR ---
  List<PieChartSectionData> _generateChartData() {
    double cash = ctrl.methodBreakdown['Cash'] ?? 0;
    double bkash = ctrl.methodBreakdown['Bkash'] ?? 0;
    double nagad = ctrl.methodBreakdown['Nagad'] ?? 0;
    double bank = ctrl.methodBreakdown['Bank'] ?? 0;
    double total = cash + bkash + nagad + bank;

    // Handle empty state
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: borderGrey,
          radius: 18,
          showTitle: false,
        ),
      ];
    }

    return [
      if (cash > 0)
        PieChartSectionData(
          value: cash,
          color: colCash,
          radius: 18,
          showTitle: false,
        ),
      if (bkash > 0)
        PieChartSectionData(
          value: bkash,
          color: colBkash,
          radius: 18,
          showTitle: false,
        ),
      if (nagad > 0)
        PieChartSectionData(
          value: nagad,
          color: colNagad,
          radius: 18,
          showTitle: false,
        ),
      if (bank > 0)
        PieChartSectionData(
          value: bank,
          color: colBank,
          radius: 18,
          showTitle: false,
        ),
    ];
  }

  Widget _chartLegendItem(String label, double amount, Color color) {
    if (amount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: slateMedium,
              ),
            ),
          ],
        ),
        Text(
          "৳${NumberFormat("#,##0").format(amount)}",
          style: const TextStyle(
            fontSize: 13,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.03),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorTheme.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: colorTheme.withOpacity(0.1)),
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
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // List
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Center(
                child: Text(
                  "- No Transactions -",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
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
                      Divider(height: 1, color: borderGrey.withOpacity(0.6)),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          DateFormat('hh:mm a').format(item.time),
                          style: const TextStyle(
                            fontSize: 10,
                            color: slateMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: slateDark,
                              ),
                            ),
                            if (item.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: slateMedium,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            // Use the controller's 'method' field for the badge
                            _createMethodBadge(item.method),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Amount
                      Text(
                        "৳${NumberFormat("#,##0").format(item.amount)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: slateDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- BADGE GENERATOR ---
  Widget _createMethodBadge(String method) {
    Color bg = slateLight;
    Color fg = slateMedium;
    String text = method.isEmpty ? "Cash" : method;
    String upper = text.toUpperCase();

    if (upper.contains("BKASH")) {
      bg = colBkash.withOpacity(0.1);
      fg = colBkash;
    } else if (upper.contains("NAGAD")) {
      bg = colNagad.withOpacity(0.1);
      fg = colNagad;
    } else if (upper.contains("BANK")) {
      bg = colBank.withOpacity(0.1);
      fg = colBank;
    } else if (upper.contains("CASH")) {
      bg = colCash.withOpacity(0.05);
      fg = slateMedium;
    } else {
      // Default / Mixed
      bg = Colors.purple.withOpacity(0.05);
      fg = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}