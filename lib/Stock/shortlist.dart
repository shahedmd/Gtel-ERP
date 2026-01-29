// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
// Adjust imports to match your project structure
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:gtel_erp/Stock/Service/servicepage.dart';
// IMPORT YOUR SHIPMENT CONTROLLER HERE

class ShortlistScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class ShortlistPage extends StatefulWidget {
  const ShortlistPage({super.key});

  @override
  State<ShortlistPage> createState() => _ShortlistPageState();
}

class _ShortlistPageState extends State<ShortlistPage> {
  final ProductController controller = Get.find<ProductController>();

  // 1. INJECT SHIPMENT CONTROLLER (For Real-time On Way Data)
  final ShipmentController shipmentCtrl = Get.put(ShipmentController());

  late TextEditingController _searchCtrl;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: controller.shortlistSearchText.value,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.shortlistSearchText.value.isEmpty) {
        controller.fetchShortList(page: 1);
      }
      // Note: We don't need controller.fetchOnWayStock() anymore
      // because shipmentCtrl handles it via Firestore stream.
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: ScrollConfiguration(
        behavior: ShortlistScrollBehavior(),
        child: Column(
          children: [
            _buildSummarySection(),
            _buildSearchBar(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    _buildTableHeader(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(child: _buildDataTableWithOverlay()),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Stock Alerts & Reordering",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
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
                color: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                borderColor: const Color(0xFFFED7AA),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: "Recommended Action",
                value: "Generate PO",
                icon: Icons.assignment_turned_in_outlined,
                color: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isText ? 18 : 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          controller.searchShortlist(val);
        },
        decoration: InputDecoration(
          hintText: "Search Shortlist by Model or Name...",
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
            onPressed: () {
              _searchCtrl.clear();
              controller.searchShortlist('');
            },
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

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
              color: Color(0xFF334155),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () {
              controller.fetchShortList(page: 1);
              // Refreshing shipment controller manually usually isn't needed due to streams,
              // but good to ensure connectivity.
            },
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

  Widget _buildDataTableWithOverlay() {
    return Obx(() {
      final isLoading = controller.isShortListLoading.value;
      final isEmpty = controller.shortListProducts.isEmpty;

      if (isLoading && isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!isLoading && isEmpty) {
        return _buildEmptyState();
      }

      return Stack(
        children: [
          Positioned.fill(child: _buildDataTableContent()),
          if (isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildDataTableContent() {
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
                          "On Way",
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
                      rows: List.generate(controller.shortListProducts.length, (
                        index,
                      ) {
                        final p = controller.shortListProducts[index];

                        // 2. USE SHIPMENT CONTROLLER FOR ON WAY QTY
                        final int onWay = shipmentCtrl.getOnWayQty(p.id);

                        final bool isCritical = p.stockQty == 0;
                        final int shortage = p.alertQty - p.stockQty;
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
                            // 3. UPDATED ON WAY CELL WITH TOOLTIP
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child:
                                    onWay > 0
                                        ? Tooltip(
                                          message: _getOnWayDetailsTooltip(
                                            p.id,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: Text(
                                              onWay.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        )
                                        : const Text(
                                          "-",
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600,
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
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 4. HELPER TO GENERATE TOOLTIP TEXT FROM AGGREGATED DATA
  String _getOnWayDetailsTooltip(int productId) {
    try {
      final productData = shipmentCtrl.aggregatedList.firstWhereOrNull(
        (element) => element.productId == productId,
      );

      if (productData == null || productData.incomingDetails.isEmpty) {
        return "Incoming";
      }

      return productData.incomingDetails
          .map((d) => "${d.shipmentName}: ${d.qty} pcs")
          .join("\n");
    } catch (e) {
      return "Incoming";
    }
  }

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
                color: Color(0xFF64748B),
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

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Obx(() {
        final int total = controller.shortlistTotal.value;
        final int current = controller.shortlistPage.value;
        final int size = controller.shortlistLimit.value;
        final int totalPages = size > 0 ? (total / size).ceil() : 0;
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
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: Color(0xFF16A34A),
            ),
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
            "No products match your search or require restocking.",
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
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    "Downloading Report...",
                    style: TextStyle(fontWeight: FontWeight.bold),
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
          "Success",
          "PDF Generated",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
          "Info",
          "No data to export",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Error",
        "$e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
