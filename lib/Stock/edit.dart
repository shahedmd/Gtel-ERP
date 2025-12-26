import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';
import 'model.dart';

/// ===============================
/// MODERN POS INPUT STYLING
/// ===============================
Widget _buildField(TextEditingController c, String label, IconData icon, {TextInputType? type}) {
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
        constraints: const BoxConstraints(maxWidth: 500), // Professional fixed width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  )
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
                    child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
/// EDIT PRODUCT DIALOG
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
        'shipmentTax': double.tryParse(shipmentTaxC.text),
        'shipmentNo': int.tryParse(shipmentNoC.text),
        'currency': double.tryParse(currencyC.text),
        'stock_qty': int.tryParse(stockC.text),
      });
      Get.back();
    },
    children: [
      _sectionHeader('Basic Information'),
      _buildField(nameC, 'Product Name', Icons.shopping_bag),
      _buildField(categoryC, 'Category', Icons.category),
      Row(
        children: [
          Expanded(child: _buildField(brandC, 'Brand', Icons.branding_watermark)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(modelC, 'Model', Icons.label)),
        ],
      ),
      _sectionHeader('Pricing & Costs'),
      Row(
        children: [
          Expanded(child: _buildField(yuanC, 'Yuan Price (¥)', Icons.money, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(weightC, 'Weight (KG)', Icons.monitor_weight, type: TextInputType.number)),
        ],
      ),
      Row(
        children: [
          Expanded(child: _buildField(agentC, 'Agent Price', Icons.person, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(wholesaleC, 'Wholesale', Icons.groups, type: TextInputType.number)),
        ],
      ),
      _sectionHeader('Inventory & Logistics'),
      Row(
        children: [
          Expanded(child: _buildField(stockC, 'Current Stock', Icons.inventory_2, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(shipmentNoC, 'Shipment No', Icons.local_shipping, type: TextInputType.number)),
        ],
      ),
      Row(
        children: [
          Expanded(child: _buildField(airC, 'Air Price', Icons.airplanemode_active, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(seaC, 'Sea Price', Icons.directions_boat, type: TextInputType.number)),
        ],
      ),
    ],
  );
}

void showCreateProductDialog(ProductController controller) {
  // 1. Initialize all Controllers
  final nameC = TextEditingController();
  final categoryC = TextEditingController();
  final brandC = TextEditingController();
  final modelC = TextEditingController();
 
  final weightC = TextEditingController();
  final yuanC = TextEditingController();
  final airC = TextEditingController();
  final seaC = TextEditingController();
 
  final agentC = TextEditingController();
  final wholesaleC = TextEditingController();
 
  final shipmentTaxC = TextEditingController();
  final shipmentNoC = TextEditingController();
  final currencyC = TextEditingController(text: controller.currentCurrency.value.toString());
  final stockC = TextEditingController(text: '0');

  _showPOSDialog(
    title: 'New Product Registration',
    onSave: () {
      // 2. Map all values to the controller
      controller.createProduct({
        'name': nameC.text,
        'category': categoryC.text,
        'brand': brandC.text,
        'model': modelC.text,
        'weight': double.tryParse(weightC.text) ?? 0.0,
        'yuan': double.tryParse(yuanC.text) ?? 0.0,
        'air': double.tryParse(airC.text) ?? 0.0,
        'sea': double.tryParse(seaC.text) ?? 0.0,
        'agent': double.tryParse(agentC.text) ?? 0.0,
        'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
        'shipmentTax': double.tryParse(shipmentTaxC.text) ?? 0.0,
        'shipmentNo': int.tryParse(shipmentNoC.text) ?? 0,
        'currency': double.tryParse(currencyC.text) ?? controller.currentCurrency.value,
        'stock_qty': int.tryParse(stockC.text) ?? 0,
      });
      Get.back();
    },
    children: [
      // --- SECTION 1 ---
      _sectionHeader('Basic Information'),
      _buildField(nameC, 'Product Name', Icons.shopping_bag),
      _buildField(categoryC, 'Category', Icons.category),
      Row(
        children: [
          Expanded(child: _buildField(brandC, 'Brand', Icons.branding_watermark)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(modelC, 'Model', Icons.label)),
        ],
      ),

      // --- SECTION 2 ---
      _sectionHeader('Costs & Pricing'),
      Row(
        children: [
          Expanded(child: _buildField(yuanC, 'Yuan Price (¥)', Icons.money, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(weightC, 'Weight (KG)', Icons.monitor_weight, type: TextInputType.number)),
        ],
      ),
      Row(
        children: [
          Expanded(child: _buildField(agentC, 'Agent Price', Icons.person, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(wholesaleC, 'Wholesale Price', Icons.groups, type: TextInputType.number)),
        ],
      ),

      // --- SECTION 3 (The missing part) ---
      _sectionHeader('Shipping & Logistics'),
      Row(
        children: [
          Expanded(child: _buildField(airC, 'Air Price (Final)', Icons.airplanemode_active, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(seaC, 'Sea Price (Final)', Icons.directions_boat, type: TextInputType.number)),
        ],
      ),
      Row(
        children: [
          Expanded(child: _buildField(shipmentTaxC, 'Shipment Tax', Icons.receipt_long, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(shipmentNoC, 'Shipment No', Icons.local_shipping, type: TextInputType.number)),
        ],
      ),

      // --- SECTION 4 ---
      _sectionHeader('System & Inventory'),
      Row(
        children: [
          Expanded(child: _buildField(currencyC, 'Exchange Rate', Icons.currency_exchange, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _buildField(stockC, 'Initial Stock', Icons.inventory_2, type: TextInputType.number)),
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
      content: const Text('This action cannot be undone. Are you sure you want to delete this product?'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            controller.deleteProduct(productId);
            Get.back();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete Product'),
        ),
      ],
    ),
  );
}