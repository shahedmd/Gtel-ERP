// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';

import 'package:intl/intl.dart';

// Enables drag scrolling for web/desktop if needed
class TableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class OnGoingShipmentsPage extends StatelessWidget {
  OnGoingShipmentsPage({super.key});

  final ShipmentController controller = Get.find<ShipmentController>();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      // Floating Action Button for PDF
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller.generateAggregatedOnWayPdf(),
        icon: const Icon(Icons.picture_as_pdf, size: 20),
        label: const Text("Download Report"),
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      appBar: AppBar(
        title: const Text(
          "Incoming Inventory",
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
      ),

      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.aggregatedList.isEmpty) {
          return _buildEmptyState();
        }

        // --- MAIN TABLE LAYOUT ---
        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
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
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: const Color(0xFFE2E8F0),
                              dataTableTheme: DataTableThemeData(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8FAFC),
                                ),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            child: DataTable(
                              headingRowHeight: 50,
                              dataRowMinHeight:
                                  60, // Taller rows for multiline content
                              dataRowMaxHeight:
                                  double.infinity, // Allow row to grow
                              horizontalMargin: 24,
                              columnSpacing: 30,
                              showBottomBorder: true,
                              columns: const [
                                DataColumn(label: Text("MODEL")),
                                DataColumn(label: Text("PRODUCT NAME")),
                                DataColumn(
                                  label: Text("TOTAL QTY"),
                                  numeric: true,
                                ),
                                DataColumn(label: Text("SHIPMENT BREAKDOWN")),
                              ],
                              rows:
                                  controller.aggregatedList.map((product) {
                                    return DataRow(
                                      cells: [
                                        // 1. Model
                                        DataCell(
                                          Text(
                                            product.model,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),

                                        // 2. Name
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 200,
                                            ),
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                color: Color(0xFF475569),
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),

                                        // 3. Total Qty (Highlighted)
                                        DataCell(
                                          Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFEFF6FF,
                                                ), // Blue 50
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFBFDBFE,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                "${product.totalQty}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(
                                                    0xFF2563EB,
                                                  ), // Blue 600
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 4. Breakdown List
                                        DataCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children:
                                                  product.incomingDetails.map((
                                                    detail,
                                                  ) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 4,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .subdirectory_arrow_right,
                                                            size: 14,
                                                            color: Color(
                                                              0xFF94A3B8,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),

                                                          // Shipment Name
                                                          Text(
                                                            detail.shipmentName,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF334155,
                                                                  ),
                                                                ),
                                                          ),

                                                          // Divider
                                                          Container(
                                                            margin:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                ),
                                                            height: 10,
                                                            width: 1,
                                                            color:
                                                                Colors
                                                                    .grey[300],
                                                          ),

                                                          // Date
                                                          Text(
                                                            DateFormat(
                                                              'MMM dd',
                                                            ).format(
                                                              detail.date,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFF64748B,
                                                                  ),
                                                                ),
                                                          ),

                                                          // Divider
                                                          Container(
                                                            margin:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                ),
                                                            height: 10,
                                                            width: 1,
                                                            color:
                                                                Colors
                                                                    .grey[300],
                                                          ),

                                                          // Qty
                                                          Text(
                                                            "${detail.qty} pcs",
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF16A34A,
                                                                  ), // Green 600
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Active Shipments",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "All incoming inventory has been received.",
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
