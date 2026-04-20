import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stock_helper_dialogs.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';

import 'widgets/stock_appbar.dart';
import 'widgets/stock_stats.dart';
import 'widgets/stock_table.dart';

class ProductScreen extends StatelessWidget {
  ProductScreen({super.key});

  final ProductController controller = Get.find<ProductController>();
  final ShipmentController shipmentController = Get.find<ShipmentController>();
  final TextEditingController currencyInput = TextEditingController();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: StockAppBar(isMobile: isMobile, controller: controller),
      body: Column(
        children: [
          // Stats + currency updater
          StockStatsSection(
            isMobile: isMobile,
            controller: controller,
            currencyInput: currencyInput,
          ),

          // Main table
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 8 : 16,
                0,
                isMobile ? 8 : 16,
                16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search + sort toolbar
                  _buildToolbar(isMobile),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // Table
                  Expanded(
                    child: StockTable(
                      isMobile: isMobile,
                      controller: controller,
                      shipmentController: shipmentController,
                      verticalScroll: _verticalScroll,
                      horizontalScroll: _horizontalScroll,
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // Pagination
                  _buildPagination(isMobile),
                ],
              ),
            ),
          ),
        ],
      ),
floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Add product button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProductDialog(controller),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        label: Text(
          'Add Product',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: isMobile ? 13 : 15,
          ),
        ),
        icon: Icon(Icons.add, color: Colors.white, size: isMobile ? 20 : 24),
      ),
    );
  }

  // ── Search + Sort Toolbar ────────────────────────────────
  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(fontSize: 13),
              onChanged: controller.search,
              decoration: InputDecoration(
                hintText:
                    isMobile
                        ? 'Search...'
                        : 'Search by model, name or brand...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sort by loss toggle
          Obx(() {
            final isActive = controller.sortByLoss.value;
            return InkWell(
              onTap: controller.toggleSortByLoss,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isActive
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.trending_down : Icons.sort,
                      color:
                          isActive ? const Color(0xFFDC2626) : Colors.grey[700],
                      size: 20,
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Loss First',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isActive
                                  ? const Color(0xFFDC2626)
                                  : Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Pagination ────────────────────────────────────────────
  Widget _buildPagination(bool isMobile) {
    return Obx(() {
      final total = controller.totalProducts.value;
      final current = controller.currentPage.value;
      final size = controller.pageSize.value;
      final totalPages = (total / size).ceil();
      final start = total == 0 ? 0 : ((current - 1) * size) + 1;
      final end = (current * size) > total ? total : (current * size);

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile)
              Text(
                'Showing $start–$end of $total results',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              )
            else
              Text(
                '$total products',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: current > 1 ? controller.previousPage : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Page $current / $totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: current < totalPages ? controller.nextPage : null,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}