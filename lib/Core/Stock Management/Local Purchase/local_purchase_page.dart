// lib/Core/Stock Management/localpurchaseapage.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordartmodel.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';

import '../../Core Utils/activity_logger.dart';
import '../stock_controller.dart';
import 'Widgets/product_cart_section.dart';
import 'Widgets/product_entry_section.dart';
import 'Widgets/supplier_section.dart';
import 'purchase_controller.dart';

const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF1F5F9);
const Color textDark = Color(0xFF334155);
const Color textLight = Color(0xFF94A3B8);

class SmartPurchaseScreen extends StatelessWidget {
  SmartPurchaseScreen({super.key});

  // Controllers
  final DebatorController _debtorCtrl = Get.find<DebatorController>();
  final DebtorPurchaseController _purchaseCtrl = Get.put(
    DebtorPurchaseController(),
  );
  final ProductController _productCtrl = Get.find<ProductController>();

  // Page-level reactive state
  final Rx<DebtorModel?> selectedSupplier = Rx<DebtorModel?>(null);
  final Rx<Product?> selectedProduct = Rx<Product?>(null);
  final RxString selectedLocation = 'Local'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  // Input controllers
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // Internal autocomplete controllers — set by child widgets
  final Rx<TextEditingController?> supplierFieldCtrl =
      Rx<TextEditingController?>(null);
  final Rx<TextEditingController?> productFieldCtrl =
      Rx<TextEditingController?>(null);

  // ─────────────────────────────────────────────────────────────
  // Logic
  // ─────────────────────────────────────────────────────────────
  void resetPage() {
    selectedSupplier.value = null;
    selectedProduct.value = null;
    _purchaseCtrl.cartItems.clear();
    qtyController.text = '1';
    costController.clear();
    noteController.clear();
    supplierFieldCtrl.value?.clear();
    productFieldCtrl.value?.clear();
    _debtorCtrl.loadBodies();
    _productCtrl.fetchProducts();

    Get.snackbar(
      'Refreshed',
      'Page has been reset.',
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
      backgroundColor: darkSlate,
    );
  }

  void calculateAutoCost(Product? p, String location) {
    if (p == null) {
      costController.clear();
      return;
    }
    double cost;
    switch (location) {
      case 'Sea':
        cost = (p.yuan * p.currency) + (p.weight * p.shipmentTax);
        break;
      case 'Air':
        cost = (p.yuan * p.currency) + (p.weight * p.shipmentTaxAir);
        break;
      default:
        cost = p.avgPurchasePrice;
    }
    costController.text = cost.toStringAsFixed(2);
  }

  void addToCart() {
    if (selectedProduct.value == null) {
      Get.snackbar(
        'Missing Data',
        'Please select a product first',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    final qty = int.tryParse(qtyController.text) ?? 0;
    final cost = double.tryParse(costController.text) ?? 0.0;

    if (qty <= 0 || cost <= 0) {
      Get.snackbar(
        'Invalid Input',
        'Enter valid quantity and cost',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    _purchaseCtrl.addToCart(
      {
        'id': selectedProduct.value!.id,
        'name': selectedProduct.value!.name,
        'model': selectedProduct.value!.model,
      },
      qty,
      cost,
      selectedLocation.value,
    );

    selectedProduct.value = null;
    productFieldCtrl.value?.clear();
    qtyController.text = '1';
    costController.clear();
  }

  Future<void> finalize() async {
    if (selectedSupplier.value == null) {
      Get.snackbar(
        'Error',
        'Please select a supplier',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    if (_purchaseCtrl.cartItems.isEmpty) {
      Get.snackbar(
        'Error',
        'Cart is empty',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    await _purchaseCtrl.finalizePurchase(
      selectedSupplier.value!.id,
      noteController.text,
      customDate: selectedDate.value,
    );

    // Activity log
    final totalItems = _purchaseCtrl.cartItems.length;
    await ActivityLogger.log(
      action: 'LOCAL_PURCHASE',
      module: 'Local Purchase',
      details:
          'Supplier: ${selectedSupplier.value!.name} | '
          'Items: $totalItems | '
          'Date: ${selectedDate.value.toLocal()}',
    );

    resetPage();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _PurchaseAppBar(onReset: resetPage),
      body: isMobile ? _mobileLayout() : _desktopLayout(),
    );
  }

  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel — forms
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SupplierSection(
                  debtorCtrl: _debtorCtrl,
                  selectedSupplier: selectedSupplier,
                  onSupplierFieldReady:
                      (ctrl) => supplierFieldCtrl.value = ctrl,
                ),
                const SizedBox(height: 20),
                ProductEntrySection(
                  productCtrl: _productCtrl,
                  selectedProduct: selectedProduct,
                  selectedLocation: selectedLocation,
                  qtyController: qtyController,
                  costController: costController,
                  isMobile: false,
                  onProductFieldReady: (ctrl) => productFieldCtrl.value = ctrl,
                  onCalculateCost: calculateAutoCost,
                  onAddToCart: addToCart,
                ),
              ],
            ),
          ),
        ),

        // Right panel — cart
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: PurchaseCartSection(
              purchaseCtrl: _purchaseCtrl,
              noteController: noteController,
              selectedDate: selectedDate,
              isMobile: false,
              onFinalize: finalize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SupplierSection(
            debtorCtrl: _debtorCtrl,
            selectedSupplier: selectedSupplier,
            onSupplierFieldReady: (ctrl) => supplierFieldCtrl.value = ctrl,
          ),
          const SizedBox(height: 16),
          ProductEntrySection(
            productCtrl: _productCtrl,
            selectedProduct: selectedProduct,
            selectedLocation: selectedLocation,
            qtyController: qtyController,
            costController: costController,
            isMobile: true,
            onProductFieldReady: (ctrl) => productFieldCtrl.value = ctrl,
            onCalculateCost: calculateAutoCost,
            onAddToCart: addToCart,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: PurchaseCartSection(
              purchaseCtrl: _purchaseCtrl,
              noteController: noteController,
              selectedDate: selectedDate,
              isMobile: true,
              onFinalize: finalize,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AppBar
// ─────────────────────────────────────────────────────────────
class _PurchaseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onReset;

  const _PurchaseAppBar({required this.onReset});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.inventory_2, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'Smart Product Purchase',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
      backgroundColor: darkSlate,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text(
            'Reset Page',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}