// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/Service/servicepage.dart';
// Adjust these imports based on your actual project structure
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';

class ShortlistScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class ShortlistPage extends StatelessWidget {
  ShortlistPage({super.key});

  final ProductController controller = Get.find<ProductController>();

  // Explicit ScrollControllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // Load Page 1 on Init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchShortList(page: 1);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: _buildAppBar(),
      body: ScrollConfiguration(
        behavior: ShortlistScrollBehavior(),
        child: Column(
          children: [
            // 1. TOP SUMMARY STATS
            _buildSummarySection(),

            // 2. MAIN TABLE AREA
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ), // Slate 200
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Title & Refresh
                    _buildTableHeader(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Data Table
                    Expanded(child: _buildDataTable()),

                    // Pagination Footer
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildPaginationFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. APP BAR
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Stock Alerts & Reordering",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A), // Slate 900
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: ElevatedButton.icon(
            onPressed: () => _handleExport(),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text("Export Report"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), // Red 600
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. SUMMARY SECTION
  // ==========================================
  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Obx(() {
        final total = controller.shortlistTotal.value;
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Products Needing Restock",
                value: total.toString(),
                icon: Icons.priority_high_rounded,
                color: const Color(0xFFFFF7ED), // Orange 50
                iconColor: const Color(0xFFEA580C), // Orange 600
                borderColor: const Color(0xFFFED7AA),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: "Recommended Action",
                value: "Generate PO",
                icon: Icons.assignment_turned_in_outlined,
                color: const Color(0xFFEFF6FF), // Blue 50
                iconColor: const Color(0xFF2563EB), // Blue 600
                borderColor: const Color(0xFFBFDBFE),
                isText: true,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required Color borderColor,
    bool isText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B), // Slate 500
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isText ? 18 : 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A), // Slate 900
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. TABLE HEADER
  // ==========================================
  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Low Stock Inventory",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF334155), // Slate 700
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => controller.fetchShortList(page: 1),
            tooltip: "Refresh List",
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. DATA TABLE (Full Width & Striped)
  // ==========================================
  Widget _buildDataTable() {
    return Obx(() {
      if (controller.isShortListLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.shortListProducts.isEmpty) {
        return _buildEmptyState();
      }

      // LAYOUT BUILDER IS KEY FOR SCREEN FIT
      return LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10,
            radius: const Radius.circular(5),
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    // FORCES TABLE TO FILL WIDTH
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: const Color(0xFFE2E8F0),
                        dataTableTheme: DataTableThemeData(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      child: DataTable(
                        headingRowHeight: 56,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 24,
                        columnSpacing: 24,
                        showBottomBorder: true,
                        columns: [
                          _col("Status", align: MainAxisAlignment.center),
                          _col("Model", align: MainAxisAlignment.start),
                          _col("Product Name", align: MainAxisAlignment.start),
                          _col(
                            "Stock",
                            align: MainAxisAlignment.end,
                            isNumeric: true,
                          ),
                          _col(
                            "Alert Limit",
                            align: MainAxisAlignment.end,
                            isNumeric: true,
                          ),
                          _col(
                            "Shortage",
                            align: MainAxisAlignment.end,
                            isNumeric: true,
                          ),
                        ],
                        rows: List.generate(
                          controller.shortListProducts.length,
                          (index) {
                            final p = controller.shortListProducts[index];
                            final bool isCritical = p.stockQty == 0;
                            final int shortage = p.alertQty - p.stockQty;
                            // STRIPED ROWS LOGIC
                            final color =
                                index.isEven
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC);

                            return DataRow(
                              color: WidgetStateProperty.all(color),
                              cells: [
                                DataCell(
                                  Center(child: _buildStatusBadge(isCritical)),
                                ),
                                DataCell(
                                  Text(
                                    p.model,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 250,
                                    ),
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      p.stockQty.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isCritical
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(p.alertQty.toString()),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "+$shortage",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // Improved Column Helper with Alignment Support
  DataColumn _col(
    String label, {
    bool isNumeric = false,
    MainAxisAlignment align = MainAxisAlignment.start,
  }) {
    return DataColumn(
      numeric: isNumeric,
      label: Expanded(
        child: Row(
          mainAxisAlignment: align,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Color(0xFF64748B), // Slate 500
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCritical) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical ? const Color(0xFFFECACA) : const Color(0xFFFED7AA),
        ),
      ),
      child: Text(
        isCritical ? "CRITICAL" : "LOW",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
        ),
      ),
    );
  }

  // ==========================================
  // 5. PAGINATION FOOTER
  // ==========================================
  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Obx(() {
        final int total = controller.shortlistTotal.value;
        final int current = controller.shortlistPage.value;
        final int size = controller.shortlistLimit.value;
        final int totalPages = (total / size).ceil();
        final int start = total == 0 ? 0 : ((current - 1) * size) + 1;
        final int end = (current * size) > total ? total : (current * size);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Showing $start - $end of $total alerts",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      current > 1 ? () => controller.prevShortlistPage() : null,
                  tooltip: "Previous",
                  splashRadius: 20,
                  color: const Color(0xFF0F172A),
                  disabledColor: const Color(0xFFCBD5E1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    "$current",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      current < totalPages
                          ? () => controller.nextShortlistPage()
                          : null,
                  tooltip: "Next",
                  splashRadius: 20,
                  color: const Color(0xFF0F172A),
                  disabledColor: const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // Green 50
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: const Color(0xFF16A34A),
            ), // Green 600
          ),
          const SizedBox(height: 20),
          const Text(
            "Healthy Inventory!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "No products are currently below their alert level.",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    Get.dialog(
      const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            margin: EdgeInsets.all(20),
            elevation: 10,
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 24),
                  Text(
                    "Downloading Report...",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Processing large dataset. Please wait.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      List<Product> allData = await controller.fetchAllShortListForExport();

      if (allData.isNotEmpty) {
        await PdfService.generateShortlistPdf(allData);

        if (Get.isDialogOpen ?? false) Get.back();

        Get.snackbar(
          "Export Complete",
          "Generated PDF for ${allData.length} items",
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          margin: const EdgeInsets.all(16),
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
          "Info",
          "No data available to export",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      print("Export Error: $e");
      Get.snackbar(
        "Export Failed",
        "Error: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
