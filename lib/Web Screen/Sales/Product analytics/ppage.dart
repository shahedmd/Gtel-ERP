import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Product%20analytics/pcontroller.dart';
import 'package:intl/intl.dart';

class HotSellingProductPage extends StatelessWidget {
  const HotSellingProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HotSalesController());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light ERP Background
      appBar: AppBar(
        title: const Text(
          "Hot Selling Products",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () => controller.fetchSalesData(),
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- SECTION 1: FILTERS (Date, Month, Year) ---
            _buildFilterSection(context, controller),

            const SizedBox(height: 16),

            // --- SECTION 2: SEARCH ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => controller.search(val),
                      decoration: const InputDecoration(
                        hintText: "Search by Product Model or Name...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- SECTION 3: DATA TABLE ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      color: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 1,
                            child: Text(
                              "#",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              "MODEL",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              "PRODUCT NAME",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "SOLD QTY",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "REVENUE",
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "STOCK",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.grey),

                    // Table List
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          );
                        }

                        if (controller.displayList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "No products sold in this time range.",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: controller.displayList.length,
                          separatorBuilder:
                              (_, __) =>
                                  const Divider(height: 1, color: Colors.grey),
                          itemBuilder: (context, index) {
                            final item = controller.displayList[index];
                            final rank =
                                ((controller.currentPage.value - 1) *
                                    controller.itemsPerPage) +
                                index +
                                1;

                            return Container(
                              color:
                                  index % 2 == 0
                                      ? Colors.white
                                      : Colors.grey.shade50,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  // Rank
                                  Expanded(
                                    flex: 1,
                                    child: _buildRankBadge(rank),
                                  ),
                                  // Model
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.product.model,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Name
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      item.product.name,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  // Total Sold
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors
                                                  .black, // Black theme as requested
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          "${item.totalSold}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Revenue
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "৳${item.totalRevenue.toStringAsFixed(0)}",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  // Stock Left
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "${item.product.stockQty}",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            item.product.stockQty <
                                                    item.product.alertQty
                                                ? Colors.red
                                                : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- SECTION 4: PAGINATION FOOTER ---
            _buildPaginationFooter(controller),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: FILTERS ---
  Widget _buildFilterSection(
    BuildContext context,
    HotSalesController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter Time Range",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Filter Chips
              _filterChip(controller, "All", "All Time"),
              const SizedBox(width: 8),
              _filterChip(controller, "Daily", "Specific Date"),
              const SizedBox(width: 8),
              _filterChip(controller, "Monthly", "Specific Month"),
              const SizedBox(width: 8),
              _filterChip(controller, "Yearly", "Specific Year"),

              const Spacer(),

              // Date Selector Button
              Obx(() {
                if (controller.filterType.value == 'All') {
                  return const SizedBox();
                }

                String displayDate = "";
                if (controller.filterType.value == 'Daily') {
                  displayDate = DateFormat(
                    'dd MMM yyyy',
                  ).format(controller.selectedDate.value);
                } else if (controller.filterType.value == 'Monthly') {
                  displayDate = DateFormat(
                    'MMMM yyyy',
                  ).format(controller.selectedDate.value);
                } else if (controller.filterType.value == 'Yearly') {
                  displayDate = DateFormat(
                    'yyyy',
                  ).format(controller.selectedDate.value);
                }

                return InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: controller.selectedDate.value,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.black, // Header background color
                              onPrimary: Colors.white, // Header text color
                              onSurface: Colors.black, // Body text color
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      controller.updateDate(picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDate,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(HotSalesController controller, String type, String label) {
    return Obx(() {
      bool isSelected = controller.filterType.value == type;
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool value) {
          if (value) controller.setFilter(type);
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.black,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: isSelected ? Colors.black : Colors.grey.shade300,
          ),
        ),
      );
    });
  }

  // --- WIDGET HELPER: PAGINATION ---
  Widget _buildPaginationFooter(HotSalesController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() {
            if (controller.filteredList.isEmpty) return const Text("0 results");
            int start =
                (controller.currentPage.value - 1) * controller.itemsPerPage +
                1;
            int end =
                ((controller.currentPage.value - 1) * controller.itemsPerPage) +
                controller.displayList.length;
            return Text(
              "Showing $start - $end of ${controller.filteredList.length} products",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            );
          }),

          Row(
            children: [
              _paginationBtn(
                icon: Icons.chevron_left,
                onTap: controller.prevPage,
                isEnabled: controller.currentPage.value > 1,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Obx(
                  () => Text(
                    "Page ${controller.currentPage.value}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Obx(
                () => _paginationBtn(
                  icon: Icons.chevron_right,
                  onTap: controller.nextPage,
                  isEnabled:
                      controller.currentPage.value < controller.totalPages,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paginationBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled ? Colors.black : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isEnabled ? Colors.white : Colors.grey.shade100,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isEnabled ? Colors.black : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color = Colors.black;
    if (rank == 1) color = Colors.amber.shade700;
    if (rank == 2) color = Colors.grey.shade700;
    if (rank == 3) color = Colors.brown.shade700;

    if (rank <= 3) {
      return Icon(Icons.workspace_premium, color: color, size: 24);
    }
    return Text("$rank", style: const TextStyle(fontWeight: FontWeight.bold));
  }
}