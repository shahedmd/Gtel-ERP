// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/details.dart';
import 'package:gtel_erp/Shipment/onhold.dart';
import 'package:gtel_erp/Shipment/shipmentdialog.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Stock/controller.dart';

// --- THEME CONSTANTS ---
const Color kDarkSlate = Color(0xFF1E293B);
const Color kPrimary = Color(0xFF2563EB);
const Color kSuccess = Color(0xFF10B981);
const Color kWarning = Color(0xFFF59E0B);
const Color kBg = Color(0xFFF1F5F9);

class ShipmentPage extends StatelessWidget {
  const ShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ShipmentController controller = Get.put(ShipmentController());
    final ProductController productController = Get.find<ProductController>();
    final VendorController vendorController = Get.find<VendorController>();

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
          TextButton.icon(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            label: const Text(
              "MISSING / ON HOLD",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Get.to(() => const OnHoldShipmentPage()),
          ),
          // --- FILTERS IN APP BAR ---
          _buildFilterDropdown(controller, vendorController),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () => productController.fetchProducts(),
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
              vendorController,
            ),
      ),
      body: Column(
        children: [
          // 1. DASHBOARD METRICS
          _buildDashboardMetrics(controller),

          // 2. SHIPMENT REGISTRY TABLE
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: kDarkSlate,
                      child: const Text(
                        "SHIPMENT REGISTRY",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Obx(() {
                        if (controller.filteredShipments.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "No Shipments Found",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                Colors.grey[100],
                              ),
                              showCheckboxColumn: false, // Make row clickable
                              columns: const [
                                DataColumn(label: Text("Purchase Date")),
                                DataColumn(label: Text("Shipment Name")),
                                DataColumn(label: Text("Vendor")),
                                DataColumn(label: Text("Carrier")),
                                DataColumn(label: Text("Items")),
                                DataColumn(label: Text("Total Value")),
                                DataColumn(label: Text("Status")),
                                DataColumn(label: Text("Report")),
                                DataColumn(label: Text("Actions")),
                              ],
                              rows:
                                  controller.filteredShipments.map((item) {
                                    return DataRow(
                                      onSelectChanged: (_) {
                                        // ROUTE TO DETAIL/EDIT SCREEN
                                        Get.to(
                                          () => ShipmentDetailScreen(
                                            shipment: item,
                                          ),
                                        );
                                      },
                                      cells: [
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(item.purchaseDate),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            item.shipmentName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(item.vendorName)),
                                        DataCell(
                                          Chip(
                                            label: Text(
                                              item.carrier,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                            backgroundColor: Colors.blue[50],
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        DataCell(Text("${item.items.length}")),
                                        DataCell(
                                          Text(
                                            controller.formatMoney(
                                              item.totalAmount,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: kDarkSlate,
                                            ),
                                          ),
                                        ),
                                        DataCell(_statusChip(item.isReceived)),
                                        DataCell(
                                          item.carrierReport != null &&
                                                  item.carrierReport!.isNotEmpty
                                              ? Tooltip(
                                                message: item.carrierReport,
                                                child: const Icon(
                                                  Icons.warning_amber,
                                                  color: Colors.orange,
                                                ),
                                              )
                                              : const SizedBox(),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.print,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                tooltip: "Print Manifest",
                                                onPressed:
                                                    () => controller
                                                        .generatePdf(item),
                                              ),
                                              // Note: We primarily use the Detail Screen for receiving now,
                                              // but this quick action is kept for convenience.
                                              if (!item.isReceived)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.download_done,
                                                    size: 18,
                                                    color: kSuccess,
                                                  ),
                                                  tooltip: "Quick Receive",
                                                  onPressed:
                                                      () => Get.to(
                                                        () =>
                                                            ShipmentDetailScreen(
                                                              shipment: item,
                                                            ),
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterDropdown(
    ShipmentController ctrl,
    VendorController vendorCtrl,
  ) {
    return Row(
      children: [
        Obx(
          () => DropdownButton<String>(
            value:
                ctrl.filterCarrier.value.isEmpty
                    ? null
                    : ctrl.filterCarrier.value,
            hint: const Text("Filter Carrier"),
            underline: Container(),
            items: [
              const DropdownMenuItem(value: "", child: Text("All Carriers")),
              ...ctrl.carrierList.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (val) => ctrl.filterCarrier.value = val ?? "",
          ),
        ),
        const SizedBox(width: 16),
        Obx(
          () => DropdownButton<String>(
            value:
                ctrl.filterVendor.value.isEmpty
                    ? null
                    : ctrl.filterVendor.value,
            hint: const Text("Filter Vendor"),
            underline: Container(),
            items: [
              const DropdownMenuItem(value: "", child: Text("All Vendors")),
              ...vendorCtrl.vendors.map(
                (v) => DropdownMenuItem(value: v.docId, child: Text(v.name)),
              ),
            ],
            onChanged: (val) => ctrl.filterVendor.value = val ?? "",
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    VendorController vendorCtrl,
  ) {
    // 1. Reset State
    ctrl.currentManifestItems.clear();
    ctrl.shipmentNameCtrl.clear();
    ctrl.totalCartonCtrl.text = "0";
    ctrl.totalWeightCtrl.text = "0";
    ctrl.globalExchangeRateCtrl.text = "0.0";
    ctrl.purchaseDateInput.value = DateTime.now(); // Only Purchase Date now
    ctrl.selectedVendorId.value = null;
    ctrl.selectedVendorName.value = null;
    ctrl.selectedCarrier.value = null;
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
            // LEFT: MANIFEST DETAILS FORM
            Expanded(
              flex: 13,
              child: Column(
                children: [
                  _buildExtendedManifestFormHeader(context, ctrl, vendorCtrl),
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
                                onPressed: () {
                                  // Pass global rate to dialog
                                  double globalRate =
                                      double.tryParse(
                                        ctrl.globalExchangeRateCtrl.text,
                                      ) ??
                                      0.0;
                                  showShipmentEntryDialog(
                                    p,
                                    ctrl,
                                    prodCtrl,
                                    globalRate,
                                  );
                                },
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

  // --- EXTENDED HEADER (Updated without Departure Date) ---
  Widget _buildExtendedManifestFormHeader(
    BuildContext context,
    ShipmentController ctrl,
    VendorController vendorCtrl,
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
          // ROW 1: Name, Purchase Date (Departure Date Removed)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: ctrl.shipmentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Shipment ID / Name",
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
                      initialDate: ctrl.purchaseDateInput.value,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) ctrl.purchaseDateInput.value = d;
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Purchase Date",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Obx(
                      () => Text(
                        DateFormat(
                          'yyyy-MM-dd',
                        ).format(ctrl.purchaseDateInput.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ROW 2: Vendor, Carrier, Global Rate
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Vendor *",
                      border: OutlineInputBorder(),
                    ),
                    value: ctrl.selectedVendorId.value,
                    items:
                        vendorCtrl.vendors.map((v) {
                          return DropdownMenuItem(
                            value: v.docId,
                            child: Text(v.name),
                          );
                        }).toList(),
                    onChanged: (val) {
                      ctrl.selectedVendorId.value = val;
                      // Update name for storage
                      try {
                        ctrl.selectedVendorName.value =
                            vendorCtrl.vendors
                                .firstWhere((v) => v.docId == val)
                                .name;
                      } catch (e) {
                        ctrl.selectedVendorName.value = "Unknown";
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Carrier *",
                      border: OutlineInputBorder(),
                    ),
                    value: ctrl.selectedCarrier.value,
                    items:
                        ctrl.carrierList
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged: (val) => ctrl.selectedCarrier.value = val,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: ctrl.globalExchangeRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Global Rate (Opt)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                    hintText: "e.g. 17.5",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ROW 3: Totals
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
            decoration: const BoxDecoration(
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
