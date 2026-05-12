import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Menubar and Navigation/app_pages.dart';
import '../../Permission/permission_button.dart';
import '../Core/Core Utils/activity_logger.dart';
import 'stock_controller.dart';
import 'stock_model.dart';

void showEditProductDialog(Product product, ProductController controller) {
  Get.dialog(
    _ProductDialog(
      title: 'Update Product',
      child: _EditProductForm(product: product, controller: controller),
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(title: title),
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

class _DialogHeader extends StatelessWidget {
  final String title;

  const _DialogHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
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
          fontWeight: readOnly ? FontWeight.w700 : FontWeight.w500,
          color: readOnly ? const Color(0xFF1E3A8A) : const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          prefixIcon: Icon(
            icon,
            size: 18,
            color: readOnly ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
          isDense: true,
          filled: true,
          fillColor:
              readOnly ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
          ),
        ),
      ),
    );
  }
}

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
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1D4ED8),
          letterSpacing: 0,
        ),
      ),
    );
  }
}

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

class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ProductController controller;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isActionLoading.value;

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: loading ? null : onPressed,
          icon:
              loading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(icon),
          label: Text(
            loading ? 'Saving...' : label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF93C5FD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    });
  }
}

class _WarehousePicker extends StatelessWidget {
  final ProductController controller;
  final RxnInt selectedWarehouseId;
  final TextEditingController locationController;
  final String title;

  const _WarehousePicker({
    required this.controller,
    required this.selectedWarehouseId,
    required this.locationController,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final warehouses = controller.activeWarehouses;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title),
          DropdownButtonFormField<int>(
            value: selectedWarehouseId.value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Warehouse',
              prefixIcon: Icon(Icons.warehouse_rounded),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items:
                warehouses.map((warehouse) {
                  final id = _parseInt(warehouse['id']);
                  final name = warehouse['name']?.toString() ?? 'Warehouse $id';

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
            onChanged: (value) => selectedWarehouseId.value = value,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: 'Location inside warehouse',
              hintText: 'Example: Rack A-3, Box 12',
              prefixIcon: Icon(Icons.location_on_outlined),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    });
  }
}

class _EditProductForm extends StatefulWidget {
  final Product product;
  final ProductController controller;

  const _EditProductForm({required this.product, required this.controller});

  @override
  State<_EditProductForm> createState() => _EditProductFormState();
}

class _EditProductFormState extends State<_EditProductForm> {
  bool _submitting = false;

  late final TextEditingController nameC;
  late final TextEditingController categoryC;
  late final TextEditingController brandC;
  late final TextEditingController modelC;
  late final TextEditingController weightC;
  late final TextEditingController yuanC;
  late final TextEditingController currencyC;
  late final TextEditingController shipmentTaxC;
  late final TextEditingController shipmentTaxAirC;
  late final TextEditingController airC;
  late final TextEditingController seaC;
  late final TextEditingController agentC;
  late final TextEditingController wholesaleC;
  late final TextEditingController shipmentNoC;
  late final TextEditingController shipmentDateC;
  late final TextEditingController alertQtyC;
  late final TextEditingController stockC;
  late final TextEditingController avgPriceC;
  late final TextEditingController seaStockC;
  late final TextEditingController airStockC;
  late final TextEditingController localStockC;
  late final TextEditingController warehouseLocationC;

  final selectedWarehouseId = RxnInt();

  @override
  void initState() {
    super.initState();

    final p = widget.product;
    final firstWarehouse =
        p.warehouseStocks.isNotEmpty ? p.warehouseStocks.first : null;

    selectedWarehouseId.value =
        firstWarehouse?.warehouseId ??
        _firstActiveWarehouseId(widget.controller);
    warehouseLocationC = TextEditingController(
      text: firstWarehouse?.location ?? '',
    );

    nameC = TextEditingController(text: p.name);
    categoryC = TextEditingController(text: p.category);
    brandC = TextEditingController(text: p.brand);
    modelC = TextEditingController(text: p.model);
    weightC = TextEditingController(text: _numText(p.weight));
    yuanC = TextEditingController(text: _numText(p.yuan));
    currencyC = TextEditingController(text: _numText(p.currency));
    shipmentTaxC = TextEditingController(text: _numText(p.shipmentTax));
    shipmentTaxAirC = TextEditingController(text: _numText(p.shipmentTaxAir));
    airC = TextEditingController(text: _numText(p.air));
    seaC = TextEditingController(text: _numText(p.sea));
    agentC = TextEditingController(text: _numText(p.agent));
    wholesaleC = TextEditingController(text: _numText(p.wholesale));
    shipmentNoC = TextEditingController(text: p.shipmentNo.toString());
    shipmentDateC = TextEditingController(
      text:
          p.shipmentDate == null
              ? ''
              : DateFormat('yyyy-MM-dd').format(p.shipmentDate!),
    );
    alertQtyC = TextEditingController(text: p.alertQty.toString());
    stockC = TextEditingController(text: p.stockQty.toString());
    avgPriceC = TextEditingController(text: _numText(p.avgPurchasePrice));
    seaStockC = TextEditingController(text: p.seaStockQty.toString());
    airStockC = TextEditingController(text: p.airStockQty.toString());
    localStockC = TextEditingController(text: p.localQty.toString());

    for (final controller in [
      yuanC,
      weightC,
      currencyC,
      shipmentTaxC,
      shipmentTaxAirC,
    ]) {
      controller.addListener(_recalculate);
    }
  }

  @override
  void dispose() {
    for (final controller in [
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
      warehouseLocationC,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  void _recalculate() {
    final yuan = double.tryParse(yuanC.text) ?? 0.0;
    final weight = double.tryParse(weightC.text) ?? 0.0;
    final currency = double.tryParse(currencyC.text) ?? 0.0;
    final seaTax = double.tryParse(shipmentTaxC.text) ?? 0.0;
    final airTax = double.tryParse(shipmentTaxAirC.text) ?? 0.0;

    if (yuan <= 0) return;

    seaC.text = ((yuan * currency) + (weight * seaTax)).toStringAsFixed(2);
    airC.text = ((yuan * currency) + (weight * airTax)).toStringAsFixed(2);
  }

  String? _validate() {
    if (nameC.text.trim().isEmpty) return 'Product name is required.';
    if (modelC.text.trim().isEmpty) return 'Model is required.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      Get.snackbar(
        'Validation',
        error,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_submitting) return;
    _submitting = true;

    try {
      final p = widget.product;
      final warehouseId = selectedWarehouseId.value;

      await widget.controller.updateProduct(
        p.id,
        {
          'name': nameC.text.trim(),
          'category': categoryC.text.trim(),
          'brand': brandC.text.trim(),
          'model': modelC.text.trim(),
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
          'shipmentdate':
              shipmentDateC.text.trim().isEmpty
                  ? null
                  : shipmentDateC.text.trim(),
          'currency': double.tryParse(currencyC.text) ?? p.currency,
          'alert_qty': int.tryParse(alertQtyC.text) ?? p.alertQty,
          'stock_qty': int.tryParse(stockC.text) ?? p.stockQty,
          'avg_purchase_price':
              double.tryParse(avgPriceC.text) ?? p.avgPurchasePrice,
          'sea_stock_qty': int.tryParse(seaStockC.text) ?? p.seaStockQty,
          'air_stock_qty': int.tryParse(airStockC.text) ?? p.airStockQty,
          'local_qty': int.tryParse(localStockC.text) ?? p.localQty,
        },
        warehouseId: warehouseId,
        warehouseLocation: warehouseLocationC.text.trim(),
      );

      await ActivityLogger.stockUpdated(
        '${p.model} updated | Agent: ${agentC.text} | Wholesale: ${wholesaleC.text}',
      );

      if (mounted) Get.back();
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Basic Information'),
        _FormField(nameC, 'Product Name *', Icons.shopping_bag),
        _FormField(categoryC, 'Category', Icons.category),
        _ResponsiveRow(
          left: _FormField(brandC, 'Brand', Icons.branding_watermark),
          right: _FormField(modelC, 'Model *', Icons.label),
        ),
        const _SectionHeader('Costs & Logic'),
        _ResponsiveRow(
          left: _FormField(
            yuanC,
            'Yuan Price',
            Icons.money,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        _ResponsiveRow(
          left: _FormField(
            shipmentTaxC,
            'Sea Tax / KG',
            Icons.directions_boat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            shipmentTaxAirC,
            'Air Tax / KG',
            Icons.airplanemode_active,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        _FormField(
          currencyC,
          'Exchange Rate',
          Icons.currency_exchange,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onTap: () => _pickDate(context, shipmentDateC),
          ),
        ),
        _FormField(
          alertQtyC,
          'Low Stock Alert Qty',
          Icons.notification_important,
          keyboardType: TextInputType.number,
        ),
        _WarehousePicker(
          controller: widget.controller,
          selectedWarehouseId: selectedWarehouseId,
          locationController: warehouseLocationC,
          title: 'Warehouse Location',
        ),
        const _SectionHeader('Sales Pricing'),
        _ResponsiveRow(
          left: _FormField(
            agentC,
            'Agent Price',
            Icons.person,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const _SectionHeader('Stock Override'),
        _FormField(
          avgPriceC,
          'Average Purchase Rate (BDT)',
          Icons.payments,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        const SizedBox(height: 22),
        _SubmitButton(
          label: 'Save Updates',
          icon: Icons.save_rounded,
          onPressed: _submit,
          controller: widget.controller,
        ),
      ],
    );
  }
}

class _CreateProductForm extends StatefulWidget {
  final ProductController controller;

  const _CreateProductForm({required this.controller});

  @override
  State<_CreateProductForm> createState() => _CreateProductFormState();
}

class _CreateProductFormState extends State<_CreateProductForm> {
  bool _submitting = false;

  late final TextEditingController nameC;
  late final TextEditingController categoryC;
  late final TextEditingController brandC;
  late final TextEditingController modelC;
  late final TextEditingController yuanC;
  late final TextEditingController weightC;
  late final TextEditingController currencyC;
  late final TextEditingController seaTaxC;
  late final TextEditingController airTaxC;
  late final TextEditingController airResultC;
  late final TextEditingController seaResultC;
  late final TextEditingController agentC;
  late final TextEditingController wholesaleC;
  late final TextEditingController shipmentNoC;
  late final TextEditingController shipmentDateC;
  late final TextEditingController stockC;
  late final TextEditingController alertQtyC;
  late final TextEditingController warehouseLocationC;

  final selectedWarehouseId = RxnInt();

  @override
  void initState() {
    super.initState();

    selectedWarehouseId.value = _firstActiveWarehouseId(widget.controller);

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
    warehouseLocationC = TextEditingController();

    for (final controller in [yuanC, weightC, currencyC, seaTaxC, airTaxC]) {
      controller.addListener(_calculate);
    }
  }

  @override
  void dispose() {
    for (final controller in [
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
      warehouseLocationC,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  void _calculate() {
    final yuan = double.tryParse(yuanC.text) ?? 0.0;
    final weight = double.tryParse(weightC.text) ?? 0.0;
    final currency =
        double.tryParse(currencyC.text) ??
        widget.controller.currentCurrency.value;
    final seaTax = double.tryParse(seaTaxC.text) ?? 0.0;
    final airTax = double.tryParse(airTaxC.text) ?? 0.0;

    if (yuan > 0) {
      seaResultC.text = ((yuan * currency) + (weight * seaTax)).toStringAsFixed(
        2,
      );
      airResultC.text = ((yuan * currency) + (weight * airTax)).toStringAsFixed(
        2,
      );
    } else {
      seaResultC.text = '0';
      airResultC.text = '0';
    }
  }

  String? _validate() {
    if (nameC.text.trim().isEmpty) return 'Product name is required.';
    if (modelC.text.trim().isEmpty) return 'Model is required.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      Get.snackbar(
        'Validation',
        error,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_submitting) return;
    _submitting = true;

    try {
      final initialStock = int.tryParse(stockC.text) ?? 0;
      final initialAvgPrice = double.tryParse(seaResultC.text) ?? 0.0;
      final modelName = modelC.text.trim();
      final productName = nameC.text.trim();

      await widget.controller.createProduct(
        {
          'name': productName,
          'category': categoryC.text.trim(),
          'brand': brandC.text.trim(),
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
          'shipmentdate':
              shipmentDateC.text.trim().isEmpty
                  ? null
                  : shipmentDateC.text.trim(),
          'currency':
              double.tryParse(currencyC.text) ??
              widget.controller.currentCurrency.value,
          'alert_qty': int.tryParse(alertQtyC.text) ?? 5,
          'stock_qty': initialStock,
          'avg_purchase_price': initialAvgPrice,
          'sea_stock_qty': initialStock,
          'air_stock_qty': 0,
          'local_qty': 0,
        },
        warehouseId: selectedWarehouseId.value,
        warehouseLocation: warehouseLocationC.text.trim(),
      );

      await ActivityLogger.log(
        action: 'CREATE_PRODUCT',
        module: 'Stock',
        details: '$modelName | $productName | Initial stock: $initialStock',
      );

      if (mounted) Get.back();
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Basic Information'),
        _FormField(nameC, 'Product Name *', Icons.shopping_bag),
        _FormField(categoryC, 'Category', Icons.category),
        _ResponsiveRow(
          left: _FormField(brandC, 'Brand', Icons.branding_watermark),
          right: _FormField(modelC, 'Model *', Icons.label),
        ),
        const _SectionHeader('Calculation Inputs'),
        _ResponsiveRow(
          left: _FormField(
            yuanC,
            'Yuan',
            Icons.money,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            weightC,
            'Weight (KG)',
            Icons.monitor_weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        _ResponsiveRow(
          left: _FormField(
            seaTaxC,
            'Sea Tax / KG',
            Icons.directions_boat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            airTaxC,
            'Air Tax / KG',
            Icons.airplanemode_active,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        _FormField(
          currencyC,
          'Exchange Rate',
          Icons.currency_exchange,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onTap: () => _pickDate(context, shipmentDateC),
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
        _WarehousePicker(
          controller: widget.controller,
          selectedWarehouseId: selectedWarehouseId,
          locationController: warehouseLocationC,
          title: 'Initial Warehouse',
        ),
        const _SectionHeader('Sales Pricing'),
        _ResponsiveRow(
          left: _FormField(
            agentC,
            'Agent Price',
            Icons.person,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          right: _FormField(
            wholesaleC,
            'Wholesale',
            Icons.groups,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(height: 22),
        _SubmitButton(
          label: 'Create Product',
          icon: Icons.check_circle_rounded,
          onPressed: _submit,
          controller: widget.controller,
        ),
      ],
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  final int productId;
  final ProductController controller;

  const _DeleteConfirmDialog({
    required this.productId,
    required this.controller,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;

    setState(() => _deleting = true);

    try {
      await widget.controller.deleteProduct(widget.productId);
      await ActivityLogger.stockDeleted(
        'Product ID: ${widget.productId} deleted',
      );

      if (mounted) Get.back();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
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
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: const Text(
        'This action cannot be undone. Are you sure you want to permanently delete this product?',
        style: TextStyle(fontSize: 15, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(
          onPressed: _deleting ? null : Get.back,
          child: const Text('Cancel'),
        ),
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canDelete,
          showDisabled: true,
          child: ElevatedButton(
            onPressed: _deleting ? null : _delete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.red.shade200,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _deleting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text(
                      'Delete Product',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
          ),
        ),
      ],
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  TextEditingController controller,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );

  if (picked != null) {
    controller.text = DateFormat('yyyy-MM-dd').format(picked);
  }
}

int? _firstActiveWarehouseId(ProductController controller) {
  if (controller.activeWarehouses.isEmpty) return null;
  return _parseInt(controller.activeWarehouses.first['id']);
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String _numText(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}