// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Expenses/dailycontroller.dart';
import 'Sales/controller.dart';
// Ensure these paths are exactly where your files are located

class OverviewController extends GetxController {
  // Use Get.find to get the already existing controllers
  final DailySalesController salesCtrl = Get.find<DailySalesController>();
  final DailyExpensesController expenseCtrl =
      Get.find<DailyExpensesController>();

  var selectedDate = DateTime.now().obs;

  // Observables for the UI
  RxDouble grossSales = 0.0.obs;
  RxDouble totalCollected = 0.0.obs;
  RxDouble totalExpenses = 0.0.obs;
  RxDouble netProfiit = 0.0.obs;
  RxDouble outstandingDebt = 0.0.obs;

  RxMap<String, double> paymentMethods =
      <String, double>{
        "cash": 0.0,
        "bkash": 0.0,
        "nagad": 0.0,
        "bank": 0.0,
      }.obs;

  @override
  void onInit() {
    super.onInit();

    // 1. Sync the dates immediately on load
    _syncDateAndFetch();

    // 2. Setup Workers: Listen to the AGGREGATE values from your sub-controllers.
    // This ensures that as soon as Firebase updates totalSales, the Overview updates.
    ever(salesCtrl.salesList, (_) => _recalculate());
    ever(expenseCtrl.dailyList, (_) => _recalculate());

    // Also recalculate if the totals in sub-controllers change
    ever(salesCtrl.totalSales, (_) => _recalculate());
    ever(expenseCtrl.dailyTotal, (_) => _recalculate());

    // 3. Initial Recalculate
    _recalculate();
  }

  void _syncDateAndFetch() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  void _recalculate() {
    // We calculate based on the current lists in the controllers
    // This makes it 100% dynamic as the Firebase stream updates the lists

    // 1. Fetch Sales Totals
    grossSales.value = salesCtrl.totalSales.value;
    totalCollected.value = salesCtrl.paidAmount.value;
    outstandingDebt.value = salesCtrl.debtorPending.value;

    // 2. Fetch Expense Totals
    totalExpenses.value = expenseCtrl.dailyTotal.value.toDouble();

    // 3. Net Profit = Total Gross Sales - Total Expenses
    netProfiit.value = totalCollected.value - totalExpenses.value;

    // 4. Calculate Payment Method Breakdown dynamically from the list
    double cash = 0, bkash = 0, nagad = 0, bank = 0;

    for (var sale in salesCtrl.salesList) {
      // paymentMethod?['type'] logic based on your SaleModel
      final method =
          sale.paymentMethod?['type']?.toString().toLowerCase().trim() ?? "";
      final paid = sale.paid;

      if (method == "cash") {
        cash += paid;
      }
      if (method == "bkash") {
        bkash += paid;
      }
      if (method == "nagad") {
        nagad += paid;
      }
      if (method == "bank") {
        bank += paid;
      }
    }

    paymentMethods["cash"] = cash;
    paymentMethods["bkash"] = bkash;
    paymentMethods["nagad"] = nagad;
    paymentMethods["bank"] = bank;

    paymentMethods.refresh();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate.value = date;
    _syncDateAndFetch(); // This triggers the sub-controllers to hit Firebase for the new date
    _recalculate();
  }
}

class DailyOverviewPage extends StatelessWidget {
  DailyOverviewPage({super.key});

  // Use Get.put if this is the first time the controller is used,
  // but ensure Sales and Expense controllers are already in memory.
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
        // If the sub-controllers are loading, show a progress bar
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildMainPerformanceCard()),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildPaymentBreakdownCard()),
                ],
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
        _statCard(
          "Net Profit",
          ctrl.netProfiit.value,
          FontAwesomeIcons.vault,
          Colors.indigo,
          isHighlight: true,
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
            "Outstanding Debt",
            "৳${ctrl.outstandingDebt.value.toStringAsFixed(0)}",
            FontAwesomeIcons.clockRotateLeft,
          ),
          const Divider(height: 40),
          _profitBar(
            "Net Profit Margin",
            ctrl.grossSales.value,
            ctrl.netProfiit.value,
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

  Widget _profitBar(String label, double total, double profit) {
    double percent = total > 0 ? (profit / total) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "${(percent * 100).toStringAsFixed(1)}%",
              style: const TextStyle(
                color: colorCash,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 12,
            backgroundColor: scaffoldBg,
            color: colorCash,
          ),
        ),
      ],
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
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: _getSections(),
              ),
            ),
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
      return PieChartSectionData(
        value: entry.value > 0 ? entry.value : 0.001,
        color: typeColors[entry.key] ?? Colors.grey,
        radius: 18,
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
