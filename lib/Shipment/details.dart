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

  // Local state for editing
  late List<ShipmentItem> editedItems;

  // New Edit Mode State
  bool _isEditingManifest = false;
  late TextEditingController _cartonCountCtrl;
  late TextEditingController _carrierRateCtrl;

  @override
  void initState() {
    super.initState();
    reportCtrl = TextEditingController(
      text: widget.shipment.carrierReport ?? "",
    );
    _cartonCountCtrl = TextEditingController(
      text: widget.shipment.totalCartons.toString(),
    );
    _carrierRateCtrl = TextEditingController(
      text: widget.shipment.carrierCostPerCarton.toString(),
    );

    // Deep Copy of items
    _resetEditedItems();
  }

  void _resetEditedItems() {
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
    _cartonCountCtrl.dispose();
    _carrierRateCtrl.dispose();
    super.dispose();
  }

  void _updateItem(int index, ShipmentItem newItem) {
    setState(() {
      editedItems[index] = newItem;
    });
  }

  void _deleteItem(int index) {
    setState(() {
      editedItems.removeAt(index);
    });
  }

  // --- CALCULATIONS ---

  // Live Recalculations for EDIT MODE
  double get liveProductCost =>
      editedItems.fold(0.0, (sum, e) => sum + e.totalItemCost);
  double get liveTotalWeight => editedItems.fold(
    0.0,
    (sum, e) => sum + (e.unitWeightSnapshot * (e.seaQty + e.airQty)),
  );
  double get liveCarrierCost {
    int ctn = int.tryParse(_cartonCountCtrl.text) ?? 0;
    double rate = double.tryParse(_carrierRateCtrl.text) ?? 0.0;
    return ctn * rate;
  }

  // The grand total of the shipment (Product + Carrier)
  double get liveGrandTotal => liveProductCost + liveCarrierCost;

  // Financials for RECEIVE MODE (Comparison)
  double get totalReceivedValue =>
      editedItems.fold(0.0, (sum, e) => sum + e.receivedItemValue);
  double get valueDifference =>
      widget.shipment.totalAmount - totalReceivedValue; // Positive = Loss

  // Weights for RECEIVE MODE (Comparison)
  double get currentReceivedWeight => editedItems.fold(0.0, (sum, e) {
    int totalReceivedQty = e.receivedSeaQty + e.receivedAirQty;
    return sum + (totalReceivedQty * e.unitWeightSnapshot);
  });
  double get weightDifference =>
      widget.shipment.totalWeight -
      currentReceivedWeight; // Positive = Weight Loss

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

  void _toggleEditMode() {
    setState(() {
      _isEditingManifest = !_isEditingManifest;
    });
  }

  void _saveManifestChanges() {
    int cartons = int.tryParse(_cartonCountCtrl.text) ?? 0;
    double rate = double.tryParse(_carrierRateCtrl.text) ?? 0.0;

    Get.defaultDialog(
      title: "Recalculate & Save?",
      middleText:
          "This will update the Original Bill, Weight, and Carrier Costs based on your changes.",
      textConfirm: "SAVE UPDATES",
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back(); // close dialog
        await controller.saveEditedManifest(
          docId: widget.shipment.docId!,
          newItems: editedItems,
          newCartonCount: cartons,
          newCarrierRate: rate,
          report: reportCtrl.text,
        );
        setState(() {
          _isEditingManifest = false;
        });
        Get.back(); // Return to previous screen usually, or stay
      },
      textCancel: "Cancel",
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isReceived = widget.shipment.isReceived;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: Text(
          _isEditingManifest
              ? "EDITING MODE"
              : "MANIFEST: ${widget.shipment.shipmentName}",
          style: TextStyle(
            color: _isEditingManifest ? Colors.red : kHeaderColor,
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
          // EDIT MODE TOGGLE
          if (!isReceived)
            Row(
              children: [
                const Text(
                  "EDIT",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _isEditingManifest,
                  activeColor: Colors.red,
                  onChanged: (val) => _toggleEditMode(),
                ),
              ],
            ),

          // ADD ITEM: Enabled in BOTH modes now, as per request
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isEditingManifest ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_isEditingManifest ? Icons.save : Icons.save_as),
                label: Text(_isEditingManifest ? "RE-CALC" : "SAVE"),
                onPressed: () {
                  if (_isEditingManifest) {
                    _saveManifestChanges();
                  } else {
                    controller.updateShipmentDetails(
                      widget.shipment,
                      editedItems,
                      reportCtrl.text,
                    );
                  }
                },
              ),
            ),

          if (!isReceived && !_isEditingManifest)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kHeaderColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text("RECEIVE"),
              onPressed: () => _showReceiveConfirmation(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. INFO HEADER (METADATA + CARTONS + RATE)
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
                          decoration: BoxDecoration(
                            color:
                                _isEditingManifest
                                    ? Colors.red[50]
                                    : kHeaderColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  "PRODUCT INFO",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  "WGT/Unit",
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _isEditingManifest
                                      ? "ORDERED (S/A)"
                                      : "ORDERED",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _isEditingManifest
                                      ? "PRICES (Sea / Air)"
                                      : "RECEIVED (Sea / Air)",
                                  style: TextStyle(
                                    color:
                                        _isEditingManifest
                                            ? Colors.black
                                            : Colors.yellowAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  "STATUS / ACTION",
                                  style: TextStyle(fontSize: 12),
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
                        _buildFinancialSummary(), // NEW DETAILED SUMMARY
                        _buildWeightSummary(),
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

          // EDITABLE HEADER FIELDS
          _isEditingManifest
              ? _editableHeaderField("CTNS", _cartonCountCtrl)
              : _headerItem(
                "CTNS",
                s.totalCartons.toString(),
                Icons.inventory_2,
              ),

          _isEditingManifest
              ? _editableHeaderField("RATE", _carrierRateCtrl)
              : _headerItem(
                "RATE",
                s.carrierCostPerCarton.toString(),
                Icons.monetization_on,
              ),

          _headerItem(
            "DATE",
            DateFormat('MM/dd').format(s.purchaseDate),
            Icons.calendar_today,
          ),
          _headerItem(
            "STATUS",
            s.isReceived ? "RCVD" : "ON WAY",
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

  Widget _editableHeaderField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10),
          isDense: true,
          contentPadding: const EdgeInsets.all(4),
          border: const OutlineInputBorder(),
        ),
        onChanged:
            (val) =>
                setState(() {}), // trigger recalculation of liveCarrierCost
      ),
    );
  }

  Widget _buildItemRow(int index, bool isReceived) {
    final item = editedItems[index];
    bool isLoss = item.lossQty > 0;
    bool isGain = item.lossQty < 0;

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
                _isEditingManifest
                    ? SizedBox(
                      height: 25,
                      width: 60,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Ctn#",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 10),
                        controller: TextEditingController(text: item.cartonNo),
                        onChanged: (val) {
                          final updated = _copyItemWith(item, cartonNo: val);
                          _updateItem(index, updated);
                        },
                      ),
                    )
                    : Text(
                      "Ctn: ${item.cartonNo}",
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
              ],
            ),
          ),

          // WEIGHT UNIT (Now Editable Without Edit Mode)
          Expanded(
            flex: 1,
            child:
                !isReceived
                    // FIX 1: Removed Expanded inside this call
                    ? _erpInputSmall(
                      value: item.unitWeightSnapshot.toString(),
                      onChanged: (val) {
                        double w = double.tryParse(val) ?? 0.0;
                        final updated = _copyItemWith(
                          item,
                          unitWeightSnapshot: w,
                        );
                        _updateItem(index, updated);
                      },
                    )
                    : Text(
                      "${item.unitWeightSnapshot} kg",
                      style: const TextStyle(fontSize: 11),
                    ),
          ),

          // ORDERED QTY (Editable in Edit Mode)
          Expanded(
            flex: 2,
            child:
                _isEditingManifest
                    ? Row(
                      children: [
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInputSmall(
                            value: item.seaQty.toString(),
                            label: "S",
                            onChanged: (v) {
                              int q = int.tryParse(v) ?? 0;
                              // When editing ordered qty, auto-update received qty to match
                              _updateItem(
                                index,
                                _copyItemWith(
                                  item,
                                  seaQty: q,
                                  receivedSeaQty: q,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInputSmall(
                            value: item.airQty.toString(),
                            label: "A",
                            onChanged: (v) {
                              int q = int.tryParse(v) ?? 0;
                              _updateItem(
                                index,
                                _copyItemWith(
                                  item,
                                  airQty: q,
                                  receivedAirQty: q,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                    : Text(
                      "${item.seaQty} / ${item.airQty}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
          ),

          // INPUTS (RECEIVED OR PRICES)
          Expanded(
            flex: 3,
            child:
                _isEditingManifest
                    // EDIT MODE: SHOW PRICES
                    ? Row(
                      children: [
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInputSmall(
                            value: item.seaPriceSnapshot.toString(),
                            label: "\$Sea",
                            onChanged: (v) {
                              _updateItem(
                                index,
                                _copyItemWith(
                                  item,
                                  seaPriceSnapshot: double.tryParse(v) ?? 0,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInputSmall(
                            value: item.airPriceSnapshot.toString(),
                            label: "\$Air",
                            onChanged: (v) {
                              _updateItem(
                                index,
                                _copyItemWith(
                                  item,
                                  airPriceSnapshot: double.tryParse(v) ?? 0,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                    // NORMAL MODE: SHOW RECEIVED INPUTS
                    : Row(
                      children: [
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInput(
                            value: item.receivedSeaQty,
                            label: "Sea",
                            enabled: !isReceived,
                            onChanged: (val) {
                              final updated = _copyItemWith(
                                item,
                                receivedSeaQty: int.tryParse(val) ?? 0,
                              );
                              _updateItem(index, updated);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // FIX 2: Wrapped in Expanded here
                        Expanded(
                          child: _erpInput(
                            value: item.receivedAirQty,
                            label: "Air",
                            enabled: !isReceived,
                            onChanged: (val) {
                              final updated = _copyItemWith(
                                item,
                                receivedAirQty: int.tryParse(val) ?? 0,
                              );
                              _updateItem(index, updated);
                            },
                          ),
                        ),
                      ],
                    ),
          ),

          // STATUS OR DELETE
          Expanded(
            flex: 2,
            child:
                _isEditingManifest
                    ? IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteItem(index),
                    )
                    : (isLoss
                        ? Row(
                          children: [
                            Checkbox(
                              value: item.ignoreMissing,
                              activeColor: Colors.orange,
                              onChanged:
                                  isReceived
                                      ? null
                                      : (v) => _updateItem(
                                        index,
                                        _copyItemWith(
                                          item,
                                          ignoreMissing: v ?? false,
                                        ),
                                      ),
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
                        )),
          ),
        ],
      ),
    );
  }

  // Helper to copy item easily
  ShipmentItem _copyItemWith(
    ShipmentItem original, {
    String? cartonNo,
    int? seaQty,
    int? airQty,
    int? receivedSeaQty,
    int? receivedAirQty,
    double? unitWeightSnapshot,
    double? seaPriceSnapshot,
    double? airPriceSnapshot,
    bool? ignoreMissing,
  }) {
    return ShipmentItem(
      productId: original.productId,
      productName: original.productName,
      productModel: original.productModel,
      productBrand: original.productBrand,
      productCategory: original.productCategory,
      unitWeightSnapshot: unitWeightSnapshot ?? original.unitWeightSnapshot,
      seaQty: seaQty ?? original.seaQty,
      airQty: airQty ?? original.airQty,
      receivedSeaQty: receivedSeaQty ?? original.receivedSeaQty,
      receivedAirQty: receivedAirQty ?? original.receivedAirQty,
      cartonNo: cartonNo ?? original.cartonNo,
      seaPriceSnapshot: seaPriceSnapshot ?? original.seaPriceSnapshot,
      airPriceSnapshot: airPriceSnapshot ?? original.airPriceSnapshot,
      ignoreMissing: ignoreMissing ?? original.ignoreMissing,
    );
  }

  // FIX 3: Removed Expanded from this helper
  Widget _erpInput({
    required int value,
    required String label,
    required bool enabled,
    required Function(String) onChanged,
  }) {
    return SizedBox(
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
    );
  }

  // FIX 3: Removed Expanded from this helper
  Widget _erpInputSmall({
    required String value,
    String? label,
    required Function(String) onChanged,
  }) {
    return SizedBox(
      height: 30,
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 11, color: Colors.red),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFinancialSummary() {
    double prodCost =
        _isEditingManifest ? liveProductCost : widget.shipment.totalAmount;
    double carrCost =
        _isEditingManifest ? liveCarrierCost : widget.shipment.totalCarrierFee;
    double grandTot = prodCost + carrCost;

    return Card(
      margin: const EdgeInsets.only(top: 16, right: 16, left: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _isEditingManifest ? Colors.red : kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditingManifest ? "LIVE RECALCULATION" : "FINANCIAL SUMMARY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: _isEditingManifest ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 10),

            _summaryRow("Product Cost", controller.formatMoney(prodCost)),
            _summaryRow("Carrier Cost", controller.formatMoney(carrCost)),
            const Divider(),
            _summaryRow(
              "ORIGINAL BILL",
              controller.formatMoney(grandTot),
              isBold: true,
            ),

            if (!_isEditingManifest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: kBgColor,
                child: Column(
                  children: [
                    _summaryRow(
                      "Received Value",
                      controller.formatMoney(totalReceivedValue),
                    ),
                    const SizedBox(height: 4),
                    _diffRow(valueDifference, isCurrency: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSummary() {
    double originalW =
        _isEditingManifest ? liveTotalWeight : widget.shipment.totalWeight;

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
            const Text(
              "WEIGHT SUMMARY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            _summaryRow(
              "Original Weight",
              "${originalW.toStringAsFixed(2)} kg",
            ),
            if (!_isEditingManifest) ...[
              _summaryRow(
                "Recv. Weight",
                "${currentReceivedWeight.toStringAsFixed(2)} kg",
              ),
              const Divider(),
              _diffRow(weightDifference, isCurrency: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isBold ? Colors.black : kHeaderColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isBold ? kAccentColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffRow(double diff, {required bool isCurrency}) {
    Color color;
    String label;
    String sign = "";

    if (diff > 0.001) {
      color = Colors.red;
      label = isCurrency ? "SHORTAGE" : "LOSS";
      sign = "-";
    } else if (diff < -0.001) {
      color = Colors.green;
      label = isCurrency ? "SURPLUS" : "EXTRA";
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
        final updatedShipment = ShipmentModel(
          docId: widget.shipment.docId,
          shipmentName: widget.shipment.shipmentName,
          purchaseDate: widget.shipment.purchaseDate,
          vendorName: widget.shipment.vendorName,
          carrier: widget.shipment.carrier,
          exchangeRate: widget.shipment.exchangeRate,
          totalCartons: widget.shipment.totalCartons,
          totalWeight: widget.shipment.totalWeight,
          carrierCostPerCarton: widget.shipment.carrierCostPerCarton,
          totalCarrierFee: widget.shipment.totalCarrierFee,
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
}