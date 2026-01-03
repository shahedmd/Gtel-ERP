import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'model.dart'; // Ensure this path is correct

class ProductController extends GetxController {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  final RxList<Product> allProducts = <Product>[].obs;

  // Filters
  final RxString selectedBrand = 'All'.obs;
  final RxString searchText = ''.obs;

  // Loading States
  final RxBool isLoading = false.obs;
  final RxBool isActionLoading =
      false.obs; // Unified loading for Create/Update/Stock

  // Global Settings
  final RxDouble currentCurrency = 17.85.obs; // BDT to CNY Rate

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt pageSize = 20.obs;
  final RxInt totalProducts = 0.obs;

  // Configuration
  static const baseUrl = 'https://dart-server-1zun.onrender.com';
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  // ==========================================
  // 1. FETCH PRODUCTS (READ)
  // ==========================================
  Future<void> fetchProducts({int? page}) async {
    // Only show loading if it's a full refresh or search, not pagination if prefer lazy loading
    isLoading.value = true;

    try {
      final current = page ?? currentPage.value;

      // Building Query Parameters cleanly
      final queryParams = {
        'page': current.toString(),
        'limit': pageSize.value.toString(),
        'search': searchText.value,
        'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
      };

      final uri = Uri.parse(
        '$baseUrl/products',
      ).replace(queryParameters: queryParams);

      final res = await http.get(uri).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);

        final List<dynamic> productsJson = data['products'] ?? [];

        // Safety: Ensure JSON map is valid before parsing
        final List<Product> loadedProducts =
            productsJson.map<Product>((e) => Product.fromJson(e)).toList();

        allProducts.assignAll(loadedProducts);

        // Safety: Handle dynamic types for total count
        var totalRaw = data['total'];
        totalProducts.value = int.tryParse(totalRaw.toString()) ?? 0;
      } else {
        _showError('Server Error: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 2. SEARCH & FILTER LOGIC
  // ==========================================
  void search(String text) {
    if (searchText.value == text) return; // Prevent duplicate calls
    searchText.value = text;
    currentPage.value = 1;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      fetchProducts();
    });
  }

  void selectBrand(String brand) {
    if (selectedBrand.value == brand) return;
    selectedBrand.value = brand;
    currentPage.value = 1;
    fetchProducts();
  }

  // ==========================================
  // 3. STOCK MANAGEMENT (CRITICAL LOGIC)
  // ==========================================

  /// Adds stock (Sea/Air/Local) and refreshes WAC from server.
  ///
  /// [productId]: The DB ID of the product
  /// [seaQty]: Quantity arriving via Sea
  /// [airQty]: Quantity arriving via Air
  /// [localQty]: Quantity bought locally
  /// [localUnitPrice]: The buying price (Unit Price) in BDT for local goods
  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0.0,
  }) async {
    isActionLoading.value = true;
    try {
      // Validation: Prevent negative inventory corruption
      if (seaQty < 0 || airQty < 0 || localQty < 0) {
        _showError("Quantities cannot be negative");
        return;
      }

      final body = {
        'id': productId,
        'sea_qty': seaQty,
        'air_qty': airQty,
        'local_qty': localQty,
        // Send as double explicitly to prevent integer truncation on server
        'local_price': localUnitPrice.toDouble(),
      };

      final res = await http.post(
        Uri.parse('$baseUrl/products/add-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        // Success: Refresh list to get new calculated WAC from server
        await fetchProducts();
        Get.snackbar(
          'Stock Updated',
          'Inventory increased & Avg Price recalculated.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        _showError('Server Calculation Error: ${res.body}');
      }
    } catch (e) {
      _showError('Network Error: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// CLIENT-SIDE HELPER: Predict New WAC
  /// Use this in your UI Dialog to show the user what the new price
  /// WILL be before they save. This helps debugging.
  double predictNewWAC(Product product, int newQty, double newUnitCost) {
    double currentTotalValue = product.stockQty * product.avgPurchasePrice;
    double newStockValue = newQty * newUnitCost;

    double totalValue = currentTotalValue + newStockValue;
    int totalQty = product.stockQty + newQty;

    if (totalQty == 0) return 0.0;
    return totalValue / totalQty;
  }

  // ==========================================
  // 4. BULK OPERATIONS (Checkout)
  // ==========================================
  Future<bool> updateStockBulk(List<Map<String, dynamic>> updates) async {
    isActionLoading.value = true;
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/products/bulk-update-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'updates': updates}),
      );

      if (res.statusCode == 200) {
        // We must fetch fresh data because the server determines
        // which bucket (Sea/Air) the stock was deducted from.
        await fetchProducts();
        return true;
      } else {
        _showError("Bulk Update Failed: ${res.body}");
        return false;
      }
    } catch (e) {
      _showError("Connection Error");
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  // ==========================================
  // 5. SETTINGS (Currency)
  // ==========================================
  Future<void> updateCurrencyAndRecalculate(double newCurrency) async {
    isActionLoading.value = true;
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/products/recalculate-prices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currency': newCurrency}),
      );

      if (res.statusCode == 200) {
        currentCurrency.value = newCurrency;
        // Reset to page 1 to see changes immediately
        currentPage.value = 1;
        await fetchProducts();

        Get.snackbar(
          'Success',
          'Prices Recalculated based on Rate: $newCurrency',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        _showError('Recalculation Failed');
      }
    } catch (e) {
      _showError('Network Error');
    } finally {
      isActionLoading.value = false;
    }
  }

  // ==========================================
  // 6. CRUD (Create, Update, Delete)
  // ==========================================
  Future<void> createProduct(Map<String, dynamic> data) async {
    await _performRequest(
      () => http.post(
        Uri.parse('$baseUrl/products/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ),
      successMessage: 'Product Created',
    );
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await _performRequest(
      () => http.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ),
      successMessage: 'Product Updated',
    );
  }

  Future<void> deleteProduct(int id) async {
    await _performRequest(
      () => http.delete(Uri.parse('$baseUrl/products/$id')),
      successMessage: 'Product Deleted',
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================

  // Generic Request Handler to reduce boilerplate
  Future<void> _performRequest(
    Future<http.Response> Function() request, {
    required String successMessage,
  }) async {
    isActionLoading.value = true;
    try {
      final res = await request();
      if (res.statusCode == 200) {
        await fetchProducts();
        Get.snackbar(
          'Success',
          successMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        _showError('Operation Failed: ${res.body}');
      }
    } catch (e) {
      _showError('Network Error');
    } finally {
      isActionLoading.value = false;
    }
  }

  void _showError(String msg) {
    Get.snackbar(
      'Error',
      msg,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
    print("Error Log: $msg");
  }

  // Pagination Controls
  void goToPage(int page) {
    currentPage.value = page;
    fetchProducts();
  }

  void nextPage() {
    if ((currentPage.value * pageSize.value) < totalProducts.value) {
      currentPage.value++;
      fetchProducts();
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      fetchProducts();
    }
  }

  List<String> get brands {
    final unique = allProducts.map((e) => e.brand).toSet().toList();
    unique.sort();
    return ['All', ...unique];
  }
}
