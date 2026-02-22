// ignore_for_file: deprecated_member_use, avoid_print
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
const Color kBg = Color(0xFFF8FAFC);
const Color kBorder = Color(0xFFE2E8F0);

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
          "LOGISTICS MANAGER",
          style: TextStyle(
            color: kDarkSlate,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorder, height: 1),
        ),
        iconTheme: const IconThemeData(color: kDarkSlate),
        actions: [
          _buildActionButton(
            label: "ON HOLD ITEMS",
            icon: Icons.warning_amber_rounded,
            color: Colors.redAccent,
            onTap: () => Get.to(() => const OnHoldShipmentPage()),
          ),
          const SizedBox(width: 12),
          // FILTERS
          _buildFilterDropdown(controller, vendorController),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: kDarkSlate,
            tooltip: "Refresh Data",
            onPressed: () => productController.fetchProducts(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        elevation: 4,
        icon: const Icon(Icons.add_location_alt),
        label: const Text(
          "CREATE SHIPMENT",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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

          // 2. SHIPMENT TABLE WITH PAGINATION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        border: Border(bottom: BorderSide(color: kBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Active Shipments",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kDarkSlate,
                            ),
                          ),
                          // Pagination Controls
                          Obx(
                            () => Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed:
                                      controller.shipmentPage.value > 1
                                          ? controller.prevPage
                                          : null,
                                ),
                                Text(
                                  "Page ${controller.shipmentPage.value} of ${controller.totalPages}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed:
                                      controller.shipmentPage.value <
                                              controller.totalPages
                                          ? controller.nextPage
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table
                    Expanded(
                      child: Obx(() {
                        if (controller.filteredShipments.isEmpty) {
                          return _buildEmptyState();
                        }
                        return SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey[50],
                            ),
                            dataRowHeight: 60,
                            dividerThickness: 1,
                            columnSpacing: 20, // Reduced spacing
                            columns: const [
                              DataColumn(
                                label: Text(
                                  "Date",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Shipment ID",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Vendor",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Carrier",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Items",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              // --- NEW COLUMN: CARTONS ---
                              DataColumn(
                                label: Text(
                                  "Ctns",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Grand Total",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Status",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Actions",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows:
                                controller.paginatedShipments.map((item) {
                                  return DataRow(
                                    onSelectChanged:
                                        (_) => Get.to(
                                          () => ShipmentDetailScreen(
                                            shipment: item,
                                          ),
                                        ),
                                    cells: [
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(item.purchaseDate),
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
                                      DataCell(
                                        SizedBox(
                                          width: 120, // Limit width
                                          child: Text(
                                            item.vendorName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        _buildCarrierBadge(item.carrier),
                                      ),
                                      DataCell(Text("${item.items.length}")),
                                      // --- NEW CELL: CARTONS ---
                                      DataCell(
                                        Text(
                                          "${item.totalCartons}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          controller.formatMoney(
                                            item.grandTotal,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: kDarkSlate,
                                          ),
                                        ),
                                      ),
                                      DataCell(_statusChip(item.isReceived)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.print_outlined,
                                                size: 20,
                                                color: Colors.black,
                                              ),
                                              onPressed:
                                                  () => controller.generatePdf(
                                                    item,
                                                  ),
                                            ),
                                            if (!item.isReceived)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.check_circle_outline,
                                                  color: kSuccess,
                                                  size: 20,
                                                ),
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

  // --- WIDGET HELPERS ---
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text("No shipments found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCarrierBadge(String carrier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Text(
        carrier,
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[800],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    ShipmentController ctrl,
    VendorController vendorCtrl,
  ) {
    return Row(
      children: [
        Obx(
          () => _styledDropdown(
            value:
                ctrl.filterCarrier.value.isEmpty
                    ? null
                    : ctrl.filterCarrier.value,
            hint: "All Carriers",
            items: ctrl.carrierList,
            onChanged: (val) => ctrl.filterCarrier.value = val ?? "",
          ),
        ),
        const SizedBox(width: 8),
        // --- FIXED VENDOR DROPDOWN OVERFLOW ---
        Obx(
          () => SizedBox(
            width: 200, // Fixed Width
            child: DropdownButtonFormField<String>(
              isExpanded: true, // Key for overflow handling
              value:
                  ctrl.filterVendor.value.isEmpty
                      ? null
                      : ctrl.filterVendor.value,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text("All Vendors", style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem(
                  value: "",
                  child: Text("All Vendors", style: TextStyle(fontSize: 12)),
                ),
                ...vendorCtrl.vendors.map(
                  (v) => DropdownMenuItem(
                    value: v.docId,
                    child: Text(
                      v.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis, // Truncate long names
                    ),
                  ),
                ),
              ],
              onChanged: (val) => ctrl.filterVendor.value = val ?? "",
            ),
          ),
        ),
      ],
    );
  }

  Widget _styledDropdown({
    String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontSize: 12)),
        underline: Container(),
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        items: [
          DropdownMenuItem(
            value: "",
            child: Text(hint, style: const TextStyle(fontSize: 12)),
          ),
          ...items.map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _statusChip(bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? kSuccess.withOpacity(0.1) : kWarning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? kSuccess : kWarning),
      ),
      child: Text(
        done ? "RECEIVED" : "ON WAY",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: done ? kSuccess : kWarning,
        ),
      ),
    );
  }

  Widget _buildDashboardMetrics(ShipmentController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => _MetricTile(
                title: "TOTAL ON WAY",
                value: ctrl.totalOnWayDisplay,
                icon: Icons.sailing,
                color: kWarning,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Obx(
              () => _MetricTile(
                title: "TOTAL COMPLETED",
                value: ctrl.totalCompletedDisplay,
                icon: Icons.check_circle,
                color: kSuccess,
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
    // Reset Everything
    ctrl.currentManifestItems.clear();
    ctrl.shipmentNameCtrl.clear();
    ctrl.totalCartonCtrl.text = "0";
    ctrl.totalWeightCtrl.text = "0";
    ctrl.carrierCostPerCtnCtrl.text = "0";
    ctrl.totalCarrierCostDisplayCtrl.text = "0";
    ctrl.globalExchangeRateCtrl.text = "0.0";
    ctrl.purchaseDateInput.value = DateTime.now();
    ctrl.selectedVendorId.value = null;
    ctrl.selectedCarrier.value = null;
    ctrl.searchCtrl.clear();
    prodCtrl.search('');

    Get.to(
      () => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            "CREATE MANIFEST",
            style: TextStyle(color: kDarkSlate, fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: kDarkSlate),
          actions: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                onPressed: ctrl.saveShipmentToFirestore,
                icon: const Icon(Icons.save, size: 18),
                label: const Text("SAVE SHIPMENT"),
              ),
            ),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: FORM & ITEMS
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  _buildExtendedManifestFormHeader(context, ctrl, vendorCtrl),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: kDarkSlate,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "MANIFEST ITEMS",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Obx(
                                  () => Text(
                                    "GRAND TOTAL (Est.): ${ctrl.currentManifestTotalDisplay}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Obx(() {
                              if (ctrl.currentManifestItems.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "Add items from the catalog ->",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: ctrl.currentManifestItems.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = ctrl.currentManifestItems[i];
                                  return ListTile(
                                    dense: true,
                                    leading: Text(
                                      "${i + 1}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${item.productModel} • Ctn: ${item.cartonNo} • ${item.seaQty}s/${item.airQty}a",
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ctrl.formatMoney(item.totalItemCost),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 18,
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
            // RIGHT: CATALOG
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "PRODUCT CATALOG",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kDarkSlate,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSuccess,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_circle, size: 18),
                            label: const Text("CREATE NEW PRODUCT"),
                            onPressed: () {
                              double globalRate =
                                  double.tryParse(
                                    ctrl.globalExchangeRateCtrl.text,
                                  ) ??
                                  0.0;
                              showShipmentEntryDialog(
                                null,
                                ctrl,
                                prodCtrl,
                                globalRate,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: ctrl.searchCtrl,
                            decoration: InputDecoration(
                              hintText: "Search...",
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
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
                        return ListView.separated(
                          itemCount: prodCtrl.allProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = prodCtrl.allProducts[i];
                            return ListTile(
                              dense: true,
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
                              trailing: TextButton(
                                onPressed: () {
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
                    // PAGINATION FOOTER FOR CATALOG
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.grey[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed:
                                  prodCtrl.currentPage.value > 1
                                      ? prodCtrl.previousPage
                                      : null,
                            ),
                            Text(
                              "${prodCtrl.currentPage.value}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: prodCtrl.nextPage,
                            ),
                          ],
                        ),
                      ),
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

  // --- NEW MANIFEST FORM HEADER (4 ROWS) ---
  Widget _buildExtendedManifestFormHeader(
    BuildContext context,
    ShipmentController ctrl,
    VendorController vendorCtrl,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SHIPMENT CONFIGURATION",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // ROW 1: ID & DATE
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl.shipmentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Shipment ID",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
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

          // ROW 2: VENDOR, CARRIER, GLOBAL RATE
          Row(
            children: [
              // --- FIXED VENDOR DROPDOWN OVERFLOW IN FORM ---
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Vendor",
                      border: OutlineInputBorder(),
                    ),
                    value: ctrl.selectedVendorId.value,
                    items:
                        vendorCtrl.vendors
                            .map(
                              (v) => DropdownMenuItem(
                                value: v.docId,
                                child: Text(
                                  v.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      ctrl.selectedVendorId.value = val;
                      try {
                        ctrl.selectedVendorName.value =
                            vendorCtrl.vendors
                                .firstWhere((v) => v.docId == val)
                                .name;
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Carrier",
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
                    labelText: "Global Rate",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 3: CARTONS & CARRIER COSTS
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl.totalCartonCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Total Cartons",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.view_in_ar),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: ctrl.carrierCostPerCtnCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Cost Per Carton",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.price_change),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: ctrl.totalCarrierCostDisplayCtrl,
                  readOnly: true, // AUTO GENERATED
                  decoration: const InputDecoration(
                    labelText: "Total Carrier Cost",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kDarkSlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 4: WEIGHT
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: ctrl.totalWeightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Total Weight (KG)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                  ),
                ),
              ),
              const Expanded(flex: 2, child: SizedBox()), // Spacer
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kDarkSlate,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}