import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';
import 'edit.dart';

class ProductScreen extends StatelessWidget {
  ProductScreen({super.key});

  final ProductController controller = Get.put(ProductController());
  final TextEditingController currencyInput = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchProducts(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // ==========================================
            // CURRENCY MANAGEMENT CARD (Recalculate Section)
            // ==========================================
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.blue[100]!),
              ),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Exchange Rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                          Obx(
                            () => Text(
                              '1 CNY = ${controller.currentCurrency.value} BDT',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: currencyInput,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Rate',
                          isDense: true,
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        final val = double.tryParse(currencyInput.text);
                        if (val != null && val > 0) {
                          Get.defaultDialog(
                            title: 'Recalculate Prices?',
                            middleText:
                                'This will update the AIR and SEA prices for ALL products in the database using the rate: $val',
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
                      child: const Text('Recalculate'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

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
                      hintText: 'Search by model...',
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
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Obx(
                    () => DropdownButtonFormField<String>(
                      value: controller.selectedBrand.value,
                      decoration: InputDecoration(
                        labelText: 'Brand',
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
                                  child: Text(
                                    b,
                                    style: const TextStyle(fontSize: 12),
                                  ),
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
            const SizedBox(height: 12),

            // ==========================================
            // DATA TABLE (Scrollable)
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
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowHeight: 45,
                              dataRowMaxHeight: 55,
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.grey[50],
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Model',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Yuan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Air BDT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Sea BDT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Agent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ), // NEW
                                DataColumn(
                                  label: Text(
                                    'Wholesale',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ), // NEW
                                DataColumn(
                                  label: Text(
                                    'Stock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Currency',
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

                              // ... inside the DataTable rows (map):
                              rows:
                                  controller.allProducts.map((p) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text('#${p.id}')),
                                        DataCell(
                                          Text(
                                            p.model,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text('¥${p.yuan}')),
                                        DataCell(
                                          Text(
                                            p.air.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            p.sea.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // NEW: AGENT PRICE (Orange color to distinguish)
                                        DataCell(
                                          Text(
                                            p.agent.toStringAsFixed(0),
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // NEW: WHOLESALE PRICE (Green color to distinguish)
                                        DataCell(
                                          Text(
                                            p.wholesale.toStringAsFixed(0),
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        DataCell(Text('${p.stockQty}')),
                                        DataCell(
                                          Text(
                                            p.currency.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Colors.blue,
                                                ),
                                                onPressed:
                                                    () => showEditProductDialog(
                                                      p,
                                                      controller,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
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
                      );
                    },
                  );
                }),
              ),
            ),

            // ==========================================
            // PAGINATION CONTROLS
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Obx(() {
                final totalPages =
                    (controller.totalProducts.value / controller.pageSize.value)
                        .ceil();
                final currentPage = controller.currentPage.value;
                final safeTotalPages = totalPages < 1 ? 1 : totalPages;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      onPressed:
                          currentPage > 1
                              ? () => controller.previousPage()
                              : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Page $currentPage of $safeTotalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      onPressed:
                          currentPage < safeTotalPages
                              ? () => controller.nextPage()
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Total: ${controller.totalProducts.value}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProductDialog(controller),
        backgroundColor: Colors.blue[800],
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
