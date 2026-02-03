// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Sale%20Return/salereturnController.dart';

class SaleReturnPage extends StatelessWidget {
  // Inject the updated controller
  final controller = Get.put(SaleReturnController());

  SaleReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50 background
      appBar: AppBar(
        title: const Text(
          "Sales Return & Adjustment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. SEARCH SECTION
          _buildSearchSection(),

          const SizedBox(height: 10),

          // 2. MAIN CONTENT (Order Details & Item Selection)
          Expanded(
            child: Obx(() {
              // Loading State
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              // Empty State
              if (controller.orderData.value == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_return_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Scan Invoice or enter last 4 digits",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Data Loaded
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfoCard(controller.orderData.value!),
                    const SizedBox(height: 24),

                    const Text(
                      "SELECT ITEMS TO RETURN",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.blueGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List of Items from Invoice
                    ...controller.orderItems.map((item) {
                      String pid = item['productId'].toString();
                      int maxQty = int.tryParse(item['qty'].toString()) ?? 0;
                      int returnQty = controller.returnQuantities[pid] ?? 0;
                      double price =
                          double.tryParse(item['saleRate'].toString()) ?? 0.0;
                      String currentDest =
                          controller.returnDestinations[pid] ?? "Local";

                      // Hide fully returned items (qty 0)
                      if (maxQty <= 0) return const SizedBox.shrink();

                      return _buildReturnItemCard(
                        pid,
                        item['name'],
                        item['model'],
                        maxQty,
                        returnQty,
                        price,
                        currentDest,
                      );
                    }),
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

  // --- WIDGETS ---

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: controller.searchController,
                decoration: InputDecoration(
                  hintText: "Enter Full ID or Last 4 Digits...",
                  prefixIcon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.blueGrey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
                onSubmitted: (val) => controller.smartSearch(val),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed:
                  () =>
                      controller.smartSearch(controller.searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text(
                "Search",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(Map<String, dynamic> data) {
    // Detect Condition
    bool isCondition = data['isCondition'] == true;
    String courierName = data['courierName'] ?? "";

    // Calculate Due
    double due = 0.0;
    if (isCondition) {
      due = double.tryParse(data['courierDue'].toString()) ?? 0.0;
    } else {
      var payMap = data['paymentDetails'];
      if (payMap != null && payMap['due'] != null) {
        due = double.tryParse(payMap['due'].toString()) ?? 0.0;
      } else {
        double gt = double.tryParse(data['grandTotal'].toString()) ?? 0;
        double paid = 0;
        if (payMap != null && payMap['actualReceived'] != null) {
          paid = double.tryParse(payMap['actualReceived'].toString()) ?? 0;
        }
        due = gt - paid;
      }
    }
    if (due < 0) due = 0;
    bool isPaid = due <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "BILL TO",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['customerName'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      data['customerPhone'] ?? "",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "INV: ${data['invoiceId']}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey,
                      ),
                    ),
                    // Show Courier Name if Condition
                    if (isCondition)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Via: $courierName",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isPaid
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      isPaid ? "PAID" : "DUE: ৳${due.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color:
                            isPaid
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  if (isCondition)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        "Condition Sale",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoBadge(
                Icons.calendar_today,
                data['date'] != null
                    ? data['date'].toString().split(' ')[0]
                    : 'N/A',
              ),
              const SizedBox(width: 12),
              _infoBadge(
                Icons.receipt_long,
                "Total: ৳${double.tryParse(data['grandTotal'].toString())?.toStringAsFixed(0) ?? '0'}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItemCard(
    String pid,
    String name,
    String model,
    int maxQty,
    int returnQty,
    double price,
    String currentDest,
  ) {
    bool isReturning = returnQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReturning ? Colors.red.shade200 : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isReturning
                    ? Colors.red.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Text(
                      "Sold Rate: ৳$price",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      "QTY: $maxQty",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // QTY CONTROL
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => controller.decrementReturn(pid),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text(
                        "$returnQty",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => controller.incrementReturn(pid, maxQty),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // CONDITIONAL: Show Destination Dropdown & Refund Value if Returning
          if (isReturning) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Destination Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _getDestColor(currentDest).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getDestColor(currentDest).withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentDest,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: _getDestColor(currentDest),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getDestColor(currentDest),
                      ),
                      items:
                          ["Local", "Air", "Sea"]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text("Return to: $e"),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) controller.setDestination(pid, val);
                      },
                    ),
                  ),
                ),

                // Refund Value
                Row(
                  children: [
                    const Text(
                      "Refund: ",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "৳${(returnQty * price).toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      if (controller.orderData.value == null) return const SizedBox.shrink();

      double refundTotal = controller.currentReturnTotal;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TOTAL REFUND / ADJUSTMENT",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "৳ ${refundTotal.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _confirmReturnDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
              child: const Text(
                "PROCESS RETURN",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // --- HELPERS ---

  Color _getDestColor(String dest) {
    switch (dest) {
      case "Local":
        return Colors.green;
      case "Air":
        return Colors.orange;
      case "Sea":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _confirmReturnDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                "Confirm Return?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "This will restore stock to the selected destination and reduce the customer's due/payment record.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Deduction Amount",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    Text(
                      "৳${controller.currentReturnTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        controller.processProductReturn();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "CONFIRM",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
  }
}
