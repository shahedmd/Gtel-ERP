// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';

/// ===============================
/// MODERN POS INPUT STYLING (MATCHING YOUR EDIT DIALOG)
/// ===============================
Widget _buildField(
  TextEditingController c,
  String label,
  IconData icon, {
  TextInputType? type,
  bool readOnly = false,
  VoidCallback? onTap,
  Color? fillColor,
  Color? iconColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: c,
      keyboardType: type ?? TextInputType.text,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? Colors.grey[700] : Colors.black,
        fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: iconColor ?? Colors.blueGrey),
        isDense: true,
        filled: true,
        fillColor: fillColor ?? (readOnly ? Colors.grey[200] : Colors.grey[50]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
    ),
  );
}

Widget _sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 15, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.blue[800],
        letterSpacing: 1.2,
      ),
    ),
  );
}

void _showPOSDialog({
  required String title,
  required List<Widget> children,
  required VoidCallback onSave,
}) {
  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    label: const Text(
                      'Update & Add to Manifest',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ==========================================================
/// SHIPMENT ENTRY DIALOG (MATCHES EDIT PRODUCT DESIGN)
/// ==========================================================
void showShipmentEntryDialog(
  Product p,
  ShipmentController shipCtrl,
  ProductController prodCtrl,
) {
  // 1. Basic Info (Editable)
  final nameC = TextEditingController(text: p.name);
  final categoryC = TextEditingController(text: p.category);
  final brandC = TextEditingController(text: p.brand);
  final modelC = TextEditingController(text: p.model);

  // 2. Costs & Logic (Editable)
  final weightC = TextEditingController(text: p.weight.toString());
  final yuanC = TextEditingController(text: p.yuan.toString());
  final currencyC = TextEditingController(text: p.currency.toString());
  final seaTaxC = TextEditingController(text: p.shipmentTax.toString());
  final airTaxC = TextEditingController(text: p.shipmentTaxAir.toString());

  // 3. Calculated Results (Auto-Updating)
  final seaPriceC = TextEditingController(text: p.sea.toString());
  final airPriceC = TextEditingController(text: p.air.toString());

  // 4. OLD STOCK INFO (Read Only - From Product)
  final oldSeaStockC = TextEditingController(text: p.seaStockQty.toString());
  final oldAirStockC = TextEditingController(text: p.airStockQty.toString());
  final oldLocalStockC = TextEditingController(text: p.localQty.toString());

  // 5. SHIPMENT ADDITION INPUTS (New)
  final addSeaQtyC = TextEditingController(text: '0');
  final addAirQtyC = TextEditingController(text: '0');
  final cartonNoC = TextEditingController();

  // Calculation Logic
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

  // Attach Listeners
  yuanC.addListener(recalculatePrices);
  weightC.addListener(recalculatePrices);
  currencyC.addListener(recalculatePrices);
  seaTaxC.addListener(recalculatePrices);
  airTaxC.addListener(recalculatePrices);

  _showPOSDialog(
    title: 'Shipment Entry: ${p.model}',
    onSave: () {
      // Prepare the update map (User edits)
      final updates = {
        'name': nameC.text,
        'category': categoryC.text, // Added category/brand edit capability
        'brand': brandC.text,
        'model': modelC.text,
        'yuan': double.tryParse(yuanC.text) ?? p.yuan,
        'weight': double.tryParse(weightC.text) ?? p.weight,
        'currency': double.tryParse(currencyC.text) ?? p.currency,
        'shipmenttax': double.tryParse(seaTaxC.text) ?? p.shipmentTax,
        'shipmenttaxair': double.tryParse(airTaxC.text) ?? p.shipmentTaxAir,
        'sea': double.tryParse(seaPriceC.text) ?? p.sea,
        'air': double.tryParse(airPriceC.text) ?? p.air,
      };

      shipCtrl.addToManifestAndVerify(
        product: p,
        updates: updates,
        seaQty: int.tryParse(addSeaQtyC.text) ?? 0,
        airQty: int.tryParse(addAirQtyC.text) ?? 0,
        cartonNo: cartonNoC.text,
      );
    },
    children: [
      // --- SECTION 1: PRODUCT INFO (Editable) ---
      _sectionHeader('Basic Information'),
      _buildField(nameC, 'Product Name', Icons.shopping_bag),
      _buildField(categoryC, 'Category', Icons.category),
      Row(
        children: [
          Expanded(
            child: _buildField(brandC, 'Brand', Icons.branding_watermark),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildField(modelC, 'Model', Icons.label)),
        ],
      ),

      // --- SECTION 2: COSTS (Editable) ---
      _sectionHeader('Costs & Logic (Auto-Updates)'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              yuanC,
              'Yuan (¥)',
              Icons.money,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              weightC,
              'Weight (KG)',
              Icons.monitor_weight,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: _buildField(
              seaTaxC,
              'Sea Tax /KG',
              Icons.directions_boat,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              airTaxC,
              'Air Tax /KG',
              Icons.airplanemode_active,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
      _buildField(
        currencyC,
        'Exchange Rate',
        Icons.currency_exchange,
        type: TextInputType.number,
      ),

      // --- SECTION 3: CALCULATED COSTS (Read Only) ---
      _sectionHeader('Calculated Landing Costs'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              seaPriceC,
              'Sea Price',
              Icons.waves,
              readOnly: true,
              fillColor: Colors.blue.withOpacity(0.05),
              iconColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              airPriceC,
              'Air Price',
              Icons.air,
              readOnly: true,
              fillColor: Colors.orange.withOpacity(0.05),
              iconColor: Colors.orange,
            ),
          ),
        ],
      ),

      // --- SECTION 4: OLD STOCK INFO (Read Only) ---
      _sectionHeader('Current Warehouse Stock'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildField(
                oldSeaStockC,
                'Sea Stock',
                Icons.warehouse,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                oldAirStockC,
                'Air Stock',
                Icons.warehouse,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                oldLocalStockC,
                'Local',
                Icons.store,
                readOnly: true,
              ),
            ),
          ],
        ),
      ),

      // --- SECTION 5: NEW SHIPMENT INPUTS (Actionable) ---
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.add_location_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "ADD TO SHIPMENT",
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    addSeaQtyC,
                    'Add Sea Qty',
                    Icons.add_box,
                    type: TextInputType.number,
                    fillColor: Colors.white,
                    iconColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    addAirQtyC,
                    'Add Air Qty',
                    Icons.add_box,
                    type: TextInputType.number,
                    fillColor: Colors.white,
                    iconColor: Colors.orange,
                  ),
                ),
              ],
            ),
            _buildField(
              cartonNoC,
              'Carton No (e.g. 1-5)',
              Icons.grid_view,
              fillColor: Colors.white,
            ),
          ],
        ),
      ),
    ],
  );
}
