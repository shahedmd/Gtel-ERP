// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Ensure intl package is in pubspec.yaml for date formatting
import 'controller.dart';
import 'model.dart';

/// ===============================
/// MODERN POS INPUT STYLING
/// ===============================
Widget _buildField(
  TextEditingController c,
  String label,
  IconData icon, {
  TextInputType? type,
  bool readOnly = false,
  VoidCallback? onTap, // Added onTap for DatePicker
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
        color: readOnly ? Colors.grey[600] : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
        isDense: true,
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : Colors.grey[50],
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

/// ===============================
/// SECTION HEADER
/// ===============================
Widget _sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
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

/// ===============================
/// MAIN DIALOG TEMPLATE
/// ===============================
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
                  const Icon(Icons.inventory, color: Colors.white, size: 20),
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
                  ElevatedButton(
                    onPressed: onSave,
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
                    child: const Text(
                      'Save Changes',
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

/// ===============================
/// EDIT PRODUCT DIALOG (FULLY UNLOCKED & REACTIVE)
/// ===============================
void showEditProductDialog(Product p, ProductController controller) {
  final nameC = TextEditingController(text: p.name);
  final categoryC = TextEditingController(text: p.category);
  final brandC = TextEditingController(text: p.brand);
  final modelC = TextEditingController(text: p.model);

  // Calculation Inputs
  final weightC = TextEditingController(text: p.weight.toString());
  final yuanC = TextEditingController(text: p.yuan.toString());
  final currencyC = TextEditingController(text: p.currency.toString());
  final shipmentTaxC = TextEditingController(
    text: p.shipmentTax.toString(),
  ); // Sea Tax
  final shipmentTaxAirC = TextEditingController(
    text: p.shipmentTaxAir.toString(),
  ); // Air Tax (New)

  // Calculated Results (Auto-updating)
  final airC = TextEditingController(text: p.air.toString());
  final seaC = TextEditingController(text: p.sea.toString());

  // Other Fields
  final agentC = TextEditingController(text: p.agent.toString());
  final wholesaleC = TextEditingController(text: p.wholesale.toString());
  final shipmentNoC = TextEditingController(text: p.shipmentNo.toString());
  final shipmentDateC = TextEditingController(
    text:
        p.shipmentDate != null
            ? DateFormat('yyyy-MM-dd').format(p.shipmentDate!)
            : '',
  );

  // Stock Fields - FULLY EDITABLE
  final stockC = TextEditingController(text: p.stockQty.toString());
  final avgPriceC = TextEditingController(text: p.avgPurchasePrice.toString());
  final seaStockC = TextEditingController(text: p.seaStockQty.toString());
  final airStockC = TextEditingController(text: p.airStockQty.toString());
  final localStockC = TextEditingController(text: p.localQty.toString());

  // --- Auto-Calculation Logic for Edit Mode ---
  void recalculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr = double.tryParse(currencyC.text) ?? 0.0;
    double seaTax = double.tryParse(shipmentTaxC.text) ?? 0.0;
    double airTax = double.tryParse(shipmentTaxAirC.text) ?? 0.0;

    if (yuan > 0) {
      double calculatedSea = (yuan * curr) + (weight * seaTax);
      double calculatedAir = (yuan * curr) + (weight * airTax);

      seaC.text = calculatedSea.toStringAsFixed(2);
      airC.text = calculatedAir.toStringAsFixed(2);
    }
  }

  // Attach Listeners
  yuanC.addListener(recalculatePrices);
  weightC.addListener(recalculatePrices);
  currencyC.addListener(recalculatePrices);
  shipmentTaxC.addListener(recalculatePrices);
  shipmentTaxAirC.addListener(recalculatePrices);

  _showPOSDialog(
    title: 'Update Product (Manual Mode)',
    onSave: () {
      controller.updateProduct(p.id, {
        'name': nameC.text,
        'category': categoryC.text,
        'brand': brandC.text,
        'model': modelC.text,
        'weight': double.tryParse(weightC.text) ?? p.weight,
        'yuan': double.tryParse(yuanC.text) ?? p.yuan,

        // Calculated/Updated Prices
        'air': double.tryParse(airC.text) ?? p.air,
        'sea': double.tryParse(seaC.text) ?? p.sea,

        'agent': double.tryParse(agentC.text) ?? p.agent,
        'wholesale': double.tryParse(wholesaleC.text) ?? p.wholesale,

        // Taxes
        'shipmenttax': double.tryParse(shipmentTaxC.text) ?? p.shipmentTax,
        'shipmenttaxair':
            double.tryParse(shipmentTaxAirC.text) ?? p.shipmentTaxAir,

        // Logistics
        'shipmentno': int.tryParse(shipmentNoC.text) ?? p.shipmentNo,
        'shipmentdate':
            shipmentDateC.text.isEmpty
                ? null
                : shipmentDateC.text, // "yyyy-MM-dd"
        'currency': double.tryParse(currencyC.text) ?? p.currency,

        // Stock Overrides
        'stock_qty': int.tryParse(stockC.text) ?? p.stockQty,
        'avg_purchase_price':
            double.tryParse(avgPriceC.text) ?? p.avgPurchasePrice,
        'sea_stock_qty': int.tryParse(seaStockC.text) ?? p.seaStockQty,
        'air_stock_qty': int.tryParse(airStockC.text) ?? p.airStockQty,
        'local_qty': int.tryParse(localStockC.text) ?? p.localQty,
      });
      Get.back();
    },
    children: [
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

      _sectionHeader('Costs & Logic (Auto-Updates)'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              yuanC,
              'Yuan Price (¥)',
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
              shipmentTaxC,
              'Sea Tax /KG',
              Icons.directions_boat,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              shipmentTaxAirC,
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

      _sectionHeader('Calculated Landing Costs'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              seaC,
              'Sea Price',
              Icons.waves,
              type: TextInputType.number,
            ),
          ), // Now auto-updates
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              airC,
              'Air Price',
              Icons.air,
              type: TextInputType.number,
            ),
          ), // Now auto-updates
        ],
      ),

      _sectionHeader('Logistics'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              shipmentNoC,
              'Shipment No',
              Icons.numbers,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              shipmentDateC,
              'Shipment Date',
              Icons.calendar_today,
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: Get.context!,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  shipmentDateC.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
          ),
        ],
      ),

      _sectionHeader('Sales Pricing'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              agentC,
              'Agent Price',
              Icons.person,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              wholesaleC,
              'Wholesale',
              Icons.groups,
              type: TextInputType.number,
            ),
          ),
        ],
      ),

      _sectionHeader('Stock & Cost (Manual Override)'),
      _buildField(
        avgPriceC,
        'Average Purchase Rate (BDT)',
        Icons.payments,
        type: TextInputType.number,
      ),
      Row(
        children: [
          Expanded(
            child: _buildField(
              stockC,
              'Total',
              Icons.inventory_2,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              seaStockC,
              'Sea',
              Icons.directions_boat,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              airStockC,
              'Air',
              Icons.airplanemode_active,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              localStockC,
              'Local',
              Icons.store,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
    ],
  );
}

/// ===============================
/// CREATE PRODUCT DIALOG (UPDATED)
/// ===============================
void showCreateProductDialog(ProductController controller) {
  // --- 1. Basic Information ---
  final nameC = TextEditingController();
  final categoryC = TextEditingController();
  final brandC = TextEditingController();
  final modelC = TextEditingController();

  // --- 2. Calculation Inputs ---
  final yuanC = TextEditingController(text: '0');
  final weightC = TextEditingController(text: '0');
  final currencyC = TextEditingController(
    text: controller.currentCurrency.value.toString(),
  );
  final seaTaxC = TextEditingController(text: '0');
  final airTaxC = TextEditingController(text: '700'); // Default Air Tax

  // --- 3. Result Fields (Calculated) ---
  final airResultC = TextEditingController(text: '0');
  final seaResultC = TextEditingController(text: '0');

  // --- 4. Pricing & Logistics ---
  final agentC = TextEditingController();
  final wholesaleC = TextEditingController();
  final shipmentNoC = TextEditingController(text: '0');
  final shipmentDateC = TextEditingController(); // New Date Field
  final stockC = TextEditingController(text: '0');

  // Logic to calculate costs based on inputs
  void calculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr =
        double.tryParse(currencyC.text) ?? controller.currentCurrency.value;
    double seaTax = double.tryParse(seaTaxC.text) ?? 0.0;
    double airTax = double.tryParse(airTaxC.text) ?? 0.0; // Dynamic Air Tax

    if (yuan > 0) {
      // Sea Cost
      double calculatedSea = (yuan * curr) + (weight * seaTax);
      // Air Cost (Dynamic)
      double calculatedAir = (yuan * curr) + (weight * airTax);

      seaResultC.text = calculatedSea.toStringAsFixed(2);
      airResultC.text = calculatedAir.toStringAsFixed(2);
    } else {
      seaResultC.text = '0';
      airResultC.text = '0';
    }
  }

  // Listeners
  yuanC.addListener(calculatePrices);
  weightC.addListener(calculatePrices);
  currencyC.addListener(calculatePrices);
  seaTaxC.addListener(calculatePrices);
  airTaxC.addListener(calculatePrices); // Listen to Air Tax changes

  _showPOSDialog(
    title: 'New Product Registration',
    onSave: () {
      int initialStock = int.tryParse(stockC.text) ?? 0;
      double initialAvgPrice = double.tryParse(seaResultC.text) ?? 0.0;

      controller.createProduct({
        'name': nameC.text,
        'category': categoryC.text,
        'brand': brandC.text,
        'model': modelC.text,
        'weight': double.tryParse(weightC.text) ?? 0.0,
        'yuan': double.tryParse(yuanC.text) ?? 0.0,

        // Calculated Prices
        'air': double.tryParse(airResultC.text) ?? 0.0,
        'sea': double.tryParse(seaResultC.text) ?? 0.0,

        'agent': double.tryParse(agentC.text) ?? 0.0,
        'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,

        // Taxes (Both editable now)
        'shipmenttax': double.tryParse(seaTaxC.text) ?? 0.0,
        'shipmenttaxair': double.tryParse(airTaxC.text) ?? 0.0,

        // Logistics
        'shipmentno': int.tryParse(shipmentNoC.text) ?? 0,
        'shipmentdate':
            shipmentDateC.text.isEmpty
                ? null
                : shipmentDateC.text, // "yyyy-MM-dd"

        'currency':
            double.tryParse(currencyC.text) ?? controller.currentCurrency.value,

        // Inventory
        'stock_qty': initialStock,
        'avg_purchase_price': initialAvgPrice,
        'sea_stock_qty': initialStock,
        'air_stock_qty': 0,
        'local_qty': 0,
      });
      Get.back();
    },
    children: [
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

      _sectionHeader('Calculation Inputs'),
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
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              currencyC,
              'Rate',
              Icons.currency_exchange,
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

      _sectionHeader('Auto-Calculated Costs'),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: seaResultC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Sea Price (BDT)",
                prefixIcon: Icon(Icons.waves, color: Colors.blue),
                filled: true,
                fillColor: Colors.blue.withOpacity(0.05),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: airResultC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Air Price (BDT)",
                prefixIcon: Icon(Icons.air, color: Colors.orange),
                filled: true,
                fillColor: Colors.orange.withOpacity(0.05),
              ),
            ),
          ),
        ],
      ),

      _sectionHeader('Logistics & Inventory'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              shipmentNoC,
              'Shipment No',
              Icons.numbers,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              shipmentDateC,
              'Date',
              Icons.calendar_today,
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: Get.context!,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  shipmentDateC.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
          ),
        ],
      ),
      _buildField(
        stockC,
        'Initial Stock (Assigned to Sea)',
        Icons.inventory_2,
        type: TextInputType.number,
      ),

      _sectionHeader('Sales Pricing'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              agentC,
              'Agent Price',
              Icons.person,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              wholesaleC,
              'Wholesale',
              Icons.groups,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
    ],
  );
}

/// ===============================
/// DELETE CONFIRM DIALOG
/// ===============================
void showDeleteConfirmDialog(int productId, ProductController controller) {
  Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Confirm Delete'),
        ],
      ),
      content: const Text(
        'This action cannot be undone. Are you sure you want to delete this product?',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            controller.deleteProduct(productId);
            Get.back();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete Product'),
        ),
      ],
    ),
  );
}
