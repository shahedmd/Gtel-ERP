// ignore_for_file: deprecated_member_use, empty_catches

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Shipment/controller.dart';

class TableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class OnGoingShipmentsPage extends StatefulWidget {
  const OnGoingShipmentsPage({super.key});

  @override
  State<OnGoingShipmentsPage> createState() => _OnGoingShipmentsPageState();
}

class _OnGoingShipmentsPageState extends State<OnGoingShipmentsPage> {
  final ShipmentController controller = Get.find<ShipmentController>();

  // Changed to GetX Rx variables!
  final RxInt currentPage = 1.obs;
  final int itemsPerPage = 15;
  final RxString searchQuery = ''.obs;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _nextPage(int totalPages) {
    if (currentPage.value < totalPages) currentPage.value++;
  }

  void _prevPage() {
    if (currentPage.value > 1) currentPage.value--;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      floatingActionButton: _buildProfessionalPDFButton(),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }

        if (controller.aggregatedList.isEmpty) {
          return _buildEmptyState();
        }
        // --- SEARCH FILTER LOGIC ---
        final filteredList =
            searchQuery.value.isEmpty
                ? controller.aggregatedList
                : controller.aggregatedList
                    .where(
                      (p) =>
                          p.model.toLowerCase().contains(
                            searchQuery.value.toLowerCase(),
                          ) ||
                          p.name.toLowerCase().contains(
                            searchQuery.value.toLowerCase(),
                          ),
                    )
                    .toList();

        // --- PAGINATION LOGIC ---
        final totalItems = filteredList.length;
        final totalPages = (totalItems / itemsPerPage).ceil();
        if (currentPage.value > totalPages && totalPages > 0) {
          currentPage.value = totalPages;
        }

        final startIndex = (currentPage.value - 1) * itemsPerPage;
        final endIndex =
            (startIndex + itemsPerPage > totalItems)
                ? totalItems
                : startIndex + itemsPerPage;

        // Prevent range errors if list is empty after search
        final paginatedList =
            filteredList.isEmpty
                ? []
                : filteredList.sublist(startIndex, endIndex);

        return Column(
          children: [
            _buildSearchBar(isMobile), // Added Search Bar
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 12 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    paginatedList.isEmpty
                        ? _buildNoSearchResults()
                        : isMobile
                        ? _buildMobileCardLayout(paginatedList)
                        : _buildDesktopOptimizedTable(paginatedList),
              ),
            ),
            _buildPaginationFooter(
              totalItems,
              startIndex,
              endIndex,
              totalPages,
              isMobile,
            ),
          ],
        );
      }),
    );
  }

  // ==========================================
  // APP BAR & SEARCH
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.inventory_rounded, color: Color(0xFF0F172A), size: 24),
          SizedBox(width: 10),
          Text(
            "Incoming Inventory",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        0,
      ),
      child: TextField(
        onChanged: (v) {
          searchQuery.value = v;
          currentPage.value = 1; // Always reset to page 1 when searching
        },
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search by model or product name...',
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalPDFButton() {
    return FloatingActionButton.extended(
      onPressed: () => controller.generateAggregatedOnWayPdf(),
      icon: const Icon(Icons.picture_as_pdf, size: 22, color: Colors.white),
      label: const Text(
        "Export PDF",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFFDC2626),
      elevation: 4,
    );
  }

  // ==========================================
  // MOBILE VIEW (CARDS)
  // ==========================================
  Widget _buildMobileCardLayout(List dynamicList) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: dynamicList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = dynamicList[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    _buildTotalQtyBadge(product.totalQty),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    const Text(
                      "SHIPMENT BREAKDOWN",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBreakdownList(product.incomingDetails),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // DESKTOP VIEW (FULL SCREEN WIDTH)
  // ==========================================
  Widget _buildDesktopOptimizedTable(List dynamicList) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // FULL SCREEN FIX: It takes the full screen width, but gracefully stops shrinking at 960px.
        final tableWidth =
            constraints.maxWidth > 960 ? constraints.maxWidth : 960.0;

        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Scrollbar(
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
                  child: SizedBox(
                    width: tableWidth, // Dynamic full width!
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TABLE HEADER
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          child: Row(
                            children: [
                              // Uses Expanded (Flex values) to stretch evenly across ANY screen size
                              Expanded(flex: 2, child: _headerText("MODEL")),
                              Expanded(
                                flex: 4,
                                child: _headerText("PRODUCT NAME"),
                              ),
                              Expanded(
                                flex: 2,
                                child: _headerText("TOTAL QTY"),
                              ),
                              Expanded(
                                flex: 4,
                                child: _headerText("SHIPMENT BREAKDOWN"),
                              ),
                            ],
                          ),
                        ),
                        // TABLE BODY
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dynamicList.length,
                          itemBuilder: (context, index) {
                            final product = dynamicList[index];
                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        product.model,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
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
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: _buildTotalQtyBadge(
                                        product.totalQty,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: _buildBreakdownList(
                                        product.incomingDetails,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
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

  Widget _headerText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    );
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================
  Widget _buildTotalQtyBadge(int qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        "$qty",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBreakdownList(List details) {
    if (details.isEmpty) {
      return const Text("-", style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          details.map<Widget>((detail) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail.shipmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 12,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Text(
                    DateFormat('MMM dd').format(detail.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 12,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Text(
                    "${detail.qty} pcs",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildPaginationFooter(
    int totalItems,
    int start,
    int end,
    int totalPages,
    bool isMobile,
  ) {
    if (totalItems == 0) {
      return const SizedBox.shrink(); // Hide footer if search is empty
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          if (!isMobile)
            Text(
              "Showing ${start + 1} to $end of $totalItems shipments",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: "Previous",
                onPressed: currentPage > 1 ? _prevPage : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  "Page ${currentPage.value} of $totalPages", // Added .value
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: "Next",
                onPressed:
                    currentPage.value < totalPages
                        ? () => _nextPage(totalPages)
                        : null,
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No shipments match "${searchQuery.value}"', // Added .value
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
