// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';
import 'package:gtel_erp/Shipment/shipmentdialog.dart'; // Import reusable dialog
import 'package:gtel_erp/Stock/controller.dart';

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
                ignoreMissing: e.ignoreMissing, // Copy the flag
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    reportCtrl.dispose();
    super.dispose();
  }

  void _updateItem(int index, ShipmentItem newItem) {
    setState(() {
      editedItems[index] = newItem;
    });
  }

  // UPDATED: Use the Reusable Dialog
  void _addNewProductWithDialog() {
    // 1. Show Search Sheet first to pick product
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
                  "Search Product to Add",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search...",
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
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Get.back(); // Close search sheet
                            // 2. Open the reusable Shipment Dialog
                            showShipmentEntryDialog(
                              p,
                              controller,
                              productController,
                              widget.shipment.exchangeRate,
                              onSubmit: (newItem) {
                                setState(() {
                                  editedItems.add(newItem);
                                });
                                Get.snackbar("Added", "Item added to list.");
                              },
                            );
                          },
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

  // Calculation Helper
  double get totalReceivedValue =>
      editedItems.fold(0.0, (sum, e) => sum + e.receivedItemValue);
  double get originalValue => widget.shipment.totalAmount;
  double get valueDifference => originalValue - totalReceivedValue;

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
              tooltip: "Add Product (Swap/Extra)",
              icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
              onPressed: _addNewProductWithDialog,
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
                  // Table Header
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
                          flex: 2,
                          child: Text(
                            "Status / Action",
                            style: TextStyle(color: Colors.white, fontSize: 12),
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
                        bool isLoss = item.lossQty > 0;
                        bool isExtra = (item.seaQty + item.airQty) == 0;

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
                                    if (isExtra)
                                      const Text(
                                        "(Added Extra)",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
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

                              // RECEIVED INPUTS
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
                                        onChanged: (val) {
                                          _updateItem(
                                            i,
                                            ShipmentItem(
                                              productId: item.productId,
                                              productName: item.productName,
                                              productModel: item.productModel,
                                              productBrand: item.productBrand,
                                              productCategory:
                                                  item.productCategory,
                                              unitWeightSnapshot:
                                                  item.unitWeightSnapshot,
                                              seaQty: item.seaQty,
                                              airQty: item.airQty,
                                              receivedSeaQty:
                                                  int.tryParse(val) ?? 0,
                                              receivedAirQty:
                                                  item.receivedAirQty,
                                              cartonNo: item.cartonNo,
                                              seaPriceSnapshot:
                                                  item.seaPriceSnapshot,
                                              airPriceSnapshot:
                                                  item.airPriceSnapshot,
                                              ignoreMissing: item.ignoreMissing,
                                            ),
                                          );
                                        },
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
                                        onChanged: (val) {
                                          _updateItem(
                                            i,
                                            ShipmentItem(
                                              productId: item.productId,
                                              productName: item.productName,
                                              productModel: item.productModel,
                                              productBrand: item.productBrand,
                                              productCategory:
                                                  item.productCategory,
                                              unitWeightSnapshot:
                                                  item.unitWeightSnapshot,
                                              seaQty: item.seaQty,
                                              airQty: item.airQty,
                                              receivedSeaQty:
                                                  item.receivedSeaQty,
                                              receivedAirQty:
                                                  int.tryParse(val) ?? 0,
                                              cartonNo: item.cartonNo,
                                              seaPriceSnapshot:
                                                  item.seaPriceSnapshot,
                                              airPriceSnapshot:
                                                  item.airPriceSnapshot,
                                              ignoreMissing: item.ignoreMissing,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // STATUS / IGNORE CHECKBOX
                              Expanded(
                                flex: 2,
                                child:
                                    isLoss
                                        ? Row(
                                          children: [
                                            Checkbox(
                                              value: item.ignoreMissing,
                                              activeColor: Colors.orange,
                                              onChanged:
                                                  isReceived
                                                      ? null
                                                      : (val) {
                                                        _updateItem(
                                                          i,
                                                          ShipmentItem(
                                                            productId:
                                                                item.productId,
                                                            productName:
                                                                item.productName,
                                                            productModel:
                                                                item.productModel,
                                                            productBrand:
                                                                item.productBrand,
                                                            productCategory:
                                                                item.productCategory,
                                                            unitWeightSnapshot:
                                                                item.unitWeightSnapshot,
                                                            seaQty: item.seaQty,
                                                            airQty: item.airQty,
                                                            receivedSeaQty:
                                                                item.receivedSeaQty,
                                                            receivedAirQty:
                                                                item.receivedAirQty,
                                                            cartonNo:
                                                                item.cartonNo,
                                                            seaPriceSnapshot:
                                                                item.seaPriceSnapshot,
                                                            airPriceSnapshot:
                                                                item.airPriceSnapshot,
                                                            ignoreMissing:
                                                                val ??
                                                                false, // Toggle Ignore
                                                          ),
                                                        );
                                                      },
                                            ),
                                            const Expanded(
                                              child: Text(
                                                "Ignore Loss?",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                        : const Text(
                                          "OK",
                                          style: TextStyle(
                                            color: Colors.green,
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

          // INFO SIDEBAR
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
                      "FINANCIAL CHECK",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoRow(
                      "Original Bill:",
                      controller.formatMoney(originalValue),
                    ),
                    _infoRow(
                      "Received Val:",
                      controller.formatMoney(totalReceivedValue),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            valueDifference > 0
                                ? Colors.red[50]
                                : Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            valueDifference > 0 ? "Shortage:" : "Surplus:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  valueDifference > 0
                                      ? Colors.red
                                      : Colors.green,
                            ),
                          ),
                          Text(
                            controller.formatMoney(valueDifference.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  valueDifference > 0
                                      ? Colors.red
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (valueDifference > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          "* This shortage will be saved as a Note, but Vendor Balance remains unchanged.",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Text(
                      "CARRIER REPORT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reportCtrl,
                      enabled: !isReceived,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: "Enter details...",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFFFF8F8),
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
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text(
              "This will finalize stock. Missing items NOT marked 'Ignore' will go to On Hold.",
            ),
            const SizedBox(height: 10),
            if (valueDifference > 0)
              Text(
                "A Shortage Note of ${controller.formatMoney(valueDifference)} will be saved.",
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
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
          totalAmount: widget.shipment.totalAmount,
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
          Text(
            val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
