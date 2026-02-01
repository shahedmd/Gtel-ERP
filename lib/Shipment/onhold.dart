// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:intl/intl.dart';

class OnHoldShipmentPage extends StatelessWidget {
  const OnHoldShipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ShipmentController controller = Get.find<ShipmentController>();

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
          // FILTER DROPDOWN
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
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: Row(
                children: const [
                  Icon(Icons.warning_amber, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "These items were ordered but not received. Click 'Release' when you recover them.",
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
            Expanded(
              child: Obx(() {
                if (controller.filteredOnHoldItems.isEmpty) {
                  return const Center(
                    child: Text(
                      "No items found.",
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
                      DataColumn(label: Text("Missing Qty")),
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
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Get.defaultDialog(
                                      title: "Recover Item?",
                                      middleText:
                                          "Confirm recovery of ${item.missingQty} pcs?",
                                      textConfirm: "CONFIRM",
                                      confirmTextColor: Colors.white,
                                      onConfirm: () {
                                        Get.back();
                                        controller.resolveOnHoldItem(item);
                                      },
                                    );
                                  },
                                  child: const Text("RELEASE"),
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
}
