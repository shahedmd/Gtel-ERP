import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordartmodel.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Stock%20Management/stock_model.dart';
import '../../Core/Core Utils/activity_logger.dart';
import '../stock_controller.dart';
import 'Widgets/product_cart_section.dart';
import 'Widgets/product_entry_section.dart';
import 'Widgets/supplier_section.dart';
import 'purchase_controller.dart';

const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF2563EB);
const Color bgGrey = Color(0xFFF1F5F9);
const Color textDark = Color(0xFF334155);
const Color textLight = Color(0xFF94A3B8);

class SmartPurchaseScreen extends StatelessWidget {
  SmartPurchaseScreen({super.key});

  final DebatorController _debtorCtrl = Get.find<DebatorController>();
  final DebtorPurchaseController _purchaseCtrl = Get.put(
    DebtorPurchaseController(),
  );
  final ProductController _productCtrl = Get.find<ProductController>();

  final Rx<DebtorModel?> selectedSupplier = Rx<DebtorModel?>(null);
  final Rx<Product?> selectedProduct = Rx<Product?>(null);

  final RxString selectedStockType = 'Local'.obs;
  final RxnInt selectedWarehouseId = RxnInt();
  final RxString selectedWarehouseName = ''.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController warehouseLocationController =
      TextEditingController();

  final Rx<TextEditingController?> supplierFieldCtrl =
      Rx<TextEditingController?>(null);
  final Rx<TextEditingController?> productFieldCtrl =
      Rx<TextEditingController?>(null);

  void _ensureWarehouseSelected() {
    if (selectedWarehouseId.value != null && selectedWarehouseId.value! > 0) {
      return;
    }

    final warehouses = _productCtrl.activeWarehouses;
    if (warehouses.isEmpty) return;

    final first = warehouses.first;
    final id = _toInt(first['id']);

    selectedWarehouseId.value = id > 0 ? id : null;
    selectedWarehouseName.value = first['name']?.toString() ?? '';
  }

  void resetPage() {
    selectedSupplier.value = null;
    selectedProduct.value = null;
    selectedStockType.value = 'Local';
    selectedWarehouseId.value = null;
    selectedWarehouseName.value = '';
    selectedDate.value = DateTime.now();

    _purchaseCtrl.cartItems.clear();

    qtyController.text = '1';
    costController.clear();
    noteController.clear();
    warehouseLocationController.clear();

    supplierFieldCtrl.value?.clear();
    productFieldCtrl.value?.clear();

    _debtorCtrl.loadBodies();
    _productCtrl.refreshStockData();

    _ensureWarehouseSelected();

    Get.snackbar(
      'Refreshed',
      'Purchase page has been reset.',
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
      backgroundColor: darkSlate,
    );
  }

  void calculateAutoCost(Product? product, String stockType) {
    if (product == null) {
      costController.clear();
      return;
    }

    double cost;

    switch (stockType) {
      case 'Sea':
        cost =
            (product.yuan * product.currency) +
            (product.weight * product.shipmentTax);
        break;
      case 'Air':
        cost =
            (product.yuan * product.currency) +
            (product.weight * product.shipmentTaxAir);
        break;
      default:
        cost = product.avgPurchasePrice;
    }

    costController.text = cost.toStringAsFixed(2);
  }

  void onWarehouseSelected(int? warehouseId, String warehouseName) {
    selectedWarehouseId.value = warehouseId;
    selectedWarehouseName.value = warehouseName;
  }

  void addToCart() {
    final product = selectedProduct.value;

    if (product == null) {
      Get.snackbar(
        'Missing Data',
        'Please select a product first.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
    final warehouseId = selectedWarehouseId.value;

    if (qty <= 0 || cost <= 0) {
      Get.snackbar(
        'Invalid Input',
        'Enter valid quantity and cost.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (warehouseId == null || warehouseId <= 0) {
      Get.snackbar(
        'Warehouse Required',
        'Please select a warehouse for this purchase.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    _purchaseCtrl.addToCart(
      product: {'id': product.id, 'name': product.name, 'model': product.model},
      qty: qty,
      cost: cost,
      stockType: selectedStockType.value,
      warehouseId: warehouseId,
      warehouseName: selectedWarehouseName.value,
      warehouseLocation: warehouseLocationController.text.trim(),
    );

    selectedProduct.value = null;
    productFieldCtrl.value?.clear();
    qtyController.text = '1';
    costController.clear();
    warehouseLocationController.clear();
  }

  Future<void> finalize() async {
    final supplier = selectedSupplier.value;

    if (supplier == null) {
      Get.snackbar(
        'Error',
        'Please select a supplier.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_purchaseCtrl.cartItems.isEmpty) {
      Get.snackbar(
        'Error',
        'Cart is empty.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final totalItems = _purchaseCtrl.cartItems.length;

    await _purchaseCtrl.finalizePurchase(
      supplier.id,
      noteController.text,
      customDate: selectedDate.value,
    );

    await ActivityLogger.log(
      action: 'LOCAL_PURCHASE',
      module: 'Local Purchase',
      details:
          'Supplier: ${supplier.name} | Items: $totalItems | Date: ${selectedDate.value.toLocal()}',
    );

    resetPage();
  }

  @override
  Widget build(BuildContext context) {
    _ensureWarehouseSelected();

    final isMobile = MediaQuery.of(context).size.width < 900;

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
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SupplierSection(
                  debtorCtrl: _debtorCtrl,
                  selectedSupplier: selectedSupplier,
                  onSupplierFieldReady: (ctrl) {
                    supplierFieldCtrl.value = ctrl;
                  },
                ),
                const SizedBox(height: 20),
                ProductEntrySection(
                  productCtrl: _productCtrl,
                  selectedProduct: selectedProduct,
                  selectedStockType: selectedStockType,
                  selectedWarehouseId: selectedWarehouseId,
                  warehouseLocationController: warehouseLocationController,
                  qtyController: qtyController,
                  costController: costController,
                  isMobile: false,
                  onProductFieldReady: (ctrl) {
                    productFieldCtrl.value = ctrl;
                  },
                  onCalculateCost: calculateAutoCost,
                  onWarehouseSelected: onWarehouseSelected,
                  onAddToCart: addToCart,
                ),
              ],
            ),
          ),
        ),
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
            onSupplierFieldReady: (ctrl) {
              supplierFieldCtrl.value = ctrl;
            },
          ),
          const SizedBox(height: 16),
          ProductEntrySection(
            productCtrl: _productCtrl,
            selectedProduct: selectedProduct,
            selectedStockType: selectedStockType,
            selectedWarehouseId: selectedWarehouseId,
            warehouseLocationController: warehouseLocationController,
            qtyController: qtyController,
            costController: costController,
            isMobile: true,
            onProductFieldReady: (ctrl) {
              productFieldCtrl.value = ctrl;
            },
            onCalculateCost: calculateAutoCost,
            onWarehouseSelected: onWarehouseSelected,
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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

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
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
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
