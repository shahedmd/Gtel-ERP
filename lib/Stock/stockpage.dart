// ignore_for_file: deprecated_member_use

import 'dart:ui'; // Required for PointerDeviceKind
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'Service/servicepage.dart';
import 'controller.dart';
import 'edit.dart';
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

  // Main Controller (Handles Products + Service + Damage)
  final ProductController controller = Get.put(ProductController());

  final TextEditingController currencyInput = TextEditingController();

  // Explicit ScrollControllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Inventory & Service Manager',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // New Service Page Button
          TextButton.icon(
            onPressed: () => Get.to(() => ServicePage()),
            icon: const Icon(Icons.handyman, color: Colors.orange),
            label: const Text(
              "Service Center",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchProducts(),
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ==========================================
              // CURRENCY MANAGEMENT CARD (Existing)
              // ==========================================
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue[100]!),
                ),
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Market Rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                              ),
                            ),
                            Obx(
                              () => Text(
                                '1 CNY = ${controller.currentCurrency.value.toStringAsFixed(2)} BDT',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const Text(
                              'Changing rate updates all Imported Stock values.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: currencyInput,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'New Rate',
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        onPressed: () {
                          final val = double.tryParse(currencyInput.text);
                          if (val != null && val > 0) {
                            Get.defaultDialog(
                              title: 'Currency Revaluation',
                              middleText:
                                  'Update to ${val.toStringAsFixed(2)}? This changes your current debt and inventory value.',
                              textConfirm: 'Update All',
                              confirmTextColor: Colors.white,
                              buttonColor: Colors.blue[800],
                              onConfirm: () {
                                controller.updateCurrencyAndRecalculate(val);
                                currencyInput.clear();
                                Get.back();
                              },
                              onCancel: () {},
                            );
                          } else {
                            Get.snackbar(
                              'Input Required',
                              'Please enter a valid currency rate',
                            );
                          }
                        },
                        icon: const Icon(Icons.currency_exchange),
                        label: const Text('Recalculate'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // SEARCH & BRAND FILTER
              // ==========================================
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (v) => controller.search(v),
                      decoration: InputDecoration(
                        hintText: 'Search by model, name or brand...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Obx(
                      () => DropdownButtonFormField<String>(
                        value: controller.selectedBrand.value,
                        decoration: InputDecoration(
                          labelText: 'Brand Filter',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items:
                            controller.brands
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) controller.selectBrand(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==========================================
              // DATA TABLE (UPDATED COLUMNS)
              // ==========================================
              Expanded(
                child: Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.allProducts.isEmpty) {
                      return const Center(child: Text('No products found.'));
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 10,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              thickness: 12,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    columnSpacing: 24,
                                    horizontalMargin: 20,
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.blueGrey[50],
                                    ),
                                    border: TableBorder(
                                      verticalInside: BorderSide(
                                        width: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'Model',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // --- NEW COLUMNS ---
                                      DataColumn(
                                        label: Text(
                                          'Yuan (¥)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Rate',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Weight',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // -------------------
                                      DataColumn(
                                        label: Text(
                                          'Avg Purchase',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Total Stock',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Sea Qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Air Qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Local Qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // --- ADDED PRICE COLUMNS ---
                                      DataColumn(
                                        label: Text(
                                          'Sea Price',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Air Price',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // ---------------------------
                                      DataColumn(
                                        label: Text(
                                          'Agent',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Wholesale',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Actions',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows:
                                        controller.allProducts.map((p) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  p.model,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              // --- MAPPED NEW COLUMNS ---
                                              DataCell(
                                                Text(p.yuan.toStringAsFixed(2)),
                                              ),
                                              DataCell(
                                                Text(
                                                  p.currency.toStringAsFixed(2),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  p.weight.toStringAsFixed(2),
                                                ),
                                              ),
                                              // -------------------------
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    p.avgPurchasePrice
                                                        .toStringAsFixed(2),
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  p.stockQty.toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(p.seaStockQty.toString()),
                                              ),
                                              DataCell(
                                                Text(p.airStockQty.toString()),
                                              ),
                                              DataCell(
                                                Text(p.localQty.toString()),
                                              ),
                                              // --- ADDED PRICE CELLS ---
                                              DataCell(
                                                Text(p.sea.toStringAsFixed(2)),
                                              ),
                                              DataCell(
                                                Text(p.air.toStringAsFixed(2)),
                                              ),
                                              // ------------------------
                                              DataCell(
                                                Text(
                                                  p.agent.toStringAsFixed(2),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  p.wholesale.toStringAsFixed(
                                                    2,
                                                  ),
                                                ),
                                              ),

                                              // --- UPDATED ACTIONS ROW ---
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // 1. ADD STOCK
                                                    IconButton(
                                                      tooltip: 'Receive Stock',
                                                      icon: const Icon(
                                                        Icons.add_box,
                                                        color: Colors.teal,
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              _showAddStockDialog(
                                                                p,
                                                                controller,
                                                              ),
                                                    ),
                                                    // 2. SEND TO SERVICE (Using ProductController)
                                                    IconButton(
                                                      tooltip:
                                                          'Send to Service',
                                                      icon: const Icon(
                                                        Icons.build,
                                                        color: Colors.orange,
                                                      ),
                                                      onPressed:
                                                          () => _showQuantityDialog(
                                                            context,
                                                            "Service",
                                                            p,
                                                            (qty) {
                                                              controller.addToService(
                                                                productId: p.id,
                                                                model: p.model,
                                                                qty: qty,
                                                                type: 'service',
                                                                currentAvgPrice:
                                                                    p.avgPurchasePrice,
                                                              );
                                                            },
                                                          ),
                                                    ),
                                                    // 3. DAMAGE (Using ProductController)
                                                    IconButton(
                                                      tooltip: 'Mark Damage',
                                                      icon: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed:
                                                          () => _showQuantityDialog(
                                                            context,
                                                            "Damage",
                                                            p,
                                                            (qty) {
                                                              controller.addToService(
                                                                productId: p.id,
                                                                model: p.model,
                                                                qty: qty,
                                                                type: 'damage',
                                                                currentAvgPrice:
                                                                    p.avgPurchasePrice,
                                                              );
                                                            },
                                                          ),
                                                    ),
                                                    // 4. EDIT
                                                    IconButton(
                                                      tooltip: 'Edit Product',
                                                      icon: const Icon(
                                                        Icons.edit,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              showEditProductDialog(
                                                                p,
                                                                controller,
                                                              ),
                                                    ),
                                                    // 5. DELETE
                                                    IconButton(
                                                      tooltip: 'Delete Product',
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              showDeleteConfirmDialog(
                                                                p.id,
                                                                controller,
                                                              ),
                                                    ),
                                                  ],
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
                        );
                      },
                    );
                  }),
                ),
              ),

              _buildPagination(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProductDialog(controller),
        backgroundColor: Colors.blue[800],
        label: const Text(
          'Add New Product',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ==========================================
  // HELPER: QUANTITY INPUT DIALOG (For Service/Damage)
  // ==========================================
  void _showQuantityDialog(
    BuildContext context,
    String actionType,
    Product p,
    Function(int) onConfirm,
  ) {
    final qtyController = TextEditingController();
    Get.defaultDialog(
      title: "$actionType: ${p.model}",
      content: Column(
        children: [
          Text(
            "Current Stock: ${p.stockQty}",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Enter Quantity to Remove",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
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
            "Invalid Quantity",
            "Amount must be > 0 and <= Current Stock",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  // ==========================================
  // ADD MIXED STOCK DIALOG
  // ==========================================
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receive Inventory: ${p.model}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Obx(
              () => Text(
                "New Avg Cost will be: ${predictedAvg.value.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter quantities to add to current stock.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(),
              TextField(
                controller: seaQtyC,
                decoration: const InputDecoration(
                  labelText: 'Sea Shipment Qty',
                  prefixIcon: Icon(Icons.waves),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculatePrediction(),
              ),
              TextField(
                controller: airQtyC,
                decoration: const InputDecoration(
                  labelText: 'Air Shipment Qty',
                  prefixIcon: Icon(Icons.airplanemode_active),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculatePrediction(),
              ),
              const SizedBox(height: 16),
              const Text(
                'OR Local Purchase',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              TextField(
                controller: localQtyC,
                decoration: const InputDecoration(
                  labelText: 'Local Quantity',
                  prefixIcon: Icon(Icons.shopping_cart),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculatePrediction(),
              ),
              TextField(
                controller: localPriceC,
                decoration: const InputDecoration(
                  labelText: 'Local Unit Cost (BDT)',
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculatePrediction(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
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
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGINATION CONTROLS UI
  // ==========================================
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Obx(() {
        final totalPages =
            (controller.totalProducts.value / controller.pageSize.value).ceil();
        final currentPage = controller.currentPage.value;
        final safePages = totalPages < 1 ? 1 : totalPages;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              onPressed:
                  currentPage > 1 ? () => controller.previousPage() : null,
            ),
            Text(
              'Page $currentPage of $safePages',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed:
                  currentPage < safePages ? () => controller.nextPage() : null,
            ),
            const SizedBox(width: 20),
            Text(
              'Total Items: ${controller.totalProducts.value}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }
}
