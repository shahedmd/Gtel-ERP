// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'salescontroller.dart'; // Ensure correct path for GeneratePDF

class MonthlySalesDetailPage extends StatelessWidget {
  final String monthKey;
  final MonthlySummary summary;

  const MonthlySalesDetailPage({
    super.key,
    required this.monthKey,
    required this.summary,
  });

  // ERP Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color alertRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    // Sort days descending (Newest date at the top)
    final days = summary.daily.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkSlate),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatMonthTitle(monthKey),
              style: const TextStyle(
                color: darkSlate,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              "Monthly Performance Audit",
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Professional PDF Button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () => generateMonthlyPdf(monthKey, summary),
              icon: const FaIcon(
                FontAwesomeIcons.filePdf,
                size: 16,
                color: alertRed,
              ),
              label: const Text(
                "Export PDF",
                style: TextStyle(color: alertRed, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. REVENUE VS COLLECTION STATS ---
            _buildDetailedStatsBlock(),

            const SizedBox(height: 32),

            // --- 2. DAILY BREAKDOWN TABLE ---
            const Text(
              "Daily Breakdown",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
            const SizedBox(height: 16),

            _buildDailyTable(days),
          ],
        ),
      ),
    );
  }

  // --- REVENUE VS COLLECTION STATS BLOCK ---
  Widget _buildDetailedStatsBlock() {
    return Row(
      children: [
        // REVENUE BLOCK
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activeAccent.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: activeAccent.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: activeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: activeAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "REVENUE",
                          style: TextStyle(
                            color: activeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "Invoiced this month",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "৳ ${NumberFormat('#,##0').format(summary.total)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),

        // COLLECTION BLOCK
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: successGreen.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: successGreen.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.savings_outlined,
                        color: successGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "COLLECTED",
                          style: TextStyle(
                            color: successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "Received this month",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "৳ ${NumberFormat('#,##0').format(summary.paid)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        darkSlate, // Keeping amount text dark for readability
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- DATA GRID TABLE ---
  Widget _buildDailyTable(List<String> days) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: const BoxDecoration(
              color: darkSlate,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
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
              ],
            ),
          ),
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final dayKey = days[index];
              final data = summary.daily[dayKey]!;
              return _buildDailyRow(dayKey, data);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRow(String dayKey, DailySummary data) {
    bool isPending = data.pending > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: textMuted),
                const SizedBox(width: 12),
                Text(
                  _formatDayKey(dayKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkSlate,
                    fontSize: 13,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isPending
                          ? warningOrange.withOpacity(0.1)
                          : successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPending ? "DUE RECORDED" : "FULLY PAID",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isPending ? warningOrange : successGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Paid
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
          // Total
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${NumberFormat('#,##0').format(data.total)}",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  String _formatMonthTitle(String key) {
    try {
      DateTime date = DateTime.parse("$key-01");
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return "Month: $key";
    }
  }

  String _formatDayKey(String key) {
    try {
      DateTime date = DateTime.parse(key);
      return DateFormat('dd MMM (EEE)').format(date);
    } catch (e) {
      return key;
    }
  }
}
