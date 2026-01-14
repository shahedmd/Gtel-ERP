// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/shipmentdialog.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';
import 'package:gtel_erp/Stock/controller.dart';

const Color kDarkSlate = Color(0xFF1E293B);
const Color kPrimary = Color(0xFF2563EB);
const Color kBg = Color(0xFFF8FAFC);

class ShipmentPage extends StatelessWidget {
  const ShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ShipmentController controller = Get.put(ShipmentController());
    final ProductController productController = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          "Shipment Dashboard",
          style: TextStyle(color: kDarkSlate, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kDarkSlate),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        icon: const Icon(Icons.add_location_alt),
        label: const Text("Create Shipment"),
        onPressed:
            () => _openCreateManifestScreen(
              context,
              controller,
              productController,
            ),
      ),
      body: Column(
        children: [
          // 1. DASHBOARD TOTALS (Goal #1)
          _buildDashboard(controller),

          // 2. SHIPMENT LIST
          Expanded(
            child: Obx(() {
              if (controller.shipments.isEmpty) {
                return const Center(child: Text("No Data"));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.shipments.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder:
                    (ctx, i) => _ShipmentCard(
                      item: controller.shipments[i],
                      controller: controller,
                    ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(ShipmentController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => _summaryCard(
                "On The Way",
                ctrl.totalOnWayValue,
                Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => _summaryCard(
                "Completed",
                ctrl.totalCompletedValue,
                Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    final fmt = NumberFormat.compactCurrency(symbol: '৳').format(value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt,
            style: TextStyle(
              color: kDarkSlate,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  // --- CREATE SCREEN (UI Logic) ---
  void _openCreateManifestScreen(
    BuildContext context,
    ShipmentController ctrl,
    ProductController prodCtrl,
  ) {
    ctrl.currentManifestItems.clear();
    ctrl.shipmentNameCtrl.clear();
    ctrl.totalCartonCtrl.text = "0";
    ctrl.totalWeightCtrl.text = "0";
    ctrl.shipmentDateInput.value = DateTime.now(); // Departure Date
    ctrl.searchCtrl.clear();
    prodCtrl.allProducts.clear();

    Get.to(
      () => Scaffold(
        appBar: AppBar(
          title: const Text(
            "New Shipment Manifest",
            style: TextStyle(color: kDarkSlate),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: kDarkSlate),
          actions: [
            Obx(
              () => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    "Total: ৳${ctrl.currentManifestTotalCost.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save, color: kPrimary),
              onPressed: ctrl.saveShipmentToFirestore,
            ),
          ],
        ),
        body: Row(
          children: [
            // Left: List
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildManifestHeader(context, ctrl), // Date Picker is here
                  Expanded(
                    child: Obx(
                      () => ListView.separated(
                        itemCount: ctrl.currentManifestItems.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = ctrl.currentManifestItems[i];
                          return ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              "${item.productModel} | Ctn: ${item.cartonNo}",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "৳${item.totalItemCost.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => ctrl.removeFromManifest(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Right: Search
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: ctrl.searchCtrl,
                        decoration: const InputDecoration(
                          hintText: "Search...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => prodCtrl.search(val),
                      ),
                    ),
                    Expanded(
                      child: Obx(() {
                        if (prodCtrl.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ListView.builder(
                          itemCount: prodCtrl.allProducts.length,
                          itemBuilder: (ctx, i) {
                            final p = prodCtrl.allProducts[i];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text(p.model),
                              trailing: const Icon(
                                Icons.add_circle,
                                color: kPrimary,
                              ),
                              onTap:
                                  () => showShipmentEntryDialog(
                                    p,
                                    ctrl,
                                    prodCtrl,
                                  ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      fullscreenDialog: true,
    );
  }

  Widget _buildManifestHeader(BuildContext context, ShipmentController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: ctrl.shipmentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Shipment Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) ctrl.shipmentDateInput.value = d;
                  },
                  child: Obx(
                    () => InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ship Date",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat(
                          'yyyy-MM-dd',
                        ).format(ctrl.shipmentDateInput.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl.totalCartonCtrl,
                  decoration: const InputDecoration(
                    labelText: "Cartons",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl.totalWeightCtrl,
                  decoration: const InputDecoration(
                    labelText: "Weight",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final ShipmentModel item;
  final ShipmentController controller;
  const _ShipmentCard({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.simpleCurrency(name: '৳', decimalDigits: 0);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.shipmentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _statusChip(item.isReceived),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Goal #4: Show Both Dates
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dateRow("Ship Date:", item.createdDate, Colors.grey),
                    if (item.arrivalDate != null)
                      _dateRow("Arrival:", item.arrivalDate!, Colors.green),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${item.totalCartons} Cartons",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      fmt.format(item.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kDarkSlate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!item.isReceived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkSlate,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text("RECEIVE STOCK"),
                  onPressed: () => _showReceiveDialog(context, item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // REPLACE THE OLD _showReceiveDialog WITH THIS VERSION
  void _showReceiveDialog(BuildContext context, ShipmentModel item) {
    // We use a reactive variable for the dialog state
    final Rx<DateTime> selectedDate = DateTime.now().obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warehouse, size: 40, color: kDarkSlate),
              const SizedBox(height: 15),
              const Text(
                "Confirm Stock Entry",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Select the date these goods arrived at the warehouse:",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // DATE PICKER BUTTON (Safe & Crash Proof)
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) selectedDate.value = d;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month, color: kPrimary),
                      const SizedBox(width: 10),
                      Obx(
                        () => Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDarkSlate,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Get.back();
                        controller.receiveShipmentFast(
                          item,
                          selectedDate.value,
                        );
                      },
                      child: const Text("CONFIRM"),
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

  Widget _dateRow(String label, DateTime d, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            "$label ${DateFormat('MM-dd').format(d)}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            done
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        done ? "RECEIVED" : "ON WAY",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: done ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}
