import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import '../Core Utils/activity_logger.dart';
import '../Permission/permission_button.dart';
import 'stockcontroller.dart';
import 'stockproductmodel.dart';

void showEditProductDialog(Product p, ProductController controller) {
  Get.dialog(
    _ProductDialog(
      title: 'Update Product',
      child: _EditProductForm(p: p, controller: controller),
    ),
    barrierDismissible: false,
  );
}

void showCreateProductDialog(ProductController controller) {
  Get.dialog(
    _ProductDialog(
      title: 'New Product Registration',
      child: _CreateProductForm(controller: controller),
    ),
    barrierDismissible: false,
  );
}

void showDeleteConfirmDialog(int productId, ProductController controller) {
  Get.dialog(
    _DeleteConfirmDialog(productId: productId, controller: controller),
  );
}

class _ProductDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProductDialog({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
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
              decoration: const BoxDecoration(
                color: Color(0xFF1E40AF),
                borderRadius: BorderRadius.only(
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
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const _FormField(
    this.controller,
    this.label,
    this.icon, {
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType ?? TextInputType.text,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(
          fontSize: 13,
          fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
          color: readOnly ? const Color(0xFF1E3A8A) : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          prefixIcon: Icon(
            icon,
            size: 18,
            color: readOnly ? Colors.blue : Colors.blueGrey,
          ),
          isDense: true,
          filled: true,
          fillColor:
              readOnly
                  ? Colors.blue.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SectionHeader — section title
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D4ED8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ResponsiveRow — mobile=column, desktop=row
// ─────────────────────────────────────────────────────────────
class _ResponsiveRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 10), right],
      );
    }

    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SubmitButton — shared save button
// ─────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EditProductForm
// ─────────────────────────────────────────────────────────────
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

    // Auto-recalculate sea/air price
    yuanC.addListener(_recalculate);
    weightC.addListener(_recalculate);
    currencyC.addListener(_recalculate);
    shipmentTaxC.addListener(_recalculate);
    shipmentTaxAirC.addListener(_recalculate);
  }

  @override
  void dispose() {
    for (final c in [
      nameC,
      categoryC,
      brandC,
      modelC,
      weightC,
      yuanC,
      currencyC,
      shipmentTaxC,
      shipmentTaxAirC,
      airC,
      seaC,
      agentC,
      wholesaleC,
      shipmentNoC,
      shipmentDateC,
      alertQtyC,
      stockC,
      avgPriceC,
      seaStockC,
      airStockC,
      localStockC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final yuan = double.tryParse(yuanC.text) ?? 0.0;
    final weight = double.tryParse(weightC.text) ?? 0.0;
    final curr = double.tryParse(currencyC.text) ?? 0.0;
    final seaTax = double.tryParse(shipmentTaxC.text) ?? 0.0;
    final airTax = double.tryParse(shipmentTaxAirC.text) ?? 0.0;

    if (yuan > 0) {
      seaC.text = ((yuan * curr) + (weight * seaTax)).toStringAsFixed(2);
      airC.text = ((yuan * curr) + (weight * airTax)).toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    final p = widget.p;
    await widget.controller.updateProduct(p.id, {
      'name': nameC.text,
      'category': categoryC.text,
      'brand': brandC.text,
      'model': modelC.text,
      'weight': double.tryParse(weightC.text) ?? p.weight,
      'yuan': double.tryParse(yuanC.text) ?? p.yuan,
      'air': double.tryParse(airC.text) ?? p.air,
      'sea': double.tryParse(seaC.text) ?? p.sea,
      'agent': double.tryParse(agentC.text) ?? p.agent,
      'wholesale': double.tryParse(wholesaleC.text) ?? p.wholesale,
      'shipmenttax': double.tryParse(shipmentTaxC.text) ?? p.shipmentTax,
      'shipmenttaxair':
          double.tryParse(shipmentTaxAirC.text) ?? p.shipmentTaxAir,
      'shipmentno': int.tryParse(shipmentNoC.text) ?? p.shipmentNo,
      'shipmentdate': shipmentDateC.text.isEmpty ? null : shipmentDateC.text,
      'currency': double.tryParse(currencyC.text) ?? p.currency,
      'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
      'stock_qty': int.tryParse(stockC.text) ?? p.stockQty,
      'avg_purchase_price':
          double.tryParse(avgPriceC.text) ?? p.avgPurchasePrice,
      'sea_stock_qty': int.tryParse(seaStockC.text) ?? p.seaStockQty,
      'air_stock_qty': int.tryParse(airStockC.text) ?? p.airStockQty,
      'local_qty': int.tryParse(localStockC.text) ?? p.localQty,
    });

    // Activity log
    await ActivityLogger.stockUpdated(
      '${p.model} updated | Agent: ${agentC.text} | Wholesale: ${wholesaleC.text}',
    );

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Basic Information'),
        _FormField(nameC, 'Product Name', Icons.shopping_bag),
        _FormField(categoryC, 'Category', Icons.category),
        _ResponsiveRow(
          left: _FormField(brandC, 'Brand', Icons.branding_watermark),
          right: _FormField(modelC, 'Model', Icons.label),
        ),

        const _SectionHeader('Costs & Logic (Auto-Updates)'),
        _ResponsiveRow(
          left: _FormField(
            yuanC,
            'Yuan Price (¥)',
            Icons.money,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            keyboardType: TextInputType.number,
          ),
        ),
        _ResponsiveRow(
          left: _FormField(
            shipmentTaxC,
            'Sea Tax /KG',
            Icons.directions_boat,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            shipmentTaxAirC,
            'Air Tax /KG',
            Icons.airplanemode_active,
            keyboardType: TextInputType.number,
          ),
        ),
        _FormField(
          currencyC,
          'Exchange Rate',
          Icons.currency_exchange,
          keyboardType: TextInputType.number,
        ),

        const _SectionHeader('Calculated Landing Costs'),
        _ResponsiveRow(
          left: _FormField(seaC, 'Sea Price', Icons.waves, readOnly: true),
          right: _FormField(airC, 'Air Price', Icons.air, readOnly: true),
        ),

        const _SectionHeader('Logistics & Inventory'),
        _ResponsiveRow(
          left: _FormField(
            shipmentNoC,
            'Shipment No',
            Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            shipmentDateC,
            'Shipment Date',
            Icons.calendar_today,
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
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
        _FormField(
          alertQtyC,
          'Low Stock Alert Qty',
          Icons.notification_important,
          keyboardType: TextInputType.number,
        ),

        const _SectionHeader('Sales Pricing'),
        _ResponsiveRow(
          left: _FormField(
            agentC,
            'Agent Price',
            Icons.person,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            keyboardType: TextInputType.number,
          ),
        ),

        const _SectionHeader('Stock Override ⚠️'),
        _FormField(
          avgPriceC,
          'Average Purchase Rate (BDT)',
          Icons.payments,
          keyboardType: TextInputType.number,
        ),
        _ResponsiveRow(
          left: _FormField(
            stockC,
            'Total Stock',
            Icons.inventory_2,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            seaStockC,
            'Sea Stock',
            Icons.directions_boat,
            keyboardType: TextInputType.number,
          ),
        ),
        _ResponsiveRow(
          left: _FormField(
            airStockC,
            'Air Stock',
            Icons.airplanemode_active,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            localStockC,
            'Local Stock',
            Icons.store,
            keyboardType: TextInputType.number,
          ),
        ),

        const SizedBox(height: 20),
        _SubmitButton(
          label: 'Save Updates',
          icon: Icons.save,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CreateProductForm
// ─────────────────────────────────────────────────────────────
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

    yuanC.addListener(_calculate);
    weightC.addListener(_calculate);
    currencyC.addListener(_calculate);
    seaTaxC.addListener(_calculate);
    airTaxC.addListener(_calculate);
  }

  @override
  void dispose() {
    for (final c in [
      nameC,
      categoryC,
      brandC,
      modelC,
      yuanC,
      weightC,
      currencyC,
      seaTaxC,
      airTaxC,
      airResultC,
      seaResultC,
      agentC,
      wholesaleC,
      shipmentNoC,
      shipmentDateC,
      stockC,
      alertQtyC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    final yuan = double.tryParse(yuanC.text) ?? 0.0;
    final weight = double.tryParse(weightC.text) ?? 0.0;
    final curr =
        double.tryParse(currencyC.text) ??
        widget.controller.currentCurrency.value;
    final seaTax = double.tryParse(seaTaxC.text) ?? 0.0;
    final airTax = double.tryParse(airTaxC.text) ?? 0.0;

    if (yuan > 0) {
      seaResultC.text = ((yuan * curr) + (weight * seaTax)).toStringAsFixed(2);
      airResultC.text = ((yuan * curr) + (weight * airTax)).toStringAsFixed(2);
    } else {
      seaResultC.text = '0';
      airResultC.text = '0';
    }
  }

  Future<void> _submit() async {
    final initialStock = int.tryParse(stockC.text) ?? 0;
    final initialAvgPrice = double.tryParse(seaResultC.text) ?? 0.0;
    final modelName = modelC.text;
    final productName = nameC.text;

    await widget.controller.createProduct({
      'name': productName,
      'category': categoryC.text,
      'brand': brandC.text,
      'model': modelName,
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

    // Activity log
    await ActivityLogger.log(
      action: 'CREATE_PRODUCT',
      module: 'Stock',
      details: '$modelName | $productName | Initial stock: $initialStock',
    );

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Basic Information'),
        _FormField(nameC, 'Product Name', Icons.shopping_bag),
        _FormField(categoryC, 'Category', Icons.category),
        _ResponsiveRow(
          left: _FormField(brandC, 'Brand', Icons.branding_watermark),
          right: _FormField(modelC, 'Model', Icons.label),
        ),

        const _SectionHeader('Calculation Inputs'),
        _ResponsiveRow(
          left: _FormField(
            yuanC,
            'Yuan (¥)',
            Icons.money,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            keyboardType: TextInputType.number,
          ),
        ),
        _ResponsiveRow(
          left: _FormField(
            seaTaxC,
            'Sea Tax /KG',
            Icons.directions_boat,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            airTaxC,
            'Air Tax /KG',
            Icons.airplanemode_active,
            keyboardType: TextInputType.number,
          ),
        ),
        _FormField(
          currencyC,
          'Rate',
          Icons.currency_exchange,
          keyboardType: TextInputType.number,
        ),

        const _SectionHeader('Auto-Calculated Costs'),
        _ResponsiveRow(
          left: _FormField(
            seaResultC,
            'Sea Price (BDT)',
            Icons.waves,
            readOnly: true,
          ),
          right: _FormField(
            airResultC,
            'Air Price (BDT)',
            Icons.air,
            readOnly: true,
          ),
        ),

        const _SectionHeader('Logistics & Inventory'),
        _ResponsiveRow(
          left: _FormField(
            shipmentNoC,
            'Shipment No',
            Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            shipmentDateC,
            'Date',
            Icons.calendar_today,
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
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
        _ResponsiveRow(
          left: _FormField(
            stockC,
            'Initial Stock (Sea)',
            Icons.inventory_2,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            alertQtyC,
            'Low Stock Alert Qty',
            Icons.notification_important,
            keyboardType: TextInputType.number,
          ),
        ),

        const _SectionHeader('Sales Pricing'),
        _ResponsiveRow(
          left: _FormField(
            agentC,
            'Agent Price',
            Icons.person,
            keyboardType: TextInputType.number,
          ),
          right: _FormField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            keyboardType: TextInputType.number,
          ),
        ),

        const SizedBox(height: 20),
        _SubmitButton(
          label: 'Create Product',
          icon: Icons.check_circle,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _DeleteConfirmDialog — permission check সহ
// ─────────────────────────────────────────────────────────────
class _DeleteConfirmDialog extends StatelessWidget {
  final int productId;
  final ProductController controller;

  const _DeleteConfirmDialog({
    required this.productId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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

        // Delete — canDelete permission লাগবে
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canDelete,
          showDisabled: true,
          child: ElevatedButton(
            onPressed: () async {
              await controller.deleteProduct(productId);
              await ActivityLogger.stockDeleted(
                'Product ID: $productId deleted',
              );
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
        ),
      ],
    );
  }
}