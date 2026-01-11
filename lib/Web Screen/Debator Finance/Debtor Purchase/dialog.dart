// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';

void showPurchaseDialog(BuildContext context, String debtorId) {
  // 1. Initialize or Find Controller
  final controller =
      Get.isRegistered<DebtorPurchaseController>()
          ? Get.find<DebtorPurchaseController>()
          : Get.put(DebtorPurchaseController());

  // 2. Trigger data load if list is empty
  if (controller.productSearchList.isEmpty) {
    controller.loadProductsForSearch();
  }

  // 3. Local Controllers
  final qtyC = TextEditingController();
  final costC = TextEditingController();

  // 4. Reactive State for Dialog
  Rxn<Map<String, dynamic>> selectedProduct = Rxn<Map<String, dynamic>>();
  RxString selectedLocation = "Sea".obs;

  // 5. Theme Colors
  const Color activeAccent = Color(0xFF3B82F6);
  const Color darkSlate = Color(0xFF111827);

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          height: 750,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: activeAccent),
                  const SizedBox(width: 10),
                  const Text(
                    "New Purchase Entry",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 15),

              // --- 1. SEARCH SECTION (Autocomplete) ---
              Obx(() {
                // Loading State
                if (controller.productSearchList.isEmpty) {
                  return const Column(
                    children: [
                      LinearProgressIndicator(color: activeAccent),
                      SizedBox(height: 5),
                      Text(
                        "Loading Products from Server...",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  );
                }

                // Search Field
                return Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    return controller.productSearchList.where((product) {
                      final name = product['name'].toString().toLowerCase();
                      final model = product['model'].toString().toLowerCase();
                      final query = textEditingValue.text.toLowerCase();
                      // Match by Name OR Model
                      return name.contains(query) || model.contains(query);
                    });
                  },
                  // What shows in the list
                  displayStringForOption:
                      (option) => "${option['name']} - ${option['model']}",

                  // Action on Selection
                  onSelected: (selection) {
                    selectedProduct.value = selection;
                    // Auto-fill cost from controller's mapped data
                    costC.text = selection['buyingPrice']?.toString() ?? "0";
                    qtyC.text = "1";
                  },

                  // Custom Input Decoration
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
                        labelText: "Scan or Search (Name / Model)",
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
              }),

              const SizedBox(height: 15),

              // --- 2. INPUTS ROW (Qty, Cost, Location, Add Button) ---
              Row(
                children: [
                  Expanded(child: _inputField(qtyC, "Quantity", Icons.numbers)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _inputField(
                      costC,
                      "Cost Rate",
                      Icons.monetization_on,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(
                      () => DropdownButtonFormField<String>(
                        value: selectedLocation.value,
                        decoration: InputDecoration(
                          labelText: "Location",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        items:
                            ["Sea", "Air", "Local"]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => selectedLocation.value = v!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedProduct.value == null) {
                          Get.snackbar(
                            "Required",
                            "Please search and select a product first",
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        // Add to Controller Cart
                        controller.addToCart(
                          selectedProduct.value!,
                          int.tryParse(qtyC.text) ?? 0,
                          double.tryParse(costC.text) ?? 0,
                          selectedLocation.value,
                        );

                        // Clear inputs for next entry
                        selectedProduct.value = null;
                        qtyC.clear();
                        costC.clear();
                        // Note: Autocomplete text remains visually, user types over it.
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

              // --- 3. CART LIST SECTION ---
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
                          "Cart is Empty",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: controller.cartItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = controller.cartItems[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFFEFF6FF,
                            ), // Light Blue
                            child: Text(
                              "${i + 1}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: activeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${item['location']} Stock | Qty: ${item['qty']} @ ${item['cost']}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Tk ${item['subtotal']}",
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
                                onPressed:
                                    () => controller.cartItems.removeAt(i),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),

              // --- 4. FOOTER (Total & Finalize) ---
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() {
                    final total = controller.cartItems.fold(
                      0.0,
                      (sum, item) => sum + (item['subtotal'] as double),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Payable",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          "Tk $total",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),
                      ],
                    );
                  }),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Finalize Purchase"),
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
                    onPressed:
                        () => controller.finalizePurchase(
                          debtorId,
                          "Stock Purchase",
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Helper Widget for Input Fields
Widget _inputField(TextEditingController c, String label, IconData icon) {
  return TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 16, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    ),
  );
}
