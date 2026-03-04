// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'salereturnController.dart'; // Ensure this path is correct

class SaleReturnPage extends StatelessWidget {
  final controller = Get.put(SaleReturnController());

  SaleReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100 background
      appBar: AppBar(
        title: const Text(
          "Edit Invoice & Return",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade300, height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. SEARCH SECTION
          _buildSearchSection(),

          // 2. MAIN CONTENT (Order Details & Item Selection)
          Expanded(
            child: Obx(() {
              // Loading State
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              // Empty State
              if (controller.orderData.value == null) {
                return _buildEmptyState();
              }

              // Data Loaded
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfoCard(controller.orderData.value!),
                    const SizedBox(height: 24),

                    // Header for Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "INVOICE ITEMS",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProductSheet(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Item"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF3B82F6,
                            ), // Blue-500
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Interactive List of Items
                    ...List.generate(controller.modifiedItems.length, (index) {
                      var item = controller.modifiedItems[index];
                      int currentQty = item['qty'] as int;

                      // Hide completely removed items from UI
                      if (currentQty <= 0) return const SizedBox.shrink();

                      return _buildEditableItemCard(index, item);
                    }),

                    const SizedBox(height: 100), // padding for bottom bar
                  ],
                ),
              );
            }),
          ),

          // 3. BOTTOM ACTION BAR
          _buildBottomBar(context),
        ],
      ),
    );
  }

  // ========================================================================
  // WIDGETS
  // ========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Ready to Edit",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan an invoice barcode or enter\nthe ID to modify items or process returns.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: controller.searchController,
                decoration: const InputDecoration(
                  hintText: "Enter Full ID or Last 4 Digits...",
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 15,
                  ),
                ),
                onSubmitted: (val) => controller.smartSearch(val),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  () =>
                      controller.smartSearch(controller.searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), // Slate-900
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
              ),
              child: const Text(
                "Search",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(Map<String, dynamic> data) {
    bool isCondition = data['isCondition'] == true;
    String courierName = data['courierName'] ?? "";
    double originalTotal =
        double.tryParse(data['grandTotal'].toString()) ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "CUSTOMER INFO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['customerName'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['customerPhone'] ?? "",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "INV: ${data['invoiceId']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCondition)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          border: Border.all(color: Colors.purple.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Condition via $courierName",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Original Total",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "৳${originalTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItemCard(int index, Map<String, dynamic> item) {
    int qty = item['qty'];
    double price = item['saleRate'];
    double subtotal = item['subtotal'];
    String pid = item['productId'].toString();
    String currentDest = controller.returnDestinations[pid] ?? 'Local';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Delete Button
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => controller.removeProduct(index),
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.shade600,
                size: 20,
              ),
              tooltip: "Remove Product",
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (item['model'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item['model'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "Rate: ৳$price",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const Text(
                      "  |  ",
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                    Text(
                      "Sub: ৳${subtotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Destination Dropdown for Return Location
                Row(
                  children: [
                    const Text(
                      "Return to: ",
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentDest,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B82F6),
                          ),
                          items:
                              ['Local', 'Sea', 'Air'].map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controller.setDestination(pid, val);
                              // Trigger UI update
                              controller.returnDestinations.refresh();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // QTY CONTROL
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => controller.decreaseQty(index),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    "$qty",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => controller.increaseQty(index),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: Color(0xFF10B981), // Green-500
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

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      if (controller.orderData.value == null) return const SizedBox.shrink();

      double originalTotal =
          double.tryParse(
            controller.orderData.value!['grandTotal'].toString(),
          ) ??
          0.0;
      double newTotal = controller.currentModifiedTotal;
      double delta = newTotal - originalTotal;

      bool isRefund = delta < 0;
      bool isExtraDue = delta > 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NEW TOTAL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "৳ ${newTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (isRefund)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Refund: ৳${delta.abs().toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    if (isExtraDue)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Extra Bill: +৳${delta.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed:
                    () => _confirmUpdateDialog(
                      context,
                      originalTotal,
                      newTotal,
                      delta,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "UPDATE INVOICE",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _confirmUpdateDialog(
    BuildContext context,
    double oldTotal,
    double newTotal,
    double delta,
  ) {
    String dominantMethod = 'Cash';
    if (controller.orderData.value != null) {
      var pd = controller.orderData.value!['paymentDetails'] ?? {};
      double c = double.tryParse(pd['cash']?.toString() ?? '0') ?? 0;
      double b = double.tryParse(pd['bkash']?.toString() ?? '0') ?? 0;
      double n = double.tryParse(pd['nagad']?.toString() ?? '0') ?? 0;
      double bk = double.tryParse(pd['bank']?.toString() ?? '0') ?? 0;

      if (b > c && b >= n && b >= bk) {
        dominantMethod = 'Bkash';
      } else if (n > c && n >= b && n >= bk) {
        dominantMethod = 'Nagad';
      } else if (bk > c && bk >= b && bk >= n) {
        dominantMethod = 'Bank';
      }
    }

    double extraPaid = delta > 0 ? delta : 0.0;
    String selectedMethod = dominantMethod;
    final extraPaidCtrl = TextEditingController(
      text: extraPaid.toStringAsFixed(0),
    );

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            // FIX: Added ConstrainedBox to prevent Dialog from stretching too wide
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            delta < 0
                                ? Colors.red.shade50
                                : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        delta < 0
                            ? Icons.assignment_return_rounded
                            : Icons.edit_document,
                        size: 40,
                        color: delta < 0 ? Colors.redAccent : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Confirm Update",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Summary Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            "Old Total:",
                            "৳${oldTotal.toStringAsFixed(0)}",
                          ),
                          const Divider(height: 16),
                          _buildSummaryRow(
                            "New Total:",
                            "৳${newTotal.toStringAsFixed(0)}",
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DYNAMIC SECTION: Collect Extra Bill if Delta is Positive
                    if (delta > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Extra Amount Due:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                Text(
                                  "৳${delta.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: extraPaidCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Amount Paying Now",
                                      labelStyle: const TextStyle(fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 0,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<String>(
                                    value: selectedMethod,
                                    decoration: InputDecoration(
                                      labelText: "Via",
                                      labelStyle: const TextStyle(fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 0,
                                          ),
                                    ),
                                    items:
                                        ['Cash', 'Bkash', 'Nagad', 'Bank'].map((
                                          m,
                                        ) {
                                          return DropdownMenuItem(
                                            value: m,
                                            child: Text(
                                              m,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged:
                                        (val) => setState(
                                          () => selectedMethod = val!,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "*If customer isn't paying right now, change the amount to 0 (It will be added as Due).",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // If Delta is Negative (Refund)
                    else if (delta < 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          "You will refund ৳${delta.abs().toStringAsFixed(0)} and restore stock for returned items.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Get.back(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Get.back();
                              controller.processEditInvoice(
                                extraCollectedAmount:
                                    delta > 0
                                        ? (double.tryParse(
                                              extraPaidCtrl.text,
                                            ) ??
                                            0.0)
                                        : 0.0,
                                extraCollectedMethod: selectedMethod,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "CONFIRM",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddProductBottomSheet(),
    );
  }
}

// ========================================================================
// CUSTOM BOTTOM SHEET (Search Existing OR Create New)
// ========================================================================

class _AddProductBottomSheet extends StatefulWidget {
  const _AddProductBottomSheet();

  @override
  State<_AddProductBottomSheet> createState() => _AddProductBottomSheetState();
}

class _AddProductBottomSheetState extends State<_AddProductBottomSheet> {
  final SaleReturnController controller = Get.find<SaleReturnController>();

  bool _isCreatingNew = false;

  // Search State
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Manual Form State
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: "0.0");
  final _qtyCtrl = TextEditingController(text: "1");

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await controller.searchStockProducts(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _promptQtyAndAdd(Map<String, dynamic> product) {
    final qtyC = TextEditingController(text: "1");
    final rateC = TextEditingController(
      text: product['buyingPrice']?.toString() ?? "0",
    ); // Default rate

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // FIX: Added ConstrainedBox for width handling
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add ${product['name']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Quantity",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Selling Rate (৳)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    controller.addNewProductToInvoice(
                      product,
                      int.tryParse(qtyC.text) ?? 1,
                      double.tryParse(rateC.text) ?? 0.0,
                      double.tryParse(
                            product['buyingPrice']?.toString() ?? "0",
                          ) ??
                          0.0,
                    );
                    Get.back(); // Close dialog
                    Get.back(); // Close bottom sheet
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Add to Invoice",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Toggle Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreatingNew = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            !_isCreatingNew
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          "Search Existing",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                !_isCreatingNew
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreatingNew = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _isCreatingNew
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          "Create New",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _isCreatingNew
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Body Content based on Toggle
          Expanded(
            child: _isCreatingNew ? _buildCreateNewForm() : _buildSearchList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search by Name or Model...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_isSearching)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "No products found.\nTry a different search or create new.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var p = _searchResults[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  title: Text(
                    p['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(p['model'] ?? ''),
                  trailing: const Icon(Icons.add_circle, color: Colors.blue),
                  onTap: () => _promptQtyAndAdd(p),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCreateNewForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: "Product Name",
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idCtrl,
                  decoration: InputDecoration(
                    labelText: "Barcode (Optional)",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Qty",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Sale Rate (৳)",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Cost Rate (৳)",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.isEmpty || _rateCtrl.text.isEmpty) {
                  Get.snackbar("Error", "Name and Sale Rate are required.");
                  return;
                }
                Get.back(); // Close bottom sheet

                if (_idCtrl.text.trim().isEmpty) {
                  controller.createAndAddNewProductToInvoice(
                    name: _nameCtrl.text,
                    model: "",
                    qty: int.tryParse(_qtyCtrl.text) ?? 1,
                    saleRate: double.tryParse(_rateCtrl.text) ?? 0.0,
                    costRate: double.tryParse(_costCtrl.text) ?? 0.0,
                  );
                } else {
                  controller.addNewProductToInvoice(
                    {"id": _idCtrl.text, "name": _nameCtrl.text, "model": ""},
                    int.tryParse(_qtyCtrl.text) ?? 1,
                    double.tryParse(_rateCtrl.text) ?? 0.0,
                    double.tryParse(_costCtrl.text) ?? 0.0,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Green
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Create & Add to Invoice",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}