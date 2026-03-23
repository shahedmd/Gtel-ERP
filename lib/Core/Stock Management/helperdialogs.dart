// ignore_for_file: deprecated_member_use, empty_catches, avoid_print

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:intl/intl.dart';
import 'stockproductmodel.dart';

Widget _responsiveRow(BuildContext context, Widget child1, Widget child2) {
  final bool isMobile = MediaQuery.of(context).size.width < 600;
  if (isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child1, const SizedBox(height: 10), child2],
    );
  }
  return Row(
    children: [
      Expanded(child: child1),
      const SizedBox(width: 12),
      Expanded(child: child2),
    ],
  );
}

Widget _buildField(
  TextEditingController c,
  String label,
  IconData icon, {
  TextInputType? type,
  bool readOnly = false,
  VoidCallback? onTap,
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
        fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
        color: readOnly ? Colors.blue[900] : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: readOnly ? Colors.blue : Colors.blueGrey,
        ),
        isDense: true,
        filled: true,
        fillColor:
            readOnly ? Colors.blue.withValues(alpha: 0.05) : Colors.grey[50],
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
    padding: const EdgeInsets.only(top: 16, bottom: 8),
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
  required Widget body,
  required VoidCallback onSave,
}) {
  final bool isMobile = Get.width < 600;

  Get.dialog(
    Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 800),
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: body,
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
    barrierDismissible:
        false, // Prevent accidental taps outside from losing data
  );
}

void showEditProductDialog(Product p, ProductController controller) {
  _showPOSDialog(
    title: 'Update Product',
    body: _EditProductForm(p: p, controller: controller),
    onSave: () {
    },
  );
}

class _EditProductForm extends StatefulWidget {
  final Product p;
  final ProductController controller;
  const _EditProductForm({required this.p, required this.controller});

  @override
  State<_EditProductForm> createState() => _EditProductFormState();
}

class _EditProductFormState extends State<_EditProductForm> {
  late final TextEditingController nameC, categoryC, brandC, modelC;
  late final TextEditingController weightC,
      yuanC,
      currencyC,
      shipmentTaxC,
      shipmentTaxAirC;
  late final TextEditingController airC,
      seaC,
      agentC,
      wholesaleC,
      shipmentNoC,
      shipmentDateC,
      alertQtyC;
  late final TextEditingController stockC,
      avgPriceC,
      seaStockC,
      airStockC,
      localStockC;

  @override
  void initState() {
    super.initState();
    final p = widget.p;

    nameC = TextEditingController(text: p.name);
    categoryC = TextEditingController(text: p.category);
    brandC = TextEditingController(text: p.brand);
    modelC = TextEditingController(text: p.model);
    weightC = TextEditingController(text: p.weight.toString());
    yuanC = TextEditingController(text: p.yuan.toString());
    currencyC = TextEditingController(text: p.currency.toString());
    shipmentTaxC = TextEditingController(text: p.shipmentTax.toString());
    shipmentTaxAirC = TextEditingController(text: p.shipmentTaxAir.toString());
    airC = TextEditingController(text: p.air.toString());
    seaC = TextEditingController(text: p.sea.toString());
    agentC = TextEditingController(text: p.agent.toString());
    wholesaleC = TextEditingController(text: p.wholesale.toString());
    shipmentNoC = TextEditingController(text: p.shipmentNo.toString());
    shipmentDateC = TextEditingController(
      text:
          p.shipmentDate != null
              ? DateFormat('yyyy-MM-dd').format(p.shipmentDate!)
              : '',
    );
    alertQtyC = TextEditingController(text: p.alertQty.toString());
    stockC = TextEditingController(text: p.stockQty.toString());
    avgPriceC = TextEditingController(text: p.avgPurchasePrice.toString());
    seaStockC = TextEditingController(text: p.seaStockQty.toString());
    airStockC = TextEditingController(text: p.airStockQty.toString());
    localStockC = TextEditingController(text: p.localQty.toString());

    // Attach Listeners
    yuanC.addListener(recalculatePrices);
    weightC.addListener(recalculatePrices);
    currencyC.addListener(recalculatePrices);
    shipmentTaxC.addListener(recalculatePrices);
    shipmentTaxAirC.addListener(recalculatePrices);
  }

  // CRITICAL: Prevent Memory Leaks
  @override
  void dispose() {
    nameC.dispose();
    categoryC.dispose();
    brandC.dispose();
    modelC.dispose();
    weightC.dispose();
    yuanC.dispose();
    currencyC.dispose();
    shipmentTaxC.dispose();
    shipmentTaxAirC.dispose();
    airC.dispose();
    seaC.dispose();
    agentC.dispose();
    wholesaleC.dispose();
    shipmentNoC.dispose();
    shipmentDateC.dispose();
    alertQtyC.dispose();
    stockC.dispose();
    avgPriceC.dispose();
    seaStockC.dispose();
    airStockC.dispose();
    localStockC.dispose();
    super.dispose();
  }

  void recalculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr = double.tryParse(currencyC.text) ?? 0.0;
    double seaTax = double.tryParse(shipmentTaxC.text) ?? 0.0;
    double airTax = double.tryParse(shipmentTaxAirC.text) ?? 0.0;

    if (yuan > 0) {
      seaC.text = ((yuan * curr) + (weight * seaTax)).toStringAsFixed(2);
      airC.text = ((yuan * curr) + (weight * airTax)).toStringAsFixed(2);
    }
  }

  void _submit() {
    widget.controller.updateProduct(widget.p.id, {
      'name': nameC.text,
      'category': categoryC.text,
      'brand': brandC.text,
      'model': modelC.text,
      'weight': double.tryParse(weightC.text) ?? widget.p.weight,
      'yuan': double.tryParse(yuanC.text) ?? widget.p.yuan,
      'air': double.tryParse(airC.text) ?? widget.p.air,
      'sea': double.tryParse(seaC.text) ?? widget.p.sea,
      'agent': double.tryParse(agentC.text) ?? widget.p.agent,
      'wholesale': double.tryParse(wholesaleC.text) ?? widget.p.wholesale,
      'shipmenttax': double.tryParse(shipmentTaxC.text) ?? widget.p.shipmentTax,
      'shipmenttaxair':
          double.tryParse(shipmentTaxAirC.text) ?? widget.p.shipmentTaxAir,
      'shipmentno': int.tryParse(shipmentNoC.text) ?? widget.p.shipmentNo,
      'shipmentdate': shipmentDateC.text.isEmpty ? null : shipmentDateC.text,
      'currency': double.tryParse(currencyC.text) ?? widget.p.currency,
      'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
      'stock_qty': int.tryParse(stockC.text) ?? widget.p.stockQty,
      'avg_purchase_price':
          double.tryParse(avgPriceC.text) ?? widget.p.avgPurchasePrice,
      'sea_stock_qty': int.tryParse(seaStockC.text) ?? widget.p.seaStockQty,
      'air_stock_qty': int.tryParse(airStockC.text) ?? widget.p.airStockQty,
      'local_qty': int.tryParse(localStockC.text) ?? widget.p.localQty,
    });
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    // Override the parent dialog's "Save" button behavior by injecting it here visually
    // OR we can just use the fields. To keep it clean, we build the fields here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Basic Information'),
        _buildField(nameC, 'Product Name', Icons.shopping_bag),
        _buildField(categoryC, 'Category', Icons.category),
        _responsiveRow(
          context,
          _buildField(brandC, 'Brand', Icons.branding_watermark),
          _buildField(modelC, 'Model', Icons.label),
        ),

        _sectionHeader('Costs & Logic (Auto-Updates)'),
        _responsiveRow(
          context,
          _buildField(
            yuanC,
            'Yuan Price (¥)',
            Icons.money,
            type: TextInputType.number,
          ),
          _buildField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            type: TextInputType.number,
          ),
        ),
        _responsiveRow(
          context,
          _buildField(
            shipmentTaxC,
            'Sea Tax /KG',
            Icons.directions_boat,
            type: TextInputType.number,
          ),
          _buildField(
            shipmentTaxAirC,
            'Air Tax /KG',
            Icons.airplanemode_active,
            type: TextInputType.number,
          ),
        ),
        _buildField(
          currencyC,
          'Exchange Rate',
          Icons.currency_exchange,
          type: TextInputType.number,
        ),

        _sectionHeader('Calculated Landing Costs'),
        _responsiveRow(
          context,
          _buildField(
            seaC,
            'Sea Price',
            Icons.waves,
            type: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            airC,
            'Air Price',
            Icons.air,
            type: TextInputType.number,
            readOnly: true,
          ),
        ),

        _sectionHeader('Logistics & Inventory'),
        _responsiveRow(
          context,
          _buildField(
            shipmentNoC,
            'Shipment No',
            Icons.numbers,
            type: TextInputType.number,
          ),
          _buildField(
            shipmentDateC,
            'Shipment Date',
            Icons.calendar_today,
            readOnly: true,
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
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
        _buildField(
          alertQtyC,
          'Low Stock Alert Qty (Default: 5)',
          Icons.notification_important,
          type: TextInputType.number,
        ),

        _sectionHeader('Sales Pricing'),
        _responsiveRow(
          context,
          _buildField(
            agentC,
            'Agent Price',
            Icons.person,
            type: TextInputType.number,
          ),
          _buildField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            type: TextInputType.number,
          ),
        ),

        _sectionHeader('Stock Override (Danger Zone)'),
        _buildField(
          avgPriceC,
          'Average Purchase Rate (BDT)',
          Icons.payments,
          type: TextInputType.number,
        ),
        _responsiveRow(
          context,
          _buildField(
            stockC,
            'Total Stock',
            Icons.inventory_2,
            type: TextInputType.number,
          ),
          _buildField(
            seaStockC,
            'Sea Stock',
            Icons.directions_boat,
            type: TextInputType.number,
          ),
        ),
        _responsiveRow(
          context,
          _buildField(
            airStockC,
            'Air Stock',
            Icons.airplanemode_active,
            type: TextInputType.number,
          ),
          _buildField(
            localStockC,
            'Local Stock',
            Icons.store,
            type: TextInputType.number,
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save),
            label: const Text("Save Updates", style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

void showCreateProductDialog(ProductController controller) {
  _showPOSDialog(
    title: 'New Product Registration',
    body: _CreateProductForm(controller: controller),
    onSave: () {}, 
  );
}

class _CreateProductForm extends StatefulWidget {
  final ProductController controller;
  const _CreateProductForm({required this.controller});

  @override
  State<_CreateProductForm> createState() => _CreateProductFormState();
}

class _CreateProductFormState extends State<_CreateProductForm> {
  late final TextEditingController nameC, categoryC, brandC, modelC;
  late final TextEditingController yuanC, weightC, currencyC, seaTaxC, airTaxC;
  late final TextEditingController airResultC, seaResultC;
  late final TextEditingController agentC,
      wholesaleC,
      shipmentNoC,
      shipmentDateC,
      stockC,
      alertQtyC;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    categoryC = TextEditingController();
    brandC = TextEditingController();
    modelC = TextEditingController();
    yuanC = TextEditingController(text: '0');
    weightC = TextEditingController(text: '0');
    currencyC = TextEditingController(
      text: widget.controller.currentCurrency.value.toString(),
    );
    seaTaxC = TextEditingController(text: '0');
    airTaxC = TextEditingController(text: '700');
    airResultC = TextEditingController(text: '0');
    seaResultC = TextEditingController(text: '0');
    agentC = TextEditingController();
    wholesaleC = TextEditingController();
    shipmentNoC = TextEditingController(text: '0');
    shipmentDateC = TextEditingController();
    stockC = TextEditingController(text: '0');
    alertQtyC = TextEditingController(text: '5');

    yuanC.addListener(calculatePrices);
    weightC.addListener(calculatePrices);
    currencyC.addListener(calculatePrices);
    seaTaxC.addListener(calculatePrices);
    airTaxC.addListener(calculatePrices);
  }

  @override
  void dispose() {
    nameC.dispose();
    categoryC.dispose();
    brandC.dispose();
    modelC.dispose();
    yuanC.dispose();
    weightC.dispose();
    currencyC.dispose();
    seaTaxC.dispose();
    airTaxC.dispose();
    airResultC.dispose();
    seaResultC.dispose();
    agentC.dispose();
    wholesaleC.dispose();
    shipmentNoC.dispose();
    shipmentDateC.dispose();
    stockC.dispose();
    alertQtyC.dispose();
    super.dispose();
  }

  void calculatePrices() {
    double yuan = double.tryParse(yuanC.text) ?? 0.0;
    double weight = double.tryParse(weightC.text) ?? 0.0;
    double curr =
        double.tryParse(currencyC.text) ??
        widget.controller.currentCurrency.value;
    double seaTax = double.tryParse(seaTaxC.text) ?? 0.0;
    double airTax = double.tryParse(airTaxC.text) ?? 0.0;

    if (yuan > 0) {
      seaResultC.text = ((yuan * curr) + (weight * seaTax)).toStringAsFixed(2);
      airResultC.text = ((yuan * curr) + (weight * airTax)).toStringAsFixed(2);
    } else {
      seaResultC.text = '0';
      airResultC.text = '0';
    }
  }

  void _submit() {
    int initialStock = int.tryParse(stockC.text) ?? 0;
    double initialAvgPrice = double.tryParse(seaResultC.text) ?? 0.0;

    widget.controller.createProduct({
      'name': nameC.text,
      'category': categoryC.text,
      'brand': brandC.text,
      'model': modelC.text,
      'weight': double.tryParse(weightC.text) ?? 0.0,
      'yuan': double.tryParse(yuanC.text) ?? 0.0,
      'air': double.tryParse(airResultC.text) ?? 0.0,
      'sea': double.tryParse(seaResultC.text) ?? 0.0,
      'agent': double.tryParse(agentC.text) ?? 0.0,
      'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
      'shipmenttax': double.tryParse(seaTaxC.text) ?? 0.0,
      'shipmenttaxair': double.tryParse(airTaxC.text) ?? 0.0,
      'shipmentno': int.tryParse(shipmentNoC.text) ?? 0,
      'shipmentdate': shipmentDateC.text.isEmpty ? null : shipmentDateC.text,
      'currency':
          double.tryParse(currencyC.text) ??
          widget.controller.currentCurrency.value,
      'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
      'stock_qty': initialStock,
      'avg_purchase_price': initialAvgPrice,
      'sea_stock_qty': initialStock,
      'air_stock_qty': 0,
      'local_qty': 0,
    });
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Basic Information'),
        _buildField(nameC, 'Product Name', Icons.shopping_bag),
        _buildField(categoryC, 'Category', Icons.category),
        _responsiveRow(
          context,
          _buildField(brandC, 'Brand', Icons.branding_watermark),
          _buildField(modelC, 'Model', Icons.label),
        ),

        _sectionHeader('Calculation Inputs'),
        _responsiveRow(
          context,
          _buildField(
            yuanC,
            'Yuan (¥)',
            Icons.money,
            type: TextInputType.number,
          ),
          _buildField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            type: TextInputType.number,
          ),
        ),
        _responsiveRow(
          context,
          _buildField(
            seaTaxC,
            'Sea Tax /KG',
            Icons.directions_boat,
            type: TextInputType.number,
          ),
          _buildField(
            airTaxC,
            'Air Tax /KG',
            Icons.airplanemode_active,
            type: TextInputType.number,
          ),
        ),
        _buildField(
          currencyC,
          'Rate',
          Icons.currency_exchange,
          type: TextInputType.number,
        ),

        _sectionHeader('Auto-Calculated Costs'),
        _responsiveRow(
          context,
          _buildField(
            seaResultC,
            'Sea Price (BDT)',
            Icons.waves,
            readOnly: true,
          ),
          _buildField(airResultC, 'Air Price (BDT)', Icons.air, readOnly: true),
        ),

        _sectionHeader('Logistics & Inventory'),
        _responsiveRow(
          context,
          _buildField(
            shipmentNoC,
            'Shipment No',
            Icons.numbers,
            type: TextInputType.number,
          ),
          _buildField(
            shipmentDateC,
            'Date',
            Icons.calendar_today,
            readOnly: true,
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
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
        _responsiveRow(
          context,
          _buildField(
            stockC,
            'Initial Stock (Sea)',
            Icons.inventory_2,
            type: TextInputType.number,
          ),
          _buildField(
            alertQtyC,
            'Low Stock Alert Qty',
            Icons.notification_important,
            type: TextInputType.number,
          ),
        ),

        _sectionHeader('Sales Pricing'),
        _responsiveRow(
          context,
          _buildField(
            agentC,
            'Agent Price',
            Icons.person,
            type: TextInputType.number,
          ),
          _buildField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            type: TextInputType.number,
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_circle),
            label: const Text("Create Product", style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// DELETE CONFIRM DIALOG
/// ===============================
void showDeleteConfirmDialog(int productId, ProductController controller) {
  Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Confirm Delete',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        'This action cannot be undone. Are you sure you want to permanently delete this product from the inventory?',
        style: TextStyle(fontSize: 15, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            controller.deleteProduct(productId);
            Get.back();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Delete Product',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}