// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Adjust imports to match your project structure
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:gtel_erp/Stock/Service/servicepage.dart';

// --- Order Cart Model and Controller --- //
class OrderCartItem {
  final Product product;
  int qty;

  OrderCartItem({required this.product, required this.qty});
}

class OrderCartController extends GetxController {
  var cartItems = <OrderCartItem>[].obs;

  // NEW: Added variables for Company Name and Delivery Method
  var companyName = ''.obs;
  var deliveryMethod = 'Sea'.obs;

  void addToCart(Product product, int qty) {
    var existing = cartItems.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existing != null) {
      existing.qty += qty;
      cartItems.refresh();
    } else {
      cartItems.add(OrderCartItem(product: product, qty: qty));
    }
  }

  void updateQty(Product product, int newQty) {
    if (newQty <= 0) return; // prevent zero or negative qty
    var existing = cartItems.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existing != null) {
      existing.qty = newQty;
      cartItems.refresh();
    }
  }

  void removeFromCart(Product product) {
    cartItems.removeWhere((item) => item.product.id == product.id);
  }

  // Clear cart entirely after successfully generating PO
  void clearCart() {
    cartItems.clear();
    companyName.value = '';
    deliveryMethod.value = 'Sea';
  }
}

// --- Scroll Behavior --- //
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
  final ShipmentController shipmentCtrl = Get.put(ShipmentController());
  final OrderCartController cartController = Get.put(OrderCartController());

  late TextEditingController _searchCtrl;
  final ScrollController _horizontalScrollController = ScrollController();

  // Keep track of Qty TextFields for each row
  final Map<int, TextEditingController> _qtyControllers = {};

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
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollController.dispose();
    for (var ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _getQtyController(int productId) {
    if (!_qtyControllers.containsKey(productId)) {
      _qtyControllers[productId] = TextEditingController(text: "1");
    }
    return _qtyControllers[productId]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: ScrollConfiguration(
        behavior: ShortlistScrollBehavior(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSummarySection(),
              _buildSearchBar(),
              Container(
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
                    _buildPaginationFooter(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildDataTableWithOverlay(),
                  ],
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.only(right: 8.0),
          child: ElevatedButton.icon(
            onPressed: () => _handleExport(),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text("Export List"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Obx(
            () => ElevatedButton.icon(
              onPressed: () => _showOrderCartDialog(),
              icon: const Icon(Icons.shopping_cart, size: 18),
              label: Text("Cart (${cartController.cartItems.length})"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
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

  Widget _buildDataTableWithOverlay() {
    return Obx(() {
      final isLoading = controller.isShortListLoading.value;
      final isEmpty = controller.shortListProducts.isEmpty;

      if (isLoading && isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (!isLoading && isEmpty) {
        return _buildEmptyState();
      }

      return Column(
        children: [
          if (isLoading)
            LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          _buildDataTableContent(),
        ],
      );
    });
  }

  Widget _buildDataTableContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
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
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
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
                    _col("Order Qty", align: MainAxisAlignment.center),
                    _col("Action", align: MainAxisAlignment.center),
                  ],
                  rows: List.generate(controller.shortListProducts.length, (
                    index,
                  ) {
                    final p = controller.shortListProducts[index];
                    final int onWay = shipmentCtrl.getOnWayQty(p.id);
                    final bool isCritical = p.stockQty == 0;
                    final color =
                        index.isEven ? Colors.white : const Color(0xFFF8FAFC);

                    return DataRow(
                      color: WidgetStateProperty.all(color),
                      cells: [
                        DataCell(Center(child: _buildStatusBadge(isCritical))),
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
                            constraints: const BoxConstraints(maxWidth: 250),
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF475569)),
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
                            child:
                                onWay > 0
                                    ? Tooltip(
                                      message: _getOnWayDetailsTooltip(p.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                          Center(
                            child: SizedBox(
                              width: 70,
                              height: 35,
                              child: TextField(
                                controller: _getQtyController(p.id),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: Color(0xFF2563EB),
                              ),
                              tooltip: "Add to Order",
                              onPressed: () {
                                String textValue = _getQtyController(p.id).text;
                                int qty = int.tryParse(textValue) ?? 0;
                                if (qty > 0) {
                                  cartController.addToCart(p, qty);
                                  Get.snackbar(
                                    "Added to Cart",
                                    "${p.name} ($qty pcs) added to your order list.",
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.green.shade600,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                  );
                                  _getQtyController(p.id).text = "1";
                                } else {
                                  Get.snackbar(
                                    "Invalid Quantity",
                                    "Please enter a valid quantity.",
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                }
                              },
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
        );
      },
    );
  }

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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
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
      // Get all paginated data from the controller first
      List<Product> allData = await controller.fetchAllShortListForExport();

      // NEW: Filter the export dataset based on the current search query
      String searchQuery = _searchCtrl.text.trim().toLowerCase();
      if (searchQuery.isNotEmpty) {
        allData =
            allData.where((p) {
              return p.name.toLowerCase().contains(searchQuery) ||
                  p.model.toLowerCase().contains(searchQuery);
            }).toList();
      }

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
          "No data to export for your search",
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

  // --- Order Cart Dialog (View/Edit/Delete) --- //
  void _showOrderCartDialog() {
    // Reset fields when opening cart
    cartController.companyName.value = '';
    cartController.deliveryMethod.value = 'Sea';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Order List",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              Expanded(
                child: Obx(() {
                  if (cartController.cartItems.isEmpty) {
                    return const Center(
                      child: Text(
                        "Your order cart is empty.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: cartController.cartItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = cartController.cartItems[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.product.model,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item.product.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.blueGrey,
                              ),
                              onPressed:
                                  () => cartController.updateQty(
                                    item.product,
                                    item.qty - 1,
                                  ),
                            ),
                            Text(
                              "${item.qty}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blueGrey,
                              ),
                              onPressed:
                                  () => cartController.updateQty(
                                    item.product,
                                    item.qty + 1,
                                  ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed:
                                  () => cartController.removeFromCart(
                                    item.product,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),

              // NEW: Company Name & Delivery Method Input fields
              const Divider(thickness: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged:
                          (val) => cartController.companyName.value = val,
                      decoration: const InputDecoration(
                        labelText: "Company Name",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Obx(
                      () => DropdownButtonFormField<String>(
                        value: cartController.deliveryMethod.value,
                        decoration: const InputDecoration(
                          labelText: "Delivery Via",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            ['Sea', 'Air']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            cartController.deliveryMethod.value = val;
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        cartController.cartItems.isEmpty
                            ? null
                            : () => _generateOrderAndSave(),
                    child: const Text(
                      "Generate PDF & Save Order",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Save Order History to Firebase & PDF Download --- //
  Future<void> _generateOrderAndSave() async {
    if (cartController.cartItems.isEmpty) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      String compName = cartController.companyName.value.trim();
      if (compName.isEmpty) compName = 'N/A';
      String dlvryMethod = cartController.deliveryMethod.value;

      // 1. Save to Firebase with new required fields
      await FirebaseFirestore.instance.collection('order_history').add({
        'date': FieldValue.serverTimestamp(),
        'company_name': compName,
        'delivery_method': dlvryMethod,
        'status': 'Pending', // Setting default status
        'total_items': cartController.cartItems.length,
        'items':
            cartController.cartItems
                .map(
                  (e) => {
                    'product_id': e.product.id,
                    'model': e.product.model,
                    'name': e.product.name,
                    'order_qty': e.qty,
                  },
                )
                .toList(),
      });

      // 2. Generate and Download PDF Report including the new fields
      await OrderPdfGenerator.generateOrderCartPdf(
        cartController.cartItems.toList(),
        compName,
        dlvryMethod,
      );

      // 3. Clear cart entirely upon success
      cartController.clearCart();

      Get.back(); // close progress dialog
      Get.back(); // close cart dialog
      Get.snackbar(
        "Success",
        "Order history saved and PDF generated successfully!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back(); // close progress dialog
      Get.snackbar(
        "Error",
        "Failed to process order: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// --- Professional Order PDF Generator --- //
class OrderPdfGenerator {
  static Future<void> generateOrderCartPdf(
    List<OrderCartItem> items,
    String company,
    String delivery,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "PURCHASE ORDER LIST",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    "Date: ${DateTime.now().toString().split(' ')[0]}",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Company, Delivery Method, and Status display block
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Company Name: $company",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "Delivery Via: $delivery",
                        style: const pw.TextStyle(color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Status: Pending",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              "Authorized Generated Report",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            // Re-ordered Columns: No. -> Product Name -> Model -> Order Quantity
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue100,
              ),
              headerHeight: 40,
              cellHeight: 30,
              headerStyle: pw.TextStyle(
                color: PdfColors.black,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: ['No.', 'Product Name', 'Model', 'Order Quantity'],
              data: List<List<String>>.generate(
                items.length,
                (index) => [
                  (index + 1).toString(),
                  items[index].product.name, // Moved up to second column
                  items[index].product.model, // Moved down to third column
                  items[index].qty.toString(),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total Ordered Models: ${items.length}",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Purchase_Order_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}