// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controller.dart'; // Import the controller above

class CashDrawerPage extends StatelessWidget {
  const CashDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CashDrawerController());

    return Scaffold(
      backgroundColor: const Color(
        0xFFF1F5F9,
      ), // Slate-100 (Matches Sales Page)
      appBar: AppBar(
        title: const Text(
          "FINANCIAL REPORTS",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B), // Slate-800
        elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), // Blue-600
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => controller.downloadPdf(),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text("Export PDF", style: TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            tooltip: "Refresh Data",
            onPressed: () => controller.fetchDrawerData(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildMainSummary(controller),
                    const SizedBox(height: 25),
                    _buildResponsivePaymentGrid(context, controller),
                    const SizedBox(height: 25),
                    _buildRecentTransactionsList(
                      controller,
                    ), // Added a list view
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- FILTERS ---
  Widget _buildFilterBar(CashDrawerController controller) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 18),
          const SizedBox(width: 15),
          // Month Dropdown
          _buildDropdown<int>(
            value: controller.selectedMonth.value,
            items: List.generate(12, (i) => i + 1),
            labelBuilder:
                (val) => DateFormat('MMMM').format(DateTime(2024, val)),
            onChanged:
                (v) => controller.changeDate(v!, controller.selectedYear.value),
          ),
          const SizedBox(width: 15),
          // Year Dropdown
          _buildDropdown<int>(
            value: controller.selectedYear.value,
            items: [2024, 2025, 2026, 2027],
            labelBuilder: (val) => val.toString(),
            onChanged:
                (v) =>
                    controller.changeDate(controller.selectedMonth.value, v!),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.blueGrey,
            size: 20,
          ),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          items:
              items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(labelBuilder(item)),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- GRAND TOTAL CARD ---
  Widget _buildMainSummary(CashDrawerController controller) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate-800
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "TOTAL SETTLED REVENUE",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "৳ ${NumberFormat('#,##0.00').format(controller.grandTotal.value)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              fontFamily: 'RobotoMono',
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('MMMM yyyy').format(
                DateTime(
                  controller.selectedYear.value,
                  controller.selectedMonth.value,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- RESPONSIVE GRID ---
  Widget _buildResponsivePaymentGrid(
    BuildContext context,
    CashDrawerController controller,
  ) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    double ratio = 1.6;

    if (screenWidth < 600) {
      crossAxisCount = 1;
      ratio = 2.5;
    } else if (screenWidth < 1100) {
      crossAxisCount = 2;
      ratio = 2.0;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: ratio,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _paymentCard(
          "CASH DRAWER",
          controller.cashTotal.value,
          Colors.green,
          Icons.money,
        ),
        _paymentCard(
          "BKASH",
          controller.bkashTotal.value,
          Colors.pink,
          Icons.phone_android,
        ),
        _paymentCard(
          "NAGAD",
          controller.nagadTotal.value,
          Colors.orange,
          Icons.wallet,
        ),
        _paymentCard(
          "BANK DEPOSIT",
          controller.bankTotal.value,
          Colors.blue,
          Icons.account_balance,
        ),
      ],
    );
  }

  Widget _paymentCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          FittedBox(
            child: Text(
              "৳${NumberFormat('#,##0').format(amount)}",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- RECENT TRANSACTIONS TABLE (Visual Only) ---
  Widget _buildRecentTransactionsList(CashDrawerController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: const Text(
              "Recent Transactions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          const Divider(height: 1),
          // Show only top 5 for UI cleanliness
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.filteredSales.take(5).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var item = controller.filteredSales[index];

              // Helper to display method
              String method = "Cash";
              var pm = item['paymentMethod'];
              if (pm is Map && pm['type'] == 'multi') {
                method = "Split Payment";
              }  if (pm is Map) {
                method = (pm['type'] ?? 'Cash').toString().toUpperCase();
              }

              // Helper for Amount
              double amount =
                  double.tryParse(item['paid'].toString()) ??
                  (pm is Map
                      ? (double.tryParse(pm['totalPaid'].toString()) ?? 0)
                      : 0);

              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                title: Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  "${DateFormat('dd MMM hh:mm a').format((item['timestamp'] as Timestamp).toDate())} • $method",
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  "+ ৳${amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
