// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:intl/intl.dart';
import 'conditioncontroller.dart';

class ConditionSalesPage extends StatelessWidget {
  const ConditionSalesPage({super.key});

  // Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final ConditionSalesController ctrl = Get.put(ConditionSalesController());

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(ctrl),
          _buildStatsTicker(ctrl),
          const SizedBox(height: 10),
          _buildFilters(ctrl),
          Expanded(child: _buildDataTable(ctrl, context)),
        ],
      ),
    );
  }

  // 1. HEADER
  Widget _buildHeader(ConditionSalesController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.local_shipping, size: 28, color: darkSlate),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Condition Sales Manager",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              Text(
                "Track shipments and collect payments from couriers",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const Spacer(),
          // Total Pending Card
          Obx(
            () => _headerCard(
              "TOTAL COURIER DUE",
              "৳ ${ctrl.totalPendingAmount.value.toStringAsFixed(0)}",
              Colors.redAccent,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 2. STATS TICKER (Horizontal Scroll of Courier Balances)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "৳${e.value.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkSlate,
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

  // 3. FILTERS
  Widget _buildFilters(ConditionSalesController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Time Filters
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
            width: 250,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (v) => ctrl.searchQuery.value = v,
              decoration: const InputDecoration(
                hintText: "Search Invoice, Phone...",
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 18),
                contentPadding: EdgeInsets.only(bottom: 10),
              ),
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
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
      );
    });
  }

  // 4. DATA TABLE
  Widget _buildDataTable(ConditionSalesController ctrl, BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value)
        return const Center(child: CircularProgressIndicator());
      if (ctrl.filteredOrders.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 10),
              Text("No condition sales found for this period"),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Date & Invoice",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Customer",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Logistics",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Total",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Due",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Action",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: ListView.separated(
                itemCount: ctrl.filteredOrders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          // 1. Date & Inv
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
                  ),
                ),
                Text(
                  DateFormat('dd MMM yy').format(order.date),
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          // 2. Customer
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName, style: const TextStyle(fontSize: 13)),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                Text(
                  "Challan: ${order.challanNo}",
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
                Text(
                  "Cartons: ${order.cartons}",
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          // 4. Total
          Expanded(
            flex: 1,
            child: Text(
              "৳${order.grandTotal.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // 5. Due
          Expanded(
            flex: 1,
            child: Text(
              isPaid ? "PAID" : "৳${order.courierDue.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green : Colors.red,
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
                        color: Colors.green,
                        size: 20,
                      )
                      : ElevatedButton.icon(
                        onPressed:
                            () => _showPaymentDialog(context, ctrl, order),
                        icon: const Icon(Icons.payments, size: 14),
                        label: const Text("Receive"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. PAYMENT DIALOG
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
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
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Invoice: ${order.invoiceId} | Customer: ${order.customerName}",
                style: const TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),

              const Text(
                "Amount Received",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: "৳ ",
                ),
              ),
              const SizedBox(height: 15),

              const Text(
                "Payment Method",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: method,
                items:
                    ["Cash", "Bank", "Bkash", "Nagad"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => method = v!,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              const Text(
                "Reference / Note",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: refC,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Optional",
                ),
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 45,
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
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    "CONFIRM PAYMENT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
}
