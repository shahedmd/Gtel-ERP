import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Stock%20Management/Local%20Purchase/purchase_controller.dart';

void showPurchaseDialog(BuildContext context, String debtorId) {
  final controller = Get.isRegistered<DebtorPurchaseController>()
      ? Get.find<DebtorPurchaseController>()
      : Get.put(DebtorPurchaseController());

  final qtyC = TextEditingController();
  final costC = TextEditingController();
  final warehouseLocationC = TextEditingController();
  final dateC = TextEditingController(
    text: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
  );

  final selectedProduct = Rxn<Map<String, dynamic>>();
  final selectedStockType = 'Sea'.obs;
  final selectedDate = DateTime.now().obs;
  final selectedWarehouseId = RxnInt();
  final selectedWarehouseName = ''.obs;

  const Color activeAccent = Color(0xFF3B82F6);
  const Color darkSlate = Color(0xFF111827);

  void ensureWarehouseSelected() {
    if (selectedWarehouseId.value != null && selectedWarehouseId.value! > 0) {
      return;
    }

    final warehouses = controller.stockCtrl.activeWarehouses;
    if (warehouses.isEmpty) return;

    final first = warehouses.first;
    final id = _toInt(first['id']);

    selectedWarehouseId.value = id > 0 ? id : null;
    selectedWarehouseName.value = first['name']?.toString() ?? '';
  }

  ensureWarehouseSelected();

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      selectedDate.value = picked;
      dateC.text = DateFormat('dd-MMM-yyyy').format(picked);
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 840),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: activeAccent),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'New Purchase Entry',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkSlate,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const SizedBox(
                      width: 130,
                      child: Text(
                        'Purchase Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: dateC,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select Date',
                          suffixIcon: const Icon(
                            Icons.calendar_today,
                            size: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 10,
                          ),
                        ),
                        onTap: () => pickDate(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (textEditingValue) async {
                        final query = textEditingValue.text.trim();
                        if (query.isEmpty) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }

                        return controller.stockCtrl.searchProductsForDropdown(
                          query,
                        );
                      },
                      displayStringForOption: (option) {
                        return '${option['name']} - ${option['model']}';
                      },
                      onSelected: (selection) {
                        selectedProduct.value = selection;
                        costC.text =
                            selection['buyingPrice']?.toString() ?? '0';
                        qtyC.text = '1';
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: constraints.maxWidth,
                              height: 300,
                              color: Colors.white,
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final option = options.elementAt(index);

                                  return ListTile(
                                    title: Text(
                                      option['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Model: ${option['model'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: activeAccent,
                                      ),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder: (
                        context,
                        textController,
                        focusNode,
                        onEditingComplete,
                      ) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: InputDecoration(
                            labelText: 'Search Product',
                            hintText: 'Type model or product name...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(qtyC, 'Quantity', Icons.numbers),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        costC,
                        'Cost Rate',
                        Icons.monetization_on,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<String>(
                          value: selectedStockType.value,
                          decoration: InputDecoration(
                            labelText: 'Stock Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Sea', child: Text('Sea')),
                            DropdownMenuItem(value: 'Air', child: Text('Air')),
                            DropdownMenuItem(
                              value: 'Local',
                              child: Text('Local'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) selectedStockType.value = value;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final warehouses = controller.stockCtrl.activeWarehouses;

                        if (warehouses.isEmpty) {
                          return TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Warehouse',
                              hintText: 'No warehouse found',
                              prefixIcon: const Icon(Icons.warehouse_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                            ),
                          );
                        }

                        final ids =
                            warehouses.map((w) => _toInt(w['id'])).toSet();

                        final value = ids.contains(selectedWarehouseId.value)
                            ? selectedWarehouseId.value
                            : null;

                        return DropdownButtonFormField<int>(
                          value: value,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Warehouse',
                            prefixIcon: const Icon(Icons.warehouse_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: warehouses.map((warehouse) {
                            final id = _toInt(warehouse['id']);
                            final name = warehouse['name']?.toString() ??
                                'Warehouse $id';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final warehouse = warehouses.firstWhereOrNull(
                              (item) => _toInt(item['id']) == value,
                            );

                            selectedWarehouseId.value = value;
                            selectedWarehouseName.value =
                                warehouse?['name']?.toString() ?? '';
                          },
                        );
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: warehouseLocationC,
                        decoration: InputDecoration(
                          labelText: 'Warehouse Location',
                          hintText: 'Rack A-3, Box 12',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          final product = selectedProduct.value;
                          final qty = int.tryParse(qtyC.text.trim()) ?? 0;
                          final cost =
                              double.tryParse(costC.text.trim()) ?? 0.0;
                          final warehouseId = selectedWarehouseId.value;

                          if (product == null) {
                            Get.snackbar(
                              'Required',
                              'Please search and select a product first.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                            );
                            return;
                          }

                          if (qty <= 0 || cost <= 0) {
                            Get.snackbar(
                              'Invalid',
                              'Enter valid quantity and cost.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                            );
                            return;
                          }

                          if (warehouseId == null || warehouseId <= 0) {
                            Get.snackbar(
                              'Warehouse Required',
                              'Please select a warehouse.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                            );
                            return;
                          }

                          controller.addToCart(
                            product: product,
                            qty: qty,
                            cost: cost,
                            stockType: selectedStockType.value,
                            warehouseId: warehouseId,
                            warehouseName: selectedWarehouseName.value,
                            warehouseLocation:
                                warehouseLocationC.text.trim(),
                          );

                          selectedProduct.value = null;
                          qtyC.clear();
                          costC.clear();
                          warehouseLocationC.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Obx(() {
                      if (controller.cartItems.isEmpty) {
                        return const Center(
                          child: Text(
                            'Cart is Empty',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: controller.cartItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final item = controller.cartItems[index];

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: activeAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              item['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Model: ${item['model']} | '
                              '${item['stockType'] ?? item['location']} | '
                              'Warehouse: ${item['warehouseName'] ?? '-'} | '
                              'Loc: ${item['warehouseLocation'] ?? '-'} | '
                              'Qty: ${item['qty']} @ ${item['cost']}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tk ${_toDouble(item['subtotal']).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkSlate,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    controller.cartItems.removeAt(index);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final total = controller.cartItems.fold<double>(
                          0,
                          (sum, item) => sum + _toDouble(item['subtotal']),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Payable',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Tk ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: darkSlate,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Finalize Purchase'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkSlate,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        controller.finalizePurchase(
                          debtorId,
                          'Stock Purchase',
                          customDate: selectedDate.value,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _inputField(TextEditingController controller, String label, IconData icon) {
  return TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 16, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    ),
  );
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
