// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:intl/intl.dart';
import 'conditioncontroller.dart';

class ConditionSalesPage extends StatelessWidget {
  const ConditionSalesPage({super.key});

  // Theme Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color alertRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    // Ensure controller is loaded
    final ConditionSalesController ctrl = Get.put(ConditionSalesController());

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(context, ctrl),
          _buildStatsTicker(ctrl),
          const SizedBox(height: 10),
          _buildFilters(context, ctrl),
          Expanded(child: _buildDataTable(ctrl, context)),
        ],
      ),
    );
  }

  // ==============================================================================
  // 1. HEADER (Updated: Removed Return Button)
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
                "Track shipments, collect due, and print invoices",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const Spacer(),

          // REMOVED: Process Return Button
          const SizedBox(width: 20),
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
  Widget _buildFilters(BuildContext context, ConditionSalesController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _filterChip(ctrl, "Today"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "This Month"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "Last Month"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "This Year"),
          const SizedBox(width: 8),
          _filterChip(ctrl, "All Time"),
          const SizedBox(width: 8),
          _customDateChip(context, ctrl),
          const Spacer(),
          // Search Bar
          Container(
            width: 320,
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
                hintText: "Search Invoice ID, Phone or Challan...",
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
        onSelected: (v) {
          ctrl.customDateRange.value =
              null; // Reset custom if predefined selected
          ctrl.selectedFilter.value = label;
        },
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

  Widget _customDateChip(BuildContext context, ConditionSalesController ctrl) {
    return Obx(() {
      bool isCustom = ctrl.selectedFilter.value == "Custom";
      String label = "Custom Date";
      if (isCustom && ctrl.customDateRange.value != null) {
        label =
            "${DateFormat('dd/MM').format(ctrl.customDateRange.value!.start)} - ${DateFormat('dd/MM').format(ctrl.customDateRange.value!.end)}";
      }

      return ActionChip(
        label: Text(label),
        onPressed: () async {
          DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2022),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  primaryColor: activeAccent,
                  colorScheme: const ColorScheme.light(primary: activeAccent),
                  buttonTheme: const ButtonThemeData(
                    textTheme: ButtonTextTheme.primary,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            ctrl.customDateRange.value = picked;
            ctrl.selectedFilter.value = "Custom";
          }
        },
        backgroundColor: isCustom ? activeAccent : Colors.white,
        labelStyle: TextStyle(
          color: isCustom ? Colors.white : darkSlate,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isCustom ? Colors.transparent : Colors.grey.shade300,
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
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.filteredOrders.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No condition sales records found for this period",
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
                    flex: 3,
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
    bool isPaid = order.courierDue <= 1.0; // Tolerance for float

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
                SelectableText(
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
                SelectableText(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Challan: ${order.challanNo}",
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showEditChallanDialog(context, ctrl, order),
                      child: const Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ],
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
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Print Button
                IconButton(
                  onPressed: () => ctrl.printInvoice(order),
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 20,
                    color: darkSlate,
                  ),
                  tooltip: "Download/Print Invoice",
                ),
                const SizedBox(width: 8),
                // Collect Button / Status
                if (isPaid)
                  const Icon(Icons.check_circle, color: successGreen, size: 22)
                else
                  ElevatedButton(
                    onPressed: () => _showPaymentDialog(context, ctrl, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditChallanDialog(
    BuildContext context,
    ConditionSalesController ctrl,
    ConditionOrderModel order,
  ) {
    final cController = TextEditingController(text: order.challanNo);
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Challan Number",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: cController,
                decoration: const InputDecoration(
                  labelText: "New Challan No",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                  ),
                  onPressed: () {
                    ctrl.updateChallanNumber(
                      order.invoiceId,
                      order.customerPhone,
                      cController.text,
                    );
                  },
                  child: const Text(
                    "Update",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        child: StatefulBuilder(
          builder: (context, setState) {
            // Dynamically change the reference input label based on payment method
            String refLabel = "Reference Note";
            String refHint = "Optional";
            if (method == "Bank") {
              refLabel = "Bank Name & Account No.";
              refHint = "Required (e.g., BRAC 1029...)";
            } else if (method == "Bkash") {
              refLabel = "Bkash Number";
              refHint = "Required (e.g., 017...)";
            } else if (method == "Nagad") {
              refLabel = "Nagad Number";
              refHint = "Required (e.g., 017...)";
            }

            return Container(
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
                      color: darkSlate, // Assuming you have this defined
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgGrey, // Assuming you have this defined
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
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
                                  color:
                                      textMuted, // Assuming you have this defined
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Due: ৳${order.courierDue}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: alertRed, // Assuming you have this defined
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          method = v;
                          refC.clear(); // Clear reference when changing method
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Payment Method",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: refC,
                    decoration: InputDecoration(
                      labelText: refLabel,
                      hintText: refHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Obx(
                      () => ElevatedButton(
                        // Disable button while loading to prevent double-clicks
                        onPressed:
                            ctrl.isLoading.value
                                ? null
                                : () {
                                  double amt =
                                      double.tryParse(amountC.text) ?? 0;

                                  // Validation
                                  if (amt <= 0) {
                                    Get.snackbar(
                                      "Error",
                                      "Please enter a valid amount",
                                    );
                                    return;
                                  }

                                  if (method != "Cash" &&
                                      refC.text.trim().isEmpty) {
                                    Get.snackbar(
                                      "Error",
                                      "$refLabel is required for $method payments",
                                    );
                                    return;
                                  }

                                  ctrl.receiveConditionPayment(
                                    order: order,
                                    receivedAmount: amt,
                                    method: method,
                                    refNumber: refC.text.trim(),
                                  );
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              successGreen, // Assuming you have this defined
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            ctrl.isLoading.value
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
