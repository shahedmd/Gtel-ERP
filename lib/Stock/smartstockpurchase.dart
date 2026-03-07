// ignore_for_file: avoid_print, deprecated_member_use, must_be_immutable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// Make sure your imports match your project structure
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/model.dart';

// --- Professional ERP Theme Colors ---
const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF1F5F9);
const Color textDark = Color(0xFF334155);
const Color textLight = Color(0xFF94A3B8);

class SmartPurchaseScreen extends StatelessWidget {
  SmartPurchaseScreen({super.key}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (debtorCtrl.bodies.isEmpty) debtorCtrl.loadBodies();
      if (productCtrl.allProducts.isEmpty) productCtrl.fetchProducts();
      purchaseCtrl.cartItems.clear();
    });
  }

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

  // --- Input Controllers ---
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // Internal references to securely clear Autocomplete fields
  TextEditingController? _internalSupplierCtrl;
  TextEditingController? _internalProductCtrl;

  // ==========================================
  // LOGIC: RESET PAGE
  // ==========================================
  void _resetPage() {
    selectedSupplier.value = null;
    selectedProduct.value = null;
    purchaseCtrl.cartItems.clear();
    qtyController.text = '1';
    costController.clear();
    noteController.clear();
    _internalSupplierCtrl?.clear();
    _internalProductCtrl?.clear();

    // Refresh background data
    debtorCtrl.loadBodies();
    productCtrl.fetchProducts();
    Get.snackbar(
      "Refreshed",
      "Page has been reset to default state.",
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
      },
      qty,
      cost,
      selectedLocation.value,
    );

    // Form Reset After Add (Automatically clears product textfield)
    selectedProduct.value = null;
    _internalProductCtrl?.clear();
    qtyController.text = '1';
    costController.clear();
  }

  // ==========================================
  // LOGIC: FINALIZE PURCHASE
  // ==========================================
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

    // Full Reset after success
    _resetPage();
  }

  // ==========================================
  // UI: MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              "Smart Product Purchase",
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
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
                  _buildProductAddSection(),
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
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _buildCartSection(),
            ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
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
                onPressed: () => _addDebtorDialog(debtorCtrl),
                icon: const Icon(
                  Icons.person_add,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  "New Supplier",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkSlate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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

              // 1. GLOBAL SEARCH: Query Firestore directly for the first term
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
                  // Silently fallback to local list if internet/query fails
                  debugPrint("Global Search Error: $e");
                }
              }

              // 2. LOCAL SEARCH: Add currently loaded bodies just in case
              for (var d in debtorCtrl.bodies) {
                combinedResults[d.id] = d;
              }

              // 3. FILTER MATCHES: Ensure ALL search terms match the combined list
              return combinedResults.values.where((d) {
                String combined =
                    "${d.name} ${d.phone} ${d.nid} ${d.address}".toLowerCase();
                for (String term in searchTerms) {
                  if (!combined.contains(term)) return false;
                }
                return true;
              });
            },
            onSelected: (selection) {
              selectedSupplier.value = selection;
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              _internalSupplierCtrl = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "Search Supplier by Name, Phone, NID...",
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
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
  Widget _buildProductAddSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
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
                onPressed: _showCreateProductInlineDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  "New Product",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                // Fallback local search
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
              _internalProductCtrl =
                  controller; // Store reference to clear automatically
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "Search Product by Model, Name, Brand...",
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
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    value: selectedLocation.value,
                    decoration: InputDecoration(
                      labelText: 'Purchase Location',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items:
                        ['Local', 'Air', 'Sea']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (val) {
                      selectedLocation.value = val!;
                      _calculateAutoCost(
                        selectedProduct.value,
                        selectedLocation.value,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Unit Cost (৳)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
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

  // ----------------------------------------------------------------
  // UI: CART & CHECKOUT SECTION
  // ----------------------------------------------------------------
  Widget _buildCartSection() {
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

        // Header Row for Cart
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
              SizedBox(width: 40), // Space for delete icon
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Obx(() {
            if (purchaseCtrl.cartItems.isEmpty) {
              return const Center(
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
              );
            }
            return ListView.separated(
              itemCount: purchaseCtrl.cartItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var item = purchaseCtrl.cartItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
          }),
        ),

        const Divider(height: 1, thickness: 1),

        // Checkout Footer
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
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Purchase Note / Invoice No. (Optional)',
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

  // ==========================================
  // CREATE NEW DEBTOR / SUPPLIER DIALOG
  // ==========================================
  void _addDebtorDialog(DebatorController controller) {
    final nameC = TextEditingController();
    final shopC = TextEditingController();
    final nidC = TextEditingController();
    final phoneC = TextEditingController();
    final addressC = TextEditingController();

    final payments = <Map<String, dynamic>>[].obs;

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

    if (payments.isEmpty) addPaymentForm();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(
                  color: darkSlate,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(
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
              // Body
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
                                  color: Colors.black.withOpacity(0.05),
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
                                          onChanged:
                                              (v) => p["type"].value = v!,
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
                                            color: Colors.green.withOpacity(
                                              0.1,
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
                                                "Cash on Delivery / Spot Payment enabled",
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
              // Footer
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
                            controller.isAddingBody.value
                                ? null
                                : () async {
                                  if (nameC.text.isEmpty ||
                                      phoneC.text.isEmpty ||
                                      shopC.text.isEmpty) {
                                    Get.snackbar(
                                      "Error",
                                      "Required fields are missing",
                                      backgroundColor: Colors.redAccent,
                                      colorText: Colors.white,
                                    );
                                    return;
                                  }
                                  final finalPayments =
                                      <Map<String, dynamic>>[];
                                  for (var p in payments) {
                                    final type = p["type"].value;
                                    if (type == "cash") {
                                      finalPayments.add({
                                        "type": "cash",
                                        "currency": "BDT",
                                      });
                                    } else if (type == "bkash" ||
                                        type == "nagad") {
                                      finalPayments.add({
                                        "type": type,
                                        "number": p[type].text,
                                      });
                                    } else if (type == "bank") {
                                      finalPayments.add({
                                        "type": "bank",
                                        "bankName": p["bankName"].text,
                                        "accountNumber": p["bankAcc"].text,
                                        "branch": p["bankBranch"].text,
                                      });
                                    }
                                  }

                                  await controller.addBody(
                                    name: nameC.text,
                                    des: shopC.text,
                                    nid: nidC.text,
                                    phone: phoneC.text,
                                    address: addressC.text,
                                    payments: finalPayments,
                                  );

                                  Get.back(); // PERFECTLY CLOSES DIALOG
                                  Get.snackbar(
                                    "Success",
                                    "Supplier Created Successfully. You can now search for them.",
                                    backgroundColor: darkSlate,
                                    colorText: Colors.white,
                                  );
                                },
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
                            controller.isAddingBody.value
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
      ),
      barrierDismissible: false,
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

  // ==========================================
  // CREATE NEW PRODUCT DIALOG (INLINE)
  // ==========================================
  void _showCreateProductInlineDialog() {
    final nameC = TextEditingController();
    final modelC = TextEditingController();
    final brandC = TextEditingController();
    final catC = TextEditingController();
    final yuanC = TextEditingController(text: '0');
    final weightC = TextEditingController(text: '0');
    final seaTaxC = TextEditingController(text: '0');
    final airTaxC = TextEditingController(text: '0');
    final agentC = TextEditingController(text: '0');
    final wholesaleC = TextEditingController(text: '0');

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Create New Product",
          style: TextStyle(fontWeight: FontWeight.bold, color: darkSlate),
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
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
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
                  productCtrl.isActionLoading.value
                      ? null
                      : () async {
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
                          'shipmentTaxAir':
                              double.tryParse(airTaxC.text) ?? 0.0,
                          'agent': double.tryParse(agentC.text) ?? 0.0,
                          'wholesale': double.tryParse(wholesaleC.text) ?? 0.0,
                          'currency': productCtrl.currentCurrency.value,
                          'alert_qty': 5,
                          'stock_qty': 0,
                        };

                        int? newId = await productCtrl.createProductReturnId(
                          newProductData,
                        );

                        if (newId != null) {
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                          Product tempProd = Product.fromJson({
                            ...newProductData,
                            'id': newId,
                          });

                          selectedProduct.value = tempProd;
                          _internalProductCtrl?.text =
                              "${tempProd.model} - ${tempProd.name}";
                          _calculateAutoCost(tempProd, selectedLocation.value);

                          Get.back(); // PERFECTLY CLOSES DIALOG
                          Get.snackbar(
                            "Success",
                            "Product Created & Selected",
                            backgroundColor: darkSlate,
                            colorText: Colors.white,
                          );
                        } else {
                          Get.back();
                          Get.snackbar(
                            "Notice",
                            "Created but could not auto-select. Search it manually.",
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                        }
                      },
              child:
                  productCtrl.isActionLoading.value
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
                        style: TextStyle(color: Colors.white),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType:
          isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
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
