import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/controller.dart';
import '../Stock/model.dart';
import '../Web Screen/Debator Finance/debatorcontroller.dart';
import 'pdf.dart';

class PurchaseController extends GetxController {
  // --------------------
  // Dependencies
  // --------------------
  final debatorC = Get.find<DebatorController>();
  final productC = Get.find<ProductController>();

  // Your Server Base URL
  static const baseUrl = 'https://dart-server-1zun.onrender.com';

  // --------------------
  // Vendor section
  // --------------------
  final phoneC = TextEditingController();
  final vendorNameC = TextEditingController();
  final shopNameC = TextEditingController();

  RxBool vendorExists = false.obs;
  RxString vendorId = ''.obs;
  RxBool isSearchingVendor = false.obs;
  RxBool isProcessing = false.obs; // To show loading during checkout

  /// Search vendor by phone from the Debator list
/// Search vendor by phone from the upgraded Debtor list
  void searchVendorByPhone(String phone) {
    // Basic guard: don't search for very short strings
    if (phone.length < 6) return;

    isSearchingVendor.value = true;

    try {
      // Accessing bodies as a List of DebtorModel
      final match = debatorC.bodies.firstWhereOrNull((d) => d.phone == phone);

      if (match != null) {
        vendorExists.value = true;
        vendorId.value = match.id; // Model ID is already a String

        // Update controllers with Model properties
        vendorNameC.text = match.name;
        shopNameC.text = match.des; // In your model, 'des' stores the shop/designation
        
        // Optional: Show a small success feedback
        // Get.snackbar("Match Found", "Vendor ${match.name} recognized", 
        //    snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.withOpacity(0.7));
      } else {
        vendorExists.value = false;
        vendorId.value = '';
        vendorNameC.clear();
        shopNameC.clear();
      }
    } catch (e) {
      debugPrint("Error searching vendor: $e");
    } finally {
      isSearchingVendor.value = false;
    }
  }

  // --------------------
  // Cart logic
  // --------------------
  RxList<PurchaseItem> cart = <PurchaseItem>[].obs;

  void addProduct(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);

    if (index == -1) {
      cart.add(PurchaseItem(product: product, qty: 1.obs));
    } else {
      cart[index].qty.value++;
    }
  }

  void increaseQty(PurchaseItem item) {
    item.qty.value++;
  }

  void decreaseQty(PurchaseItem item) {
    if (item.qty.value > 1) {
      item.qty.value--;
    }
  }

  void removeItem(PurchaseItem item) {
    cart.remove(item);
  }

  void clearAll() {
    phoneC.clear();
    vendorNameC.clear();
    shopNameC.clear();
    cart.clear();
    vendorExists.value = false;
    vendorId.value = '';
    isProcessing.value = false;
  }

  // --------------------
  // PHASE 2: COMPLETE PURCHASE
  // --------------------
  Future<void> completePurchase() async {
    // Validations
    if (vendorId.value.isEmpty) {
      Get.snackbar('Error', 'Please select or search for a vendor first',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (cart.isEmpty) {
      Get.snackbar('Cart Empty', 'Please add at least one product to the cart',
          backgroundColor: Colors.orange);
      return;
    }

    isProcessing.value = true;

    try {
      // 1. Update Product Stock on Server
      for (var item in cart) {
        final p = item.product;
        // Logic: Add current stock + newly purchased qty
        final newStock = p.stockQty + item.qty.value;

        final updatedData = {
          'name': p.name,
          'category': p.category,
          'brand': p.brand,
          'model': p.model,
          'weight': p.weight,
          'yuan': p.yuan,
          'air': p.air,
          'sea': p.sea,
          'agent': p.agent,
          'wholesale': p.wholesale,
          'shipmentTax': p.shipmentTax,
          'shipmentNo': p.shipmentNo,
          'currency': p.currency,
          'stock_qty': newStock,
        };

        // Send update request to server
        // Using the existing updateProduct method from ProductController for consistency
        await productC.updateProduct(p.id, updatedData);
      }

      // 2. Calculate total transaction amount
      // Using 'agent' price as the cost of purchase for accounting
      final totalAmount = cart.fold<double>(
        0,
        (sum, item) => sum + (item.qty.value * item.product.sea),
      );

      // 3. Add single debit transaction for vendor
      await debatorC.addTransactionFORpurchase(
        vendorId.value,
        totalAmount,
        "Stock Purchase: ${cart.length} unique items",
        DateTime.now(),
      );

      // 4. Refresh the main product list to show new stock numbers
      await productC.fetchProducts();

      // 5. Generate and preview PDF
      await PurchasePdf.createAndPreview(c: this);

      // 6. Cleanup
      Get.snackbar('Success', 'Purchase completed, Stock updated, and Transaction recorded',
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
     
      clearAll();

    } catch (e) {
      print('[ERROR] Purchase processing failed: $e');
      Get.snackbar('System Error', 'Failed to complete purchase. Check server status.',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isProcessing.value = false;
    }
  }
}

// --------------------
// Purchase item model
// --------------------
class PurchaseItem {
  final Product product;
  final RxInt qty;

  PurchaseItem({required this.product, required this.qty});
}