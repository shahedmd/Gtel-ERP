// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: c,
      keyboardType: type ?? TextInputType.text,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
        isDense: true,
        filled: true,
        fillColor: Colors.grey[50],
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
        constraints: const BoxConstraints(
          maxWidth: 600,
        ), // Slightly wider for 18 fields
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
/// EDIT PRODUCT DIALOG (Updated for 18 Fields)
/// ===============================
void showEditProductDialog(Product p, ProductController controller) {
  final nameC = TextEditingController(text: p.name);
  final categoryC = TextEditingController(text: p.category);
  final brandC = TextEditingController(text: p.brand);
  final modelC = TextEditingController(text: p.model);
  final weightC = TextEditingController(text: p.weight.toString());
  final yuanC = TextEditingController(text: p.yuan.toString());
  final airC = TextEditingController(text: p.air.toString());
  final seaC = TextEditingController(text: p.sea.toString());
  final agentC = TextEditingController(text: p.agent.toString());
  final wholesaleC = TextEditingController(text: p.wholesale.toString());
  final shipmentTaxC = TextEditingController(text: p.shipmentTax.toString());
  final shipmentNoC = TextEditingController(text: p.shipmentNo.toString());
  final currencyC = TextEditingController(text: p.currency.toString());
  final stockC = TextEditingController(text: p.stockQty.toString());

  // New Tracking Controllers
  final avgPriceC = TextEditingController(text: p.avgPurchasePrice.toString());
  final seaStockC = TextEditingController(text: p.seaStockQty.toString());
  final airStockC = TextEditingController(text: p.airStockQty.toString());

  _showPOSDialog(
    title: 'Update Product',
    onSave: () {
      controller.updateProduct(p.id, {
        'name': nameC.text,
        'category': categoryC.text,
        'brand': brandC.text,
        'model': modelC.text,
        'weight': double.tryParse(weightC.text),
        'yuan': double.tryParse(yuanC.text),
        'air': double.tryParse(airC.text),
        'sea': double.tryParse(seaC.text),
        'agent': double.tryParse(agentC.text),
        'wholesale': double.tryParse(wholesaleC.text),
        'shipmenttax': double.tryParse(shipmentTaxC.text), // Lowercase key
        'shipmentno': int.tryParse(shipmentNoC.text), // Lowercase key
        'currency': double.tryParse(currencyC.text),
        'stock_qty': int.tryParse(stockC.text),
        'avg_purchase_price': double.tryParse(avgPriceC.text),
        'sea_stock_qty': int.tryParse(seaStockC.text),
        'air_stock_qty': int.tryParse(airStockC.text),
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
      _sectionHeader('Costs & Logic (Import)'),
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
              'Shipment Tax',
              Icons.receipt_long,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              currencyC,
              'Exchange Rate',
              Icons.currency_exchange,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
      _sectionHeader('Pricing (Sales)'),
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
      _sectionHeader('Stock & Cost Tracking'),
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
              'Total Stock',
              Icons.inventory_2,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              seaStockC,
              'Sea Stock',
              Icons.directions_boat,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              airStockC,
              'Air Stock',
              Icons.airplanemode_active,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
      _sectionHeader('Reference Data (Do not edit usually)'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              airC,
              'Calculated Air',
              Icons.air,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              seaC,
              'Calculated Sea',
              Icons.waves,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              shipmentNoC,
              'Shipment No',
              Icons.numbers,
              type: TextInputType.number,
            ),
          ),
        ],
      ),
    ],
  );
}

/// ===============================
/// CREATE PRODUCT DIALOG (Updated for 18 Fields)
/// ===============================
void showCreateProductDialog(ProductController controller) {
  // --- 1. Basic Information ---
  final nameC = TextEditingController();
  final categoryC = TextEditingController(); // ADDED BACK
  final brandC = TextEditingController();
  final modelC = TextEditingController();

  // --- 2. Calculation Inputs ---
  final yuanC = TextEditingController(text: '0');
  final weightC = TextEditingController(text: '0');
  final currencyC = TextEditingController(
    text: controller.currentCurrency.value.toString(),
  );
  final seaTaxC = TextEditingController(text: '0'); // Maps to shipmenttax
  final airTaxC = TextEditingController(text: '700'); // UI only for calculation

  // --- 3. Result Fields (Calculated) ---
  final airResultC = TextEditingController(text: '0');
  final seaResultC = TextEditingController(text: '0');

  // --- 4. Pricing & Inventory ---
  final agentC = TextEditingController();
  final wholesaleC = TextEditingController();
  final shipmentNoC = TextEditingController(text: '0');
  final stockC = TextEditingController(text: '0');

  // Logic to calculate both prices based on their specific taxes
  void calculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr =
        double.tryParse(currencyC.text) ?? controller.currentCurrency.value;
    double seaTax = double.tryParse(seaTaxC.text) ?? 0.0;
    double airTax = double.tryParse(airTaxC.text) ?? 0.0;

    if (yuan > 0) {
      double calculatedSea = (yuan * curr) + (weight * seaTax);
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
  airTaxC.addListener(calculatePrices);

  _showPOSDialog(
    title: 'New Product Registration',
    onSave: () {
      // PROPER MAPPING OF ALL 18 FIELDS (ID is 0 for new)
      controller.createProduct({
        'name': nameC.text,
        'category': categoryC.text, // 1
        'brand': brandC.text, // 2
        'model': modelC.text, // 3
        'weight': double.tryParse(weightC.text) ?? 0.0, // 4
        'yuan': double.tryParse(yuanC.text) ?? 0.0, // 5
        'air': double.tryParse(airResultC.text) ?? 0.0, // 6 (Calculated)
        'sea': double.tryParse(seaResultC.text) ?? 0.0, // 7 (Calculated)
        'agent': double.tryParse(agentC.text) ?? 0.0, // 8
        'wholesale': double.tryParse(wholesaleC.text) ?? 0.0, // 9
        'shipmenttax': double.tryParse(seaTaxC.text) ?? 0.0, // 10
        'shipmentno': int.tryParse(shipmentNoC.text) ?? 0, // 11
        'currency':
            double.tryParse(currencyC.text) ??
            controller.currentCurrency.value, // 12
        'stock_qty': int.tryParse(stockC.text) ?? 0, // 13
        'avg_purchase_price': double.tryParse(seaResultC.text) ?? 0.0, // 14
        'sea_stock_qty': int.tryParse(stockC.text) ?? 0, // 15
        'air_stock_qty': 0, // 16 (Starts at 0 for new items)
        // Fields 17 & 18 are "name" and "id" handled by nameC.text and DB auto-gen
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
              Icons.waves,
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

      _sectionHeader('Auto-Calculated Costs (Landing)'),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: seaResultC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Sea Price (BDT)",
                prefixIcon: Icon(Icons.calculate, color: Colors.blue),
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
                prefixIcon: Icon(Icons.calculate, color: Colors.orange),
                filled: true,
                fillColor: Colors.orange.withOpacity(0.05),
              ),
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
              'Wholesale Price',
              Icons.groups,
              type: TextInputType.number,
            ),
          ),
        ],
      ),

      _sectionHeader('Initial Inventory'),
      Row(
        children: [
          Expanded(
            child: _buildField(
              stockC,
              'Initial Stock',
              Icons.inventory_2,
              type: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildField(
              shipmentNoC,
              'Shipment No',
              Icons.numbers,
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
