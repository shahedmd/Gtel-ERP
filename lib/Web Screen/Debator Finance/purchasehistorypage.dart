// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/purchasehistory.dart';
import 'package:intl/intl.dart';

class GlobalPurchasePage extends StatelessWidget {
  GlobalPurchasePage({super.key});

  final controller = Get.put(GlobalPurchaseHistoryController());

  // --- ERP BLACK THEME ---
  static const Color erpBlack = Color(0xFF111827);
  static const Color erpGrey = Color(0xFFF3F4F6);
  static const Color erpBorder = Color(0xFFE5E7EB);
  static const Color activeBlue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: erpGrey,
      appBar: AppBar(
        title: const Text(
          "All Purchases History",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: erpBlack,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Obx(() {
            return controller.isPdfLoading.value
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
                : IconButton(
                  onPressed: controller.downloadBulkPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: "Download Period Report",
                );
          }),
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
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
                const SizedBox(height: 12),

                // Active Range Display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: erpBlack,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => Text(
                          "${DateFormat('dd MMM yyyy').format(controller.dateRange.value.start)}  —  ${DateFormat('dd MMM yyyy').format(controller.dateRange.value.end)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Obx(
                        () => Text(
                          "Total: Tk ${controller.totalAmount.value.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
          const Divider(height: 1, color: erpBorder),

          // 2. HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("DATE", style: _headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text("SUPPLIER / DEBTOR", style: _headerStyle),
                ),
                Expanded(flex: 2, child: Text("TYPE", style: _headerStyle)),
                Expanded(
                  flex: 2,
                  child: Text(
                    "AMOUNT",
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    "ACT",
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: erpBorder),

          // 3. LIST VIEW
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: erpBlack),
                );
              }
              if (controller.purchaseList.isEmpty) {
                return const Center(
                  child: Text("No purchases found in this period."),
                );
              }
              return ListView.separated(
                itemCount: controller.purchaseList.length,
                separatorBuilder:
                    (c, i) => const Divider(height: 1, color: erpBorder),
                itemBuilder: (context, index) {
                  return _buildListItem(
                    context,
                    controller.purchaseList[index],
                  );
                },
              );
            }),
          ),

          // 4. PAGINATION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => ElevatedButton.icon(
                    onPressed:
                        controller.isFirstPage.value
                            ? null
                            : controller.prevPage,
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text("Previous"),
                    style: _blackButtonStyle,
                  ),
                ),
                Obx(
                  () => ElevatedButton(
                    onPressed:
                        controller.hasMore.value ? controller.nextPage : null,
                    style: _blackButtonStyle,
                    child: Row(
                      children: const [
                        Text("Next Page"),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 14),
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

  // --- WIDGETS ---

  Widget _filterButton(String label, HistoryFilter type) {
    return Expanded(
      child: Obx(() {
        bool isActive = controller.activeFilter.value == type;
        return OutlinedButton(
          onPressed: () => controller.applyFilter(type),
          style: OutlinedButton.styleFrom(
            backgroundColor: isActive ? erpBlack : Colors.white,
            foregroundColor: isActive ? Colors.white : erpBlack,
            side: const BorderSide(color: erpBlack),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        );
      }),
    );
  }

  Widget _buildListItem(BuildContext context, Map<String, dynamic> item) {
    DateTime date = (item['date'] as Timestamp).toDate();
    String type = (item['type'] ?? 'unknown').toString();
    double amount =
        double.tryParse((item['totalAmount'] ?? item['amount']).toString()) ??
        0.0;

    // Identity Logic
    String debtorId = item['debtorId'];

    bool isInvoice = type == 'invoice';
    Color typeColor = isInvoice ? activeBlue : Colors.green;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM').format(date),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),

          // Supplier Name (Reactive from Cache)
          Expanded(
            flex: 3,
            child: Obx(() {
              String name =
                  controller.debtorNameCache[debtorId] ?? "Loading...";
              return Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: erpBlack,
                ),
              );
            }),
          ),

          // Type Badge
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Expanded(
            flex: 2,
            child: Text(
              amount.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isInvoice ? erpBlack : Colors.green[700],
              ),
            ),
          ),

          // Action (View Details)
          SizedBox(
            width: 50,
            child:
                isInvoice
                    ? IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => _showDetailsDialog(context, item),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- DETAILS DIALOG ---
  void _showDetailsDialog(BuildContext context, Map<String, dynamic> item) {
    List items = item['items'] ?? [];
    String debtorName =
        controller.debtorNameCache[item['debtorId']] ?? "Unknown";

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(20),
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
                            "PURCHASE DETAILS",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: erpBlack,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "From: $debtorName",
                            style: TextStyle(
                              color: activeBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Get.back(),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // Product History Table
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: erpBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.grey[100],
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "ITEM / MODEL",
                                  style: _headerStyle,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text("QTY", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "COST",
                                  textAlign: TextAlign.right,
                                  style: _headerStyle,
                                ),
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
                            itemCount: items.length,
                            separatorBuilder:
                                (c, i) => const Divider(height: 1),
                            itemBuilder: (c, i) {
                              var p = items[i];
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            p['model'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        p['qty'].toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['cost'].toString(),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['subtotal'].toString(),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
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

                  // Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Grand Total: ${item['totalAmount']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Obx(
                        () => ElevatedButton.icon(
                          style: _blackButtonStyle,
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
                                  : const Icon(Icons.download, size: 16),
                          label: const Text("Download Bill"),
                          onPressed:
                              controller.isSinglePdfLoading.value
                                  ? null
                                  : () =>
                                      controller.generateSingleInvoicePdf(item),
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

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
  );

  static final ButtonStyle _blackButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: erpBlack,
    foregroundColor: Colors.white,
    disabledBackgroundColor: Colors.grey[300],
    disabledForegroundColor: Colors.grey[500],
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );
}