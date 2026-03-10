// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

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

  // Chart & Method Palette
  static const Color colCash = Color(0xFF1E293B); // Dark Slate for Cash
  static const Color colBkash = Color(0xFFE11471); // Official Bkash Pink
  static const Color colNagad = Color(0xFFF58220); // Official Nagad Orange
  static const Color colBank = Color(0xFF2563EB); // Bank Blue

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
                CircularProgressIndicator(color: infoBlue),
                SizedBox(height: 16),
                Text(
                  "Calculating Balance History...",
                  style: TextStyle(
                    color: slateMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

              const SizedBox(height: 24),

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
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "Sorted by Time (Newest First)",
                    style: TextStyle(
                      color: slateMedium.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive switching for Tablet/Web vs Mobile
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
  // 0. BALANCE SHEET SECTION
  // =========================================
  Widget _buildBalanceSheetSection() {
    final currency = NumberFormat("#,##0.00");
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
                        fontSize: 12,
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
                        fontSize: 12,
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
                        fontSize: 12,
                        color: slateMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "৳${currency.format(ctrl.closingCash.value)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
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
                  color: color.withOpacity(0.9),
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
              "৳${NumberFormat("#,##0.00").format(amount)}",
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
                "Income Source Breakdown",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: slateDark,
                ),
              ),
              Icon(FontAwesomeIcons.chartPie, color: slateMedium, size: 16),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 45,
                        sections: _generateChartData(),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Center(
                      child: Icon(
                        FontAwesomeIcons.wallet,
                        color: slateMedium.withOpacity(0.3),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
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
                    const SizedBox(height: 12),
                    _chartLegendItem(
                      "Bkash",
                      ctrl.methodBreakdown['Bkash'] ?? 0,
                      colBkash,
                    ),
                    const SizedBox(height: 12),
                    _chartLegendItem(
                      "Nagad",
                      ctrl.methodBreakdown['Nagad'] ?? 0,
                      colNagad,
                    ),
                    const SizedBox(height: 12),
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
    if (amount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: slateDark,
          ),
        ),
      ],
    );
  }

  // =========================================
  // 3. LEDGER COLUMNS (UPDATED UI)
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
            color: Colors.grey.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  "৳${NumberFormat("#,##0").format(total)}",
                  style: TextStyle(
                    color: colorTheme,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // List
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      FontAwesomeIcons.folderOpen,
                      size: 28,
                      color: borderGrey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "No Transactions",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                return _buildLedgerItemRow(item);
              },
            ),
        ],
      ),
    );
  }

  // --- NEW: CLEAN LIST ITEM ROW ---
  Widget _buildLedgerItemRow(LedgerItem item) {
    bool isIncome = item.type == 'income';
    Color amountColor = isIncome ? successGreen : errorRed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Visual Method Icon
          _buildMethodIcon(item.method),
          const SizedBox(width: 14),

          // 2. Details (Title, Subtitle & Badge)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        item.title, // e.g. "Condition Sale", "Deposit", "Expense"
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: slateDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _createMethodBadge(item.method),
                  ],
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle, // e.g. Customer Name, Bank Details, Note
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: slateMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Amount and Time Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isIncome ? '+' : '-'}৳${NumberFormat("#,##0").format(item.amount)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(item.time),
                style: const TextStyle(
                  fontSize: 10,
                  color: slateMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HELPER: Visual Icon for the left side of the row ---
  Widget _buildMethodIcon(String method) {
    IconData icon = FontAwesomeIcons.moneyBillWave;
    Color color = colCash;
    Color bg = colCash.withOpacity(0.1);

    String upper = method.toUpperCase();
    if (upper.contains("BKASH")) {
      icon = FontAwesomeIcons.mobileScreen;
      color = colBkash;
      bg = colBkash.withOpacity(0.1);
    } else if (upper.contains("NAGAD")) {
      icon = FontAwesomeIcons.mobileScreen;
      color = colNagad;
      bg = colNagad.withOpacity(0.1);
    } else if (upper.contains("BANK")) {
      icon = FontAwesomeIcons.buildingColumns;
      color = colBank;
      bg = colBank.withOpacity(0.1);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Icon(icon, size: 14, color: color)),
    );
  }

  // --- HELPER: Small Badge next to the Title ---
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
      bg = colCash.withOpacity(0.08);
      fg = colCash;
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