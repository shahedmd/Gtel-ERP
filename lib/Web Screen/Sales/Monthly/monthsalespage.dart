// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'details.dart';
import 'salescontroller.dart';

class MonthlySalesPage extends StatelessWidget {
  MonthlySalesPage({super.key});

  final controller = Get.put(MonthlySalesController());

  // Professional ERP Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

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

  // --- 2. SUMMARY OVERVIEW (Aggregate Total) ---
  Widget _buildSummaryOverview() {
    // Calculate aggregate totals from all months
    double grandTotal = 0;
    for (var m in controller.monthlyData.value.values) {
      grandTotal += m.total;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(
              FontAwesomeIcons.chartPie,
              color: activeAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AGGREGATE ANNUAL REVENUE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                "Total sales from all recorded months",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "৳ ${grandTotal.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkSlate,
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
            width: 80,
            child: Text(
              "Details",
              textAlign: TextAlign.center,
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

  // --- 4. MAIN LIST CONTENT ---
  Widget _buildMainContent() {
    if (controller.monthlyData.value.isEmpty) {
      return _buildEmptyState();
    }

    final monthKeys = controller.monthlyData.value.keys.toList();

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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        hasDues
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: hasDues ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasDues ? "OUTSTANDING" : "SETTLED",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              hasDues
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Collected (Paid)
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${data.paid.toStringAsFixed(2)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Total Revenue
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${data.total.toStringAsFixed(2)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                    fontSize: 16,
                  ),
                ),
              ),
              // Action Icon
              const SizedBox(
                width: 80,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.black12,
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
