// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:intl/intl.dart';

class OnHoldShipmentPage extends StatelessWidget {
  const OnHoldShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ShipmentController controller = Get.find<ShipmentController>();
    final ProductController productController = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "ON HOLD / MISSING ITEMS",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Obx(
              () => DropdownButton<String>(
                value:
                    controller.filterOnHoldCarrier.value.isEmpty
                        ? null
                        : controller.filterOnHoldCarrier.value,
                hint: const Text("Filter Carrier"),
                underline: Container(),
                items: [
                  const DropdownMenuItem(
                    value: "",
                    child: Text("All Carriers"),
                  ),
                  ...controller.carrierList.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged:
                    (val) => controller.filterOnHoldCarrier.value = val ?? "",
              ),
            ),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "These items were ordered but not received. "
                      "Click 'RELEASE' to add recovered stock back to inventory.",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Table
            Expanded(
              child: Obx(() {
                if (controller.filteredOnHoldItems.isEmpty) {
                  return const Center(
                    child: Text(
                      "No items on hold.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Purchase Date")),
                      DataColumn(label: Text("Shipment ID")),
                      DataColumn(label: Text("Carrier")),
                      DataColumn(label: Text("Product")),
                      DataColumn(label: Text("On Hold Qty")),
                      DataColumn(label: Text("Action")),
                    ],
                    rows:
                        controller.filteredOnHoldItems.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(item.purchaseDate),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.shipmentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(Text(item.carrier)),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.productModel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${item.missingQty}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.undo, size: 16),
                                  label: const Text("RELEASE"),
                                  onPressed:
                                      () => _showReleaseDialog(
                                        context,
                                        controller,
                                        productController,
                                        item,
                                      ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showReleaseDialog(
    BuildContext context,
    ShipmentController controller,
    ProductController productController,
    dynamic item,
  ) {
    // Dialog এর নিজস্ব local state — StatefulBuilder দিয়ে manage
    Warehouse? selectedWarehouse;
    final qtyCtrl = TextEditingController(text: item.missingQty.toString());
    final locationCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    "Release to Stock",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product info chip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productModel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Total on hold: ${item.missingQty} pcs  •  ${item.shipmentName}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── QTY TO RELEASE ──────────────────────────
                    const Text(
                      "Qty to Release",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Decrement
                        IconButton(
                          onPressed: () {
                            final cur = int.tryParse(qtyCtrl.text) ?? 1;
                            if (cur > 1) {
                              qtyCtrl.text = (cur - 1).toString();
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              // Live feedback — partial নাকি full release
                              helperText: _releaseHelperText(
                                qtyCtrl.text,
                                item.missingQty,
                              ),
                              helperStyle: TextStyle(
                                color:
                                    _isPartialRelease(
                                          qtyCtrl.text,
                                          item.missingQty,
                                        )
                                        ? Colors.orange
                                        : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onChanged: (val) {
                              // clamp to max
                              final parsed = int.tryParse(val) ?? 0;
                              if (parsed > item.missingQty) {
                                qtyCtrl.text = item.missingQty.toString();
                                qtyCtrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: qtyCtrl.text.length),
                                );
                              }
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Increment
                        IconButton(
                          onPressed: () {
                            final cur = int.tryParse(qtyCtrl.text) ?? 0;
                            if (cur < item.missingQty) {
                              qtyCtrl.text = (cur + 1).toString();
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: Colors.green,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        // Quick fill — All button
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            qtyCtrl.text = item.missingQty.toString();
                            setDialogState(() {});
                          },
                          child: const Text(
                            "ALL",
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── WAREHOUSE DROPDOWN ───────────────────────
                    const Text(
                      "Destination Warehouse",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Warehouse?>(
                      value: selectedWarehouse,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: "Optional",
                        prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<Warehouse?>(
                          value: null,
                          child: Text(
                            "No specific warehouse",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ...productController.activeWarehouses.map(
                          (w) => DropdownMenuItem<Warehouse?>(
                            value: w,
                            child: Text(w.name),
                          ),
                        ),
                      ],
                      onChanged: (w) {
                        setDialogState(() {
                          selectedWarehouse = w;
                          // Warehouse change হলে location clear করো
                          if (w == null) locationCtrl.clear();
                        });
                      },
                    ),

                    // ── LOCATION — warehouse select হলেই দেখাবে ─
                    if (selectedWarehouse != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Location in Warehouse",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: "e.g. Rack A3, Shelf 2",
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    qtyCtrl.dispose();
                    locationCtrl.dispose();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text("CANCEL"),
                ),
                Obx(
                  () => ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    icon:
                        controller.isLoading.value
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.check, size: 16),
                    label: Text(
                      controller.isLoading.value
                          ? "Releasing..."
                          : _isPartialRelease(qtyCtrl.text, item.missingQty)
                          ? "PARTIAL RELEASE"
                          : "RELEASE ALL",
                    ),
                    onPressed:
                        controller.isLoading.value
                            ? null
                            : () async {
                              final qty = int.tryParse(qtyCtrl.text) ?? 0;
                              if (qty <= 0) {
                                Get.snackbar(
                                  "Error",
                                  "Quantity must be at least 1",
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              Navigator.of(ctx).pop();
                              await controller.resolveOnHoldItem(
                                item,
                                releaseQty: qty,
                                warehouseId: selectedWarehouse?.id,
                                warehouseLocation:
                                    locationCtrl.text.trim().isEmpty
                                        ? null
                                        : locationCtrl.text.trim(),
                              );
                              qtyCtrl.dispose();
                              locationCtrl.dispose();
                            },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper — partial release কিনা
  bool _isPartialRelease(String qtyText, int maxQty) {
    final qty = int.tryParse(qtyText) ?? 0;
    return qty > 0 && qty < maxQty;
  }

  // Helper — qty input এর নিচে hint text
  String _releaseHelperText(String qtyText, int maxQty) {
    final qty = int.tryParse(qtyText) ?? 0;
    if (qty <= 0) return "Enter a quantity";
    if (qty >= maxQty) return "Full release — item will be cleared";
    final remaining = maxQty - qty;
    return "Partial — $remaining pcs will remain on hold";
  }
}
