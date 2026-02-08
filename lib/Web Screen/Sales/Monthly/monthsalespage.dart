// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'salescontroller.dart'; // Ensure this points to your new MonthlySalesController file

class MonthlySalesPage extends StatelessWidget {
  MonthlySalesPage({super.key});

  final controller = Get.put(MonthlySalesController());

  // Professional ERP Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color errorRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildSummaryOverview(),
          _buildTableHead(),
          Expanded(child: _buildMainContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller.generateMonthlyReportPDF(),
        backgroundColor: darkSlate,
        icon: const Icon(FontAwesomeIcons.filePdf, color: Colors.white),
        label: const Text(
          "Download Report",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // --- 1. APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Monthly Sales Analytics",
            style: TextStyle(
              color: darkSlate,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Daily breakdown of Sales vs Collections",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed:
              () => controller.loadMonthlyData(controller.selectedDate.value),
          icon: const Icon(Icons.refresh, color: activeAccent),
          tooltip: "Refresh Data",
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // --- 2. MONTH SELECTOR ---
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            "Select Period:",
            style: TextStyle(fontWeight: FontWeight.bold, color: darkSlate),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: Obx(() {
                // Ensure the currently selected date is normalized to the 1st of the month
                DateTime current = DateTime(
                  controller.selectedDate.value.year,
                  controller.selectedDate.value.month,
                  1,
                );

                return DropdownButton<DateTime>(
                  value: current,
                  icon: const Icon(Icons.arrow_drop_down, color: activeAccent),
                  items: List.generate(12, (index) {
                    // Generate last 12 months
                    DateTime date = DateTime(
                      DateTime.now().year,
                      DateTime.now().month - index,
                      1,
                    );
                    return DropdownMenuItem(
                      value: date,
                      child: Text(
                        DateFormat('MMMM yyyy').format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: darkSlate,
                        ),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) controller.loadMonthlyData(val);
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. DASHBOARD SUMMARY ---
  Widget _buildSummaryOverview() {
    return Obx(
      () => Container(
        margin: const EdgeInsets.all(24),
        child: Row(
          children: [
            _buildSummaryCard(
              "TOTAL SALES",
              controller.totalMonthlySales.value,
              FontAwesomeIcons.fileInvoiceDollar,
              activeAccent,
            ),
            const SizedBox(width: 16),
            _buildSummaryCard(
              "COLLECTED",
              controller.totalMonthlyCollection.value,
              FontAwesomeIcons.handHoldingDollar,
              successGreen,
            ),
            const SizedBox(width: 16),
            _buildSummaryCard(
              "BALANCE DUE",
              controller.totalMonthlyDue.value,
              FontAwesomeIcons.scaleUnbalanced,
              controller.totalMonthlyDue.value > 0 ? warningOrange : textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                  ),
                ),
                Icon(icon, size: 16, color: color.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat('#,##0').format(amount),
              style: TextStyle(
                fontSize:
                    18, // Responsive sizing might be needed for small screens
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. TABLE HEADERS ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "Date",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Sales",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Collected",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Balance",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. MAIN LIST ---
  Widget _buildMainContent() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: activeAccent),
        );
      }

      if (controller.dailyStats.value.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(FontAwesomeIcons.calendarXmark, size: 40, color: textMuted),
              SizedBox(height: 16),
              Text(
                "No transactions found for this month",
                style: TextStyle(color: textMuted),
              ),
            ],
          ),
        );
      }

      // Convert map entries to list for ListView
      final dailyList = controller.dailyStats.value.entries.toList();

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          80,
        ), // Bottom padding for FAB
        itemCount: dailyList.length,
        separatorBuilder:
            (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (context, index) {
          final stat = dailyList[index].value;
          final isNegative =
              stat.netDifference <
              0; // Negative means Collected > Sales (e.g. paying old debts)

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Date & Invoice Count
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM (EEEE)').format(stat.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: darkSlate,
                        ),
                      ),
                      Text(
                        "${stat.invoiceCount} invoices",
                        style: const TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),

                // Sales Amount
                Expanded(
                  flex: 2,
                  child: Text(
                    NumberFormat('#,##0').format(stat.totalSales),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: darkSlate),
                  ),
                ),

                // Collected Amount
                Expanded(
                  flex: 2,
                  child: Text(
                    NumberFormat('#,##0').format(stat.totalCollected),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Balance (Difference)
                Expanded(
                  flex: 2,
                  child: Text(
                    NumberFormat('#,##0').format(stat.netDifference),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      // If netDifference is positive, it's Due (Orange/Red).
                      // If negative, it means we collected more than we sold (Green - paying back).
                      color:
                          isNegative
                              ? successGreen
                              : (stat.netDifference > 0
                                  ? warningOrange
                                  : textMuted),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}