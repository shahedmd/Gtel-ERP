// ignore_for_file: deprecated_member_use, avoid_print
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Added for date formatting
// IMPORTANT: Update this import path
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';

void showPurchaseDialog(BuildContext context, String debtorId) {
  final controller =
      Get.isRegistered<DebtorPurchaseController>()
          ? Get.find<DebtorPurchaseController>()
          : Get.put(DebtorPurchaseController());

  // Local Controllers
  final qtyC = TextEditingController();
  final costC = TextEditingController();
  final dateC = TextEditingController(
    text: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
  ); // Date Controller

  // Reactive State
  Rxn<Map<String, dynamic>> selectedProduct = Rxn<Map<String, dynamic>>();
  RxString selectedLocation = "Sea".obs;
  Rx<DateTime> selectedDate = DateTime.now().obs; // Store the date

  const Color activeAccent = Color(0xFF3B82F6);
  const Color darkSlate = Color(0xFF111827);

  // Helper function to pick date
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate.value) {
      selectedDate.value = picked;
      dateC.text = DateFormat('dd-MMM-yyyy').format(picked);
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          height: 800, // Increased height slightly for date field
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

              // --- 0. DATE SELECTION (NEW) ---
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Purchase Date:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: dateC,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: "Select Date",
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 10,
                        ),
                      ),
                      onTap: () => _pickDate(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // --- 1. SERVER-SIDE AUTOCOMPLETE ---
              // (Kept largely the same, just wrapped in LayoutBuilder for constraints)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return await controller.stockCtrl
                          .searchProductsForDropdown(textEditingValue.text);
                    },
                    displayStringForOption:
                        (option) => "${option['name']} - ${option['model']}",
                    onSelected: (selection) {
                      selectedProduct.value = selection;
                      costC.text = selection['buyingPrice']?.toString() ?? "0";
                      qtyC.text = "1";
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: constraints.maxWidth,
                            height: 300,
                            color: Colors.white,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              separatorBuilder:
                                  (context, index) => const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> option = options
                                    .elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Model: ${option['model'] ?? 'N/A'}",
                                    style: const TextStyle(color: activeAccent),
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
                          labelText: "Search Server (Model or Name)",
                          hintText: "Type model number...",
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

              const SizedBox(height: 15),

              // --- 2. INPUTS (Qty, Cost, Location) ---
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

                        // Add to cart
                        controller.addToCart(
                          selectedProduct.value!,
                          int.tryParse(qtyC.text) ?? 0,
                          double.tryParse(costC.text) ?? 0,
                          selectedLocation.value,
                        );

                        // Reset fields but keep product search logic ready
                        selectedProduct.value = null;
                        qtyC.clear();
                        costC.clear();
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

              // --- 3. CART LIST ---
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
                            backgroundColor: const Color(0xFFEFF6FF),
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
                            "Model: ${item['model']} | ${item['location']} | Qty: ${item['qty']} @ ${item['cost']}",
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

              // --- 4. FINAL ACTIONS ---
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
                          customDate:
                              selectedDate.value, // Pass the custom date
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