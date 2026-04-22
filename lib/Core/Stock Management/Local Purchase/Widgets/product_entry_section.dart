import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import '../../../Core Utils/app_logger.dart';
import '../../stock_controller.dart';
import '../local_purchase_page.dart';
import 'create_product_inline_dialog.dart';

class ProductEntrySection extends StatelessWidget {
  final ProductController productCtrl;
  final Rx<Product?> selectedProduct;
  final RxString selectedLocation;
  final TextEditingController qtyController;
  final TextEditingController costController;
  final bool isMobile;
  final void Function(TextEditingController) onProductFieldReady;
  final void Function(Product?, String) onCalculateCost;
  final VoidCallback onAddToCart;

  const ProductEntrySection({
    super.key,
    required this.productCtrl,
    required this.selectedProduct,
    required this.selectedLocation,
    required this.qtyController,
    required this.costController,
    required this.isMobile,
    required this.onProductFieldReady,
    required this.onCalculateCost,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _StepLabel(step: '2', title: 'Add Item to Cart'),
              ElevatedButton.icon(
                onPressed: () => Get.dialog(
                  CreateProductInlineDialog(
                    productCtrl: productCtrl,
                    onCreated: (p) {
                      selectedProduct.value = p;
                      onCalculateCost(p, selectedLocation.value);
                    },
                  ),
                ),
                icon: const Icon(Icons.add,
                    size: 16, color: Colors.white),
                label: const Text('New Product',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Product search autocomplete
          Autocomplete<Product>(
            displayStringForOption: (o) => '${o.model} - ${o.name}',
            optionsBuilder: (textEditingValue) async {
              final q = textEditingValue.text.trim();
              if (q.isEmpty) return const [];

              // Try server search first
              try {
                final uri =
                    Uri.parse('${ProductController.baseUrl}/products')
                        .replace(queryParameters: {
                  'page': '1',
                  'limit': '20',
                  'search': q,
                });
                final res =
                    await http.get(uri).timeout(const Duration(seconds: 5));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  final List productsJson = data['products'] ?? [];
                  return productsJson
                      .map((e) => Product.fromJson(e))
                      .toList();
                }
              } catch (e) {
                AppLogger.w('Product search fallback: $e');
              }

              // Local cache fallback
              final qLower = q.toLowerCase();
              final terms = qLower.split(RegExp(r'\s+'));
              return productCtrl.allProducts.where((p) {
                final combined =
                    '${p.model} ${p.name} ${p.brand}'.toLowerCase();
                return terms.every((t) => combined.contains(t));
              });
            },
            onSelected: (p) {
              selectedProduct.value = p;
              onCalculateCost(p, selectedLocation.value);
            },
            fieldViewBuilder: (ctx, ctrl, focus, _) {
              onProductFieldReady(ctrl);
              return TextField(
                controller: ctrl,
                focusNode: focus,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText:
                      'Search Product by Model, Name, Brand...',
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(
                      Icons.inventory_2_outlined,
                      color: textLight),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: bgGrey,
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Location, Qty, Cost inputs
          isMobile
              ? Column(
                  children: [
                    _LocationDropdown(
                      selectedLocation: selectedLocation,
                      selectedProduct: selectedProduct,
                      onCalculateCost: onCalculateCost,
                    ),
                    const SizedBox(height: 12),
                    _QtyInput(controller: qtyController),
                    const SizedBox(height: 12),
                    _CostInput(controller: costController),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _LocationDropdown(
                        selectedLocation: selectedLocation,
                        selectedProduct: selectedProduct,
                        onCalculateCost: onCalculateCost,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _QtyInput(controller: qtyController)),
                    const SizedBox(width: 16),
                    Expanded(
                        child:
                            _CostInput(controller: costController)),
                  ],
                ),

          const SizedBox(height: 24),

          // Add to cart button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.add_shopping_cart,
                  color: Colors.white),
              label: const Text(
                'Add to Cart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────
class _LocationDropdown extends StatelessWidget {
  final RxString selectedLocation;
  final Rx<Product?> selectedProduct;
  final void Function(Product?, String) onCalculateCost;

  const _LocationDropdown({
    required this.selectedLocation,
    required this.selectedProduct,
    required this.onCalculateCost,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => DropdownButtonFormField<String>(
          value: selectedLocation.value,
          decoration: InputDecoration(
            labelText: 'Purchase Location',
            labelStyle: const TextStyle(fontSize: 11),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          items: ['Local', 'Air', 'Sea']
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            selectedLocation.value = val;
            onCalculateCost(selectedProduct.value, val);
          },
        ));
  }
}

class _QtyInput extends StatelessWidget {
  final TextEditingController controller;

  const _QtyInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Quantity',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CostInput extends StatelessWidget {
  final TextEditingController controller;

  const _CostInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Unit Cost (৳)',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step label — reused from supplier_section
// ─────────────────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String step;
  final String title;

  const _StepLabel({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: activeAccent,
          child: Text(step,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            )),
      ],
    );
  }
}