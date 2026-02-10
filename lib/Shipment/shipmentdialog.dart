// ignore_for_file: deprecated_member_use, avoid_print
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'shipmodel.dart';

void showShipmentEntryDialog(
  Product? p, // Nullable: Pass null to CREATE NEW PRODUCT
  ShipmentController shipCtrl,
  ProductController prodCtrl,
  double globalRate, {
  Function(ShipmentItem)? onSubmit,
}) {
  final isNewProduct = p == null;

  // -- CONTROLLERS --
  final nameC = TextEditingController(text: p?.name ?? '');
  final categoryC = TextEditingController(
    text: p?.category ?? 'Mobile Accessories',
  );
  final brandC = TextEditingController(text: p?.brand ?? '');
  final modelC = TextEditingController(text: p?.model ?? '');

  // Rates & Weights
  double effectiveRate = (globalRate > 0) ? globalRate : (p?.currency ?? 18.20);
  final weightC = TextEditingController(text: (p?.weight ?? 0.0).toString());
  final yuanC = TextEditingController(text: (p?.yuan ?? 0.0).toString());
  final currencyC = TextEditingController(text: effectiveRate.toString());

  // Tax
  final seaTaxC = TextEditingController(
    text: (p?.shipmentTax ?? 550.0).toString(),
  );
  final airTaxC = TextEditingController(
    text: (p?.shipmentTaxAir ?? 1200.0).toString(),
  );

  // Prices (Calculated)
  double initSea =
      isNewProduct
          ? 0.0
          : (p.yuan * effectiveRate) + (p.weight * p.shipmentTax);
  double initAir =
      isNewProduct
          ? 0.0
          : (p.yuan * effectiveRate) + (p.weight * p.shipmentTaxAir);

  final seaPriceC = TextEditingController(text: initSea.toStringAsFixed(2));
  final airPriceC = TextEditingController(text: initAir.toStringAsFixed(2));

  // Sales
  final agentC = TextEditingController(text: (p?.agent ?? 0).toString());
  final wholesaleC = TextEditingController(
    text: (p?.wholesale ?? 0).toString(),
  );
  final alertQtyC = TextEditingController(text: (p?.alertQty ?? 5).toString());

  // Shipment Quantity
  final addSeaQtyC = TextEditingController(text: '0');
  final addAirQtyC = TextEditingController(text: '0');
  final cartonNoC = TextEditingController();

  // Stock Reference (Only for existing)
  final oldSeaStock = p?.seaStockQty ?? 0;
  final oldAirStock = p?.airStockQty ?? 0;
  final oldLocalStock = p?.localQty ?? 0;
  final onWayQty = isNewProduct ? 0 : shipCtrl.getOnWayQty(p.id);

  // -- LOGIC: Auto Calculate Prices --
  void recalculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr = double.tryParse(currencyC.text) ?? 0.0;
    double sTax = double.tryParse(seaTaxC.text) ?? 0.0;
    double aTax = double.tryParse(airTaxC.text) ?? 0.0;

    double calculatedSea = (yuan * curr) + (weight * sTax);
    double calculatedAir = (yuan * curr) + (weight * aTax);

    seaPriceC.text = calculatedSea.toStringAsFixed(2);
    airPriceC.text = calculatedAir.toStringAsFixed(2);
  }

  // Bind Listeners
  yuanC.addListener(recalculatePrices);
  weightC.addListener(recalculatePrices);
  currencyC.addListener(recalculatePrices);
  seaTaxC.addListener(recalculatePrices);
  airTaxC.addListener(recalculatePrices);

  // If new, trigger once to set zeros or defaults
  if (isNewProduct) recalculatePrices();

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 850,
        constraints: const BoxConstraints(maxHeight: 850),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color:
                    isNewProduct
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNewProduct ? Icons.add_circle : Icons.edit,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isNewProduct
                        ? "NEW PRODUCT ENTRY"
                        : "EDIT ${p.model.toUpperCase()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (!isNewProduct)
                    Text(
                      "On Way: $onWayQty",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY (Scrollable) ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: BASIC INFO
                    _sectionTitle("IDENTITY"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(
                            modelC,
                            "Model No.",
                            autoFocus: isNewProduct,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(nameC, "Product Name")),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(brandC, "Brand")),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(categoryC, "Category")),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 2: COSTING
                    _sectionTitle("COSTING PARAMETERS"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(yuanC, "Yuan (¥)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(currencyC, "Rate", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(weightC, "Weight (KG)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(seaTaxC, "Sea Tax", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(airTaxC, "Air Tax", isNum: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 3: CALCULATED COSTS & SALES
                    Row(
                      children: [
                        // Calculated Costs
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("LANDING COST (AUTO)"),
                              Row(
                                children: [
                                  Expanded(
                                    child: _erpReadOnly(
                                      seaPriceC,
                                      "Sea Cost",
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _erpReadOnly(
                                      airPriceC,
                                      "Air Cost",
                                      Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Sales Prices
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("SALES PRICES"),
                              Row(
                                children: [
                                  Expanded(
                                    child: _erpInput(
                                      agentC,
                                      "Agent",
                                      isNum: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _erpInput(
                                      wholesaleC,
                                      "Wholesale",
                                      isNum: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 4: SHIPMENT ENTRY & SETTINGS
                    _sectionTitle("MANIFEST ENTRY"),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _erpInput(
                              addSeaQtyC,
                              "Add Sea Qty",
                              isNum: true,
                              bgColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _erpInput(
                              addAirQtyC,
                              "Add Air Qty",
                              isNum: true,
                              bgColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _erpInput(
                              cartonNoC,
                              "Carton No",
                              bgColor: Colors.white,
                              hint: "1-5",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _erpInput(
                              alertQtyC,
                              "Alert Qty",
                              isNum: true,
                              bgColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // UPDATED CURRENT STOCK DISPLAY
                    if (!isNewProduct)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: Colors.orange[800],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "CURRENT STOCK:   SEA: $oldSeaStock   |   AIR: $oldAirStock   |   LOCAL: $oldLocalStock",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --- FOOTER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // 1. Validation
                      if (modelC.text.isEmpty || nameC.text.isEmpty) {
                        Get.snackbar("Required", "Model and Name are missing");
                        return;
                      }

                      // Capture calculated costs
                      double sCost = double.tryParse(seaPriceC.text) ?? 0.0;
                      double aCost = double.tryParse(airPriceC.text) ?? 0.0;

                      // 2. Prepare Data Map (FIXED AVG PURCHASE PRICE)
                      final Map<String, dynamic> data = {
                        'name': nameC.text,
                        'category': categoryC.text,
                        'brand': brandC.text,
                        'model': modelC.text,
                        'yuan': double.tryParse(yuanC.text) ?? 0.0,
                        'weight': double.tryParse(weightC.text) ?? 0.0,
                        'currency': double.tryParse(currencyC.text) ?? 0.0,
                        'shipmenttax': double.tryParse(seaTaxC.text) ?? 0.0,
                        'shipmenttaxair': double.tryParse(airTaxC.text) ?? 0.0,

                        // Calculated Costs
                        'sea': sCost,
                        'air': aCost,

                        // *** FIX: Explicitly set avg_purchase_price ***
                        'avg_purchase_price': sCost > 0 ? sCost : aCost,

                        'agent': double.tryParse(agentC.text) ?? 0.0,
                        'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
                        'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
                      };

                      // 3. Preserve Stock Logic
                      if (!isNewProduct) {
                        data['stock_qty'] = p.stockQty;
                        data['sea_stock_qty'] = p.seaStockQty;
                        data['air_stock_qty'] = p.airStockQty;
                        data['local_qty'] = p.localQty;
                      } else {
                        data['stock_qty'] = 0;
                        data['sea_stock_qty'] = 0;
                        data['air_stock_qty'] = 0;
                        data['local_qty'] = 0;
                      }

                      int sQty = int.tryParse(addSeaQtyC.text) ?? 0;
                      int aQty = int.tryParse(addAirQtyC.text) ?? 0;

                      // 4. Submit
                      if (onSubmit != null) {
                        // Edit Existing Item in Manifest List
                        final newItem = ShipmentItem(
                          productId: isNewProduct ? 0 : p.id,
                          productName: nameC.text,
                          productModel: modelC.text,
                          productBrand: brandC.text,
                          productCategory: categoryC.text,
                          unitWeightSnapshot:
                              double.tryParse(weightC.text) ?? 0,
                          seaQty: 0,
                          airQty: 0,
                          receivedSeaQty: sQty,
                          receivedAirQty: aQty,
                          cartonNo: cartonNoC.text,
                          seaPriceSnapshot: sCost,
                          airPriceSnapshot: aCost,
                          ignoreMissing: true,
                        );
                        onSubmit(newItem);
                        Get.back();
                      } else {
                        // Add New to Controller
                        shipCtrl.addToManifestAndVerify(
                          productId: isNewProduct ? null : p.id,
                          productData: data,
                          seaQty: sQty,
                          airQty: aQty,
                          cartonNo: cartonNoC.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isNewProduct
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF1E293B),
                    ),
                    child: Text(
                      isNewProduct ? "CREATE & ADD" : "UPDATE & ADD",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// --- SMALLER ERP INPUTS WIDGETS ---
Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
      ),
    ),
  );
}

Widget _erpInput(
  TextEditingController ctrl,
  String label, {
  bool isNum = false,
  bool autoFocus = false,
  Color? bgColor,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 36, // Compact height for ERP
        child: TextField(
          controller: ctrl,
          autofocus: autoFocus,
          keyboardType:
              isNum
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            filled: true,
            fillColor: bgColor ?? Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _erpReadOnly(TextEditingController ctrl, String label, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: TextField(
          controller: ctrl,
          readOnly: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
    ],
  );
}