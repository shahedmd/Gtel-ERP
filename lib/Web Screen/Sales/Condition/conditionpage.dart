// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:intl/intl.dart';
import 'conditioncontroller.dart';

class ConditionSalesPage extends StatelessWidget {
  const ConditionSalesPage({super.key});

  // Theme Colors (Professional Slate/Blue Theme)
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color alertRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    // Inject Controller
    final ConditionSalesController ctrl = Get.put(ConditionSalesController());

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(context, ctrl),
          _buildStatsTicker(ctrl),
          const SizedBox(height: 10),
          _buildFilters(ctrl),
          Expanded(child: _buildDataTable(ctrl, context)),
        ],
      ),
    );
  }

  // ==============================================================================
  // 1. HEADER (Added Return Button)
  // ==============================================================================
  Widget _buildHeader(BuildContext context, ConditionSalesController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 24,
              color: activeAccent,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Condition Sales & Courier Ledger",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              Text(
                "Track shipments, collect due, and manage returns",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const Spacer(),

          // --- NEW: RETURN BUTTON ---
          ElevatedButton.icon(
            onPressed: () => _showReturnInterface(context, ctrl),
            icon: const Icon(Icons.assignment_return, size: 18),
            label: const Text("PROCESS RETURN"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Total Pending Card
          Obx(
            () => _headerCard(
              "TOTAL COURIER DUE",
              "৳ ${ctrl.totalPendingAmount.value.toStringAsFixed(0)}",
              alertRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // 2. STATS TICKER
  // ==============================================================================
  Widget _buildStatsTicker(ConditionSalesController ctrl) {
    return Obx(() {
      if (ctrl.courierBalances.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children:
              ctrl.courierBalances.entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "৳${e.value.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: darkSlate,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    });
  }

  // ==============================================================================
  // 3. FILTERS
  // ==============================================================================
  Widget _buildFilters(ConditionSalesController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _filterChip(ctrl, "Today"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "This Month"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "This Year"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "All Time"),
          const Spacer(),
          // Search
          Container(
            width: 300,
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (v) => ctrl.searchQuery.value = v,
              decoration: const InputDecoration(
                hintText: "Search Invoice, Phone, Courier...",
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 20, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ConditionSalesController ctrl, String label) {
    return Obx(() {
      bool isSelected = ctrl.selectedFilter.value == label;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => ctrl.selectedFilter.value = label,
        selectedColor: activeAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : darkSlate,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
      );
    });
  }

  // ==============================================================================
  // 4. DATA TABLE
  // ==============================================================================
  Widget _buildDataTable(ConditionSalesController ctrl, BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.filteredOrders.isEmpty)
        return const Center(child: CircularProgressIndicator());
      if (ctrl.filteredOrders.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No condition sales records found",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10)],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      "DATE & INVOICE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "CUSTOMER",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "LOGISTICS",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "TOTAL AMOUNT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "COURIER DUE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "ACTION",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView.separated(
                itemCount: ctrl.filteredOrders.length,
                separatorBuilder:
                    (_, __) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (context, index) {
                  final order = ctrl.filteredOrders[index];
                  return _orderRow(order, context, ctrl);
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _orderRow(
    ConditionOrderModel order,
    BuildContext context,
    ConditionSalesController ctrl,
  ) {
    bool isPaid = order.courierDue <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // 1. Date
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.invoiceId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                    fontSize: 13,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yy, hh:mm a').format(order.date),
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          // 2. Customer
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  order.customerPhone,
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          // 3. Logistics
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    order.courierName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Challan: ${order.challanNo}",
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          // 4. Total
          Expanded(
            flex: 2,
            child: Text(
              "৳${order.grandTotal.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          // 5. Due
          Expanded(
            flex: 2,
            child: Text(
              isPaid ? "CLEARED" : "৳${order.courierDue.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid ? successGreen : alertRed,
                fontSize: 13,
              ),
            ),
          ),
          // 6. Action
          Expanded(
            flex: 2,
            child: Center(
              child:
                  isPaid
                      ? const Icon(
                        Icons.check_circle,
                        color: successGreen,
                        size: 22,
                      )
                      : ElevatedButton(
                        onPressed:
                            () => _showPaymentDialog(context, ctrl, order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          "Collect",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // 5. DIALOGS (Payment & Return)
  // ==============================================================================

  void _showPaymentDialog(
    BuildContext context,
    ConditionSalesController ctrl,
    ConditionOrderModel order,
  ) {
    final amountC = TextEditingController(text: order.courierDue.toString());
    final refC = TextEditingController();
    String method = "Cash";

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Receive from ${order.courierName}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Invoice: ${order.invoiceId}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Due: ৳${order.courierDue}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: alertRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Received Amount",
                  prefixText: "৳ ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: method,
                items:
                    ["Cash", "Bank", "Bkash", "Nagad"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => method = v!,
                decoration: const InputDecoration(
                  labelText: "Payment Method",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: refC,
                decoration: const InputDecoration(
                  labelText: "Reference / Transaction ID",
                  hintText: "Optional",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    double amt = double.tryParse(amountC.text) ?? 0;
                    if (amt > 0) {
                      ctrl.receiveConditionPayment(
                        order: order,
                        receivedAmount: amt,
                        method: method,
                        refNumber: refC.text,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "CONFIRM COLLECTION",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: RETURN INTERFACE ---
  void _showReturnInterface(
    BuildContext context,
    ConditionSalesController ctrl,
  ) {
    ctrl.returnSearchCtrl.clear();
    ctrl.returnOrderData.value = null;
    ctrl.returnOrderItems.clear();

    Get.dialog(
      Dialog(
        backgroundColor: bgGrey,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700, // Wide dialog for better view
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Condition Sales Return",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: darkSlate,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 30),

              // Search Bar inside Dialog
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl.returnSearchCtrl,
                      decoration: const InputDecoration(
                        hintText: "Enter Invoice ID (e.g. GTEL-24...)",
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (val) => ctrl.findInvoiceForReturn(val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(
                    () => ElevatedButton(
                      onPressed:
                          ctrl.isLoading.value
                              ? null
                              : () => ctrl.findInvoiceForReturn(
                                ctrl.returnSearchCtrl.text,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkSlate,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      child:
                          ctrl.isLoading.value
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                "Find Invoice",
                                style: TextStyle(color: Colors.white),
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Results Area
              Expanded(
                child: Obx(() {
                  if (ctrl.returnOrderData.value == null) {
                    return Center(
                      child: Text(
                        "Search for a condition order to process return.",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Invoice Info Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Customer: ${ctrl.returnOrderData.value!['customerName']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Courier: ${ctrl.returnOrderData.value!['courierName']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Items List
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: ctrl.returnOrderItems.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = ctrl.returnOrderItems[index];
                              String pid = item['productId'];
                              int maxQty = int.parse(item['qty'].toString());
                              double price = double.parse(
                                item['saleRate'].toString(),
                              );
                              int retQty = ctrl.returnQuantities[pid] ?? 0;

                              if (maxQty <= 0)
                                return const SizedBox.shrink(); // Hide previously fully returned

                              return Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "Rate: ৳$price",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Qty Control
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            size: 16,
                                          ),
                                          onPressed:
                                              () => ctrl.decrementReturn(pid),
                                          constraints: const BoxConstraints(),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            "$retQty",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => ctrl.incrementReturn(
                                                pid,
                                                maxQty,
                                              ),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      "৳${(retQty * price).toStringAsFixed(0)}",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: alertRed,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Footer Actions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Refund Adjustment",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    "৳ ${ctrl.totalRefundValue.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: alertRed,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => ctrl.processConditionReturn(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alertRed,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "CONFIRM RETURN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
