// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Shipment/controller.dart';
import '../../Stock/allshipmentlist.dart';
import '../../Stock/shortlist.dart';
import '../../Stock/Service/servicepage.dart';
import 'stockcontroller.dart';
import '../../Stock/edit.dart';
import '../../Stock/model.dart';

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
  final ShipmentController shipmentController = Get.put(ShipmentController());

  final TextEditingController currencyInput = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isMobile),
      body: ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: Column(
          children: [
            _buildStatsSection(context, isMobile),
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
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildControlToolbar(isMobile),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Expanded(child: _buildOptimizedTable(isMobile)),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    _buildPaginationFooter(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  // ==========================================
  // APP BAR
  // ==========================================
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFF1E293B),
            size: isMobile ? 22 : 26,
          ),
          const SizedBox(width: 10),
          Text(
            'Inventory',
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
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
            icon: const Icon(Icons.more_vert, color: Color(0xFF1E293B)),
            onSelected: (value) {
              if (value == 'shipments') Get.to(() => OnGoingShipmentsPage());
              if (value == 'service') Get.to(() => ServicePage());
              if (value == 'alerts') Get.to(() => ShortlistPage());
              if (value == 'refresh') controller.fetchProducts();
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'shipments',
                    child: ListTile(
                      leading: Icon(Icons.local_shipping, color: Colors.orange),
                      title: Text("Shipments"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'service',
                    child: ListTile(
                      leading: Icon(Icons.handyman, color: Colors.orange),
                      title: Text("Service Center"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'alerts',
                    child: ListTile(
                      leading: Icon(Icons.warning_amber, color: Colors.red),
                      title: Text("Low Stock"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh, color: Colors.blue),
                      title: Text("Refresh Data"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          )
        else ...[
          TextButton.icon(
            onPressed: () => Get.to(() => OnGoingShipmentsPage()),
            style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
            icon: const Icon(Icons.local_shipping, size: 20),
            label: const Text("Shipments"),
          ),
          TextButton.icon(
            onPressed: () => Get.to(() => ServicePage()),
            style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
            icon: const Icon(Icons.handyman_outlined, size: 20),
            label: const Text("Service Center"),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => Get.to(() => ShortlistPage()),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
            ),
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: const Text("Alerts"),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: "Refresh Data",
            onPressed: () => controller.fetchProducts(),
          ),
          const SizedBox(width: 16),
        ],
      ],
    );
  }

  // ==========================================
  // STATS & BULK CURRENCY UPDATE
  // ==========================================
  Widget _buildStatsSection(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child:
          isMobile
              ? Column(
                children: [
                  _buildStatCard(isMobile: isMobile),
                  const SizedBox(height: 12),
                  _buildExchangeRateCard(isMobile: isMobile),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 2, child: _buildStatCard(isMobile: isMobile)),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildExchangeRateCard(isMobile: isMobile),
                  ),
                ],
              ),
    );
  }

  Widget _buildStatCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.monetization_on,
              color: Colors.blue,
              size: isMobile ? 24 : 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Warehouse Value",
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(
                  () => Text(
                    "৳ ${controller.formattedTotalValuation}",
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRateCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_exchange, color: Colors.amber),
          ),
          SizedBox(width: isMobile ? 10 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bulk Currency Update (CNY)",
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(
                  () => Text(
                    "Current: 1 ¥ = ${controller.currentCurrency.value.toStringAsFixed(2)} ৳",
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: isMobile ? 80 : 120,
            child: TextField(
              controller: currencyInput,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'New Rate',
                fillColor: Colors.grey.shade100,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _handleCurrencyUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
            ),
            icon: Icon(Icons.update, size: isMobile ? 16 : 20),
            label: Text(isMobile ? "Set" : "Apply to All"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOOLBAR (SEARCH & FILTERS)
  // ==========================================
  Widget _buildControlToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => controller.search(v),
              decoration: InputDecoration(
                hintText:
                    isMobile
                        ? 'Search...'
                        : 'Search by model, name or brand...',
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
          Obx(() {
            bool isActive = controller.sortByLoss.value;
            return InkWell(
              onTap: () => controller.toggleSortByLoss(),
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
                        "Loss First",
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

  // ==========================================
  // LAG-FREE CUSTOM TABLE
  // ==========================================
  Widget _buildOptimizedTable(bool isMobile) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.allProducts.isEmpty) return _buildEmptyState();

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
              // OVERFLOW FIXED: 1180 (columns) + 32 (padding) + 8 (buffer) = 1220. No more 32px crash!
              child: SizedBox(
                width: 1220,
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
                          _headerCell('MODEL', 120),
                          _headerCell('NAME', 180),
                          _headerCell('STATUS', 80),
                          _headerCell('PROFIT', 100),
                          _headerCell('STOCK', 80),
                          _headerCell('ON WAY', 80),
                          _headerCell('SEA / AIR', 100),
                          _headerCell('AVG COST', 100),
                          _headerCell('AGENT', 100),
                          _headerCell('WHOLESALE', 100),
                          _headerCell('ACTIONS', 140),
                        ],
                      ),
                    ),
                    // TABLE BODY
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.allProducts.length,
                      itemBuilder: (context, index) {
                        final p = controller.allProducts[index];
                        int onWay = shipmentController.getOnWayQty(p.id);
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              _dataCell(
                                Text(
                                  p.model,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                120,
                              ),
                              _dataCell(
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                180,
                              ),
                              _dataCell(
                                _buildStockBadge(p.stockQty, p.alertQty),
                                80,
                              ),
                              _dataCell(_buildProfitCell(p), 100),
                              _dataCell(
                                Text(
                                  p.stockQty.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color:
                                        p.stockQty <= p.alertQty
                                            ? Colors.red
                                            : Colors.black,
                                  ),
                                ),
                                80,
                              ),
                              _dataCell(
                                onWay > 0
                                    ? _badge(onWay.toString(), Colors.blue)
                                    : const Text(
                                      "-",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                80,
                              ),
                              _dataCell(
                                Text(
                                  "${p.seaStockQty} / ${p.airStockQty}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                100,
                              ),
                              _dataCell(
                                Text(
                                  "৳${p.avgPurchasePrice.toStringAsFixed(1)}",
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                100,
                              ),
                              _dataCell(
                                Text("৳${p.agent.toStringAsFixed(1)}"),
                                100,
                              ),
                              _dataCell(
                                Text("৳${p.wholesale.toStringAsFixed(1)}"),
                                100,
                              ),
                              _dataCell(_buildActions(context, p), 140),
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
      );
    });
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _dataCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  // ==========================================
  // CELL WIDGETS
  // ==========================================
  Widget _buildProfitCell(Product p) {
    double profitAgent = p.agent - p.avgPurchasePrice;
    double profitWholesale = p.wholesale - p.avgPurchasePrice;

    Widget profitLine(String label, double profit) {
      bool isLoss = profit < 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            "${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isLoss ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        profitLine("A", profitAgent),
        const SizedBox(height: 2),
        profitLine("W", profitWholesale),
      ],
    );
  }

  Widget _badge(String text, MaterialColor color) {
    return Container(
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

  Widget _buildStockBadge(int stock, int alert) => _badge(
    stock <= alert ? 'LOW' : 'OK',
    stock <= alert ? Colors.red : Colors.green,
  );

  // ==========================================
  // ACTIONS & DIALOGS
  // ==========================================
  Widget _buildActions(BuildContext context, Product p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.add_shopping_cart,
            color: Colors.teal,
            size: 20,
          ),
          tooltip: "Add Stock",
          onPressed: () => _showAddStockDialog(context, p, controller),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
          tooltip: "Edit",
          onPressed: () => showEditProductDialog(p, controller),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
          onSelected: (val) {
            if (val == 'service') {
              _showQuantityDialog(
                context,
                "Service",
                p,
                (qty) => controller.addToService(
                  productId: p.id,
                  model: p.model,
                  qty: qty,
                  type: 'service',
                  currentAvgPrice: p.avgPurchasePrice,
                ),
              );
            }
            if (val == 'damage') {
              _showQuantityDialog(
                context,
                "Damage",
                p,
                (qty) => controller.addToService(
                  productId: p.id,
                  model: p.model,
                  qty: qty,
                  type: 'damage',
                  currentAvgPrice: p.avgPurchasePrice,
                ),
              );
            }
            if (val == 'delete') showDeleteConfirmDialog(p.id, controller);
          },
          itemBuilder:
              (context) => const [
                PopupMenuItem(
                  value: 'service',
                  child: ListTile(
                    leading: Icon(Icons.handyman, color: Colors.orange),
                    title: Text('Send to Service'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'damage',
                  child: ListTile(
                    leading: Icon(Icons.broken_image, color: Colors.red),
                    title: Text('Mark as Damage'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.grey),
                    title: Text('Delete Product'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ],
    );
  }

  void _showAddStockDialog(
    BuildContext context,
    Product p,
    ProductController controller,
  ) {
    final seaQtyC = TextEditingController(text: '0');
    final airQtyC = TextEditingController(text: '0');
    final localQtyC = TextEditingController(text: '0');
    final localPriceC = TextEditingController(text: '0');
    final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);
    final RxDouble predictedAvg = p.avgPurchasePrice.obs;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    void calculatePrediction() {
      int s = int.tryParse(seaQtyC.text) ?? 0;
      int a = int.tryParse(airQtyC.text) ?? 0;
      int l = int.tryParse(localQtyC.text) ?? 0;
      double lp = double.tryParse(localPriceC.text) ?? 0.0;

      double oldValue = p.stockQty * p.avgPurchasePrice;
      double seaUnitCost = (p.yuan * p.currency) + (p.weight * p.shipmentTax);
      double airUnitCost =
          (p.yuan * p.currency) + (p.weight * p.shipmentTaxAir);

      double newBatchValue = (s * seaUnitCost) + (a * airUnitCost) + (l * lp);
      int totalNewQty = p.stockQty + s + a + l;

      if (totalNewQty > 0) {
        predictedAvg.value = (oldValue + newBatchValue) / totalNewQty;
      }
    }

    Widget inputField(String label, TextEditingController ctrl, IconData icon) {
      return TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => calculatePrediction(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Receive Stock: ${p.model}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                          "New Avg Cost: ৳${predictedAvg.value.toStringAsFixed(2)}",
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
                inputField("Sea Qty", seaQtyC, Icons.waves),
                const SizedBox(height: 10),
                inputField("Air Qty", airQtyC, Icons.airplanemode_active),
                const Divider(height: 30),
                const Text(
                  "Local Purchase",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: inputField("Qty", localQtyC, Icons.inventory),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: inputField(
                        "Unit Price",
                        localPriceC,
                        Icons.price_change,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Obx(
                  () => InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: Get.context!,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) selectedDate.value = picked;
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Shipment Date (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        selectedDate.value == null
                            ? 'Select Date'
                            : DateFormat(
                              'dd MMM yyyy',
                            ).format(selectedDate.value!),
                      ),
                    ),
                  ),
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
                shipmentDate: selectedDate.value,
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
          Get.snackbar(
            "Error",
            "Invalid Quantity",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  void _handleCurrencyUpdate() {
    final val = double.tryParse(currencyInput.text);
    if (val != null && val > 0) {
      Get.defaultDialog(
        title: 'Confirm Bulk Revaluation',
        middleText:
            'Update Currency Rate to ¥1 = ৳${val.toStringAsFixed(2)}? This will automatically recalculate the Average Cost and Prices for ALL products in your warehouse.',
        textConfirm: 'Update All',
        confirmTextColor: Colors.white,
        buttonColor: Colors.amber.shade700,
        onConfirm: () {
          controller.updateCurrencyAndRecalculate(val);
          currencyInput.clear();
          Get.back();
        },
      );
    } else {
      Get.snackbar(
        'Error',
        'Please enter a valid currency rate.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildPaginationFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 12,
      ),
      child: Obx(() {
        final total = controller.totalProducts.value;
        final current = controller.currentPage.value;
        final size = controller.pageSize.value;
        final totalPages = (total / size).ceil();
        final start = total == 0 ? 0 : ((current - 1) * size) + 1;
        final end = (current * size) > total ? total : (current * size);

        return Row(
          children: [
            if (!isMobile)
              Text(
                "Showing $start to $end of $total results",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.black),
                  tooltip: "Previous",
                  onPressed:
                      current > 1 ? () => controller.previousPage() : null,
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
                  icon: const Icon(Icons.chevron_right, color: Colors.black),
                  tooltip: "Next",
                  onPressed:
                      current < totalPages ? () => controller.nextPage() : null,
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
        padding: EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}