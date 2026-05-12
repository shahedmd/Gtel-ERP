import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock%20Management/stock_model.dart';
import 'package:http/http.dart' as http;

import '../../../Core/Core Utils/app_logger.dart';
import '../../stock_controller.dart';
import '../local_purchase_page.dart';
import 'create_product_inline_dialog.dart';

class ProductEntrySection extends StatelessWidget {
  final ProductController productCtrl;
  final Rx<Product?> selectedProduct;
  final RxString selectedStockType;
  final RxnInt selectedWarehouseId;
  final TextEditingController warehouseLocationController;
  final TextEditingController qtyController;
  final TextEditingController costController;
  final bool isMobile;
  final void Function(TextEditingController) onProductFieldReady;
  final void Function(Product?, String) onCalculateCost;
  final void Function(int? warehouseId, String warehouseName)
  onWarehouseSelected;
  final VoidCallback onAddToCart;

  const ProductEntrySection({
    super.key,
    required this.productCtrl,
    required this.selectedProduct,
    required this.selectedStockType,
    required this.selectedWarehouseId,
    required this.warehouseLocationController,
    required this.qtyController,
    required this.costController,
    required this.isMobile,
    required this.onProductFieldReady,
    required this.onCalculateCost,
    required this.onWarehouseSelected,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
          _Header(
            productCtrl: productCtrl,
            selectedProduct: selectedProduct,
            selectedStockType: selectedStockType,
            onCalculateCost: onCalculateCost,
          ),
          const SizedBox(height: 16),
          _ProductSearch(
            productCtrl: productCtrl,
            selectedProduct: selectedProduct,
            selectedStockType: selectedStockType,
            onProductFieldReady: onProductFieldReady,
            onCalculateCost: onCalculateCost,
          ),
          const SizedBox(height: 18),
          isMobile
              ? Column(
                children: [
                  _StockTypeDropdown(
                    selectedStockType: selectedStockType,
                    selectedProduct: selectedProduct,
                    onCalculateCost: onCalculateCost,
                  ),
                  const SizedBox(height: 12),
                  _WarehouseDropdown(
                    productCtrl: productCtrl,
                    selectedWarehouseId: selectedWarehouseId,
                    onWarehouseSelected: onWarehouseSelected,
                  ),
                  const SizedBox(height: 12),
                  _WarehouseLocationInput(
                    controller: warehouseLocationController,
                  ),
                  const SizedBox(height: 12),
                  _QtyInput(controller: qtyController),
                  const SizedBox(height: 12),
                  _CostInput(controller: costController),
                ],
              )
              : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StockTypeDropdown(
                          selectedStockType: selectedStockType,
                          selectedProduct: selectedProduct,
                          onCalculateCost: onCalculateCost,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WarehouseDropdown(
                          productCtrl: productCtrl,
                          selectedWarehouseId: selectedWarehouseId,
                          onWarehouseSelected: onWarehouseSelected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _WarehouseLocationInput(
                          controller: warehouseLocationController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _QtyInput(controller: qtyController)),
                      const SizedBox(width: 12),
                      Expanded(child: _CostInput(controller: costController)),
                    ],
                  ),
                ],
              ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text(
                'Add to Cart',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ProductController productCtrl;
  final Rx<Product?> selectedProduct;
  final RxString selectedStockType;
  final void Function(Product?, String) onCalculateCost;

  const _Header({
    required this.productCtrl,
    required this.selectedProduct,
    required this.selectedStockType,
    required this.onCalculateCost,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _StepLabel(step: '2', title: 'Add Item to Cart')),
        ElevatedButton.icon(
          onPressed:
              () => Get.dialog(
                CreateProductInlineDialog(
                  productCtrl: productCtrl,
                  onCreated: (product) {
                    selectedProduct.value = product;
                    onCalculateCost(product, selectedStockType.value);
                  },
                ),
              ),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text(
            'New Product',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _ProductSearch extends StatelessWidget {
  final ProductController productCtrl;
  final Rx<Product?> selectedProduct;
  final RxString selectedStockType;
  final void Function(TextEditingController) onProductFieldReady;
  final void Function(Product?, String) onCalculateCost;

  const _ProductSearch({
    required this.productCtrl,
    required this.selectedProduct,
    required this.selectedStockType,
    required this.onProductFieldReady,
    required this.onCalculateCost,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (product) => '${product.model} - ${product.name}',
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const [];

        try {
          final uri = Uri.parse(
            '${ProductController.baseUrl}/products',
          ).replace(
            queryParameters: {'page': '1', 'limit': '20', 'search': query},
          );

          final res = await http.get(uri).timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final List productsJson = data['products'] ?? [];

            return productsJson
                .whereType<Map>()
                .map(
                  (item) => Product.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
          }
        } catch (e) {
          AppLogger.w('Product search fallback: $e');
        }

        final qLower = query.toLowerCase();
        final terms = qLower.split(RegExp(r'\s+'));

        return productCtrl.allProducts.where((product) {
          final combined =
              '${product.model} ${product.name} ${product.brand}'.toLowerCase();
          return terms.every((term) => combined.contains(term));
        });
      },
      onSelected: (product) {
        selectedProduct.value = product;
        onCalculateCost(product, selectedStockType.value);
      },
      fieldViewBuilder: (ctx, ctrl, focus, _) {
        onProductFieldReady(ctrl);

        return TextField(
          controller: ctrl,
          focusNode: focus,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Search product by model, name or brand',
            labelStyle: const TextStyle(fontSize: 11),
            prefixIcon: const Icon(
              Icons.inventory_2_outlined,
              color: textLight,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: bgGrey,
          ),
        );
      },
    );
  }
}

class _StockTypeDropdown extends StatelessWidget {
  final RxString selectedStockType;
  final Rx<Product?> selectedProduct;
  final void Function(Product?, String) onCalculateCost;

  const _StockTypeDropdown({
    required this.selectedStockType,
    required this.selectedProduct,
    required this.onCalculateCost,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: selectedStockType.value,
        decoration: InputDecoration(
          labelText: 'Stock Type',
          labelStyle: const TextStyle(fontSize: 11),
          prefixIcon: const Icon(Icons.category_rounded, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: const [
          DropdownMenuItem(value: 'Local', child: Text('Local')),
          DropdownMenuItem(value: 'Air', child: Text('Air')),
          DropdownMenuItem(value: 'Sea', child: Text('Sea')),
        ],
        onChanged: (value) {
          if (value == null) return;
          selectedStockType.value = value;
          onCalculateCost(selectedProduct.value, value);
        },
      ),
    );
  }
}

class _WarehouseDropdown extends StatelessWidget {
  final ProductController productCtrl;
  final RxnInt selectedWarehouseId;
  final void Function(int? warehouseId, String warehouseName)
  onWarehouseSelected;

  const _WarehouseDropdown({
    required this.productCtrl,
    required this.selectedWarehouseId,
    required this.onWarehouseSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final warehouses = productCtrl.activeWarehouses;

      if (warehouses.isEmpty) {
        return TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Warehouse',
            hintText: 'No warehouse found',
            prefixIcon: const Icon(Icons.warehouse_rounded, size: 18),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }

      final ids = warehouses.map((w) => _toInt(w['id'])).toSet();
      final selected =
          ids.contains(selectedWarehouseId.value)
              ? selectedWarehouseId.value
              : null;

      return DropdownButtonFormField<int>(
        value: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Warehouse',
          labelStyle: const TextStyle(fontSize: 11),
          prefixIcon: const Icon(Icons.warehouse_rounded, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items:
            warehouses.map((warehouse) {
              final id = _toInt(warehouse['id']);
              final name = warehouse['name']?.toString() ?? 'Warehouse $id';

              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
        onChanged: (value) {
          final warehouse = warehouses.firstWhereOrNull(
            (item) => _toInt(item['id']) == value,
          );

          onWarehouseSelected(value, warehouse?['name']?.toString() ?? '');
        },
      );
    });
  }
}

class _WarehouseLocationInput extends StatelessWidget {
  final TextEditingController controller;

  const _WarehouseLocationInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Warehouse Location',
        hintText: 'Rack A-3, Box 12',
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
        prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Unit Cost (Tk)',
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: const Icon(Icons.payments_rounded, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

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
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}