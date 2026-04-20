// lib/Core/Stock Management/widgets/stock_stats.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';

class StockStatsSection extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;
  final TextEditingController currencyInput;

  const StockStatsSection({
    super.key,
    required this.isMobile,
    required this.controller,
    required this.currencyInput,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child:
          isMobile
              ? Column(
                children: [
                  _StatCard(isMobile: isMobile, controller: controller),
                  const SizedBox(height: 12),
                  _ExchangeRateCard(
                    isMobile: isMobile,
                    controller: controller,
                    currencyInput: currencyInput,
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _StatCard(
                      isMobile: isMobile,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _ExchangeRateCard(
                      isMobile: isMobile,
                      controller: controller,
                      currencyInput: currencyInput,
                    ),
                  ),
                ],
              ),
    );
  }
}

// ── Total Valuation Card ─────────────────────────────────────
class _StatCard extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;

  const _StatCard({required this.isMobile, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.monetization_on,
              color: Colors.blue,
              size: isMobile ? 24 : 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Warehouse Value',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(
                  () => Text(
                    '৳ ${controller.formattedTotalValuation}',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exchange Rate Card ───────────────────────────────────────
class _ExchangeRateCard extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;
  final TextEditingController currencyInput;

  const _ExchangeRateCard({
    required this.isMobile,
    required this.controller,
    required this.currencyInput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_exchange, color: Colors.amber),
          ),
          SizedBox(width: isMobile ? 10 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Currency Update (CNY)',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(
                  () => Text(
                    'Current: 1 ¥ = ${controller.currentCurrency.value.toStringAsFixed(2)} ৳',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: isMobile ? 80 : 120,
            child: TextField(
              controller: currencyInput,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'New Rate',
                fillColor: Colors.grey.shade100,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _handleCurrencyUpdate(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
            ),
            icon: Icon(Icons.update, size: isMobile ? 16 : 20),
            label: Text(isMobile ? 'Set' : 'Apply to All'),
          ),
        ],
      ),
    );
  }

  void _handleCurrencyUpdate(BuildContext context) {
    final val = double.tryParse(currencyInput.text);
    if (val != null && val > 0) {
      Get.defaultDialog(
        title: 'Confirm Bulk Revaluation',
        middleText:
            'Update to ¥1 = ৳${val.toStringAsFixed(2)}?\nThis will recalculate Avg Cost for ALL products.',
        textConfirm: 'Update All',
        confirmTextColor: Colors.white,
        buttonColor: Colors.amber.shade700,
        onConfirm: () {
          controller.updateCurrencyAndRecalculate(val);
          currencyInput.clear();
          Get.back();
        },
      );
    } else {
      Get.snackbar(
        'Error',
        'Please enter a valid currency rate.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}