// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'details.dart'; // Ensure this matches your file structure
import 'salescontroller.dart'; // Ensure this points to MonthlySalesController

class MonthlySalesPage extends StatelessWidget {
  MonthlySalesPage({super.key});

  final controller = Get.put(MonthlySalesController());

  // Professional ERP Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningOrange = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.monthlyData.value.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: activeAccent),
          );
        }

        return Column(
          children: [
            _buildHeader(),
            _buildSummaryOverview(),
            _buildTableHead(),
            Expanded(child: _buildMainContent()),
          ],
        );
      }),
    );
  }

  // --- 1. HEADER (Title & Refresh) ---
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
                "Monthly Sales Analytics",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              Text(
                "Consolidated financial performance by month",
                style: TextStyle(fontSize: 14, color: textMuted),
              ),
            ],
          ),
          const Spacer(),
          // Refresh Button
          IconButton(
            onPressed: () => controller.fetchSales(),
            icon: const Icon(Icons.refresh, color: activeAccent),
            tooltip: "Sync Data",
          ),
        ],
      ),
    );
  }

  // --- 2. YEARLY SUMMARY OVERVIEW ---
  Widget _buildSummaryOverview() {
    // Calculate aggregate totals from all months
    double grandTotalRevenue = 0;
    double grandTotalCollected = 0;

    for (var m in controller.monthlyData.value.values) {
      grandTotalRevenue += m.total;
      grandTotalCollected += m.paid;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Revenue Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              FontAwesomeIcons.chartLine,
              color: activeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 20),

          // Yearly Revenue
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TOTAL YEARLY REVENUE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "৳ ${NumberFormat('#,##0').format(grandTotalRevenue)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ],
            ),
          ),

          Container(width: 1, height: 50, color: Colors.grey.shade200),
          const SizedBox(width: 20),

          // Yearly Collection
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TOTAL YEARLY COLLECTED",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "৳ ${NumberFormat('#,##0').format(grandTotalCollected)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: successGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. TABLE HEADER ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
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
              "Billing Month",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Status",
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Revenue",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 50,
            child: Center(
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. MAIN LIST CONTENT ---
  Widget _buildMainContent() {
    if (controller.monthlyData.value.isEmpty) {
      return _buildEmptyState();
    }

    final monthKeys = controller.monthlyData.value.keys.toList();
    // Sort descending (newest month first) if not already sorted by controller
    // monthKeys.sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: monthKeys.length,
      itemBuilder: (context, index) {
        final key = monthKeys[index];
        final data = controller.monthlyData.value[key]!;
        return _buildMonthRow(context, key, data);
      },
    );
  }

  Widget _buildMonthRow(BuildContext context, String key, dynamic data) {
    bool hasDues = data.pending > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap:
            () => Get.to(
              () => MonthlySalesDetailPage(monthKey: key, summary: data),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              // Month Title
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.calendarCheck,
                      size: 14,
                      color: activeAccent,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatMonthKey(key),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          hasDues
                              ? warningOrange.withOpacity(0.1)
                              : successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasDues ? "OUTSTANDING" : "SETTLED",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasDues ? warningOrange : successGreen,
                      ),
                    ),
                  ),
                ),
              ),
              // Collected (Paid)
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${NumberFormat('#,##0').format(data.paid)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Total Revenue
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${NumberFormat('#,##0').format(data.total)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                    fontSize: 15,
                  ),
                ),
              ),
              // Arrow
              const SizedBox(
                width: 50,
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  String _formatMonthKey(String key) {
    try {
      DateTime date = DateTime.parse("$key-01");
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return key;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(FontAwesomeIcons.folderOpen, size: 50, color: Colors.black12),
          SizedBox(height: 16),
          Text(
            "No sales data available for reports",
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }
}
