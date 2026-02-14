// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Live%20order/salemodel.dart';
// CHANGE THIS IMPORT if your controller file is named differently
import '../Stock/model.dart';
class LiveOrderSalesPage extends StatelessWidget {
  const LiveOrderSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    final controller = Get.put(LiveSalesController());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // Left Side: Product Table
          Expanded(flex: 6, child: _ProductTableSection(controller)),

          // Right Side: Cart & Checkout
          Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(-8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(controller),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeToggle(controller),
                        const SizedBox(height: 20),
                        _buildCustomerSection(controller),
                        const SizedBox(height: 20),
                        _buildCartSection(
                          controller,
                        ), // UPDATED with Price Editor Logic
                        const SizedBox(height: 20),
                        _buildPaymentSection(controller),
                        const SizedBox(height: 20),
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

  Widget _buildHeader(LiveSalesController controller) {
    return Obx(
      () => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color:
              controller.isConditionSale.value
                  ? const Color(0xFFC2410C) // Orange-700
                  : const Color(0xFF1E293B), // Slate-800
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                controller.isConditionSale.value
                    ? Icons.local_shipping_outlined
                    : Icons.point_of_sale,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                controller.isConditionSale.value
                    ? "CONDITION SALE & CHALLAN"
                    : "CHECKOUT & BILLING",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODE TOGGLE ---
  Widget _buildModeToggle(LiveSalesController controller) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              controller.isConditionSale.value
                  ? Colors.orange.shade50
                  : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                controller.isConditionSale.value
                    ? Colors.orange.shade200
                    : Colors.blue.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isConditionSale.value
                      ? "Condition / Courier Mode"
                      : "Direct Sales Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color:
                        controller.isConditionSale.value
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                  ),
                ),
                Text(
                  controller.isConditionSale.value
                      ? "Generates Challan & Ledger"
                      : "Generates Invoice & Payment",
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        controller.isConditionSale.value
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            Switch(
              value: controller.isConditionSale.value,
              activeColor: Colors.deepOrange,
              activeTrackColor: Colors.orange.shade200,
              inactiveThumbColor: Colors.blue.shade700,
              inactiveTrackColor: Colors.blue.shade200,
              onChanged: (val) {
                controller.isConditionSale.value = val;
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. CUSTOMER & LOGISTICS INFO ---
  Widget _buildCustomerSection(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person_outline, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text(
                "Customer & Logistics",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Type Tabs
          Obx(() {
            return Row(
              children:
                  ["Retailer", "Agent", "Debtor"].map((type) {
                    bool isSelected = controller.customerType.value == type;
                    bool isDisabled =
                        controller.isConditionSale.value && type == "Debtor";

                    if (isDisabled) return const SizedBox.shrink();

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => controller.customerType.value = type,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          }),
          const SizedBox(height: 16),

          Obx(() {
            return Column(
              children: [
                // --- SECTION A: CUSTOMER IDENTITY ---
                if (controller.customerType.value == "Debtor" &&
                    !controller.isConditionSale.value)
                  // 1. DEBTOR SEARCH
                  Column(
                    children: [
                      TextField(
                        controller: controller.debtorPhoneSearch,
                        decoration: InputDecoration(
                          labelText: "Search Debtor Database",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon:
                              controller.debtorPhoneSearch.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
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
                                    e.name.toLowerCase().contains(
                                      v.toLowerCase(),
                                    ),
                              );
                          controller.selectedDebtor.value = match;
                        },
                      ),
                      const SizedBox(height: 10),
                      if (controller.selectedDebtor.value != null)
                        _buildSelectedDebtorCard(controller)
                      else if (controller.debtorPhoneSearch.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Debtor not found",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  // 2. MANUAL ENTRY
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _miniTextField(
                              controller.nameC,
                              "Customer Name",
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniTextField(
                              controller.phoneC,
                              "Phone Number",
                              Icons.phone,
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _miniTextField(
                        controller.shopC,
                        "Shop Name / Reference (Optional)",
                        Icons.store,
                      ),
                      // --- ADDRESS VISIBLE FOR EVERYONE ---
                      const SizedBox(height: 12),
                      _miniTextField(
                        controller.addressC,
                        "Customer Address",
                        Icons.location_on,
                      ),
                    ],
                  ),

                // --- SECTION B: PACKAGER ---
                const SizedBox(height: 12),
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedPackager.value,
                      hint: Row(
                        children: const [
                          Icon(
                            Icons.inventory_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Select Packager / Packed By",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                      items:
                          controller.packagerList.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    value,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (newValue) {
                        controller.selectedPackager.value = newValue;
                      },
                    ),
                  ),
                ),

                // --- SECTION C: LOGISTICS (CONDITION ONLY EXTRA FIELDS) ---
                if (controller.isConditionSale.value) ...[
                  const SizedBox(height: 20),
                  const Divider(thickness: 1, height: 1),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Condition Logistics Details",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Courier Dropdown
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 45,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: controller.selectedCourier.value,
                                  hint: const Text(
                                    "Select Courier Service",
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
                                  },
                                ),
                              ),
                            ),
                            if (controller.selectedCourier.value != null &&
                                controller.selectedCourier.value != 'Other')
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  "Current Due: ৳${controller.calculatedCourierDue.value}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                          ],
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
                      const SizedBox(width: 10),
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
                  if (controller.selectedCourier.value == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _miniTextField(
                        controller.otherCourierC,
                        "Enter Transport / Courier Name",
                        Icons.local_shipping,
                      ),
                    ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // --- UPDATED DEBTOR CARD ---
  Widget _buildSelectedDebtorCard(LiveSalesController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 18,
                  child: const Icon(
                    Icons.person,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.selectedDebtor.value!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        controller.selectedDebtor.value!.phone,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.green),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "PREVIOUS BALANCE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "৳ ${controller.totalPreviousDue.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. UPDATED CART SECTION WITH PRICE EDITOR & VALIDATION LOGIC ---
  Widget _buildCartSection(LiveSalesController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Item Details & Rate",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  "Subtotal",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            if (controller.cart.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    "Cart is empty",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
              );
            }

            // Determine if Price should be editable
            // Requirement: Agent & Debtor = Fixed Price
            bool isPriceFixed =
                (controller.customerType.value == 'Agent' ||
                    controller.customerType.value == 'Debtor');

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.cart.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = controller.cart[index];
                final bool isLoss = item.isLoss;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  "Rate: ",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                // --- EDITABLE PRICE FIELD ---
                                SizedBox(
                                  width: 80,
                                  height: 30,
                                  child: CartPriceEditor(
                                    initialPrice: item.priceAtSale,
                                    isLoss: isLoss,
                                    readOnly:
                                        isPriceFixed, // Pass the lock state
                                    onChanged:
                                        (val) => controller.updateItemPrice(
                                          index,
                                          val,
                                        ),
                                  ),
                                ),
                                if (isLoss)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
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
                        onDecrease: () {
                          if (item.quantity.value > 1) {
                            item.quantity.value--;
                            controller.cart.refresh();
                            controller.updatePaymentCalculations();
                          } else {
                            controller.cart.removeAt(index);
                            controller.updatePaymentCalculations();
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
                              "Only ${item.product.stockQty} items available",
                            );
                          }
                        },
                        onSubmit:
                            (val) => controller.updateQuantity(index, val),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "৳${item.subtotal.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isLoss ? Colors.red : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // --- 3. PAYMENT SECTION ---
  Widget _buildPaymentSection(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                      : "Payment Details",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. CASH
          _moneyInput(controller.cashC, "Cash Received", Colors.green),
          const SizedBox(height: 12),

          // 2. MOBILE BANKING
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _moneyInput(controller.bkashC, "Bkash Amt", Colors.pink),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _detailInput(
                  controller.bkashNumberC,
                  "Bkash Number (017...)",
                  Icons.phone_android,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _moneyInput(
                  controller.nagadC,
                  "Nagad Amt",
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _detailInput(
                  controller.nagadNumberC,
                  "Nagad Number (016...)",
                  Icons.phone_android,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. BANKING
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _moneyInput(
                  controller.bankC,
                  "Bank Amt",
                  Colors.blue.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _detailInput(
                  controller.bankNameC,
                  "Bank Name (e.g. City Bank)",
                  Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailInput(
            controller.bankAccC,
            "Bank Account Number / Transaction ID",
            Icons.numbers,
          ),

          const SizedBox(height: 16),

          // Payment Summary
          Obx(() {
            String label = "";
            Color color = Colors.black;

            if (controller.isConditionSale.value) {
              double due =
                  controller.grandTotal - controller.totalPaidInput.value;
              double collect = due > 0 ? due : 0;
              label = "Courier Collect: ৳${collect.toStringAsFixed(0)}";
              color = Colors.deepOrange;
            } else {
              if (controller.totalPaidInput.value > controller.grandTotal &&
                  controller.customerType.value != "Debtor") {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.isConditionSale.value
                            ? "Total Advance"
                            : "Total Received",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "৳${controller.totalPaidInput.value.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- UPDATED BOTTOM TOTAL BAR ---
  Widget _buildBottomTotalBar(LiveSalesController controller) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Discount Adjustment",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: controller.discountC,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "0.00",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(),
                    prefixText: "- ",
                  ),
                  onChanged: (v) {
                    controller.discountVal.value = double.tryParse(v) ?? 0.0;
                    controller.updatePaymentCalculations();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // CURRENT INVOICE TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                controller.customerType.value == "Debtor"
                    ? "THIS INVOICE"
                    : "GRAND TOTAL",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: controller.customerType.value == "Debtor" ? 14 : 16,
                  color: Colors.black87,
                ),
              ),
              Obx(
                () => Text(
                  "৳ ${controller.grandTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize:
                        controller.customerType.value == "Debtor" ? 18 : 24,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),

          // DEBTOR TOTAL PAYABLE BREAKDOWN
          Obx(() {
            if (controller.customerType.value == "Debtor" &&
                controller.selectedDebtor.value != null &&
                !controller.isConditionSale.value) {
              double totalPayable =
                  controller.grandTotal + controller.totalPreviousDue;

              return Column(
                children: [
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "(+) Previous Balance",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "৳ ${controller.totalPreviousDue.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "TOTAL PAYABLE",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          "৳ ${totalPayable.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),

          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      controller.isConditionSale.value
                          ? Colors.deepOrange
                          : const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: (controller.isConditionSale.value
                          ? Colors.deepOrange
                          : const Color(0xFF2563EB))
                      .withOpacity(0.4),
                ),
                onPressed:
                    controller.isProcessing.value
                        ? null
                        : controller.finalizeSale,
                child:
                    controller.isProcessing.value
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              "PROCESSING...",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              controller.isConditionSale.value
                                  ? Icons.print
                                  : Icons.check_circle,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              controller.isConditionSale.value
                                  ? "PROCESS & PRINT CHALLAN"
                                  : "COMPLETE SALE & INVOICE",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _miniTextField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: c,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
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
        labelStyle: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        prefixText: "৳",
        filled: true,
        fillColor: color.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  Widget _detailInput(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueGrey),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PRODUCT TABLE SECTION
// ---------------------------------------------------------------------------
class _ProductTableSection extends StatelessWidget {
  final LiveSalesController controller;
  const _ProductTableSection(this.controller);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTopHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 10),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildTableHeader(),
                  Expanded(
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
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No products loaded",
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
                  _buildPaginationControls(),
                ],
              ),
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
                "PRODUCT INVENTORY",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.circle, color: Colors.green, size: 10),
                  SizedBox(width: 6),
                  Text(
                    "System Online & Ready",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 350,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
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
              hintText: "Search Model, Name, Code...",
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
              prefixIcon: Icon(
                Icons.search,
                size: 22,
                color: Color(0xFF2563EB),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "ITEM NAME",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "BRAND",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "MODEL",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "RATE (BDT)",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => Text(
              "Page ${controller.currentPage} of ${controller.totalPages}",
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: controller.prevPage,
                icon: const Icon(Icons.chevron_left, color: Colors.black),
              ),
              IconButton(
                onPressed: controller.nextPage,
                icon: const Icon(Icons.chevron_right, color: Colors.black),
              ),
            ],
          ),
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
    const double nameSize = 13;
    const double metaSize = 12;
    const double smallSize = 11;

    Color stockColor =
        product.stockQty == 0
            ? Colors.red
            : (product.stockQty < 5 ? Colors.orange : Colors.green);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => controller.addToCart(product),
        hoverColor: Colors.blue.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: nameSize,
                    color: Color(0xFF334155),
                  ),
                ),
              ),

              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.model,
                      style: const TextStyle(
                        fontSize: smallSize,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // 4. Stock
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: stockColor),
                    const SizedBox(width: 8),
                    Text(
                      product.stockQty.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: metaSize,
                        color: stockColor,
                      ),
                    ),
                  ],
                ),
              ),
              // 5. Rate
              Expanded(
                flex: 2,
                child: Obx(() {
                  double price =
                      (controller.customerType.value == "Retailer")
                          ? product.wholesale
                          : product.agent;

                  bool isLoss = price < product.avgPurchasePrice;

                  return Text(
                    "৳ ${price.toStringAsFixed(2)}",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: metaSize,
                      color: isLoss ? Colors.red : Colors.black87,
                    ),
                  );
                }),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 30,
                height: 30,
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
                    size: 18,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onDecrease,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(Icons.remove, color: Colors.red.shade400, size: 16),
            ),
          ),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          SizedBox(
            width: 40,
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
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          InkWell(
            onTap: widget.onIncrease,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(Icons.add, color: Colors.green.shade400, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// --- UPDATED WIDGET: CART PRICE EDITOR ---
class CartPriceEditor extends StatefulWidget {
  final double initialPrice;
  final bool isLoss;
  final bool readOnly; // ADDED THIS
  final Function(String) onChanged;

  const CartPriceEditor({
    super.key,
    required this.initialPrice,
    required this.isLoss,
    this.readOnly = false, // ADDED THIS
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
    // Use toStringAsFixed(0) if you prefer integers, or (2) for decimals
    _ctrl = TextEditingController(text: widget.initialPrice.toStringAsFixed(0));
    _focusNode = FocusNode();

    // Submit when focus is lost
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onChanged(_ctrl.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CartPriceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update text if the value changed externally (e.g. switching customer type)
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
      textAlign: TextAlign.left,
      readOnly: widget.readOnly, // USE THE PARAMETER
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        // Shows RED text if selling below cost
        color:
            widget.isLoss
                ? Colors.red
                : (widget.readOnly
                    ? Colors.grey.shade700
                    : Colors.blue.shade800),
      ),
      decoration: InputDecoration(
        prefixText: "৳",
        prefixStyle: TextStyle(
          fontSize: 13,
          color: widget.readOnly ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        isDense: true,
        // Visual feedback for Read Only state
        filled: widget.readOnly,
        fillColor: widget.readOnly ? Colors.grey.shade100 : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border:
            widget.readOnly
                ? InputBorder
                    .none // No underline if fixed
                : UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
        focusedBorder:
            widget.readOnly
                ? InputBorder.none
                : const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
      ),
      onSubmitted: (val) {
        if (!widget.readOnly) {
          widget.onChanged(val);
        }
      },
    );
  }
}