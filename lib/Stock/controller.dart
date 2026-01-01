import 'dart:convert';
import 'dart:async'; // Required for Timer (Debouncing)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'model.dart';

class ProductController extends GetxController {
  // Observables for data
  final RxList<Product> allProducts = <Product>[].obs;

  // Observables for state
  final RxString selectedBrand = 'All'.obs;
  final RxString searchText = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isEditingLoading = false.obs;
  final RxBool isLoadingstock = false.obs;
  final RxDouble currentCurrency = 17.85.obs;

  // API Configuration
  // Ensure this URL is correct. Note: Render sleeps, so first request might be slow.
  static const baseUrl = 'https://dart-server-1zun.onrender.com';

  // Pagination Observables
  final RxInt currentPage = 1.obs;
  final RxInt pageSize = 20.obs;
  final RxInt totalProducts = 0.obs;

  // Timer for search debouncing (Crucial for fixing Postgres 42P05 error)
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  // ==========================================
  // FETCH PRODUCTS (GET)
  // Handles all 18 fields via the Product.fromJson
  // ==========================================
  Future<void> fetchProducts({int? page}) async {
    isLoading.value = true;
    try {
      final current = page ?? currentPage.value;

      final uri = Uri.parse('$baseUrl/products').replace(
        queryParameters: {
          'page': current.toString(),
          'limit': pageSize.value.toString(),
          'search': searchText.value,
          'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
        },
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);

        // 1. Get the raw list
        final List<dynamic> productsJson = data['products'] ?? [];

        // 2. Map JSON to Product objects with explicit typing
        final List<Product> loadedProducts =
            productsJson.map<Product>((e) => Product.fromJson(e)).toList();

        // 3. Assign to your RxList
        allProducts.assignAll(loadedProducts);

        // 4. Handle total count (Now expects a standard int from server ::int fix)
        var totalRaw = data['total'];
        if (totalRaw is String) {
          totalProducts.value = int.tryParse(totalRaw) ?? 0;
        } else {
          totalProducts.value = totalRaw ?? 0;
        }
      } else {
        // If server returns 500, we catch it here
        Get.snackbar(
          'Server Error ${res.statusCode}',
          'Check server logs. Database column mismatch or BigInt issue.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("Fetch Error: $e");
      Get.snackbar('Error', 'Connection failed or JSON parsing error.');
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // SEARCH WITH DEBOUNCE
  // ==========================================
  void search(String text) {
    searchText.value = text;
    currentPage.value = 1; // Always reset to page 1 when searching

    // Cancel existing timer if user is still typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Wait 500ms after last keystroke before hitting the server
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchProducts();
    });
  }

  // ==========================================
  // BRAND FILTER
  // ==========================================
  void selectBrand(String brand) {
    selectedBrand.value = brand;
    currentPage.value = 1; // Reset to page 1
    fetchProducts();
  }

  // ==========================================
  // UPDATE CURRENCY & RECALCULATE (BULK)
  // Re-values inventory for imports based on credit model
  // ==========================================
  Future<void> updateCurrencyAndRecalculate(double newCurrency) async {
    try {
      isLoading.value = true;
      final res = await http.put(
        Uri.parse('$baseUrl/products/recalculate-prices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currency': newCurrency}),
      );

      if (res.statusCode == 200) {
        currentCurrency.value = newCurrency;
        // Refresh the first page to see the new calculated prices and purchase rates
        await fetchProducts(page: 1);
        Get.snackbar(
          'Success',
          'Currency updated. Stock values re-calculated based on today\'s rate.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar('Error', 'Failed to recalculate: ${res.body}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error');
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // CRUD OPERATIONS
  // ==========================================

  // NOTE: 'data' must contain all 18 fields to avoid null errors on server
  Future<void> createProduct(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      final res = await http.post(
        Uri.parse('$baseUrl/products/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        await fetchProducts();
        Get.snackbar('Success', 'Product added successfully');
      } else {
        Get.snackbar('Error', 'Failed to add: ${res.body}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed');
    } finally {
      isLoading.value = false;
    }
  }

  // NOTE: 'data' must contain all 18 fields because server overwrites everything
  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      isEditingLoading.value = true;
      final res = await http.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        await fetchProducts();
        Get.snackbar('Success', 'Product updated fully');
      } else {
        Get.snackbar('Error', 'Update failed: ${res.body}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error during update');
    } finally {
      isEditingLoading.value = false;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      isLoading.value = true;
      final res = await http.delete(Uri.parse('$baseUrl/products/$id'));

      if (res.statusCode == 200) {
        await fetchProducts();
        Get.snackbar('Deleted', 'Product removed successfully');
      } else {
        Get.snackbar('Error', 'Delete request failed');
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error');
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // NEW: ADD MIXED STOCK (Shipment Intake)
  // Handles Sea, Air, and Local quantities + WAC calculation
  // ==========================================
  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localPrice = 0.0,
  }) async {
    try {
      isLoadingstock.value = true;
      final res = await http.post(
        Uri.parse('$baseUrl/products/add-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': productId,
          'sea_qty': seaQty,
          'air_qty': airQty,
          'local_qty': localQty,
          'local_price': localPrice,
        }),
      );

      if (res.statusCode == 200) {
        await fetchProducts(); // Refresh to see updated WAC and stock levels
        Get.snackbar(
          'Success',
          'Stock Added. Average Purchase Price recalculated.',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        print(res.body);
        Get.snackbar('Error', 'Failed to update stock: ${res.body}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed');
    } finally {
      isLoadingstock.value = false;
    }
  }

  // ==========================================
  // BULK UPDATE STOCK (POS CHECKOUT)
  // Uses server-side FIFO logic (Sea stock first)
  // ==========================================
  Future<bool> updateStockBulk(List<Map<String, dynamic>> updates) async {
    try {
      isLoadingstock.value = true;

      final response = await http.put(
        Uri.parse('$baseUrl/products/bulk-update-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'updates': updates}),
      );

      if (response.statusCode == 200) {
        // Since the server performs complex deduction logic between Sea/Air buckets,
        // we refresh the list from the server to ensure Flutter matches the DB exactly.
        await fetchProducts();
        return true;
      } else {
        Get.snackbar(
          "Server Error",
          "Failed to update stock: ${response.body}",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        "Network Error",
        "Check your internet connection",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoadingstock.value = false;
    }
  }

  // ==========================================
  // PAGINATION HELPERS
  // ==========================================
  void goToPage(int page) {
    currentPage.value = page;
    fetchProducts(page: page);
  }

  void nextPage() {
    if ((currentPage.value * pageSize.value) < totalProducts.value) {
      currentPage.value += 1;
      fetchProducts();
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value -= 1;
      fetchProducts();
    }
  }

  // Get list of unique brands currently visible for the dropdown
  List<String> get brands {
    final uniqueBrands = allProducts.map((e) => e.brand).toSet().toList();
    uniqueBrands.sort();
    if (!uniqueBrands.contains('All')) return ['All', ...uniqueBrands];
    return uniqueBrands;
  }

  @override
  void onClose() {
    _debounce?.cancel(); // Important: cancel timer when controller dies
    super.onClose();
  }
}
