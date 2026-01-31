// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:intl/intl.dart';

// RE-USE THE DIALOG, BUT ADAPTED TO PUSH TO LOCAL STATE
import 'package:gtel_erp/Shipment/shipmentdialog.dart';
// NOTE: You might need to slightly modify showShipmentEntryDialog to accept a callback
// OR we can make a small local version here.
// For "Don't remove anything", I will use the product catalog search to add items.

class ShipmentDetailScreen extends StatefulWidget {
  final ShipmentModel shipment;
  const ShipmentDetailScreen({super.key, required this.shipment});

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final ShipmentController controller = Get.find<ShipmentController>();
  final ProductController productController = Get.find<ProductController>();
  late TextEditingController reportCtrl;

  late List<ShipmentItem> editedItems;

  @override
  void initState() {
    super.initState();
    reportCtrl = TextEditingController(
      text: widget.shipment.carrierReport ?? "",
    );
    // Deep Copy
    editedItems =
        widget.shipment.items
            .map(
              (e) => ShipmentItem(
                productId: e.productId,
                productName: e.productName,
                productModel: e.productModel,
                productBrand: e.productBrand,
                productCategory: e.productCategory,
                unitWeightSnapshot: e.unitWeightSnapshot,
                seaQty: e.seaQty,
                airQty: e.airQty,
                receivedSeaQty: e.receivedSeaQty,
                receivedAirQty: e.receivedAirQty,
                cartonNo: e.cartonNo,
                seaPriceSnapshot: e.seaPriceSnapshot,
                airPriceSnapshot: e.airPriceSnapshot,
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    reportCtrl.dispose();
    super.dispose();
  }

  void _updateQty(int index, String type, int newVal) {
    setState(() {
      final old = editedItems[index];
      editedItems[index] = ShipmentItem(
        productId: old.productId,
        productName: old.productName,
        productModel: old.productModel,
        productBrand: old.productBrand,
        productCategory: old.productCategory,
        unitWeightSnapshot: old.unitWeightSnapshot,
        seaQty: old.seaQty,
        airQty: old.airQty,
        receivedSeaQty: type == 'sea' ? newVal : old.receivedSeaQty,
        receivedAirQty: type == 'air' ? newVal : old.receivedAirQty,
        cartonNo: old.cartonNo,
        seaPriceSnapshot: old.seaPriceSnapshot,
        airPriceSnapshot: old.airPriceSnapshot,
      );
    });
  }

  // LOGIC TO ADD NEW ITEM TO EDIT LIST
  void _addNewProduct() {
    // Show a bottom sheet with product search
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            height: Get.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Add Extra Product",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search Product...",
                  ),
                  onChanged: (val) => productController.search(val),
                ),
                Expanded(
                  child: Obx(
                    () => ListView.builder(
                      itemCount: productController.allProducts.length,
                      itemBuilder: (c, i) {
                        final p = productController.allProducts[i];
                        return ListTile(
                          title: Text(p.model),
                          subtitle: Text(p.name),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              // Add to editedItems list
                              setState(() {
                                editedItems.add(
                                  ShipmentItem(
                                    productId: p.id,
                                    productName: p.name,
                                    productModel: p.model,
                                    productBrand: p.brand,
                                    productCategory: p.category,
                                    unitWeightSnapshot: p.weight,
                                    seaQty: 0, // Not in original order
                                    airQty: 0, // Not in original order
                                    receivedSeaQty: 0, // User will edit this
                                    receivedAirQty: 0, // User will edit this
                                    cartonNo: 'Extra',
                                    seaPriceSnapshot: p.sea,
                                    airPriceSnapshot: p.air,
                                  ),
                                );
                              });
                              Get.back();
                              Get.snackbar(
                                "Added",
                                "Product added to list. Please enter Received Qty.",
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isReceived = widget.shipment.isReceived;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("SHIPMENT: ${widget.shipment.shipmentName}"),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (!isReceived)
            IconButton(
              tooltip: "Add Product (Mistake/Extra)",
              icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
              onPressed: _addNewProduct,
            ),
          if (!isReceived)
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("SAVE CHANGES"),
              onPressed: () {
                controller.updateShipmentDetails(
                  widget.shipment,
                  editedItems,
                  reportCtrl.text,
                );
              },
            ),
          const SizedBox(width: 10),
          if (!isReceived)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download_done),
              label: const Text("RECEIVE STOCK"),
              onPressed: () => _showReceiveConfirmation(),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blueGrey[800],
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            "Product",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Ordered (S/A)",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            "RECEIVED (S/A)",
                            style: TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            "Cost (Unit)",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            "Loss",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: editedItems.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = editedItems[i];
                        // Calc unit cost for display
                        double unitCost =
                            item.seaPriceSnapshot > 0
                                ? item.seaPriceSnapshot
                                : item.airPriceSnapshot;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ORDERED
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "${item.seaQty} / ${item.airQty}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              // RECEIVED
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: TextFormField(
                                        initialValue:
                                            item.receivedSeaQty.toString(),
                                        enabled: !isReceived,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          labelText: "Sea",
                                        ),
                                        onChanged:
                                            (val) => _updateQty(
                                              i,
                                              'sea',
                                              int.tryParse(val) ?? 0,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: TextFormField(
                                        initialValue:
                                            item.receivedAirQty.toString(),
                                        enabled: !isReceived,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          labelText: "Air",
                                        ),
                                        onChanged:
                                            (val) => _updateQty(
                                              i,
                                              'air',
                                              int.tryParse(val) ?? 0,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // COST
                              Expanded(
                                flex: 1,
                                child: Text(unitCost.toStringAsFixed(1)),
                              ),

                              // LOSS
                              Expanded(
                                flex: 1,
                                child: Text(
                                  "${item.lossQty}",
                                  style: TextStyle(
                                    color:
                                        item.lossQty > 0
                                            ? Colors.red
                                            : Colors.green,
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
          ),

          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SHIPMENT INFO",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoRow("Carrier", widget.shipment.carrier),
                    _infoRow("Vendor", widget.shipment.vendorName),
                    _infoRow(
                      "Purchased",
                      DateFormat(
                        'yyyy-MM-dd',
                      ).format(widget.shipment.purchaseDate),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "CARRIER / LOSS REPORT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reportCtrl,
                      enabled: !isReceived,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: "Enter details about lost items...",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFFFF8F8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "* Items marked as LOSS (Ordered > Received) will automatically move to the 'On Hold / Missing' page upon receiving.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
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

  void _showReceiveConfirmation() {
    Get.defaultDialog(
      title: "Confirm Receive",
      middleText:
          "This will add the 'RECEIVED' quantities to your stock.\n\nAny Missing items will be moved to the 'On Hold' list.",
      textConfirm: "PROCESS STOCK",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      onConfirm: () {
        final updatedShipment = ShipmentModel(
          docId: widget.shipment.docId,
          shipmentName: widget.shipment.shipmentName,
          purchaseDate: widget.shipment.purchaseDate,
          vendorName: widget.shipment.vendorName,
          carrier: widget.shipment.carrier,
          exchangeRate: widget.shipment.exchangeRate,
          totalCartons: widget.shipment.totalCartons,
          totalWeight: widget.shipment.totalWeight,
          totalAmount: widget.shipment.totalAmount, // Vendor bill stays same
          isReceived: false,
          items: editedItems,
          carrierReport: reportCtrl.text,
        );

        controller
            .updateShipmentDetails(
              updatedShipment,
              editedItems,
              reportCtrl.text,
            )
            .then((_) {
              controller.receiveShipmentFast(updatedShipment, DateTime.now());
            });
      },
    );
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
