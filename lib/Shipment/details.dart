// ignore_for_file: deprecated_member_use, avoid_print
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Shipment/shipmodel.dart';
import 'package:gtel_erp/Shipment/shipmentdialog.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:intl/intl.dart';

// --- ERP THEME COLORS ---
const Color kHeaderColor = Color(0xFF1E293B); // Slate 900
const Color kBgColor = Color(0xFFF1F5F9); // Slate 100
const Color kBorderColor = Color(0xFFE2E8F0); // Slate 200
const Color kAccentColor = Color(0xFF2563EB); // Blue 600

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

  // Local state for editing before saving
  late List<ShipmentItem> editedItems;

  @override
  void initState() {
    super.initState();
    reportCtrl = TextEditingController(
      text: widget.shipment.carrierReport ?? "",
    );

    // Deep Copy of items to allow editing without mutating original immediately
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
                ignoreMissing: e.ignoreMissing,
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

  // --- CALCULATIONS ---

  // Financials
  double get totalReceivedValue =>
      editedItems.fold(0.0, (sum, e) => sum + e.receivedItemValue);
  double get originalValue => widget.shipment.totalAmount;
  double get valueDifference =>
      originalValue - totalReceivedValue; // Positive = Loss, Negative = Surplus

  // Weights (The Requested Update)
  double get originalWeight => widget.shipment.totalWeight;

  double get currentReceivedWeight => editedItems.fold(0.0, (sum, e) {
    int totalReceivedQty = e.receivedSeaQty + e.receivedAirQty;
    return sum + (totalReceivedQty * e.unitWeightSnapshot);
  });

  double get weightDifference =>
      originalWeight -
      currentReceivedWeight; // Positive = Weight Loss, Negative = Extra Weight

  // --- ACTIONS ---

  void _addNewProductWithDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            height: Get.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "ADD PRODUCT TO SHIPMENT",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: kHeaderColor,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Search model or name...",
                    filled: true,
                    fillColor: kBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => productController.search(val),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Obx(
                    () => ListView.separated(
                      itemCount: productController.allProducts.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final p = productController.allProducts[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.model,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(p.name),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("SELECT"),
                            onPressed: () {
                              Get.back();
                              showShipmentEntryDialog(
                                p,
                                controller,
                                productController,
                                widget.shipment.exchangeRate,
                                onSubmit: (newItem) {
                                  setState(() {
                                    editedItems.add(newItem);
                                  });
                                  Get.snackbar(
                                    "Success",
                                    "Added ${newItem.productModel} to list",
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                  );
                                },
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
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: Text(
          "MANIFEST: ${widget.shipment.shipmentName}",
          style: const TextStyle(
            color: kHeaderColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kHeaderColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorderColor, height: 1),
        ),
        actions: [
          if (!isReceived)
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, color: kAccentColor),
              label: const Text(
                "ADD ITEM",
                style: TextStyle(
                  color: kAccentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _addNewProductWithDialog,
            ),
          if (!isReceived)
            TextButton.icon(
              icon: const Icon(Icons.save_as, color: Colors.green),
              label: const Text(
                "SAVE DRAFT",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                controller.updateShipmentDetails(
                  widget.shipment,
                  editedItems,
                  reportCtrl.text,
                );
              },
            ),
          const SizedBox(width: 8),
          if (!isReceived)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kHeaderColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text("RECEIVE STOCK"),
              onPressed: () => _showReceiveConfirmation(),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // 1. INFO HEADER (METADATA)
          _buildInfoHeader(),

          // 2. MAIN CONTENT SPLIT
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: ITEMS TABLE
                Expanded(
                  flex: 3,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: kBorderColor),
                    ),
                    child: Column(
                      children: [
                        // TABLE HEADER
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: kHeaderColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "PRODUCT INFO",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  "WGT/Unit",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "ORDERED (S/A)",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "RECEIVED (SEA / AIR)",
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
                                  "STATUS",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // TABLE BODY
                        Expanded(
                          child: ListView.separated(
                            itemCount: editedItems.length,
                            separatorBuilder:
                                (c, i) => const Divider(
                                  height: 1,
                                  color: kBorderColor,
                                ),
                            itemBuilder:
                                (ctx, i) => _buildItemRow(i, isReceived),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // RIGHT: SUMMARY & ACTIONS
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummaryCard("FINANCIAL SUMMARY", [
                          _summaryRow(
                            "Original Bill",
                            controller.formatMoney(originalValue),
                          ),
                          _summaryRow(
                            "Received Value",
                            controller.formatMoney(totalReceivedValue),
                          ),
                          const Divider(),
                          _diffRow(valueDifference, isCurrency: true),
                        ]),
                        _buildSummaryCard("WEIGHT SUMMARY", [
                          _summaryRow(
                            "Original Weight",
                            "${originalWeight.toStringAsFixed(2)} kg",
                          ),
                          _summaryRow(
                            "Recv. Weight",
                            "${currentReceivedWeight.toStringAsFixed(2)} kg",
                          ),
                          const Divider(),
                          _diffRow(weightDifference, isCurrency: false),
                        ]),
                        _buildReportCard(isReceived),
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

  // --- WIDGET COMPONENTS ---

  Widget _buildInfoHeader() {
    final s = widget.shipment;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _headerItem("VENDOR", s.vendorName, Icons.store),
          _headerItem("CARRIER", s.carrier, Icons.local_shipping),
          _headerItem(
            "EX. RATE",
            s.exchangeRate.toString(),
            Icons.currency_exchange,
          ),
          _headerItem(
            "DATE",
            DateFormat('yyyy-MM-dd').format(s.purchaseDate),
            Icons.calendar_today,
          ),
          _headerItem(
            "STATUS",
            s.isReceived ? "RECEIVED" : "ON WAY",
            s.isReceived ? Icons.check_circle : Icons.timer,
            color: s.isReceived ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _headerItem(String label, String val, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              val,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color ?? kHeaderColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemRow(int index, bool isReceived) {
    final item = editedItems[index];
    bool isLoss = item.lossQty > 0;
    bool isGain = item.lossQty < 0; // Negative loss means we received MORE

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          // PRODUCT INFO
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productModel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  item.productName,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Ctn: ${item.cartonNo}",
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // WEIGHT UNIT
          Expanded(
            flex: 1,
            child: Text(
              "${item.unitWeightSnapshot} kg",
              style: const TextStyle(fontSize: 11),
            ),
          ),

          // ORDERED
          Expanded(
            flex: 2,
            child: Text(
              "${item.seaQty} / ${item.airQty}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          // INPUTS (RECEIVED)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _erpInput(
                  value: item.receivedSeaQty,
                  label: "Sea",
                  enabled: !isReceived,
                  onChanged: (val) {
                    // COPY ITEM, UPDATE VALUE, TRIGGER STATE
                    final updated = ShipmentItem(
                      productId: item.productId,
                      productName: item.productName,
                      productModel: item.productModel,
                      productBrand: item.productBrand,
                      productCategory: item.productCategory,
                      unitWeightSnapshot: item.unitWeightSnapshot,
                      seaQty: item.seaQty,
                      airQty: item.airQty,
                      cartonNo: item.cartonNo,
                      seaPriceSnapshot: item.seaPriceSnapshot,
                      airPriceSnapshot: item.airPriceSnapshot,
                      ignoreMissing: item.ignoreMissing,
                      receivedAirQty: item.receivedAirQty, // Keep Air Same
                      receivedSeaQty: int.tryParse(val) ?? 0, // Update Sea
                    );
                    _updateItem(index, updated);
                  },
                ),
                const SizedBox(width: 8),
                _erpInput(
                  value: item.receivedAirQty,
                  label: "Air",
                  enabled: !isReceived,
                  onChanged: (val) {
                    final updated = ShipmentItem(
                      productId: item.productId,
                      productName: item.productName,
                      productModel: item.productModel,
                      productBrand: item.productBrand,
                      productCategory: item.productCategory,
                      unitWeightSnapshot: item.unitWeightSnapshot,
                      seaQty: item.seaQty,
                      airQty: item.airQty,
                      cartonNo: item.cartonNo,
                      seaPriceSnapshot: item.seaPriceSnapshot,
                      airPriceSnapshot: item.airPriceSnapshot,
                      ignoreMissing: item.ignoreMissing,
                      receivedSeaQty: item.receivedSeaQty, // Keep Sea Same
                      receivedAirQty: int.tryParse(val) ?? 0, // Update Air
                    );
                    _updateItem(index, updated);
                  },
                ),
              ],
            ),
          ),

          // STATUS
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
                                  : (v) {
                                    // Just toggle boolean
                                    final updated = ShipmentItem(
                                      productId: item.productId,
                                      productName: item.productName,
                                      productModel: item.productModel,
                                      productBrand: item.productBrand,
                                      productCategory: item.productCategory,
                                      unitWeightSnapshot:
                                          item.unitWeightSnapshot,
                                      seaQty: item.seaQty,
                                      airQty: item.airQty,
                                      cartonNo: item.cartonNo,
                                      seaPriceSnapshot: item.seaPriceSnapshot,
                                      airPriceSnapshot: item.airPriceSnapshot,
                                      receivedSeaQty: item.receivedSeaQty,
                                      receivedAirQty: item.receivedAirQty,
                                      ignoreMissing: v ?? false,
                                    );
                                    _updateItem(index, updated);
                                  },
                        ),
                        Expanded(
                          child: Text(
                            "Missing ${item.lossQty}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                    : isGain
                    ? Text(
                      "Extra +${item.lossQty.abs()}",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    )
                    : const Text(
                      "Matched",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _erpInput({
    required int value,
    required String label,
    required bool enabled,
    required Function(String) onChanged,
  }) {
    return Expanded(
      child: SizedBox(
        height: 35,
        child: TextFormField(
          initialValue: value.toString(),
          enabled: enabled,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 0,
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(top: 16, right: 16, left: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: kHeaderColor),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _diffRow(double diff, {required bool isCurrency}) {
    // If diff is positive: Original > Received (Shortage/Less Weight) -> Red
    // If diff is negative: Original < Received (Surplus/More Weight) -> Green
    // If diff is zero: Matched -> Grey

    Color color;
    String label;
    String sign = "";

    if (diff > 0.001) {
      color = Colors.red;
      label = isCurrency ? "SHORTAGE" : "WEIGHT LOSS";
      sign = "-";
    } else if (diff < -0.001) {
      color = Colors.green;
      label = isCurrency ? "SURPLUS" : "EXTRA WEIGHT";
      sign = "+";
    } else {
      color = Colors.grey;
      label = "MATCHED";
    }

    String valStr =
        isCurrency
            ? controller.formatMoney(diff.abs())
            : "${diff.abs().toStringAsFixed(2)} kg";

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            "$sign $valStr",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(bool isReceived) {
    return Card(
      margin: const EdgeInsets.only(top: 16, right: 16, bottom: 20),
      color: const Color(0xFFFFF7ED), // Light orange bg
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFFFEDD5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CARRIER / INTERNAL REPORT",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reportCtrl,
              enabled: !isReceived,
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: "Note damages, delays or adjustments...",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveConfirmation() {
    Get.defaultDialog(
      title: "Confirm Stock Receipt",
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        children: [
          const Text(
            "Are you sure you want to finalize this shipment?",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (valueDifference > 0)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red[50],
              child: Text(
                "Warning: Shortage of ${controller.formatMoney(valueDifference)} detected. This will be logged as Vendor Loss.",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            "Stock will be added to inventory immediately.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      textConfirm: "CONFIRM & RECEIVE",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: kHeaderColor,
      onConfirm: () {
        // Construct the updated model
        final updatedShipment = ShipmentModel(
          docId: widget.shipment.docId,
          shipmentName: widget.shipment.shipmentName,
          purchaseDate: widget.shipment.purchaseDate,
          vendorName: widget.shipment.vendorName,
          carrier: widget.shipment.carrier,
          exchangeRate: widget.shipment.exchangeRate,

          // Preserve Original Data
          totalCartons: widget.shipment.totalCartons,
          totalWeight: widget.shipment.totalWeight,
          carrierCostPerCarton: widget.shipment.carrierCostPerCarton,
          totalCarrierFee: widget.shipment.totalCarrierFee,
          totalAmount: widget.shipment.totalAmount,

          isReceived: false,
          items: editedItems,
          carrierReport: reportCtrl.text,
        );

        // Save & Process
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
}