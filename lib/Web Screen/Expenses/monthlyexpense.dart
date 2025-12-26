// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'monthlycontroller.dart';

class MonthlyExpensesPage extends StatelessWidget {
  MonthlyExpensesPage({super.key});

  final MonthlyExpensesController controller = Get.put(MonthlyExpensesController());

  // Professional Theme Colors (Sync with Sidebar)
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(),
          _buildGrandTotalCard(),
          _buildTableHead(),
          Expanded(
            child: Obx(() {
              if (controller.monthlyList.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                itemCount: controller.monthlyList.length,
                itemBuilder: (context, index) {
                  final monthData = controller.monthlyList[index];
                  return _buildMonthRow(context, monthData);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- HEADER SECTION ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Expense Analytics",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkSlate),
              ),
              Text(
                "Monthly financial breakdown and summaries",
                style: TextStyle(fontSize: 14, color: textMuted),
              ),
            ],
          ),
          const Spacer(),
          // Refresh Action
          IconButton(
            onPressed: () => controller.fetchMonthlyExpenses(),
            icon: const Icon(Icons.refresh, color: activeAccent),
            tooltip: "Refresh Data",
          ),
        ],
      ),
    );
  }

  // --- TOP STAT CARD (Lifetime/Grand Total) ---
  Widget _buildGrandTotalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: activeAccent.withOpacity(0.1),
            child: const Icon(FontAwesomeIcons.chartLine, color: activeAccent, size: 16),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AGGREGATE EXPENDITURE", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.1)),
              Text("Lifetime Total across all months", 
                style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          const Spacer(),
          Obx(() => Text(
            "৳ ${controller.grandTotalAllMonths.value.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: darkSlate),
          )),
        ],
      ),
    );
  }

  // --- TABLE HEAD ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text("Billing Month", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("Day Entries", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("Total Amount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, ),textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text("Actions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, ),textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // --- MONTH DATA ROW ---
  Widget _buildMonthRow(BuildContext context, dynamic month) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap: () => _showMonthlyDetails(context, month),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              // Month Key
              Expanded(
                flex: 3,
                child: Text(
                  month.monthKey,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: darkSlate, fontSize: 15),
                ),
              ),
              // Count of Days
              Expanded(
                flex: 2,
                child: Text("${month.items.length} Days logged", style: const TextStyle(color: textMuted)),
              ),
              // Total Amount
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${month.total.toStringAsFixed(2)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: activeAccent, fontSize: 16),
                ),
              ),
              // Actions
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.filePdf, color: Colors.redAccent, size: 18),
                      onPressed: () => controller.generateMonthlyPDF(month.monthKey),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DRILL DOWN DIALOG (POS Style) ---
  void _showMonthlyDetails(BuildContext context, dynamic month) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: darkSlate,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    Text("Breakdown: ${month.monthKey}", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close, color: Colors.white54)),
                  ],
                ),
              ),
              // Daily List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: month.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = month.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: activeAccent),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy').format(DateTime.parse(item.date)),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            "৳ ${item.total}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: darkSlate),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Summary Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: bgGrey, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("MONTHLY ACCUMULATION:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textMuted)),
                    Text("৳ ${month.total}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkSlate)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(FontAwesomeIcons.boxOpen, size: 50, color: Colors.black12),
          SizedBox(height: 16),
          Text("No expense history found.", style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }
}