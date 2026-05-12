import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../stock_controller.dart';

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
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child:
          isMobile
              ? Column(
                children: [
                  _InventorySummary(controller: controller, isMobile: isMobile),
                  const SizedBox(height: 12),
                  _ExchangeRateCard(
                    isMobile: isMobile,
                    controller: controller,
                    currencyInput: currencyInput,
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _InventorySummary(
                      controller: controller,
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
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

class _InventorySummary extends StatelessWidget {
  final ProductController controller;
  final bool isMobile;

  const _InventorySummary({required this.controller, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedWarehouse = controller.selectedWarehouseName;
      final selectedWarehouseId = controller.selectedWarehouseId.value;
      final productCount = controller.totalProducts.value;
      final pageCount = controller.allProducts.length;
      final totalQty =
          selectedWarehouseId == null
              ? controller.allProducts.fold<int>(
                0,
                (sum, product) => sum + product.stockQty,
              )
              : controller.warehouseTotalQty(selectedWarehouseId);

      return Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child:
            isMobile
                ? Column(
                  children: [
                    _MainValueBlock(
                      title:
                          selectedWarehouseId == null
                              ? 'Total Stock Value'
                              : '$selectedWarehouse Value',
                      value: controller.formattedTotalValuation,
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF2563EB),
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Products',
                            value: productCount.toString(),
                            icon: Icons.category_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            label: 'Page Items',
                            value: pageCount.toString(),
                            icon: Icons.view_list_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            label: 'Qty',
                            value: totalQty.toString(),
                            icon: Icons.inventory_2_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _MainValueBlock(
                        title:
                            selectedWarehouseId == null
                                ? 'Total Stock Value'
                                : '$selectedWarehouse Value',
                        value: controller.formattedTotalValuation,
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF2563EB),
                        isMobile: isMobile,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Products',
                        value: productCount.toString(),
                        icon: Icons.category_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Page Items',
                        value: pageCount.toString(),
                        icon: Icons.view_list_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Qty',
                        value: totalQty.toString(),
                        icon: Icons.inventory_2_rounded,
                      ),
                    ),
                  ],
                ),
      );
    });
  }
}

class _MainValueBlock extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isMobile;

  const _MainValueBlock({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: isMobile ? 42 : 48,
          height: isMobile ? 42 : 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: isMobile ? 22 : 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF2563EB)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
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
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
      ),
      child:
          isMobile
              ? Column(
                children: [
                  _ExchangeHeader(controller: controller, isMobile: isMobile),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CurrencyInput(currencyInput: currencyInput),
                      ),
                      const SizedBox(width: 8),
                      _ApplyButton(
                        controller: controller,
                        currencyInput: currencyInput,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: _ExchangeHeader(
                      controller: controller,
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: _CurrencyInput(currencyInput: currencyInput),
                  ),
                  const SizedBox(width: 8),
                  _ApplyButton(
                    controller: controller,
                    currencyInput: currencyInput,
                    isMobile: isMobile,
                  ),
                ],
              ),
    );
  }
}

class _ExchangeHeader extends StatelessWidget {
  final ProductController controller;
  final bool isMobile;

  const _ExchangeHeader({required this.controller, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: isMobile ? 40 : 44,
          height: isMobile ? 40 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.currency_exchange_rounded,
            color: Color(0xFFD97706),
          ),
        ),
        SizedBox(width: isMobile ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bulk Currency Update (CNY)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Obx(
                () => Text(
                  'Current: 1 CNY = Tk ${controller.currentCurrency.value.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrencyInput extends StatelessWidget {
  final TextEditingController currencyInput;

  const _CurrencyInput({required this.currencyInput});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: currencyInput,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: 'New Rate',
        fillColor: const Color(0xFFF8FAFC),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final ProductController controller;
  final TextEditingController currencyInput;
  final bool isMobile;

  const _ApplyButton({
    required this.controller,
    required this.currencyInput,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isActionLoading.value;

      return ElevatedButton.icon(
        onPressed: loading ? null : () => _handleCurrencyUpdate(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD97706),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFFCD34D),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon:
            loading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Icon(Icons.update_rounded, size: isMobile ? 16 : 18),
        label: Text(
          isMobile ? 'Set' : 'Apply',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    });
  }

  void _handleCurrencyUpdate(BuildContext context) {
    final value = double.tryParse(currencyInput.text.trim());

    if (value == null || value <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid currency rate.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.defaultDialog(
      title: 'Confirm Bulk Revaluation',
      middleText:
          'Update to 1 CNY = Tk ${value.toStringAsFixed(2)}?\nThis will recalculate product costs.',
      textCancel: 'Cancel',
      textConfirm: 'Update All',
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFD97706),
      onConfirm: () async {
        Get.back();
        await controller.updateCurrencyAndRecalculate(value);
        currencyInput.clear();
      },
    );
  }
}

