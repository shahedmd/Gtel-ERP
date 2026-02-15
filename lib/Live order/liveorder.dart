// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// IMPORTANT: Ensure this import points to your actual controller file
import 'package:gtel_erp/Live%20order/salemodel.dart';

class LiveOrderSalesPage extends StatelessWidget {
  const LiveOrderSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    final controller = Get.put(LiveSalesController());

    // UI Local State for Cart Search
    final RxString cartSearchQuery = ''.obs;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100 background
      // 1. FULL PAGE SCROLLABLE
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(controller),

            // Control Panel (Customer & Payment)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildCustomerSection(controller),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1, height: 1),
                  const SizedBox(height: 16),
                  _buildExpandedPaymentSection(controller),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. EXPANDED WORKSPACE (Fixed Height for Tables to allow internal scrolling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 850, // Large fixed height for desktop-like feel
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inventory (Left)
                    Expanded(
                      flex: 6,
                      child: _productInventoryTable(controller),
                    ),
                    const SizedBox(width: 12),
                    // Cart (Right)
                    Expanded(
                      flex: 4,
                      child: _buildCartSection(controller, cartSearchQuery),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Padding for scrolling ease
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP BAR ---
  Widget _buildTopBar(LiveSalesController controller) {
    return Obx(
      () => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color:
              controller.isConditionSale.value
                  ? const Color(0xFFC2410C) // Orange-700 for Condition
                  : const Color(0xFF0F172A), // Slate-900 for Regular
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    controller.isConditionSale.value
                        ? Icons.local_shipping
                        : Icons.point_of_sale,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isConditionSale.value
                          ? "CONDITION / COURIER MANAGER"
                          : "POINT OF SALE (POS)",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Sales & Inventory System",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Toggle Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Text(
                    controller.isConditionSale.value
                        ? "Switch to Direct Sale"
                        : "Switch to Condition",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: controller.isConditionSale.value,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.orange.shade300,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey,
                    onChanged: (val) => controller.isConditionSale.value = val,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. CUSTOMER SECTION (FIXED) ---
  Widget _buildCustomerSection(LiveSalesController controller) {
    return Obx(() {
      bool isAgent = controller.customerType.value == "AGENT";
      // bool isCondition = controller.isConditionSale.value; // No longer needed for hiding

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2.1 Customer Type Tabs
              SizedBox(
                width: 320,
                child: Row(
                  children:
                      ["WHOLESALE", "VIP", "AGENT"].map((type) {
                        bool isSelected = controller.customerType.value == type;

                        // FIX: Removed the check that hid AGENT in condition mode

                        return Expanded(
                          child: InkWell(
                            onTap: () => controller.customerType.value = type,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 40,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.transparent
                                          : Colors.grey.shade300,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                        : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                type,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),

              const SizedBox(width: 16),

              // 2.2 Agent Search Bar (FIXED: Now visible even if Condition is ON)
              if (isAgent)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _erpInput(
                          controller.debtorPhoneSearch,
                          "Search Existing Agent (Name/Phone)...",
                          icon: Icons.search,
                          highlight: true,
                          fillColor: Colors.yellow.shade50,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Verified Balance Badge
                      if (controller.selectedDebtor.value != null)
                        Expanded(
                          flex: 4,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "FOUND",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      "Previous Due",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      "৳${controller.totalPreviousDue.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        // "New Agent" Hint
                        Expanded(
                          flex: 4,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              "* To create NEW Agent, ignore search and fill info below.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 2.3 Manual Info Fields
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _erpInput(
                  controller.phoneC,
                  "Phone Number",
                  isNumber: true,
                  highlight: true,
                  icon: Icons.phone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _erpInput(
                  controller.nameC,
                  "Customer Name",
                  icon: Icons.person,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _erpInput(
                  controller.addressC,
                  "Address / Location",
                  icon: Icons.location_on,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _erpInput(
                  controller.shopC,
                  "Shop / Reference",
                  icon: Icons.store,
                ),
              ),
            ],
          ),

          // 2.4 Logistics Row
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 240,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedPackager.value,
                      hint: const Text(
                        "Select Packager",
                        style: TextStyle(fontSize: 12),
                      ),
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      items:
                          controller.packagerList
                              .map(
                                (String value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (n) => controller.selectedPackager.value = n,
                    ),
                  ),
                ),

                if (controller.isConditionSale.value) ...[
                  const SizedBox(width: 16),
                  Container(width: 1, height: 25, color: Colors.grey.shade300),
                  const SizedBox(width: 16),
                  // Courier Dropdown
                  Container(
                    height: 40,
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.selectedCourier.value,
                        hint: const Text(
                          "Select Courier",
                          style: TextStyle(fontSize: 12),
                        ),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        items:
                            controller.courierList
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => controller.selectedCourier.value = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 140,
                    child: _erpInput(
                      controller.challanC,
                      "Challan No",
                      icon: Icons.receipt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: _erpInput(
                      controller.cartonsC,
                      "Carton Qty",
                      isNumber: true,
                      icon: Icons.inventory_2,
                    ),
                  ),
                  if (controller.selectedCourier.value == 'Other') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _erpInput(
                        controller.otherCourierC,
                        "Custom Courier Name",
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  // ... (Rest of the UI code remains exactly the same as you provided) ...
  // [I am omitting the unchanged parts to save space, but you should keep them]

  // --- 3. EXPANDED PAYMENT SECTION ---
  Widget _buildExpandedPaymentSection(LiveSalesController controller) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CASH BLOCK
            Expanded(
              flex: 2,
              child: Container(
                height: 85,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withOpacity(0.5),
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.money, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "CASH PAYMENT",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    _erpPaymentInput(
                      controller.cashC,
                      "Received Amount",
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // MOBILE BANKING BLOCK
            Expanded(
              flex: 5,
              child: Container(
                height: 85,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50.withOpacity(0.3),
                  border: Border.all(color: Colors.pink.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.mobile_friendly,
                          size: 18,
                          color: Colors.pink,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "MOBILE BANKING",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // BKASH
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _erpPaymentInput(
                                  controller.bkashC,
                                  "Bkash Amt",
                                  Colors.pink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 6,
                                child: _erpInput(
                                  controller.bkashNumberC,
                                  "Bkash No (017..)",
                                  icon: Icons.phone_android,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // NAGAD
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _erpPaymentInput(
                                  controller.nagadC,
                                  "Nagad Amt",
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 6,
                                child: _erpInput(
                                  controller.nagadNumberC,
                                  "Nagad No (016..)",
                                  icon: Icons.phone_android,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            // BANK BLOCK
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.3),
                  border: Border.all(color: Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: _erpPaymentInput(
                        controller.bankC,
                        "Bank Amt",
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _erpInput(
                        controller.bankNameC,
                        "Bank Name (e.g. City Bank)",
                        icon: Icons.business,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _erpInput(
                        controller.bankAccC,
                        "Acc No / Trx ID",
                        icon: Icons.numbers,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // DISCOUNT BLOCK
            Expanded(
              flex: 2,
              child: TextField(
                controller: controller.discountC,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: "DISCOUNT",
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  prefixText: "- ",
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) {
                  controller.discountVal.value = double.tryParse(v) ?? 0.0;
                  controller.updatePaymentCalculations();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 4. CART & SEARCH ---
  Widget _buildCartSection(
    LiveSalesController controller,
    RxString searchQuery,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Header & Search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "SALE ORDER (${controller.cart.length})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => Text(
                        "৳${controller.grandTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Cart
                SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (val) => searchQuery.value = val,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Find in Cart (Name or Model)...",
                      prefixIcon: const Icon(
                        Icons.filter_list,
                        size: 18,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cart List
          Expanded(
            child: Obx(() {
              if (controller.cart.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_shopping_cart,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Cart is Empty",
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                );
              }

              // SEARCH FILTER
              final filteredCart =
                  controller.cart.where((item) {
                    final query = searchQuery.value.toLowerCase();
                    return item.product.name.toLowerCase().contains(query) ||
                        item.product.model.toLowerCase().contains(query);
                  }).toList();

              if (filteredCart.isEmpty) {
                return const Center(
                  child: Text("No item found matching query"),
                );
              }

              // UPDATED LOGIC:
              // VIP & AGENT = Fixed Price (Read-only)
              // WHOLESALE = Editable
              bool isPriceFixed =
                  (controller.customerType.value == 'VIP' ||
                      controller.customerType.value == 'AGENT');

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filteredCart.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = filteredCart[index];
                  // Important: Get real index for controller update
                  final originalIndex = controller.cart.indexOf(item);
                  final isLoss = item.isLoss;

                  return Container(
                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.model,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 28,
                                    child: CartPriceEditor(
                                      initialPrice: item.priceAtSale,
                                      isLoss: isLoss,
                                      readOnly: isPriceFixed,
                                      onChanged:
                                          (v) => controller.updateItemPrice(
                                            originalIndex,
                                            v,
                                          ),
                                    ),
                                  ),
                                  if (isLoss)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.warning_amber,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CartQuantityEditor(
                          currentQty: item.quantity.value,
                          maxStock: item.product.stockQty,
                          onIncrease: () {
                            if (item.quantity.value < item.product.stockQty) {
                              item.quantity.value++;
                              controller.cart.refresh();
                              controller.updatePaymentCalculations();
                            }
                          },
                          onDecrease: () {
                            if (item.quantity.value > 1) {
                              item.quantity.value--;
                              controller.cart.refresh();
                              controller.updatePaymentCalculations();
                            } else {
                              controller.cart.removeAt(originalIndex);
                              controller.updatePaymentCalculations();
                            }
                          },
                          onSubmit:
                              (v) =>
                                  controller.updateQuantity(originalIndex, v),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            "৳${item.subtotal.toStringAsFixed(0)}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),

          // Cart Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Obx(() {
                  double paid = controller.totalPaidInput.value;
                  double due = controller.grandTotal - paid;
                  String lbl =
                      due > 0
                          ? "DUE AMOUNT"
                          : (paid > controller.grandTotal
                              ? "CHANGE RETURN"
                              : "PAID");
                  Color clr = due > 0 ? Colors.red : Colors.green;
                  double val = due > 0 ? due : (paid - controller.grandTotal);
                  if (paid == controller.grandTotal) val = 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Paid: ৳${paid.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: clr.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$lbl: ৳${val.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: clr,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Obx(
                    () => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            controller.isConditionSale.value
                                ? Colors.deepOrange
                                : const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed:
                          controller.isProcessing.value
                              ? null
                              : controller.finalizeSale,
                      icon:
                          controller.isProcessing.value
                              ? const SizedBox.shrink()
                              : const Icon(
                                Icons.print,
                                size: 20,
                                color: Colors.white,
                              ),
                      label:
                          controller.isProcessing.value
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                controller.isConditionSale.value
                                    ? "PROCESS CHALLAN"
                                    : "COMPLETE INVOICE",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
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

  // --- 5. PRODUCT TABLE (LEFT SIDE) ---
  Widget _productInventoryTable(LiveSalesController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Table Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: Colors.black87,
                ),
                const SizedBox(width: 10),
                const Text(
                  "PRODUCT CATALOG",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 250,
                  height: 40,
                  child: TextField(
                    onChanged: (v) => controller.productCtrl.search(v),
                    decoration: InputDecoration(
                      hintText: "Search Name / Model / Code...",
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Headers
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    "PRODUCT NAME",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "MODEL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "STOCK",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "RATE",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SizedBox(width: 50),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: Obx(() {
              if (controller.productCtrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView.separated(
                itemCount: controller.productCtrl.allProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = controller.productCtrl.allProducts[index];
                  final stockColor =
                      p.stockQty == 0
                          ? Colors.red
                          : (p.stockQty < 5 ? Colors.orange : Colors.green);

                  return Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => controller.addToCart(p),
                      hoverColor: Colors.blue.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.model,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: stockColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.stockQty.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: stockColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Obx(() {
                                // Decide which price to show in the list based on selection
                                double price;
                                if (controller.customerType.value == "AGENT") {
                                  price = p.agent;
                                } else {
                                  // VIP & Wholesale both use base wholesale price
                                  price = p.wholesale;
                                }
                                return Text(
                                  "৳${price.toStringAsFixed(0)}",
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 40,
                              height: 30,
                              child: ElevatedButton(
                                onPressed: () => controller.addToCart(p),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.blue.shade50,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // Pagination Footer
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => Text(
                    "Page ${controller.currentPage} of ${controller.totalPages}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: controller.prevPage,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: controller.nextPage,
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  // --- HELPER: ERP STYLE INPUTS ---
  Widget _erpInput(
    TextEditingController c,
    String hint, {
    bool isNumber = false,
    bool highlight = false,
    IconData? icon,
    Color? fillColor,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon:
              icon != null ? Icon(icon, size: 16, color: Colors.grey) : null,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          filled: true,
          fillColor: fillColor ?? Colors.white,
        ),
      ),
    );
  }

  Widget _erpPaymentInput(TextEditingController c, String label, Color color) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          prefixText: "৳ ",
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOGIC WIDGETS
// ---------------------------------------------------------------------------

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
    return Container(
      width: 90,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onDecrease,
            child: Container(
              width: 28,
              alignment: Alignment.center,
              color: Colors.grey.shade100,
              child: const Icon(Icons.remove, size: 14),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (v) => widget.onSubmit(v),
            ),
          ),
          InkWell(
            onTap: widget.onIncrease,
            child: Container(
              width: 28,
              alignment: Alignment.center,
              color: Colors.grey.shade100,
              child: const Icon(Icons.add, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CartPriceEditor extends StatefulWidget {
  final double initialPrice;
  final bool isLoss;
  final bool readOnly;
  final Function(String) onChanged;

  const CartPriceEditor({
    super.key,
    required this.initialPrice,
    required this.isLoss,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  State<CartPriceEditor> createState() => _CartPriceEditorState();
}

class _CartPriceEditorState extends State<CartPriceEditor> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialPrice.toStringAsFixed(0));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onChanged(_ctrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant CartPriceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPrice != oldWidget.initialPrice && !_focusNode.hasFocus) {
      _ctrl.text = widget.initialPrice.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: widget.readOnly,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color:
            widget.isLoss
                ? Colors.red
                : (widget.readOnly ? Colors.grey : Colors.blue),
      ),
      decoration: InputDecoration(
        prefixText: "৳",
        prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border:
            widget.readOnly ? InputBorder.none : const UnderlineInputBorder(),
      ),
      onSubmitted: (v) {
        if (!widget.readOnly) widget.onChanged(v);
      },
    );
  }
}