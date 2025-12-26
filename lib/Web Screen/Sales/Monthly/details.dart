// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'salescontroller.dart';





class MonthlySalesDetailPage extends StatelessWidget {
  final String monthKey;
  final MonthlySummary summary;

  const MonthlySalesDetailPage({
    super.key,
    required this.monthKey,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final days = summary.daily.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF0C2E69),
        centerTitle: true,
        title: Text("Monthly Sales • $monthKey", style: TextStyle(color: Colors.white),),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filePdf, color: Colors.white,),
            onPressed: () {
              // PDF GENERATION CALL
              generateMonthlyPdf(monthKey, summary);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _buildSummaryPOS(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(25),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final dayKey = days[index];
                final data = summary.daily[dayKey]!;
          
                return _buildDayTile(dayKey, data);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 TOP SUMMARY POS CARD
  Widget _buildSummaryPOS() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _summaryRow(
              icon: FontAwesomeIcons.sackDollar,
              label: "Total",
              value: summary.total,
              color: Colors.black,
              big: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniSummary(
                    "Paid",
                    summary.paid,
                    Colors.green,
                    FontAwesomeIcons.circleCheck,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniSummary(
                    "Pending",
                    summary.pending,
                    Colors.orange,
                    FontAwesomeIcons.clock,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    bool big = false,
  }) {
    return Row(
      children: [
        FaIcon(icon, color: color),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          "৳${value.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: big ? 20 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _miniSummary(
      String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// 🔹 DAILY POS TILE
  Widget _buildDayTile(String dayKey, DailySummary data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.calendarDay,
                  size: 14,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  dayKey,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  data.total.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip("Paid", data.paid, Colors.green),
                const SizedBox(width: 6),
                _chip("Pending", data.pending, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${value.toStringAsFixed(0)}",
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
