// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'salescontroller.dart';

class MonthlySalesDetailPage extends StatelessWidget {
  final String monthKey;
  final MonthlySummary summary;

  const MonthlySalesDetailPage({
    super.key,
    required this.monthKey,
    required this.summary,
  });

  // ERP Theme Colors (Matching your Sidebar and other pages)
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

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
                color: Colors.redAccent,
              ),
              label: const Text(
                "Export PDF",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
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
            // --- 1. MONTHLY STATS GRID ---
            _buildMonthlyStats(),

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

  // --- TOP DASHBOARD STATS ---
  Widget _buildMonthlyStats() {
    return Row(
      children: [
        _statCard(
          "Total Sales",
          summary.total,
          FontAwesomeIcons.sackDollar,
          activeAccent,
        ),
        const SizedBox(width: 16),
        _statCard(
          "Total Collected",
          summary.paid,
          FontAwesomeIcons.circleCheck,
          Colors.green,
        ),
        const SizedBox(width: 16),
        _statCard(
          "Total Outstanding",
          summary.pending,
          FontAwesomeIcons.clock,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _statCard(String label, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: FaIcon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                Text(
                  "৳ ${value.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                    "Day Total",
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
                  ),
                ),
              ],
            ),
          ),
          // Status Badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isPending
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPending ? "DUE RECORDED" : "FULLY PAID",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isPending
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Paid
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${data.paid.toStringAsFixed(2)}",
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${data.total.toStringAsFixed(2)}",
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
      return DateFormat('dd MMM yyyy (EEEE)').format(date);
    } catch (e) {
      return key;
    }
  }
}
