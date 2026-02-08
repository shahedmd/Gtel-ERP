// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'salescontroller.dart'; // Ensure this points to your MonthlySalesController file

class MonthlySalesDetailPage extends StatelessWidget {
  final DailyStat dailyStat;

  MonthlySalesDetailPage({super.key, required this.dailyStat});

  final MonthlySalesController controller = Get.find<MonthlySalesController>();

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
              DateFormat('MMMM dd, yyyy').format(dailyStat.date),
              style: const TextStyle(
                color: darkSlate,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              "Daily Transaction Log",
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDaySummaryCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: const [
                Icon(FontAwesomeIcons.listCheck, size: 14, color: textMuted),
                SizedBox(width: 8),
                Text(
                  "INVOICE LIST",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  // --- 1. DAY SUMMARY CARD ---
  Widget _buildDaySummaryCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Sales
            _summaryItem(
              "Sales Volume",
              dailyStat.totalSales,
              FontAwesomeIcons.fileInvoiceDollar,
              activeAccent,
            ),
            VerticalDivider(color: Colors.grey.shade200, thickness: 1),
            // Collection
            _summaryItem(
              "Cash Collected",
              dailyStat.totalCollected,
              FontAwesomeIcons.handHoldingDollar,
              successGreen,
            ),
            VerticalDivider(color: Colors.grey.shade200, thickness: 1),
            // Balance
            _summaryItem(
              "Net Balance",
              dailyStat.netDifference,
              FontAwesomeIcons.scaleUnbalanced,
              dailyStat.netDifference > 0 ? warningOrange : textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double amount, IconData icon, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: textMuted,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat('#,##0').format(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- 2. TRANSACTION LIST BUILDER ---
  Widget _buildTransactionList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: controller.fetchTransactionsForDay(dailyStat.date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: activeAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(FontAwesomeIcons.boxOpen, size: 40, color: Colors.black12),
                SizedBox(height: 16),
                Text(
                  "No invoices generated on this date",
                  style: TextStyle(color: textMuted),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
          itemCount: transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return _buildTransactionCard(tx);
          },
        );
      },
    );
  }

  // --- 3. INDIVIDUAL TRANSACTION CARD ---
  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final bool isCondition = tx['isCondition'] == true;
    final String customerName = tx['customerName'] ?? 'Unknown';
    final String invoiceId = tx['invoiceId'] ?? 'N/A';
    final double amount = double.tryParse(tx['grandTotal'].toString()) ?? 0.0;
    final String type =
        isCondition
            ? "Condition"
            : (tx['customerType'] ?? 'General').toString().toUpperCase();
    final String courier = tx['courierName'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
                  isCondition
                      ? warningOrange.withOpacity(0.1)
                      : activeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                isCondition
                    ? FontAwesomeIcons.truckFast
                    : FontAwesomeIcons.fileInvoice,
                size: 20,
                color: isCondition ? warningOrange : activeAccent,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: darkSlate,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        invoiceId,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCondition && courier.isNotEmpty ? "Via $courier" : type,
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "৳ ${NumberFormat('#,##0').format(amount)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Invoiced",
                style: TextStyle(fontSize: 10, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
