// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/purchasehistory.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';

class GlobalPurchasePage extends StatelessWidget {
  GlobalPurchasePage({super.key});

  final GlobalPurchaseHistoryController controller = Get.put(
    GlobalPurchaseHistoryController(),
  );
  final DebatorController debtorCtrl = Get.find<DebatorController>();

  static const Color darkSlate = Color(0xFF0F172A);
  static const Color activeBlue = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color borderGrey = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF334155);
  static const Color successGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    if (debtorCtrl.bodies.isEmpty) debtorCtrl.loadBodies();

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history_edu, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Text(
              "Purchase & Payment History",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: darkSlate,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Obx(
            () =>
                controller.isPdfLoading.value
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : TextButton.icon(
                      onPressed: controller.downloadBulkPdf,
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "Export Report",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP ACTION & FILTER BAR
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: borderGrey)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date Filters
                    Row(
                      children: [
                        _filterButton("Daily", HistoryFilter.daily),
                        const SizedBox(width: 8),
                        _filterButton("Monthly", HistoryFilter.monthly),
                        const SizedBox(width: 8),
                        _filterButton("Yearly", HistoryFilter.yearly),
                        const SizedBox(width: 8),
                        _filterButton("Custom", HistoryFilter.custom),
                      ],
                    ),

                    Row(
                      children: [
                        _buildSupplierSearch(),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showMakePaymentDialog(context),
                          icon: const Icon(
                            Icons.payment,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            "Make Payment",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: darkSlate,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => Text(
                          "Period:  ${DateFormat('dd MMM yyyy').format(controller.dateRange.value.start)}  —  ${DateFormat('dd MMM yyyy').format(controller.dateRange.value.end)}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Obx(
                        () => Text(
                          "Total Invoiced Amount: ৳${controller.totalAmount.value.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.white,
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("DATE", style: _headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text("SUPPLIER / DEBTOR", style: _headerStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text("RECORD TYPE", style: _headerStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL AMOUNT",
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    "ACTIONS",
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderGrey, thickness: 1),

          // 3. MAIN LIST VIEW
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.purchaseList.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: activeBlue),
                );
              }
              if (controller.purchaseList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No records found for this period.",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: controller.purchaseList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder:
                    (context, index) =>
                        _buildListItem(context, controller.purchaseList[index]),
              );
            }),
          ),

          // 4. PAGINATION BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: borderGrey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => OutlinedButton.icon(
                    onPressed:
                        controller.isFirstPage.value
                            ? null
                            : controller.prevPage,
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text("Previous Page"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => ElevatedButton(
                    onPressed:
                        controller.hasMore.value ? controller.nextPage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkSlate,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          "Next Page",
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
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

  // --- UI COMPONENTS ---

  Widget _filterButton(String label, HistoryFilter type) {
    return Obx(() {
      bool isActive = controller.activeFilter.value == type;
      return InkWell(
        onTap: () => controller.applyFilter(type),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? darkSlate : Colors.white,
            border: Border.all(color: isActive ? darkSlate : borderGrey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : textDark,
            ),
          ),
        ),
      );
    });
  }

  // ==========================================
  // PERFECTED GLOBAL SEARCH INTEGRATION
  // ==========================================
  Widget _buildSupplierSearch() {
    TextEditingController? searchCtrl;
    return SizedBox(
      width: 250,
      child: Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (option) => option['name'] ?? '',
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            controller.searchSupplier('');
            return const Iterable<Map<String, dynamic>>.empty();
          }
          // Trigger the global controller search
          controller.searchSupplier(textEditingValue.text);
          // Return a dummy list so the optionsViewBuilder overlay shows up
          return const [
            {'dummy': true},
          ];
        },
        onSelected: (selection) {
          controller.setSupplierFilter(selection['id']);
          // Optional: Unfocus keyboard
          FocusManager.instance.primaryFocus?.unfocus();
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 250,
                  maxWidth: 250,
                ),
                child: Obx(() {
                  if (controller.isSearchingSupplier.value) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: activeBlue,
                        ),
                      ),
                    );
                  }
                  if (controller.searchedSuppliers.isEmpty) {
                    return const SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          "No matching suppliers",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: controller.searchedSuppliers.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = controller.searchedSuppliers[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          option['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${option['phone'] ?? ''} ${option['address'] ?? ''}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          searchCtrl?.text = option['name'];
                          onSelected(option);
                        },
                      );
                    },
                  );
                }),
              ),
            ),
          );
        },
        fieldViewBuilder: (
          context,
          controllerRef,
          focusNode,
          onFieldSubmitted,
        ) {
          searchCtrl = controllerRef;
          return TextField(
            controller: controllerRef,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: "Filter by Supplier...",
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.grey,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  searchCtrl?.clear();
                  controller.setSupplierFilter(
                    null,
                  ); // Clear filter & reload all
                },
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderGrey),
              ),
              filled: true,
              fillColor: bgGrey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildListItem(BuildContext context, Map<String, dynamic> item) {
    DateTime date =
        (item['date'] is Timestamp)
            ? (item['date'] as Timestamp).toDate()
            : DateTime.now();
    String type = (item['type'] ?? 'unknown').toString().toLowerCase();
    double amount =
        double.tryParse((item['totalAmount'] ?? item['amount']).toString()) ??
        0.0;
    String debtorId = item['debtorId'];

    bool isInvoice = type == 'invoice';
    Color typeColor =
        isInvoice
            ? activeBlue
            : (type == 'adjustment' ? Colors.orange : successGreen);
    IconData typeIcon =
        isInvoice
            ? Icons.inventory_2
            : (type == 'adjustment' ? Icons.sync_alt : Icons.payments);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Obx(
              () => Text(
                controller.debtorNameCache[debtorId] ?? "Loading...",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(typeIcon, size: 12, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "৳${amount.toStringAsFixed(2)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isInvoice ? textDark : successGreen,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child:
                isInvoice
                    ? IconButton(
                      icon: const Icon(Icons.visibility, color: activeBlue),
                      tooltip: "View & Edit Invoice",
                      onPressed: () => _showInvoiceDetailsDialog(context, item),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MAKE PAYMENT DIALOG (Updated Search)
  // ==========================================
  void _showMakePaymentDialog(BuildContext context) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final methodC = "Cash".obs;
    Map<String, dynamic>? selectedDialogSupplier;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Make Payment to Supplier",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const Divider(height: 30),

              const Text(
                "Select Supplier",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option['name'] ?? '',
                optionsBuilder: (val) {
                  if (val.text.isEmpty) {
                    controller.searchSupplier('');
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  controller.searchSupplier(val.text);
                  return const [
                    {'dummy': true},
                  ];
                },
                onSelected: (selection) => selectedDialogSupplier = selection,
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 400,
                        ),
                        child: Obx(() {
                          if (controller.isSearchingSupplier.value) {
                            return const SizedBox(
                              height: 50,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (controller.searchedSuppliers.isEmpty) {
                            return const SizedBox(
                              height: 50,
                              child: Center(
                                child: Text("No matching suppliers found"),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: controller.searchedSuppliers.length,
                            separatorBuilder:
                                (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option =
                                  controller.searchedSuppliers[index];
                              return ListTile(
                                title: Text(
                                  option['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(option['phone'] ?? ''),
                                onTap: () => onSelected(option),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  );
                },
                fieldViewBuilder: (context, ctrl, focus, onSub) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: InputDecoration(
                      hintText: "Search supplier by name, phone...",
                      prefixIcon: const Icon(Icons.business, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountC,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Payment Amount (৳)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Obx(
                      () => DropdownButtonFormField<String>(
                        value: methodC.value,
                        decoration: InputDecoration(
                          labelText: "Method",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items:
                            ["Cash", "Bank", "Bkash", "Nagad"]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => methodC.value = v!,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteC,
                decoration: InputDecoration(
                  labelText: "Note / Ref No.",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedDialogSupplier == null) {
                        Get.snackbar(
                          "Error",
                          "Please select a supplier first.",
                        );
                        return;
                      }
                      double amt = double.tryParse(amountC.text) ?? 0;
                      if (amt <= 0) {
                        Get.snackbar("Error", "Enter a valid amount.");
                        return;
                      }
                      controller.makePayment(
                        debtorId: selectedDialogSupplier!['id'],
                        debtorName: selectedDialogSupplier!['name'],
                        amount: amt,
                        method: methodC.value,
                        note: noteC.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      "Confirm Payment",
                      style: TextStyle(color: Colors.white),
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

  // ==========================================
  // VIEW & EDIT INVOICE DIALOG
  // ==========================================
  void _showInvoiceDetailsDialog(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    bool isEditing = false;
    List<Map<String, dynamic>> editedItems = List<Map<String, dynamic>>.from(
      item['items'] ?? [],
    );

    // Dynamic Controllers for Edit Mode
    List<TextEditingController> qtyCtrls = [];
    List<TextEditingController> costCtrls = [];

    void initControllers() {
      qtyCtrls =
          editedItems
              .map((e) => TextEditingController(text: e['qty'].toString()))
              .toList();
      costCtrls =
          editedItems
              .map((e) => TextEditingController(text: e['cost'].toString()))
              .toList();
    }

    initControllers();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setState) {
              double currentTotal = 0;
              if (isEditing) {
                for (int i = 0; i < editedItems.length; i++) {
                  int q = int.tryParse(qtyCtrls[i].text) ?? 0;
                  double c = double.tryParse(costCtrls[i].text) ?? 0;
                  currentTotal += (q * c);
                }
              } else {
                currentTotal =
                    double.tryParse(item['totalAmount'].toString()) ?? 0;
              }

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? "EDIT PURCHASE INVOICE"
                                    : "PURCHASE INVOICE DETAILS",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: darkSlate,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Supplier: ${controller.debtorNameCache[item['debtorId']] ?? "Unknown"}",
                                style: const TextStyle(
                                  color: activeBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (!isEditing)
                                OutlinedButton.icon(
                                  onPressed:
                                      () => setState(() => isEditing = true),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text("Edit Invoice"),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Get.back(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 30),

                      // Items Table
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: borderGrey),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Container(
                              color: bgGrey,
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text("ITEM", style: _headerStyle),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text("QTY", style: _headerStyle),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text("COST", style: _headerStyle),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "TOTAL",
                                      textAlign: TextAlign.right,
                                      style: _headerStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: editedItems.length,
                                separatorBuilder:
                                    (c, i) => const Divider(height: 1),
                                itemBuilder: (c, i) {
                                  var p = editedItems[i];
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "${p['model'] ?? ''} | Loc: ${p['location'] ?? 'Local'}",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child:
                                              isEditing
                                                  ? TextField(
                                                    controller: qtyCtrls[i],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    onChanged:
                                                        (v) => setState(() {}),
                                                  )
                                                  : Text(
                                                    p['qty'].toString(),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child:
                                              isEditing
                                                  ? TextField(
                                                    controller: costCtrls[i],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    onChanged:
                                                        (v) => setState(() {}),
                                                  )
                                                  : Text(
                                                    "৳${p['cost']}",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "৳${isEditing ? ((int.tryParse(qtyCtrls[i].text) ?? 0) * (double.tryParse(costCtrls[i].text) ?? 0)).toStringAsFixed(2) : p['subtotal']}",
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: activeBlue,
                                            ),
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
                      ),
                      const SizedBox(height: 20),

                      // Footer / Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Grand Total: ৳${currentTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: darkSlate,
                            ),
                          ),
                          if (isEditing)
                            ElevatedButton.icon(
                              onPressed: () {
                                // Compile new items
                                for (int i = 0; i < editedItems.length; i++) {
                                  int q = int.tryParse(qtyCtrls[i].text) ?? 0;
                                  double c =
                                      double.tryParse(costCtrls[i].text) ?? 0;
                                  editedItems[i]['qty'] = q;
                                  editedItems[i]['cost'] = c;
                                  editedItems[i]['subtotal'] = q * c;
                                }
                                controller.editPurchase(
                                  debtorId: item['debtorId'],
                                  purchaseId: item['id'],
                                  oldItems: List<Map<String, dynamic>>.from(
                                    item['items'],
                                  ),
                                  newItems: editedItems,
                                  oldTotal:
                                      double.tryParse(
                                        item['totalAmount'].toString(),
                                      ) ??
                                      0,
                                  newTotal: currentTotal,
                                );
                              },
                              icon: const Icon(
                                Icons.save,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text(
                                "Save Changes",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                            )
                          else
                            Obx(
                              () => ElevatedButton.icon(
                                onPressed:
                                    controller.isSinglePdfLoading.value
                                        ? null
                                        : () => controller
                                            .generateSingleInvoicePdf(item),
                                icon:
                                    controller.isSinglePdfLoading.value
                                        ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.download,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                label: const Text(
                                  "Download Bill",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkSlate,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: textDark,
    letterSpacing: 0.5,
  );
}