// ignore_for_file: deprecated_member_use, avoid_print
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'shipmodel.dart'; // Ensure this matches your project structure

// --- SHOW SHIPMENT ENTRY DIALOG (UPDATED WITH LOCAL QTY) ---

void showShipmentEntryDialog(
  Product? p, // Nullable: Pass null to CREATE NEW PRODUCT
  ShipmentController shipCtrl,
  ProductController prodCtrl,
  double globalRate, {
  Function(ShipmentItem)? onSubmit,
}) {
  // Flag to check if we are creating a new product or editing existing one
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

  // Alert Qty
  final alertQtyC = TextEditingController(text: (p?.alertQty ?? 5).toString());

  // Shipment Quantity
  final addSeaQtyC = TextEditingController(text: '0');
  final addAirQtyC = TextEditingController(text: '0');
  final cartonNoC = TextEditingController();

  // Stock Reference (Only for existing)
  final oldSeaStock = p?.seaStockQty ?? 0;
  final oldAirStock = p?.airStockQty ?? 0;
  final oldLocalStock = p?.localQty ?? 0; // <--- ADDED LOCAL STOCK REFERENCE
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 900),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isNewProduct ? Colors.teal[800] : Colors.blue[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNewProduct ? Icons.add_circle_outline : Icons.edit_note,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNewProduct
                            ? "CREATE NEW PRODUCT"
                            : "EDIT & ADD TO MANIFEST",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        isNewProduct
                            ? "Enter details to create and add to shipment"
                            : "Model: ${p.model.toUpperCase()}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!isNewProduct)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "On Way: $onWayQty",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
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
                    _sectionTitle("PRODUCT IDENTITY"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(
                            modelC,
                            "Model No.",
                            autoFocus: isNewProduct,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _erpInput(nameC, "Product Name")),
                        const SizedBox(width: 16),
                        Expanded(child: _erpInput(brandC, "Brand")),
                        const SizedBox(width: 16),
                        Expanded(child: _erpInput(categoryC, "Category")),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ROW 2: COSTING
                    _sectionTitle("COSTING & WEIGHT"),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _erpInput(
                              yuanC,
                              "Yuan (¥)",
                              isNum: true,
                              prefix: "¥ ",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _erpInput(
                              currencyC,
                              "Ex. Rate",
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _erpInput(
                              weightC,
                              "Weight (KG)",
                              isNum: true,
                              suffix: " kg",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _erpInput(
                              seaTaxC,
                              "Sea Tax/KG",
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _erpInput(
                              airTaxC,
                              "Air Tax/KG",
                              isNum: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ROW 3: CALCULATED COSTS & SALES
                    Row(
                      children: [
                        // Calculated Costs
                        Expanded(
                          flex: 4,
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
                                  const SizedBox(width: 16),
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
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("SALES PRICING"),
                              Row(
                                children: [
                                  Expanded(
                                    child: _erpInput(
                                      agentC,
                                      "Agent",
                                      isNum: true,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
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
                    const SizedBox(height: 24),

                    // ROW 4: SHIPMENT ENTRY & SETTINGS
                    _sectionTitle("SHIPMENT QUANTITY & SETTINGS"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _erpInput(
                                  addSeaQtyC,
                                  "Sea Quantity",
                                  isNum: true,
                                  bgColor: Colors.white,
                                  hasBorder: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _erpInput(
                                  addAirQtyC,
                                  "Air Quantity",
                                  isNum: true,
                                  bgColor: Colors.white,
                                  hasBorder: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: _erpInput(
                                  cartonNoC,
                                  "Carton Number(s)",
                                  bgColor: Colors.white,
                                  hasBorder: true,
                                  hint: "e.g. 1-5",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              // Added Alert Qty Field
                              Expanded(
                                flex: 2,
                                child: _erpInput(
                                  alertQtyC,
                                  "Alert Qty",
                                  isNum: true,
                                  bgColor: Colors.white,
                                  hasBorder: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Mini Summary for Existing
                              Expanded(
                                flex: 5,
                                child:
                                    !isNewProduct
                                        ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Current Stock (Preserved)",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _miniStockTag(
                                                  "Sea",
                                                  oldSeaStock,
                                                ),
                                                const SizedBox(width: 8),
                                                _miniStockTag(
                                                  "Air",
                                                  oldAirStock,
                                                ),
                                                const SizedBox(width: 8),
                                                // --- ADDED LOCAL QTY ---
                                                _miniStockTag(
                                                  "Loc",
                                                  oldLocalStock,
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                        : Container(),
                              ),
                            ],
                          ),
                        ],
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
                border: Border(top: BorderSide(color: Colors.black12)),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // 1. Validation
                      if (modelC.text.isEmpty || nameC.text.isEmpty) {
                        Get.snackbar(
                          "Missing Info",
                          "Name and Model are required",
                        );
                        return;
                      }

                      // 2. Prepare Data Map
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
                        'sea': double.tryParse(seaPriceC.text) ?? 0.0,
                        'air': double.tryParse(airPriceC.text) ?? 0.0,
                        'agent': double.tryParse(agentC.text) ?? 0.0,
                        'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
                        'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
                      };

                      // --- PRESERVE ALL STOCK FOR EXISTING PRODUCTS ---
                      if (!isNewProduct) {
                        data['stock_qty'] = p.stockQty;
                        data['sea_stock_qty'] = p.seaStockQty;
                        data['air_stock_qty'] = p.airStockQty;
                        data['local_qty'] =
                            p.localQty; // Ensure Local Qty is sent back
                      } else {
                        // For NEW products, start with 0 stock
                        data['stock_qty'] = 0;
                        data['sea_stock_qty'] = 0;
                        data['air_stock_qty'] = 0;
                        data['local_qty'] = 0;
                      }

                      int sQty = int.tryParse(addSeaQtyC.text) ?? 0;
                      int aQty = int.tryParse(addAirQtyC.text) ?? 0;

                      if (onSubmit != null) {
                        // For editing items already in manifest or details
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
                          seaPriceSnapshot:
                              double.tryParse(seaPriceC.text) ?? 0,
                          airPriceSnapshot:
                              double.tryParse(airPriceC.text) ?? 0,
                          ignoreMissing: true,
                        );
                        onSubmit(newItem);
                        Get.back();
                      } else {
                        // MAIN FLOW: Add to Controller
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
                          isNewProduct ? Colors.teal[700] : Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      elevation: 2,
                    ),
                    icon: Icon(
                      isNewProduct ? Icons.save : Icons.add_shopping_cart,
                      size: 20,
                    ),
                    label: Text(
                      isNewProduct
                          ? "CREATE & ADD TO SHIPMENT"
                          : "UPDATE & ADD TO SHIPMENT",
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

// --- ERP UI COMPONENTS ---

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 0.8,
      ),
    ),
  );
}

Widget _erpInput(
  TextEditingController ctrl,
  String label, {
  bool isNum = false,
  bool autoFocus = false,
  String? prefix,
  String? suffix,
  Color? bgColor,
  bool hasBorder = false,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 42,
        child: TextField(
          controller: ctrl,
          autofocus: autoFocus,
          keyboardType:
              isNum
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            filled: true,
            fillColor: bgColor ?? Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  hasBorder
                      ? const BorderSide(color: Colors.black12)
                      : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  hasBorder
                      ? const BorderSide(color: Colors.black12)
                      : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _erpReadOnly(TextEditingController ctrl, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
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
        const SizedBox(height: 2),
        TextField(
          controller: ctrl,
          readOnly: true,
          decoration: const InputDecoration.collapsed(hintText: ""),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    ),
  );
}

Widget _miniStockTag(String type, int qty) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      "$type: $qty",
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}