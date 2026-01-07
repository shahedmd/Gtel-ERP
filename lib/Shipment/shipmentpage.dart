// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:intl/intl.dart';
import 'controller.dart';


// --- YOUR DESIGN SYSTEM ---
const Color kDarkSlate = Color(0xFF111827);
const Color kActiveAccent = Color(0xFF3B82F6);
const Color kBgGrey = Color(0xFFF9FAFB);
const Color kTextMuted = Color(0xFF6B7280);
const Color kWhite = Colors.white;

class ShipmentPage extends StatelessWidget {
  const ShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject Controllers
    final ShipmentController controller = Get.put(ShipmentController());
    final ProductController productController = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: kBgGrey,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0.5,
        title: const Text(
          "Shipment Management",
          style: TextStyle(color: kDarkSlate, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kDarkSlate),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Download Manifest",
            onPressed: controller.generatePdf,
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kActiveAccent,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text("New Shipment"),
        onPressed: () => _openAddDialog(context, controller, productController),
      ),
      body: Obx(() {
        if (controller.shipments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: kTextMuted.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No shipments found",
                  style: TextStyle(color: kTextMuted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.shipments.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = controller.shipments[index];
            return _ShipmentCard(item: item, controller: controller);
          },
        );
      }),
    );
  }

  // --- DIALOG: MATCHING STOCK PAGE SEARCH ---
  void _openAddDialog(
    BuildContext context,
    ShipmentController ctrl,
    ProductController prodCtrl,
  ) {
    // Reset state
    ctrl.resetInputs();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Create Shipment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDarkSlate,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: kTextMuted),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // 1. Search Box (Triggers Controller Search)
              TextField(
                controller: ctrl.searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search Product Name/Model...",
                  prefixIcon: const Icon(Icons.search, color: kTextMuted),
                  filled: true,
                  fillColor: kBgGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),
                ),
                onChanged: (val) => prodCtrl.search(val),
              ),
              const SizedBox(height: 10),

              // 2. Search Results List (Reactive)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Obx(() {
                  if (prodCtrl.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (prodCtrl.allProducts.isEmpty) {
                    return const Center(child: Text("No products found"));
                  }

                  return ListView.builder(
                    itemCount: prodCtrl.allProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = prodCtrl.allProducts[i];
                      return Obx(() {
                        final isSelected =
                            ctrl.selectedProduct.value?.id == p.id;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: kActiveAccent.withOpacity(0.1),
                          title: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text("${p.model} | Stock: ${p.stockQty}"),
                          onTap: () => ctrl.selectedProduct.value = p,
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: kActiveAccent,
                                  )
                                  : null,
                        );
                      });
                    },
                  );
                }),
              ),

              const SizedBox(height: 15),

              // 3. Qty Inputs
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      ctrl.seaCtrl,
                      "Sea Qty",
                      Icons.water,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      ctrl.airCtrl,
                      "Air Qty",
                      Icons.air,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // 4. Shipment Date Picker
              const Text(
                "Shipment Date (Departure)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kTextMuted,
                ),
              ),
              const SizedBox(height: 5),
              Obx(
                () => InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: ctrl.shipmentDateInput.value,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) ctrl.shipmentDateInput.value = d;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kBgGrey,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: kDarkSlate,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat(
                            'yyyy-MM-dd',
                          ).format(ctrl.shipmentDateInput.value),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kActiveAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: ctrl.createShipment,
                  child: const Text(
                    "ADD TO MANIFEST",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildInput(
    TextEditingController c,
    String label,
    IconData icon,
    Color color,
  ) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }
}

// --- CARD COMPONENT ---
class _ShipmentCard extends StatelessWidget {
  final ShipmentModel item;
  final ShipmentController controller;

  const _ShipmentCard({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isDone = item.isReceived;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isDone ? Colors.green : Colors.orange,
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kDarkSlate,
                      ),
                    ),
                    Text(
                      "${item.productModel} • ${item.productBrand}",
                      style: const TextStyle(fontSize: 13, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              _statusChip(isDone),
            ],
          ),
          const Divider(height: 24, color: kBgGrey),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _detailItem(
                "Sea Qty",
                "${item.seaQty}",
                Icons.water_drop,
                Colors.blue,
              ),
              _detailItem(
                "Air Qty",
                "${item.airQty}",
                Icons.air,
                Colors.orange,
              ),
              _detailItem(
                "Ship Date",
                DateFormat('MM-dd').format(item.createdDate),
                Icons.date_range,
                kDarkSlate,
              ),
              _detailItem(
                "Entry Date",
                item.arrivalDate != null
                    ? DateFormat('MM-dd').format(item.arrivalDate!)
                    : "--",
                Icons.check_circle_outline,
                isDone ? Colors.green : kTextMuted,
              ),
            ],
          ),
          if (!isDone) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text("INPUT TO STOCK"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkSlate,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => controller.receiveShipment(item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailItem(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.8)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
      ],
    );
  }

  Widget _statusChip(bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            done
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        done ? "COMPLETED" : "ON WAY",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: done ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}
