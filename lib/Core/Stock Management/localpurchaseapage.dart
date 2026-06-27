// ignore_for_file: avoid_print, deprecated_member_use, must_be_immutable
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordartmodel.dart';

// --- Professional ERP Theme Colors ---
const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF1F5F9);
const Color textDark = Color(0xFF334155);
const Color textLight = Color(0xFF94A3B8);

class SmartPurchaseScreen extends StatefulWidget {
  const SmartPurchaseScreen({super.key});

  @override
  State<SmartPurchaseScreen> createState() => _SmartPurchaseScreenState();
}

class _SmartPurchaseScreenState extends State<SmartPurchaseScreen> {
  // --- Controllers ---
  final DebatorController debtorCtrl = Get.find<DebatorController>();
  final DebtorPurchaseController purchaseCtrl = Get.put(
    DebtorPurchaseController(),
  );
  final ProductController productCtrl = Get.find<ProductController>();

  // --- Reactive States ---
  final Rx<DebtorModel?> selectedSupplier = Rx<DebtorModel?>(null);
  final Rx<Product?> selectedProduct = Rx<Product?>(null);
  final RxString selectedLocation = 'Local'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  // --- Warehouse States ---
  final Rx<Warehouse?> selectedPurchaseWarehouse = Rx<Warehouse?>(null);
  late TextEditingController warehouseLocationCtrl;

  // --- Input Controllers (Memory Safe) ---
  late TextEditingController qtyController;
  late TextEditingController costController;
  late TextEditingController noteController;
  TextEditingController? _internalSupplierCtrl;
  TextEditingController? _internalProductCtrl;

  @override
  void initState() {
    super.initState();
    qtyController = TextEditingController(text: '1');
    costController = TextEditingController();
    noteController = TextEditingController();
    warehouseLocationCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (debtorCtrl.bodies.isEmpty) debtorCtrl.loadBodies();
      if (productCtrl.allProducts.isEmpty) productCtrl.fetchProducts();
      if (productCtrl.warehouses.isEmpty) productCtrl.fetchWarehouses();
      purchaseCtrl.cartItems.clear();
    });
  }

  @override
  void dispose() {
    // CRITICAL: Prevent Memory Leaks
    qtyController.dispose();
    costController.dispose();
    noteController.dispose();
    warehouseLocationCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC: RESET PAGE
  // ==========================================
  void _resetPage() {
    selectedSupplier.value = null;
    selectedProduct.value = null;
    selectedPurchaseWarehouse.value = null;
    purchaseCtrl.cartItems.clear();
    qtyController.text = '1';
    costController.clear();
    noteController.clear();
    warehouseLocationCtrl.clear();
    _internalSupplierCtrl?.clear();
    _internalProductCtrl?.clear();
    debtorCtrl.loadBodies();
    productCtrl.fetchProducts();
    Get.snackbar(
      "Refreshed",
      "Page has been reset.",
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
      backgroundColor: darkSlate,
    );
  }

  void _calculateAutoCost(Product? p, String location) {
    if (p == null) {
      costController.clear();
      return;
    }
    double calculatedCost = 0.0;
    if (location == 'Sea') {
      calculatedCost = (p.yuan * p.currency) + (p.weight * p.shipmentTax);
    } else if (location == 'Air') {
      calculatedCost = (p.yuan * p.currency) + (p.weight * p.shipmentTaxAir);
    } else {
      calculatedCost = p.avgPurchasePrice;
    }

    costController.text = calculatedCost.toStringAsFixed(2);
  }

  void _addToCart() {
    if (selectedProduct.value == null) {
      Get.snackbar(
        "Missing Data",
        "Please select a product first",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    int qty = int.tryParse(qtyController.text) ?? 0;
    double cost = double.tryParse(costController.text) ?? 0.0;

    if (qty <= 0 || cost <= 0) {
      Get.snackbar(
        "Invalid Input",
        "Enter valid quantity and cost",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    purchaseCtrl.addToCart(
      {
        'id': selectedProduct.value!.id,
        'name': selectedProduct.value!.name,
        'model': selectedProduct.value!.model,
        if (selectedPurchaseWarehouse.value != null)
          'warehouse_id': selectedPurchaseWarehouse.value!.id,
        if (selectedPurchaseWarehouse.value != null)
          'warehouse_name': selectedPurchaseWarehouse.value!.name,
        if (warehouseLocationCtrl.text.trim().isNotEmpty)
          'warehouse_location': warehouseLocationCtrl.text.trim(),
      },
      qty,
      cost,
      selectedLocation.value,
    );

    selectedProduct.value = null;
    _internalProductCtrl?.clear();
    qtyController.text = '1';
    costController.clear();
    warehouseLocationCtrl.clear();
    // Note: selectedPurchaseWarehouse intentionally kept — usually all items
    // in one purchase go to the same warehouse.
  }

  void _finalize() async {
    if (selectedSupplier.value == null) {
      Get.snackbar(
        "Error",
        "Please select a supplier",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    if (purchaseCtrl.cartItems.isEmpty) {
      Get.snackbar(
        "Error",
        "Cart is empty",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    await purchaseCtrl.finalizePurchase(
      selectedSupplier.value!.id,
      noteController.text,
      customDate: selectedDate.value,
    );
    _resetPage();
  }

  // ==========================================
  // UI: MAIN BUILD (RESPONSIVE)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              "Smart Product Purchase",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontSize: 11,
              ),
            ),
          ],
        ),
        backgroundColor: darkSlate,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _resetPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              "Reset Page",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT PANEL: Forms & Inputs
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSupplierSection(),
                const SizedBox(height: 20),
                _buildProductAddSection(false),
              ],
            ),
          ),
        ),
        // RIGHT PANEL: Cart & Finalize
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
            child: _buildCartSection(false),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSupplierSection(),
          const SizedBox(height: 16),
          _buildProductAddSection(true),
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
            child: _buildCartSection(true),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // UI: SUPPLIER SECTION
  // ----------------------------------------------------------------
  Widget _buildSupplierSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: activeAccent,
                    child: Text(
                      "1",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Select Supplier",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed:
                    () => Get.dialog(AddSupplierDialog(debtorCtrl: debtorCtrl)),
                icon: const Icon(
                  Icons.person_add,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  "New Supplier",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkSlate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Autocomplete<DebtorModel>(
            displayStringForOption:
                (option) => "${option.name} (${option.phone})",
            optionsBuilder: (textEditingValue) async {
              String queryText = textEditingValue.text.trim();
              if (queryText.isEmpty) return const Iterable<DebtorModel>.empty();

              String qLower = queryText.toLowerCase();
              List<String> searchTerms = qLower.split(RegExp(r'\s+'));
              String primaryTerm = searchTerms.first;

              Map<String, DebtorModel> combinedResults = {};

              if (primaryTerm.isNotEmpty) {
                try {
                  var snap =
                      await debtorCtrl.db
                          .collection('debatorbody')
                          .where('searchKeywords', arrayContains: primaryTerm)
                          .limit(20)
                          .get();
                  for (var doc in snap.docs) {
                    combinedResults[doc.id] = DebtorModel.fromFirestore(doc);
                  }
                } catch (e) {
                  debugPrint("Global Search Error: $e");
                }
              }

              for (var d in debtorCtrl.bodies) {
                combinedResults[d.id] = d;
              }

              return combinedResults.values.where((d) {
                String combined =
                    "${d.name} ${d.phone} ${d.nid} ${d.address}".toLowerCase();
                for (String term in searchTerms) {
                  if (!combined.contains(term)) return false;
                }
                return true;
              });
            },
            onSelected: (selection) => selectedSupplier.value = selection,
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              _internalSupplierCtrl = controller;
              return TextField(
                style: const TextStyle(fontSize: 13),
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "Search Supplier by Name, Phone, NID...",
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.business, color: textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: bgGrey,
                ),
              );
            },
          ),
          Obx(() {
            if (selectedSupplier.value != null) {
              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: activeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Selected: ${selectedSupplier.value!.name}  |  Current Payable: ৳${selectedSupplier.value!.purchaseDue.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: activeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // UI: PRODUCT ENTRY SECTION
  // ----------------------------------------------------------------
  Widget _buildProductAddSection(bool isMobile) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: activeAccent,
                    child: Text(
                      "2",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Add Item to Cart",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed:
                    () => Get.dialog(
                      CreateProductInlineDialog(
                        productCtrl: productCtrl,
                        onCreated: (Product p) {
                          selectedProduct.value = p;
                          _internalProductCtrl?.text = "${p.model} - ${p.name}";
                          _calculateAutoCost(p, selectedLocation.value);
                        },
                      ),
                    ),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  "New Product",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Autocomplete<Product>(
            displayStringForOption:
                (option) => "${option.model} - ${option.name}",
            optionsBuilder: (textEditingValue) async {
              String queryText = textEditingValue.text.trim();
              if (queryText.isEmpty) return const Iterable<Product>.empty();

              try {
                final uri = Uri.parse(
                  '${ProductController.baseUrl}/products',
                ).replace(
                  queryParameters: {
                    'page': '1',
                    'limit': '20',
                    'search': queryText,
                  },
                );
                final res = await http.get(uri);
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  final List productsJson = data['products'] ?? [];
                  return productsJson.map((e) => Product.fromJson(e)).toList();
                }
              } catch (e) {
                AppLogger.i(e.toString());
              }

              String qLower = queryText.toLowerCase();
              List<String> searchTerms = qLower.split(RegExp(r'\s+'));
              return productCtrl.allProducts.where((p) {
                String combined =
                    "${p.model} ${p.name} ${p.brand}".toLowerCase();
                for (String term in searchTerms) {
                  if (!combined.contains(term)) return false;
                }
                return true;
              });
            },
            onSelected: (selection) {
              selectedProduct.value = selection;
              _calculateAutoCost(selection, selectedLocation.value);
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              _internalProductCtrl = controller;
              return TextField(
                style: const TextStyle(fontSize: 13),
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "Search Product by Model, Name, Brand...",
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(
                    Icons.inventory_2_outlined,
                    color: textLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: bgGrey,
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ROW 1: Location / Qty / Cost
          if (isMobile) ...[
            _buildLocationDropdown(),
            const SizedBox(height: 12),
            _buildQtyInput(),
            const SizedBox(height: 12),
            _buildCostInput(),
          ] else
            Row(
              children: [
                Expanded(child: _buildLocationDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildQtyInput()),
                const SizedBox(width: 16),
                Expanded(child: _buildCostInput()),
              ],
            ),

          const SizedBox(height: 12),

          // ROW 2: Warehouse / Location
          if (isMobile) ...[
            _buildWarehouseDropdown(),
            const SizedBox(height: 12),
            _buildWarehouseLocationInput(),
          ] else
            Row(
              children: [
                Expanded(flex: 2, child: _buildWarehouseDropdown()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildWarehouseLocationInput()),
              ],
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addToCart,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text(
                "Add to Cart",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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

  Widget _buildLocationDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: selectedLocation.value,
        decoration: InputDecoration(
          labelText: 'Purchase Location',
          labelStyle: const TextStyle(fontSize: 11),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items:
            ['Local', 'Air', 'Sea']
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
        onChanged: (val) {
          selectedLocation.value = val!;
          _calculateAutoCost(selectedProduct.value, selectedLocation.value);
        },
      ),
    );
  }

  Widget _buildQtyInput() {
    return TextField(
      controller: qtyController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Quantity',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCostInput() {
    return TextField(
      controller: costController,
      style: const TextStyle(fontSize: 13),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Unit Cost (৳)',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ----------------------------------------------------------------
  // UI: WAREHOUSE INPUTS
  // ----------------------------------------------------------------

  Widget _buildWarehouseDropdown() {
    return Obx(
      () => DropdownButtonFormField<Warehouse?>(
        value: selectedPurchaseWarehouse.value,
        decoration: InputDecoration(
          labelText: 'Warehouse (Optional)',
          labelStyle: const TextStyle(fontSize: 11),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.warehouse_outlined, color: textLight),
        ),
        items: [
          const DropdownMenuItem<Warehouse?>(
            value: null,
            child: Text(
              'No Warehouse',
              style: TextStyle(fontSize: 13, color: textLight),
            ),
          ),
          ...productCtrl.activeWarehouses.map(
            (w) => DropdownMenuItem<Warehouse?>(
              value: w,
              child: Text(w.name, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
        onChanged: (val) => selectedPurchaseWarehouse.value = val,
      ),
    );
  }

  Widget _buildWarehouseLocationInput() {
    return TextField(
      controller: warehouseLocationCtrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Shelf / Location (Optional)',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.pin_drop_outlined, color: textLight),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ----------------------------------------------------------------
  // UI: CART & CHECKOUT SECTION
  // ----------------------------------------------------------------
  Widget _buildCartSection(bool isMobile) {
    Widget cartList = Obx(() {
      if (purchaseCtrl.cartItems.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_shopping_cart,
                  size: 60,
                  color: Colors.black12,
                ),
                SizedBox(height: 16),
                Text(
                  "Cart is currently empty",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        shrinkWrap: isMobile,
        physics:
            isMobile
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
        itemCount: purchaseCtrl.cartItems.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var item = purchaseCtrl.cartItems[index];
          final hasWarehouse = item.containsKey('warehouse_name');
          final hasLocation = item.containsKey('warehouse_location');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${item['model']} - ${item['name']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Loc: ${item['location']} | Cost: ৳${item['cost']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (hasWarehouse) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.warehouse_outlined,
                              size: 11,
                              color: activeAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item['warehouse_name'],
                              style: const TextStyle(
                                color: activeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hasLocation) ...[
                              const Text(
                                " · ",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              const Icon(
                                Icons.pin_drop_outlined,
                                size: 11,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item['warehouse_location'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "${item['qty']}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "৳${item['subtotal']}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => purchaseCtrl.cartItems.removeAt(index),
                  splashRadius: 20,
                ),
              ],
            ),
          );
        },
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: darkSlate,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                "Purchase Cart Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: bgGrey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  "Item",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Qty",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Subtotal",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
        ),
        const Divider(height: 1),

        // Responsive List Wrapper
        isMobile ? cartList : Expanded(child: cartList),

        const Divider(height: 1, thickness: 1),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Grand Total",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Obx(() {
                    double grandTotal = purchaseCtrl.cartItems.fold(
                      0.0,
                      (sum, item) => sum + item['subtotal'],
                    );
                    return Text(
                      "৳${grandTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: activeAccent,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(fontSize: 13),
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Purchase Note / Invoice No. (Optional)',
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(
                    Icons.note_alt_outlined,
                    color: textLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: bgGrey,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: purchaseCtrl.isLoading.value ? null : _finalize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        purchaseCtrl.isLoading.value
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              "Finalize & Post Purchase",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MEMORY SAFE STATEFUL DIALOGS
// ============================================================================

class AddSupplierDialog extends StatefulWidget {
  final DebatorController debtorCtrl;
  const AddSupplierDialog({super.key, required this.debtorCtrl});

  @override
  State<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  late TextEditingController nameC, shopC, nidC, phoneC, addressC;
  final RxList<Map<String, dynamic>> payments = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    shopC = TextEditingController();
    nidC = TextEditingController();
    phoneC = TextEditingController();
    addressC = TextEditingController();
    addPaymentForm();
  }

  void addPaymentForm() {
    payments.add({
      "type": "cash".obs,
      "bkash": TextEditingController(),
      "nagad": TextEditingController(),
      "bankName": TextEditingController(),
      "bankAcc": TextEditingController(),
      "bankBranch": TextEditingController(),
    });
  }

  @override
  void dispose() {
    nameC.dispose();
    shopC.dispose();
    nidC.dispose();
    phoneC.dispose();
    addressC.dispose();
    for (var p in payments) {
      (p["bkash"] as TextEditingController).dispose();
      (p["nagad"] as TextEditingController).dispose();
      (p["bankName"] as TextEditingController).dispose();
      (p["bankAcc"] as TextEditingController).dispose();
      (p["bankBranch"] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.userPlus,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "Register New Supplier",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "IDENTITY INFORMATION",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeAccent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            nameC,
                            "Full Name",
                            Icons.person,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogField(
                            shopC,
                            "Company/Shop",
                            Icons.store,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            nidC,
                            "NID / Trade Lic.",
                            Icons.badge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogField(
                            phoneC,
                            "Phone Number",
                            Icons.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      addressC,
                      "Permanent Address",
                      Icons.location_on,
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PAYMENT METHODS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeAccent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: addPaymentForm,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add Method"),
                          style: TextButton.styleFrom(
                            foregroundColor: activeAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => Column(
                        children: List.generate(payments.length, (index) {
                          var p = payments[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: bgGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  visualDensity: VisualDensity.compact,
                                  leading: const Icon(
                                    Icons.payments,
                                    color: activeAccent,
                                    size: 20,
                                  ),
                                  title: Obx(
                                    () => DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: p["type"].value,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: darkSlate,
                                          fontSize: 13,
                                        ),
                                        items:
                                            ["cash", "bkash", "nagad", "bank"]
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(
                                                      e.toUpperCase(),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) => p["type"].value = v!,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () => payments.removeAt(index),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  child: Obx(() {
                                    final type = p["type"].value;
                                    if (type == "cash") {
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Cash Payment enabled",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (type == "bkash" ||
                                        type == "nagad") {
                                      return _buildDialogField(
                                        p[type],
                                        "${type.toUpperCase()} Account Number",
                                        Icons.phone_android,
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          _buildDialogField(
                                            p["bankName"],
                                            "Bank Name",
                                            Icons.account_balance,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildDialogField(
                                            p["bankAcc"],
                                            "Account Number",
                                            Icons.numbers,
                                          ),
                                        ],
                                      );
                                    }
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: bgGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Obx(
                    () => ElevatedButton(
                      onPressed:
                          widget.debtorCtrl.isAddingBody.value
                              ? null
                              : _saveSupplier,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          widget.debtorCtrl.isAddingBody.value
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                "Confirm & Save",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSupplier() async {
    if (nameC.text.isEmpty || phoneC.text.isEmpty || shopC.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Required fields are missing",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    final finalPayments = <Map<String, dynamic>>[];
    for (var p in payments) {
      final type = p["type"].value;
      if (type == "cash") {
        finalPayments.add({"type": "cash", "currency": "BDT"});
      } else if (type == "bkash" || type == "nagad") {
        finalPayments.add({"type": type, "number": p[type].text});
      } else if (type == "bank") {
        finalPayments.add({
          "type": "bank",
          "bankName": p["bankName"].text,
          "accountNumber": p["bankAcc"].text,
          "branch": p["bankBranch"].text,
        });
      }
    }

    await widget.debtorCtrl.addBody(
      name: nameC.text,
      des: shopC.text,
      nid: nidC.text,
      phone: phoneC.text,
      address: addressC.text,
      payments: finalPayments,
    );
    Get.back();
    Get.snackbar(
      "Success",
      "Supplier Created Successfully.",
      backgroundColor: darkSlate,
      colorText: Colors.white,
    );
  }

  Widget _buildDialogField(
    TextEditingController c,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
        filled: true,
        fillColor: bgGrey,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}

class CreateProductInlineDialog extends StatefulWidget {
  final ProductController productCtrl;
  final Function(Product) onCreated;
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
  late TextEditingController nameC,
      modelC,
      brandC,
      catC,
      yuanC,
      weightC,
      seaTaxC,
      airTaxC,
      agentC,
      wholesaleC;

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
    nameC.dispose();
    modelC.dispose();
    brandC.dispose();
    catC.dispose();
    yuanC.dispose();
    weightC.dispose();
    seaTaxC.dispose();
    airTaxC.dispose();
    agentC.dispose();
    wholesaleC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Create New Product",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: darkSlate,
          fontSize: 13,
        ),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Basic Info",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activeAccent,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildProductField("Model", modelC)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildProductField("Name", nameC)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildProductField("Brand", brandC)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildProductField("Category", catC)),
                ],
              ),
              const Divider(height: 30),

              const Text(
                "RMB & Shipping Data",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activeAccent,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildProductField(
                      "RMB (Yuan)",
                      yuanC,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProductField(
                      "Weight (KG)",
                      weightC,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildProductField(
                      "Sea Tax",
                      seaTaxC,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProductField(
                      "Air Tax",
                      airTaxC,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),

              const Text(
                "Selling Prices",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activeAccent,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildProductField(
                      "Agent Price",
                      agentC,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProductField(
                      "Wholesale Price",
                      wholesaleC,
                      isNumber: true,
                    ),
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
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Obx(
          () => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed:
                widget.productCtrl.isActionLoading.value ? null : _saveProduct,
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
                      "Create & Select",
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
          ),
        ),
      ],
    );
  }

  void _saveProduct() async {
    if (modelC.text.isEmpty || nameC.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Model and Name are required",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    Map<String, dynamic> newProductData = {
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

    int? newId = await widget.productCtrl.createProductReturnId(newProductData);
    if (newId != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      Product tempProd = Product.fromJson({...newProductData, 'id': newId});
      widget.onCreated(tempProd);
      Get.back();
      Get.snackbar(
        "Success",
        "Product Created & Selected",
        backgroundColor: darkSlate,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildProductField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      controller: ctrl,
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
