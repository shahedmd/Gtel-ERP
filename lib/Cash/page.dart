// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controller.dart';

class CashDrawerPage extends StatelessWidget {
  const CashDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CashDrawerController());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "CASH DRAWER & REVENUE",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => controller.fetchDrawerData(),
            icon: const Icon(Icons.sync),
          ),
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
                    _buildPaymentGrid(controller),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Colors.blueGrey),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: controller.selectedMonth.value,
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1))),
              ),
            ),
            onChanged:
                (v) => controller.changeDate(v!, controller.selectedYear.value),
          ),
          const SizedBox(width: 20),
          DropdownButton<int>(
            value: controller.selectedYear.value,
            items:
                [2024, 2025, 2026]
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                    )
                    .toList(),
            onChanged:
                (v) =>
                    controller.changeDate(controller.selectedMonth.value, v!),
          ),
        ],
      ),
    );
  }

  // --- GRAND TOTAL CARD ---
  Widget _buildMainSummary(CashDrawerController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "TOTAL SETTLED REVENUE",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "৳ ${controller.grandTotal.value.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "For ${DateFormat('MMMM yyyy').format(DateTime(controller.selectedYear.value, controller.selectedMonth.value))}",
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- INDIVIDUAL BUCKETS ---
  Widget _buildPaymentGrid(CashDrawerController controller) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _paymentCard(
          "CASH",
          controller.cashTotal.value,
          Colors.green,
          Icons.payments,
        ),
        _paymentCard(
          "BKASH",
          controller.bkashTotal.value,
          Colors.pink,
          Icons.mobile_friendly,
        ),
        _paymentCard(
          "NAGAD",
          controller.nagadTotal.value,
          Colors.orange,
          Icons.account_balance_wallet,
        ),
        _paymentCard(
          "BANK",
          controller.bankTotal.value,
          Colors.blue,
          Icons.account_balance,
        ),
      ],
    );
  }

  Widget _paymentCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              "৳${amount.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
