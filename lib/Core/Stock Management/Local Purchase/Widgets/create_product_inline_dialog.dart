import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core Utils/activity_logger.dart';
import '../../stock_controller.dart';
import '../../stockproductmodel.dart';
import '../local_purchase_page.dart';

class CreateProductInlineDialog extends StatefulWidget {
  final ProductController productCtrl;
  final void Function(Product) onCreated;

  const CreateProductInlineDialog({
    super.key,
    required this.productCtrl,
    required this.onCreated,
  });

  @override
  State<CreateProductInlineDialog> createState() =>
      _CreateProductInlineDialogState();
}

class _CreateProductInlineDialogState extends State<CreateProductInlineDialog> {
  late TextEditingController nameC, modelC, brandC, catC;
  late TextEditingController yuanC, weightC, seaTaxC, airTaxC;
  late TextEditingController agentC, wholesaleC;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    modelC = TextEditingController();
    brandC = TextEditingController();
    catC = TextEditingController();
    yuanC = TextEditingController(text: '0');
    weightC = TextEditingController(text: '0');
    seaTaxC = TextEditingController(text: '0');
    airTaxC = TextEditingController(text: '0');
    agentC = TextEditingController(text: '0');
    wholesaleC = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    for (final c in [
      nameC,
      modelC,
      brandC,
      catC,
      yuanC,
      weightC,
      seaTaxC,
      airTaxC,
      agentC,
      wholesaleC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Create New Product',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: darkSlate,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Basic Info'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('Model', modelC)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Name', nameC)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('Brand', brandC)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Category', catC)),
                ],
              ),

              const Divider(height: 30),
              _sectionLabel('RMB & Shipping'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('RMB (Yuan)', yuanC, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field('Weight (KG)', weightC, isNumber: true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('Sea Tax', seaTaxC, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Air Tax', airTaxC, isNumber: true)),
                ],
              ),

              const Divider(height: 30),
              _sectionLabel('Selling Prices'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field('Agent Price', agentC, isNumber: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field('Wholesale', wholesaleC, isNumber: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        Obx(
          () => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: widget.productCtrl.isActionLoading.value ? null : _save,
            child:
                widget.productCtrl.isActionLoading.value
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Create & Select',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (modelC.text.isEmpty || nameC.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Model and Name are required',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final data = {
      'name': nameC.text,
      'model': modelC.text,
      'brand': brandC.text,
      'category': catC.text,
      'yuan': double.tryParse(yuanC.text) ?? 0.0,
      'weight': double.tryParse(weightC.text) ?? 0.0,
      'shipmentTax': double.tryParse(seaTaxC.text) ?? 0.0,
      'shipmentTaxAir': double.tryParse(airTaxC.text) ?? 0.0,
      'agent': double.tryParse(agentC.text) ?? 0.0,
      'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
      'currency': widget.productCtrl.currentCurrency.value,
      'alert_qty': 5,
      'stock_qty': 0,
    };

    final newId = await widget.productCtrl.createProductReturnId(data);
    if (newId != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      final tempProd = Product.fromJson({...data, 'id': newId});

      await ActivityLogger.log(
        action: 'CREATE_PRODUCT',
        module: 'Local Purchase',
        details: '${modelC.text} | ${nameC.text} created inline',
      );

      widget.onCreated(tempProd);
      Get.back();
      Get.snackbar(
        'Success',
        'Product Created & Selected',
        backgroundColor: darkSlate,
        colorText: Colors.white,
      );
    }
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      color: activeAccent,
      fontSize: 13,
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      keyboardType:
          isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}