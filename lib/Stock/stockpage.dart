// ignore_for_file: deprecated_member_use

import 'dart:ui'; // Required for PointerDeviceKind
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Added for Date Formatting
import 'package:gtel_erp/Stock/shortlist.dart'; // Ensure path is correct
import 'Service/servicepage.dart'; // Ensure path is correct
import 'controller.dart';
import 'edit.dart'; // Ensure path is correct
import 'model.dart';

// THIS CLASS ENABLES MOUSE DRAGGING FOR HORIZONTAL SCROLL
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class ProductScreen extends StatelessWidget {
  ProductScreen({super.key});

  final ProductController controller = Get.put(ProductController());
  final TextEditingController currencyInput = TextEditingController();

  // Explicit ScrollControllers for the table
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F4F6,
      ), // Modern Light Grey ERP Background
      appBar: _buildAppBar(),
      body: ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: Column(
          children: [
            // 1. TOP STATS DASHBOARD
            _buildStatsSection(context),

            // 2. MAIN CONTENT AREA (Search + Table)
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. CONTROL TOOLBAR (Search, Filter, Export)
                    _buildControlToolbar(),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),

                    // B. DATA TABLE
                    Expanded(child: _buildDataTable()),

                    // C. PAGINATION FOOTER
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    _buildPaginationFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProductDialog(controller),
        backgroundColor: const Color(0xFF2563EB), // Royal Blue
        elevation: 4,
        label: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),

        heroTag:
            FloatingActionButtonLocation.centerFloat, // Change location here
      ),
    );
  }

  // ==========================================
  // 1. APP BAR
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: Color(0xFF1E293B)),
          SizedBox(width: 10),
          Text(
            'Inventory Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B), // Slate 800
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: [
        // Service Center Button
        TextButton.icon(
          onPressed: () => Get.to(() => ServicePage()),
          style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
          icon: const Icon(Icons.handyman_outlined, size: 20),
          label: const Text("Service Center"),
        ),
        const SizedBox(width: 8),
        // Low Stock Button
        TextButton.icon(
          onPressed: () => Get.to(() => ShortlistPage()),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFFEF2F2),
            foregroundColor: const Color(0xFFDC2626),
          ),
          icon: const Icon(Icons.warning_amber_rounded, size: 20),
          label: const Text("Low Stock Alerts"),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
          tooltip: "Refresh Data",
          onPressed: () => controller.fetchProducts(),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // ==========================================
  // 2. STATS DASHBOARD
  // ==========================================
  Widget _buildStatsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // TOTAL VALUE CARD
          Expanded(
            flex: 2,
            child: _buildStatCard(
              title: "Total Warehouse Value",
              content: Obx(
                () => Text(
                  "৳ ${controller.formattedTotalValuation}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              icon: Icons.monetization_on,
              color: Colors.blue.shade50,
              iconColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),

          // CURRENCY CARD
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.currency_exchange,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Exchange Rate (CNY to BDT)",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Obx(
                        () => Text(
                          "1 ¥ = ${controller.currentCurrency.value.toStringAsFixed(2)} ৳",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Currency Edit
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: currencyInput,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'New Rate',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _handleCurrencyUpdate(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Update"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Widget content,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
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
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. TOOLBAR (Search, Filter)
  // ==========================================
  Widget _buildControlToolbar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: (v) => controller.search(v),
              decoration: InputDecoration(
                hintText: 'Search by model, name or brand...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Brand Filter
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Obx(
                () => DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.selectedBrand.value,
                    icon: const Icon(Icons.filter_list, color: Colors.grey),
                    isExpanded: true,
                    items:
                        controller.brands
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) controller.selectBrand(v);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. DATA TABLE (Professional Grid)
  // ==========================================
  Widget _buildDataTable() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.allProducts.isEmpty) {
        return _buildEmptyState();
      }

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
                thickness: 10,
                radius: const Radius.circular(5),
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: const Color(0xFFE2E8F0)),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF1F5F9),
                        ),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        dividerThickness: 1,
                        columns: _getColumns(),
                        rows: _getRows(context),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ------------------------------------
  // COLUMNS DEFINITION
  // ------------------------------------
  List<DataColumn> _getColumns() {
    // Helper for Styled Header Text
    DataColumn col(String name, {bool isNumeric = false}) {
      return DataColumn(
        numeric: isNumeric,
        label: Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Color(0xFF64748B), // Slate 500
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return [
      col('Name'),
      col('Model'),
      col('Brand'),
      col('Status'), // New Status Column
      col('Stock', isNumeric: true),
      col('Sea Qty', isNumeric: true),
      col('Air Qty', isNumeric: true),
      col('Avg Cost', isNumeric: true),
      col('Ship Date'),
      col('Agent', isNumeric: true),
      col('Wholesale', isNumeric: true),
      col('Actions'),
    ];
  }

  // ------------------------------------
  // ROWS DEFINITION
  // ------------------------------------
  List<DataRow> _getRows(BuildContext context) {
    return controller.allProducts.map((p) {
      return DataRow(
        cells: [
            DataCell(
            Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          // 1. Model
          DataCell(
            Text(
              p.model,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          // 2. Brand
          DataCell(Text(p.brand)),
          // 3. Status Badge
          DataCell(_buildStockBadge(p.stockQty, p.alertQty)),
          // 4. Total Stock
          DataCell(
            Text(
              p.stockQty.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // 5. Sea
          DataCell(Text(p.seaStockQty.toString())),
          // 6. Air
          DataCell(Text(p.airStockQty.toString())),
          // 7. Avg Cost (Green)
          DataCell(
            Text(
              p.avgPurchasePrice.toStringAsFixed(2),
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 8. Date
          DataCell(
            Text(
              p.shipmentDate != null
                  ? DateFormat('dd MMM yyyy').format(p.shipmentDate!)
                  : '-',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // 9. Yuan
          DataCell(Text(p.agent.toStringAsFixed(2))),
          // 10. Weight
          DataCell(Text(p.wholesale.toStringAsFixed(2))),
          // 11. Actions
          DataCell(_buildActions(context, p)),
        ],
      );
    }).toList();
  }

  Widget _buildStockBadge(int stock, int alert) {
    bool isLow = stock <= alert;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLow ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
        ),
      ),
      child: Text(
        isLow ? 'LOW' : 'OK',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, Product p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionBtn(
          icon: Icons.add_shopping_cart,
          color: Colors.teal,
          tooltip: 'Add Stock',
          onTap: () => _showAddStockDialog(p, controller),
        ),
        const SizedBox(width: 4),
        _actionBtn(
          icon: Icons.edit_outlined,
          color: Colors.blue,
          tooltip: 'Edit',
          onTap: () => showEditProductDialog(p, controller),
        ),
        const SizedBox(width: 4),
        // More Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
          onSelected: (val) {
            if (val == 'service') {
              _showQuantityDialog(
                context,
                "Service",
                p,
                (qty) => _handleService(p, qty, 'service'),
              );
            } else if (val == 'damage') {
              _showQuantityDialog(
                context,
                "Damage",
                p,
                (qty) => _handleService(p, qty, 'damage'),
              );
            } else if (val == 'delete') {
              showDeleteConfirmDialog(p.id, controller);
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'service',
                  child: Row(
                    children: [
                      Icon(Icons.handyman, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Send to Service'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'damage',
                  child: Row(
                    children: [
                      Icon(Icons.broken_image, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Mark as Damage'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Delete Product'),
                    ],
                  ),
                ),
              ],
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(4),
      onPressed: onTap,
    );
  }

  // ==========================================
  // 5. PAGINATION FOOTER
  // ==========================================
  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Obx(() {
        final int total = controller.totalProducts.value;
        final int current = controller.currentPage.value;
        final int size = controller.pageSize.value;
        final int totalPages = (total / size).ceil();
        final int start = ((current - 1) * size) + 1;
        final int end = (current * size) > total ? total : (current * size);

        // Safe display if total is 0
        if (total == 0) return const SizedBox();

        return Row(
          children: [
            Text(
              "Showing $start to $end of $total results",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.black,),
                  onPressed:
                      current > 1 ? () => controller.previousPage() : null,
                  tooltip: "Previous Page",
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
                    "Page $current",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.black,),
                  onPressed:
                      current < totalPages ? () => controller.nextPage() : null,
                  tooltip: "Next Page",
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  // ==========================================
  // HELPER FUNCTIONS & DIALOGS
  // ==========================================

  void _handleCurrencyUpdate() {
    final val = double.tryParse(currencyInput.text);
    if (val != null && val > 0) {
      Get.defaultDialog(
        title: 'Confirm Revaluation',
        middleText:
            'Update Rate to ${val.toStringAsFixed(2)}? This affects inventory value.',
        textConfirm: 'Update',
        confirmTextColor: Colors.white,
        buttonColor: const Color(0xFF0F172A),
        onConfirm: () {
          controller.updateCurrencyAndRecalculate(val);
          currencyInput.clear();
          Get.back();
        },
      );
    } else {
      Get.snackbar('Error', 'Invalid Rate');
    }
  }

  void _handleService(Product p, int qty, String type) {
    controller.addToService(
      productId: p.id,
      model: p.model,
      qty: qty,
      type: type,
      currentAvgPrice: p.avgPurchasePrice,
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    String actionType,
    Product p,
    Function(int) onConfirm,
  ) {
    final qtyController = TextEditingController();
    Get.defaultDialog(
      title: "$actionType Item",
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        children: [
          Text(
            "${p.model} (Stock: ${p.stockQty})",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Quantity",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      textConfirm: "Confirm",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: actionType == "Damage" ? Colors.red : Colors.orange,
      onConfirm: () {
        int qty = int.tryParse(qtyController.text) ?? 0;
        if (qty > 0 && qty <= p.stockQty) {
          onConfirm(qty);
          Get.back();
        } else {
          Get.snackbar("Error", "Invalid Quantity");
        }
      },
    );
  }

  void _showAddStockDialog(Product p, ProductController controller) {
    final seaQtyC = TextEditingController(text: '0');
    final airQtyC = TextEditingController(text: '0');
    final localQtyC = TextEditingController(text: '0');
    final localPriceC = TextEditingController(text: '0');

    final RxDouble predictedAvg = p.avgPurchasePrice.obs;

    void calculatePrediction() {
      int s = int.tryParse(seaQtyC.text) ?? 0;
      int a = int.tryParse(airQtyC.text) ?? 0;
      int l = int.tryParse(localQtyC.text) ?? 0;
      double lp = double.tryParse(localPriceC.text) ?? 0.0;
      predictedAvg.value = controller.predictNewWAC(p, s, a, l, lp);
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Receive Stock: ${p.model}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Obx(
                        () => Text(
                          "New Avg Cost: ${predictedAvg.value.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _inputField(
                  "Sea Qty",
                  seaQtyC,
                  Icons.waves,
                  calculatePrediction,
                ),
                const SizedBox(height: 10),
                _inputField(
                  "Air Qty",
                  airQtyC,
                  Icons.airplanemode_active,
                  calculatePrediction,
                ),
                const Divider(height: 30),
                const Text(
                  "Local Purchase",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        "Qty",
                        localQtyC,
                        Icons.inventory,
                        calculatePrediction,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        "Unit Price (BDT)",
                        localPriceC,
                        Icons.price_change,
                        calculatePrediction,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              controller.addMixedStock(
                productId: p.id,
                seaQty: int.tryParse(seaQtyC.text) ?? 0,
                airQty: int.tryParse(airQtyC.text) ?? 0,
                localQty: int.tryParse(localQtyC.text) ?? 0,
                localUnitPrice: double.tryParse(localPriceC.text) ?? 0.0,
              );
              Get.back();
            },
            child: const Text(
              'Confirm Receive',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    Function() onChange,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChange(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
