// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'shipmodel.dart'; // Import the model for ShipmentItem

// Modified to accept a callback for custom logic (Details Page)
void showShipmentEntryDialog(
  Product p,
  ShipmentController shipCtrl,
  ProductController prodCtrl,
  double globalRate, {
  Function(ShipmentItem)? onSubmit, // Optional callback
}) {
  final nameC = TextEditingController(text: p.name);
  final categoryC = TextEditingController(text: p.category);
  final brandC = TextEditingController(text: p.brand);
  final modelC = TextEditingController(text: p.model);

  double effectiveRate = (globalRate > 0) ? globalRate : p.currency;

  final weightC = TextEditingController(text: p.weight.toString());
  final yuanC = TextEditingController(text: p.yuan.toString());
  final currencyC = TextEditingController(text: effectiveRate.toString());
  final seaTaxC = TextEditingController(text: p.shipmentTax.toString());
  final airTaxC = TextEditingController(text: p.shipmentTaxAir.toString());

  double initSea = (p.yuan * effectiveRate) + (p.weight * p.shipmentTax);
  double initAir = (p.yuan * effectiveRate) + (p.weight * p.shipmentTaxAir);

  final seaPriceC = TextEditingController(text: initSea.toStringAsFixed(2));
  final airPriceC = TextEditingController(text: initAir.toStringAsFixed(2));

  final agentC = TextEditingController(text: p.agent.toString());
  final wholesaleC = TextEditingController(text: p.wholesale.toString());

  final oldSeaStockC = TextEditingController(text: p.seaStockQty.toString());
  final oldAirStockC = TextEditingController(text: p.airStockQty.toString());
  final oldLocalStockC = TextEditingController(text: p.localQty.toString());

  final addSeaQtyC = TextEditingController(text: '0');
  final addAirQtyC = TextEditingController(text: '0');
  final cartonNoC = TextEditingController();

  int onWayQty = shipCtrl.getOnWayQty(p.id);

  void recalculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr = double.tryParse(currencyC.text) ?? 0.0;
    double sTax = double.tryParse(seaTaxC.text) ?? 0.0;
    double aTax = double.tryParse(airTaxC.text) ?? 0.0;

    if (yuan > 0) {
      double calculatedSea = (yuan * curr) + (weight * sTax);
      double calculatedAir = (yuan * curr) + (weight * aTax);
      seaPriceC.text = calculatedSea.toStringAsFixed(2);
      airPriceC.text = calculatedAir.toStringAsFixed(2);
    }
  }

  yuanC.addListener(recalculatePrices);
  weightC.addListener(recalculatePrices);
  currencyC.addListener(recalculatePrices);
  seaTaxC.addListener(recalculatePrices);
  airTaxC.addListener(recalculatePrices);

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      backgroundColor: Colors.grey[50],
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        onSubmit != null ? "ADD EXTRA ITEM" : "ADD TO MANIFEST",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        p.model.toUpperCase(),
                        style: TextStyle(color: Colors.blue[100], fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "On Way: $onWayQty",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _posHeader("PRODUCT IDENTITY"),
                    Row(
                      children: [
                        Expanded(child: _posInput(nameC, "Product Name")),
                        const SizedBox(width: 12),
                        Expanded(child: _posInput(brandC, "Brand")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _posInput(modelC, "Model")),
                        const SizedBox(width: 12),
                        Expanded(child: _posInput(categoryC, "Category")),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _posHeader("COST CALCULATION (AUTO UPDATES)"),
                    Row(
                      children: [
                        Expanded(
                          child: _posInput(yuanC, "Yuan (¥)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _posInput(weightC, "Weight (KG)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _posInput(currencyC, "Ex. Rate", isNum: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _posInput(seaTaxC, "Sea Tax/KG", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _posInput(airTaxC, "Air Tax/KG", isNum: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _posReadOnly(
                            seaPriceC,
                            "Sea Price",
                            icon: Icons.waves,
                            color: Colors.blue[700]!,
                            bgColor: Colors.blue[50]!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _posReadOnly(
                            airPriceC,
                            "Air Price",
                            icon: Icons.air,
                            color: Colors.orange[800]!,
                            bgColor: Colors.orange[50]!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _posHeader("SALES PRICING (UPDATE)"),
                    Row(
                      children: [
                        Expanded(
                          child: _posInput(agentC, "Agent Price", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _posInput(
                            wholesaleC,
                            "Wholesale",
                            isNum: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _posHeader("CURRENT WAREHOUSE STOCK (REF ONLY)"),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _stockBadge("Sea Stock", oldSeaStockC.text),
                          ),
                          _vDivider(),
                          Expanded(
                            child: _stockBadge("Air Stock", oldAirStockC.text),
                          ),
                          _vDivider(),
                          Expanded(
                            child: _stockBadge("Local", oldLocalStockC.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(
                          color: Colors.blue[200]!,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                size: 20,
                                color: Colors.blue[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                onSubmit != null
                                    ? "ADD EXTRA QUANTITY"
                                    : "SHIPMENT QUANTITY",
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _posInput(
                                  addSeaQtyC,
                                  "Sea Qty",
                                  isNum: true,
                                  borderColor: Colors.blue[300],
                                  filledColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _posInput(
                                  addAirQtyC,
                                  "Air Qty",
                                  isNum: true,
                                  borderColor: Colors.blue[300],
                                  filledColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _posInput(
                            cartonNoC,
                            "Carton Number (e.g. 1-10)",
                            borderColor: Colors.blue[300],
                            filledColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final updates = {
                        'name': nameC.text,
                        'category': categoryC.text,
                        'brand': brandC.text,
                        'model': modelC.text,
                        'yuan': double.tryParse(yuanC.text) ?? p.yuan,
                        'weight': double.tryParse(weightC.text) ?? p.weight,
                        'currency':
                            double.tryParse(currencyC.text) ?? p.currency,
                        'shipmenttax':
                            double.tryParse(seaTaxC.text) ?? p.shipmentTax,
                        'shipmenttaxair':
                            double.tryParse(airTaxC.text) ?? p.shipmentTaxAir,
                        'sea': double.tryParse(seaPriceC.text) ?? p.sea,
                        'air': double.tryParse(airPriceC.text) ?? p.air,
                        'agent': double.tryParse(agentC.text) ?? p.agent,
                        'wholesale':
                            double.tryParse(wholesaleC.text) ?? p.wholesale,
                      };

                      int seaQ = int.tryParse(addSeaQtyC.text) ?? 0;
                      int airQ = int.tryParse(addAirQtyC.text) ?? 0;

                      if (onSubmit != null) {
                        // Create item for Details page
                        final newItem = ShipmentItem(
                          productId: p.id,
                          productName: nameC.text,
                          productModel: modelC.text,
                          productBrand: brandC.text,
                          productCategory: categoryC.text,
                          unitWeightSnapshot:
                              double.tryParse(weightC.text) ?? 0,
                          seaQty: 0, // Ordered is 0 for extra items
                          airQty: 0,
                          receivedSeaQty: seaQ,
                          receivedAirQty: airQ,
                          cartonNo: cartonNoC.text,
                          seaPriceSnapshot:
                              double.tryParse(seaPriceC.text) ?? 0,
                          airPriceSnapshot:
                              double.tryParse(airPriceC.text) ?? 0,
                          ignoreMissing:
                              true, // Auto ignore missing since ordered is 0
                        );
                        onSubmit(newItem);
                        Get.back(); // Smooth close
                      } else {
                        // Original Create flow
                        shipCtrl.addToManifestAndVerify(
                          product: p,
                          updates: updates,
                          seaQty: seaQ,
                          airQty: airQ,
                          cartonNo: cartonNoC.text,
                        );
                        // addToManifestAndVerify calls Get.back() internally
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      onSubmit != null ? "ADD ITEM" : "ADD TO MANIFEST",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
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

// ... include the _posInput, _posHeader, etc. helper widgets here (same as before) ...
Widget _posHeader(String title) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    title,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey[600],
      letterSpacing: 0.5,
    ),
  ),
);
Widget _posInput(
  TextEditingController ctrl,
  String label, {
  bool isNum = false,
  Color? borderColor,
  Color? filledColor,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
    ),
    const SizedBox(height: 4),
    SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        keyboardType:
            isNum
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          filled: true,
          fillColor: filledColor ?? Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: borderColor ?? Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: borderColor ?? Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
    ),
  ],
);
Widget _posReadOnly(
  TextEditingController ctrl,
  String label, {
  required IconData icon,
  required Color color,
  required Color bgColor,
}) => Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: bgColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withOpacity(0.3)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        readOnly: true,
        decoration: const InputDecoration.collapsed(hintText: ""),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    ],
  ),
);
Widget _stockBadge(String label, String value) => Column(
  children: [
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    const SizedBox(height: 2),
    Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  ],
);
Widget _vDivider() => Container(
  height: 30,
  width: 1,
  color: Colors.grey[300],
  margin: const EdgeInsets.symmetric(horizontal: 4),
);
