// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/model.dart';
import 'salemodel.dart';

class LiveOrderSalesPage extends StatelessWidget {
  const LiveOrderSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the updated controller
    final controller = Get.put(LiveSalesController());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100
      body: Row(
        children: [
          // LEFT: Products Section
          Expanded(flex: 6, child: _ProductTableSection(controller)),

          // RIGHT: Checkout Panel
          Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(controller),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeToggle(controller),
                        const SizedBox(height: 15),
                        _buildCustomerSection(controller),
                        const SizedBox(height: 20),
                        _buildCartSection(controller),
                        const SizedBox(height: 20),
                        _buildPaymentSection(controller),
                      ],
                    ),
                  ),
                ),
                _buildBottomTotalBar(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(LiveSalesController controller) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color:
              controller.isConditionSale.value
                  ? const Color(0xFFC2410C) // Orange-700
                  : const Color(0xFF1E293B), // Slate-800
        ),
        child: Center(
          child: Text(
            controller.isConditionSale.value
                ? "CONDITION SALE & CHALLAN"
                : "CHECKOUT & BILLING",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // --- MODE TOGGLE ---
  Widget _buildModeToggle(LiveSalesController controller) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              controller.isConditionSale.value
                  ? Colors.orange.shade50
                  : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                controller.isConditionSale.value
                    ? Colors.orange.shade200
                    : Colors.blue.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  controller.isConditionSale.value
                      ? Icons.local_shipping
                      : Icons.store,
                  color:
                      controller.isConditionSale.value
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                ),
                const SizedBox(width: 10),
                Text(
                  controller.isConditionSale.value
                      ? "Condition / Courier Mode"
                      : "Direct Sales Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        controller.isConditionSale.value
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            Switch(
              value: controller.isConditionSale.value,
              activeColor: Colors.deepOrange,
              onChanged: (val) {
                controller.isConditionSale.value = val;
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. CUSTOMER & LOGISTICS INFO (UPDATED) ---
  Widget _buildCustomerSection(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Customer Details",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 10),

          // Customer Type Tabs (Hidden/Limited in Condition Mode)
          Obx(() {
            return Row(
              children:
                  ["Retailer", "Agent", "Debtor"].map((type) {
                    bool isSelected = controller.customerType.value == type;
                    // Disable Debtor in Condition mode
                    bool isDisabled =
                        controller.isConditionSale.value && type == "Debtor";

                    if (isDisabled) return const SizedBox.shrink();

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => controller.customerType.value = type,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          }),
          const SizedBox(height: 15),

          Obx(() {
            // DEBTOR SEARCH (Only for Direct Debtor Sales)
            if (controller.customerType.value == "Debtor" &&
                !controller.isConditionSale.value) {
              return Column(
                children: [
                  TextField(
                    controller: controller.debtorPhoneSearch,
                    decoration: InputDecoration(
                      labelText: "Search Debtor",
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon:
                          controller.debtorPhoneSearch.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  controller.debtorPhoneSearch.clear();
                                  controller.selectedDebtor.value = null;
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        controller.selectedDebtor.value = null;
                        return;
                      }
                      final match = controller.debtorCtrl.bodies
                          .firstWhereOrNull(
                            (e) =>
                                e.phone.contains(v) ||
                                e.name.toLowerCase().contains(v.toLowerCase()),
                          );
                      controller.selectedDebtor.value = match;
                    },
                  ),
                  const SizedBox(height: 8),
                  if (controller.selectedDebtor.value != null)
                    _buildSelectedDebtorCard(controller)
                  else if (controller.debtorPhoneSearch.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      color: Colors.red.shade50,
                      child: const Text(
                        "Debtor not found",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              );
            }

            // MANUAL ENTRY & LOGISTICS (Condition Fields Updated Here)
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _miniTextField(
                        controller.nameC,
                        "Name",
                        Icons.person,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniTextField(
                        controller.phoneC,
                        "Phone",
                        Icons.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _miniTextField(
                  controller.shopC,
                  "Shop Name (Optional)",
                  Icons.store,
                ),

                // --- NEW: LOGISTICS FIELDS FOR CONDITION SALE ---
                if (controller.isConditionSale.value) ...[
                  const SizedBox(height: 15),
                  const Divider(thickness: 1),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Logistics & Courier Info",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _miniTextField(
                          controller.addressC,
                          "Delivery Address",
                          Icons.location_on,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: _miniTextField(
                          controller.challanC,
                          "Challan No",
                          Icons.receipt_long,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // 1. COURIER DROPDOWN
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.selectedCourier.value,
                              hint: const Text(
                                "Select Courier",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              isExpanded: true,
                              items:
                                  controller.courierList
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                controller.selectedCourier.value = v;
                                // Optional: Trigger due calculation when selected
                                if (v != null) {
                                  controller.calculateCourierDueFor(v);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 2. CARTONS INPUT
                      Expanded(
                        flex: 1,
                        child: _miniTextField(
                          controller.cartonsC,
                          "Cartons",
                          Icons.inventory_2,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedDebtorCard(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.selectedDebtor.value!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                controller.selectedDebtor.value!.phone,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. CART SECTION ---
  Widget _buildCartSection(LiveSalesController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Item Details",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Total",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Obx(
            () => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.cart.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = controller.cart[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "৳${item.priceAtSale}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CartQuantityEditor(
                        currentQty: item.quantity.value,
                        maxStock: item.product.stockQty,
                        onDecrease: () {
                          if (item.quantity.value > 1) {
                            item.quantity.value--;
                            controller.cart.refresh();
                            controller.updatePaymentCalculations();
                          } else {
                            controller.cart.removeAt(index);
                          }
                        },
                        onIncrease: () {
                          if (item.quantity.value < item.product.stockQty) {
                            item.quantity.value++;
                            controller.cart.refresh();
                            controller.updatePaymentCalculations();
                          } else {
                            Get.snackbar(
                              "Stock Limit",
                              "Only ${item.product.stockQty} available",
                            );
                          }
                        },
                        onSubmit: (val) {
                          controller.updateQuantity(index, val);
                        },
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "৳${item.subtotal.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. PAYMENT SECTION (Updated Summary Logic) ---
  Widget _buildPaymentSection(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(
                () => Text(
                  controller.isConditionSale.value
                      ? "Advance Payment"
                      : "Payment Split",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const Icon(
                Icons.payments_outlined,
                size: 16,
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _moneyInput(controller.cashC, "Cash", Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _moneyInput(controller.bkashC, "bKash", Colors.pink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _moneyInput(controller.nagadC, "Nagad", Colors.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _moneyInput(controller.bankC, "Bank", Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Payment Summary Bar
          Obx(() {
            String label = "";
            Color color = Colors.black;

            if (controller.isConditionSale.value) {
              // Condition Mode: Show Advance vs Courier Due
              double due =
                  controller.grandTotal - controller.totalPaidInput.value;
              double collect = due > 0 ? due : 0;
              label = "Courier Collect: ৳${collect.toStringAsFixed(0)}";
              color = Colors.deepOrange;
            } else {
              // Normal Mode: Show Paid vs Due/Change
              if (controller.totalPaidInput.value > controller.grandTotal) {
                label =
                    "Change: ৳${controller.changeReturn.value.toStringAsFixed(0)}";
                color = Colors.green;
              } else {
                double due =
                    controller.grandTotal - controller.totalPaidInput.value;
                label = "Due: ৳${due.toStringAsFixed(0)}";
                color = Colors.red;
              }
            }

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    controller.isConditionSale.value
                        ? "Total Advance: ৳${controller.totalPaidInput.value.toStringAsFixed(0)}"
                        : "Total Paid: ৳${controller.totalPaidInput.value.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomTotalBar(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Discount", style: TextStyle(color: Colors.grey)),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller.discountC,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "0",
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                  onChanged: (v) {
                    controller.discountVal.value = double.tryParse(v) ?? 0.0;
                    controller.updatePaymentCalculations();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "GRAND TOTAL",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Obx(
                () => Text(
                  "৳ ${controller.grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      controller.isConditionSale.value
                          ? Colors.deepOrange
                          : const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                onPressed:
                    controller.isProcessing.value
                        ? null
                        : controller.finalizeSale,
                child:
                    controller.isProcessing.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          controller.isConditionSale.value
                              ? "PROCESS CONDITION & PRINT CHALLAN"
                              : "COMPLETE SALE & PRINT",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _miniTextField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: c,
        style: const TextStyle(fontSize: 13),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 16, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _moneyInput(TextEditingController c, String label, Color color) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 12),
        prefixText: "৳",
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}

// --------------------------------------------------------
// PRODUCTS TABLE & ROW (No Changes)
// --------------------------------------------------------

class _ProductTableSection extends StatelessWidget {
  final LiveSalesController controller;
  const _ProductTableSection(this.controller);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
      child: Column(
        children: [
          _buildTopHeader(),
          const SizedBox(height: 15),
          _buildTableHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300),
                  right: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Obx(() {
                if (controller.productCtrl.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.productCtrl.allProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No products found",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: controller.productCtrl.allProducts.length,
                  separatorBuilder:
                      (context, index) =>
                          const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    return _ProductRow(
                      product: controller.productCtrl.allProducts[index],
                      controller: controller,
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PRODUCTS",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 5),
                  Text(
                    "System Online",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 380,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: (v) => controller.productCtrl.search(v),
            textAlignVertical: TextAlignVertical.center,
            decoration: const InputDecoration(
              hintText: "Search by Model, Name or Code...",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "ITEM DESCRIPTION",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "STOCK",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "RATE (BDT)",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 50),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final LiveSalesController controller;
  const _ProductRow({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    Color stockColor = Colors.green;
    if (product.stockQty == 0) {
      stockColor = Colors.red;
    } else if (product.stockQty < 5) {
      stockColor = Colors.orange;
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => controller.addToCart(product),
        hoverColor: Colors.blue.withOpacity(0.02),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.model,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: stockColor),
                    const SizedBox(width: 6),
                    Text(
                      product.stockQty.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: stockColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Obx(() {
                  double price =
                      (controller.customerType.value == "Retailer")
                          ? product.wholesale
                          : product.agent;
                  return Text(
                    "৳ ${price.toStringAsFixed(2)}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  );
                }),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 35,
                height: 35,
                child: ElevatedButton(
                  onPressed: () => controller.addToCart(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartQuantityEditor extends StatefulWidget {
  final int currentQty;
  final int maxStock;
  final Function(String) onSubmit;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const CartQuantityEditor({
    super.key,
    required this.currentQty,
    required this.maxStock,
    required this.onSubmit,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  State<CartQuantityEditor> createState() => _CartQuantityEditorState();
}

class _CartQuantityEditorState extends State<CartQuantityEditor> {
  late TextEditingController _textCtrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.currentQty.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onSubmit(_textCtrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant CartQuantityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQty != oldWidget.currentQty && !_focusNode.hasFocus) {
      _textCtrl.text = widget.currentQty.toString();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: widget.onDecrease,
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(
              Icons.remove_circle_outline,
              color: Colors.red,
              size: 22,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: TextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (val) => widget.onSubmit(val),
          ),
        ),
        InkWell(
          onTap: widget.onIncrease,
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(
              Icons.add_circle_outline,
              color: Colors.green,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
