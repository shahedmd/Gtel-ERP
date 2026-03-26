// ignore_for_file: deprecated_member_use, empty_catches

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockdamange_servicepage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';

// ==========================================
// 1. ORDER CART STATE MANAGEMENT
// ==========================================
class OrderCartItem {
  final Product product;
  int qty;
  OrderCartItem({required this.product, required this.qty});
}

class OrderCartController extends GetxController {
  var cartItems = <OrderCartItem>[].obs;
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
    if (newQty <= 0) return;
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

  void clearCart() {
    cartItems.clear();
    companyName.value = '';
    deliveryMethod.value = 'Sea';
  }
}

// ==========================================
// 2. MAIN SHORTLIST UI PAGE
// ==========================================
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
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isMobile),
      body: ScrollConfiguration(
        behavior: ShortlistScrollBehavior(),
        child: Column(
          children: [
            _buildSummarySection(isMobile),
            _buildSearchBar(isMobile),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 20,
                  0,
                  isMobile ? 12 : 20,
                  20,
                ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableHeader(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(child: _buildDataLayout(isMobile)),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildPaginationFooter(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFF0F172A),
            size: isMobile ? 22 : 26,
          ),
          const SizedBox(width: 10),
          Text(
            "Stock Alerts",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              fontSize: isMobile ? 18 : 22,
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
        if (isMobile)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onSelected: (v) {
              if (v == 'export') _handleExport();
              if (v == 'cart') _showOrderCartDialog(context);
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.blue),
                      title: Text("Export PDF", style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'cart',
                    child: Obx(
                      () => ListTile(
                        leading: const Icon(
                          Icons.shopping_cart,
                          color: Colors.red,
                        ),
                        title: Text(
                          "Cart (${cartController.cartItems.length}, )",
                          style: TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _handleExport,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text("Export List"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 12),
          Obx(
            () => ElevatedButton.icon(
              onPressed: () => _showOrderCartDialog(context),
              icon: const Icon(Icons.shopping_cart, size: 18),
              label: Text("Cart (${cartController.cartItems.length})"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ],
    );
  }

  Widget _buildSummarySection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
      child: Obx(() {
        final total = controller.shortlistTotal.value;
        final cards = [
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
          SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
          Expanded(
            child: _buildStatCard(
              title: "Recommended Action",
              value: "Generate PO",
              icon: Icons.assignment_turned_in,
              color: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              borderColor: const Color(0xFFBFDBFE),
              isText: true,
            ),
          ),
        ];
        return isMobile
            ? Column(
              children: [
                Row(children: [cards[0]]),
                const SizedBox(height: 12),
                Row(children: [cards[2]]),
              ],
            )
            : Row(children: cards);
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isText ? 18 : 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 0,
      ).copyWith(bottom: 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => controller.searchShortlist(val),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Search short list by model or product name...",
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Low Stock Inventory",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => controller.fetchShortList(page: 1),
            tooltip: "Refresh",
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
  // RESPONSIVE DATA LAYOUT
  // ==========================================
  Widget _buildDataLayout(bool isMobile) {
    return Obx(() {
      if (controller.isShortListLoading.value &&
          controller.shortListProducts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.shortListProducts.isEmpty) {
        return _buildEmptyState();
      }

      return isMobile ? _buildMobileCards() : _buildDesktopTable();
    });
  }

  Widget _buildMobileCards() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: controller.shortListProducts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _MobileCard(
          product: controller.shortListProducts[index],
          shipmentCtrl: shipmentCtrl,
          cartController: cartController,
        );
      },
    );
  }

  // CENTERED DESKTOP TABLE FIX
  Widget _buildDesktopTable() {
    return LayoutBuilder(
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
                // WRAPPING IN CONSTRAINED BOX + CENTER TO FORCE CENTER ALIGNMENT ON WIDE SCREENS
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Center(
                    child: SizedBox(
                      width:
                          1050, // Fixed width locks the column spacing perfectly
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TABLE HEADER
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                _headerCell("STATUS", 100),
                                _headerCell("MODEL", 120),
                                _headerCell("PRODUCT NAME", 200),
                                _headerCell("PRICE (AIR/SEA)", 120),
                                _headerCell("STOCK", 80),
                                _headerCell("ON WAY", 80),
                                _headerCell("ALERT", 80),
                                _headerCell("ORDER QTY", 90),
                                _headerCell("ACTION", 80),
                              ],
                            ),
                          ),
                          // TABLE ROWS (Memory safe, isolated states)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.shortListProducts.length,
                            itemBuilder: (context, index) {
                              return _DesktopRow(
                                product: controller.shortListProducts[index],
                                shipmentCtrl: shipmentCtrl,
                                cartController: cartController,
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
          ),
        );
      },
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      child: Obx(() {
        final total = controller.shortlistTotal.value;
        final current = controller.shortlistPage.value;
        final size = controller.shortlistLimit.value;
        final totalPages = size > 0 ? (total / size).ceil() : 0;
        final start = total == 0 ? 0 : ((current - 1) * size) + 1;
        final end = (current * size) > total ? total : (current * size);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile)
              Text(
                "Showing $start - $end of $total alerts",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      current > 1 ? () => controller.prevShortlistPage() : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      current < totalPages
                          ? () => controller.nextShortlistPage()
                          : null,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Color(0xFF10B981),
            ),
            SizedBox(height: 16),
            Text(
              "Healthy Inventory!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "No products require restocking at this moment.",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. ORDER CART DIALOG (WITH EDITABLE QTY)
  // ==========================================
  void _showOrderCartDialog(BuildContext context) {
    cartController.companyName.value = '';
    cartController.deliveryMethod.value = 'Sea';
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 650,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_cart, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Text(
                        "Purchase Order Cart",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(thickness: 1, height: 20),

              Expanded(
                child: Obx(() {
                  if (cartController.cartItems.isEmpty) {
                    return const Center(
                      child: Text(
                        "Your cart is empty.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: cartController.cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _CartItemRow(
                        item: cartController.cartItems[index],
                        cartController: cartController,
                      );
                    },
                  );
                }),
              ),

              const Divider(thickness: 1, height: 24),
              if (isMobile) ...[
                _buildCartFormInput(
                  "Company / Supplier Name",
                  (v) => cartController.companyName.value = v,
                ),
                const SizedBox(height: 12),
                _buildCartDropdown(),
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildCartFormInput(
                        "Company / Supplier Name",
                        (v) => cartController.companyName.value = v,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildCartDropdown()),
                  ],
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      "Generate PO & Save",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed:
                        cartController.cartItems.isEmpty
                            ? null
                            : () => _generateOrderAndSave(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartFormInput(String label, Function(String) onChanged) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildCartDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: cartController.deliveryMethod.value,
        decoration: const InputDecoration(
          labelText: "Delivery Via",
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        items:
            [
              'Sea',
              'Air',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) {
          if (val != null) cartController.deliveryMethod.value = val;
        },
      ),
    );
  }

  Future<void> _generateOrderAndSave() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      String compName = cartController.companyName.value.trim();
      if (compName.isEmpty) compName = 'N/A';
      String dlvryMethod = cartController.deliveryMethod.value;

      await FirebaseFirestore.instance.collection('order_history').add({
        'date': FieldValue.serverTimestamp(),
        'company_name': compName,
        'delivery_method': dlvryMethod,
        'status': 'Pending',
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

      await OrderPdfGenerator.generateOrderCartPdf(
        cartController.cartItems.toList(),
        compName,
        dlvryMethod,
      );
      cartController.clearCart();
      Get.back(); // close loading
      Get.back(); // close cart
      Get.snackbar(
        "Success",
        "Purchase Order generated and saved successfully!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        "Error",
        "Failed to process order: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleExport() async {
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Generating..."),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      List<Product> allData = await controller.fetchAllShortListForExport();
      String query = _searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        allData =
            allData
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.model.toLowerCase().contains(query),
                )
                .toList();
      }

      if (allData.isNotEmpty) {
        await PdfService.generateShortlistPdf(allData);
        Get.back();
        Get.snackbar(
          "Success",
          "PDF Generated",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.back();
        Get.snackbar(
          "Info",
          "No data to export",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        "Error",
        "$e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// ==========================================
// CART ITEM WIDGET (EDITABLE TEXTFIELD)
// ==========================================
class _CartItemRow extends StatefulWidget {
  final OrderCartItem item;
  final OrderCartController cartController;

  const _CartItemRow({required this.item, required this.cartController});

  @override
  State<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<_CartItemRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If external state updates qty (like clearCart or +/- buttons), update the field
    if (widget.item.qty.toString() != _qtyCtrl.text) {
      _qtyCtrl.text = widget.item.qty.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _updateQty(int newQty) {
    if (newQty > 0) {
      widget.cartController.updateQty(widget.item.product, newQty);
      _qtyCtrl.text = newQty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.product.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.item.product.name,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _updateQty(widget.item.qty - 1),
              ),
              SizedBox(
                width: 60,
                height: 35,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    int q = int.tryParse(val) ?? 0;
                    if (q > 0) {
                      widget.cartController.updateQty(widget.item.product, q);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _updateQty(widget.item.qty + 1),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed:
                    () => widget.cartController.removeFromCart(
                      widget.item.product,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. MEMORY SAFE ROWS & CARDS
// ==========================================

/// DESKTOP ROW
class _DesktopRow extends StatefulWidget {
  final Product product;
  final ShipmentController shipmentCtrl;
  final OrderCartController cartController;

  const _DesktopRow({
    required this.product,
    required this.shipmentCtrl,
    required this.cartController,
  });

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  late TextEditingController qtyCtrl;

  @override
  void initState() {
    super.initState();
    qtyCtrl = TextEditingController(text: "1");
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final int onWay = widget.shipmentCtrl.getOnWayQty(p.id);
    final bool isCritical = p.stockQty <= 0;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(isCritical),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              p.model,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flight_takeoff,
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "৳${p.air.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_boat,
                      size: 12,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "৳${p.sea.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(
            width: 80,
            child: Text(
              "${p.stockQty}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCritical ? Colors.red : Colors.black,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child:
                onWay > 0
                    ? _badge(onWay.toString(), Colors.blue)
                    : const Text("-"),
          ),
          SizedBox(width: 80, child: Text("${p.alertQty}")),

          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 70,
                height: 35,
                child: TextField(
                  controller: qtyCtrl,
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

          SizedBox(
            width: 80,
            child: IconButton(
              icon: const Icon(
                Icons.add_shopping_cart,
                color: Color(0xFF2563EB),
              ),
              onPressed: () {
                int qty = int.tryParse(qtyCtrl.text) ?? 0;
                if (qty > 0) {
                  widget.cartController.addToCart(p, qty);
                  Get.snackbar(
                    "Added",
                    "${p.model} added to PO.",
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                  qtyCtrl.text = "1";
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isCritical) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCritical ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Text(
        isCritical ? "CRITICAL" : "LOW",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isCritical ? Colors.red : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _badge(String text, MaterialColor color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.shade50,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.shade200),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color.shade800,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

/// MOBILE CARD
class _MobileCard extends StatefulWidget {
  final Product product;
  final ShipmentController shipmentCtrl;
  final OrderCartController cartController;

  const _MobileCard({
    required this.product,
    required this.shipmentCtrl,
    required this.cartController,
  });

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  late TextEditingController qtyCtrl;

  @override
  void initState() {
    super.initState();
    qtyCtrl = TextEditingController(text: "1");
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bool isCritical = p.stockQty <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isCritical ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCritical ? "CRITICAL" : "LOW",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCritical ? Colors.red : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Current Stock",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          "${p.stockQty}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Air: ৳${p.air.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          "Sea: ৳${p.sea.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Order Qty",
                          labelStyle: TextStyle(fontSize: 10),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text("Add"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                      onPressed: () {
                        int qty = int.tryParse(qtyCtrl.text) ?? 0;
                        if (qty > 0) {
                          widget.cartController.addToCart(p, qty);
                          Get.snackbar(
                            "Added",
                            "Added to PO",
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                          qtyCtrl.text = "1";
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. ENTERPRISE PDF GENERATOR
// ==========================================
class OrderPdfGenerator {
  static Future<void> generateOrderCartPdf(
    List<OrderCartItem> items,
    String company,
    String delivery,
  ) async {
    final pdf = pw.Document();

    double grandTotal = 0;
    for (var item in items) {
      double price =
          delivery.toLowerCase() == 'air' ? item.product.air : item.product.sea;
      grandTotal += (price * item.qty);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "PURCHASE ORDER",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  "Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
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
                        "Supplier: $company",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Delivery Method: $delivery",
                        style: const pw.TextStyle(
                          color: PdfColors.grey800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Status: PENDING",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              headers: [
                'No.',
                'Model',
                'Product Name',
                'Unit Price ($delivery)',
                'Order Qty',
                'Total Price',
              ],
              data: List<List<String>>.generate(items.length, (index) {
                final item = items[index];
                double unitPrice =
                    delivery.toLowerCase() == 'air'
                        ? item.product.air
                        : item.product.sea;
                double totalLine = unitPrice * item.qty;
                return [
                  (index + 1).toString(),
                  item.product.model,
                  item.product.name,
                  "¥${unitPrice.toStringAsFixed(2)}",
                  item.qty.toString(),
                  "¥${totalLine.toStringAsFixed(2)}",
                ];
              }),
            ),
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Total Items: ${items.length}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Grand Total: ¥${grandTotal.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Prepared By",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Authorized Signature",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'Purchase_Order_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }
}
