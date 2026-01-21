// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/shipmentdialog.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';


// --- THEME CONSTANTS ---
const Color kDarkSlate = Color(0xFF1E293B);
const Color kPrimary = Color(0xFF2563EB);
const Color kSuccess = Color(0xFF10B981);
const Color kWarning = Color(0xFFF59E0B);
const Color kBg = Color(0xFFF1F5F9);

// ==============================================================================
// 1. SHIPMENT PAGE (UI)
// ==============================================================================

class ShipmentPage extends StatelessWidget {
  const ShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject Controllers
    final ShipmentController controller = Get.put(ShipmentController());
    final ProductController productController = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          "LOGISTICS DASHBOARD",
          style: TextStyle(
            color: kDarkSlate,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kDarkSlate),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              productController.fetchProducts();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        icon: const Icon(Icons.add_location_alt),
        label: const Text(
          "NEW SHIPMENT",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed:
            () => _openCreateManifestScreen(
              context,
              controller,
              productController,
            ),
      ),
      body: Column(
        children: [
          // 1. DASHBOARD METRICS
          _buildDashboardMetrics(controller),

          // 2. SHIPMENT LIST
          Expanded(
            child: Obx(() {
              if (controller.shipments.isEmpty) {
                return _buildEmptyState();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No Shipments Found",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(ShipmentController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => _MetricCard(
                title: "ON THE WAY",
                value: ctrl.totalOnWayDisplay,
                color: kWarning,
                icon: Icons.sailing,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(
              () => _MetricCard(
                title: "COMPLETED",
                value: ctrl.totalCompletedDisplay,
                color: kSuccess,
                icon: Icons.check_circle_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CREATE MANIFEST SCREEN ---
  void _openCreateManifestScreen(
    BuildContext context,
    ShipmentController ctrl,
    ProductController prodCtrl,
  ) {
    // Reset State
    ctrl.currentManifestItems.clear();
    ctrl.shipmentNameCtrl.clear();
    ctrl.totalCartonCtrl.text = "0";
    ctrl.totalWeightCtrl.text = "0";
    ctrl.shipmentDateInput.value = DateTime.now();
    ctrl.searchCtrl.clear();
    prodCtrl.search('');

    Get.to(
      () => Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            "CREATE NEW MANIFEST",
            style: TextStyle(color: kDarkSlate, fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: kDarkSlate),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: ctrl.saveShipmentToFirestore,
                icon: const Icon(Icons.save_alt),
                label: const Text("FINALIZE & SAVE"),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            // LEFT: MANIFEST DETAILS
            Expanded(
              flex: 13,
              child: Column(
                children: [
                  _buildManifestFormHeader(context, ctrl),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "MANIFEST ITEMS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kDarkSlate,
                                  ),
                                ),
                                Obx(
                                  () => Text(
                                    "Total: ${ctrl.currentManifestTotalDisplay}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: kPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Obx(() {
                              if (ctrl.currentManifestItems.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "Select products from the right list ->",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: ctrl.currentManifestItems.length,
                                separatorBuilder:
                                    (c, i) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = ctrl.currentManifestItems[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[50],
                                      child: Text(
                                        "${i + 1}",
                                        style: const TextStyle(
                                          color: kPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${item.productModel} • Ctn: ${item.cartonNo}",
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              ctrl.formatMoney(
                                                item.totalItemCost,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              "Sea: ${item.seaQty} | Air: ${item.airQty}",
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => ctrl.removeFromManifest(i),
                                        ),
                                      ],
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

            // RIGHT: PRODUCT CATALOG
            Expanded(
              flex: 7,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: kDarkSlate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PRODUCT CATALOG",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: ctrl.searchCtrl,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText: "Search model or name...",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 12,
                              ),
                            ),
                            onChanged: (val) => prodCtrl.search(val),
                          ),
                        ],
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
                              title: Text(
                                p.model,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[100],
                                  foregroundColor: kDarkSlate,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onPressed:
                                    () => showShipmentEntryDialog(
                                      p,
                                      ctrl,
                                      prodCtrl,
                                    ),
                                child: const Text("ADD"),
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

  Widget _buildManifestFormHeader(
    BuildContext context,
    ShipmentController ctrl,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SHIPMENT DETAILS",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: ctrl.shipmentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Shipment Name / ID",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: ctrl.shipmentDateInput.value,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) ctrl.shipmentDateInput.value = d;
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Departure Date",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Obx(
                      () => Text(
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl.totalCartonCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Total Cartons",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grid_view),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: ctrl.totalWeightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Total Weight (KG)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kDarkSlate,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        item.isReceived
                            ? kSuccess.withOpacity(0.1)
                            : kWarning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.isReceived ? Icons.inventory : Icons.sailing,
                    color: item.isReceived ? kSuccess : kWarning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.shipmentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Total Items: ${item.items.length}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      controller.formatMoney(item.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kDarkSlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _statusChip(item.isReceived),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),

            // Details Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      Icons.calendar_today_outlined,
                      "Departed",
                      DateFormat('dd MMM yyyy').format(item.createdDate),
                    ),
                    if (item.arrivalDate != null) ...[
                      const SizedBox(height: 6),
                      _infoRow(
                        Icons.event_available,
                        "Arrived",
                        DateFormat('dd MMM yyyy').format(item.arrivalDate!),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${item.totalCartons} Cartons",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${item.totalWeight} KG",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => controller.generatePdf(item),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text("MANIFEST"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDarkSlate,
                    side: const BorderSide(color: kDarkSlate),
                  ),
                ),
                const Spacer(),
                if (!item.isReceived)
                  Obx(
                    () =>
                        controller.isLoading.value
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kDarkSlate,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.download_done, size: 18),
                              label: const Text("RECEIVE STOCK"),
                              onPressed:
                                  () => _showReceiveDialog(context, item),
                            ),
                  )
                else
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: kSuccess),
                    label: const Text(
                      "STOCK UPDATED",
                      style: TextStyle(color: kSuccess),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveDialog(BuildContext context, ShipmentModel item) {
    final ShipmentController controller = Get.find<ShipmentController>();
    final VendorController vendorCtrl = Get.find<VendorController>();

    final Rx<DateTime> selectedDate = DateTime.now().obs;
    final Rxn<String> selectedVendorId = Rxn<String>();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warehouse_rounded,
                  size: 40,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Confirm Stock Arrival",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              // 1. DATE PICKER
              const Text(
                "Arrival Date:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: kPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Obx(
                        () => Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate.value),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. VENDOR SELECTION
              const Text(
                "Supplier / Vendor (For Credit Entry):",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Obx(() {
                  if (vendorCtrl.vendors.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("No Vendors Found"),
                    );
                  }

                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("Select Vendor (Optional)"),
                      value: selectedVendorId.value,
                      items:
                          vendorCtrl.vendors.map((vendor) {
                            return DropdownMenuItem(
                              value: vendor.docId,
                              child: Text(
                                vendor.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        selectedVendorId.value = val;
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // 3. BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDarkSlate,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        // 1. Force close keyboard
                        FocusScope.of(context).unfocus();

                        // 2. Close the SELECTION Dialog (Not the loading one)
                        Get.back();

                        // 3. Call Controller (No loading dialog will appear now)
                        controller.receiveShipmentFast(
                          item,
                          selectedDate.value,
                          selectedVendorId: selectedVendorId.value,
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _statusChip(bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? kSuccess : kWarning,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        done ? "RECEIVED" : "ON WAY",
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}