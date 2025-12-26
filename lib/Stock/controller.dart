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
  final RxDouble currentCurrency = 17.85.obs;

  // API Configuration
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

      print('[API] GET: $uri');

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
        totalProducts.value = data['total'] ?? 0;
      } else {
        Get.snackbar('Error', 'Server returned ${res.statusCode}');
      }
    } catch (e) {
      print('[ERROR] fetchProducts: $e');
      Get.snackbar('Error', 'Connection failed.');
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
        // Refresh the first page to see the new calculated prices
        await fetchProducts(page: 1);
        Get.snackbar(
          'Success',
          'AIR & SEA prices updated for all items.',
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
        Get.snackbar('Error', 'Failed to add product');
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed');
    } finally {
      isLoading.value = false;
    }
  }

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
        Get.snackbar('Success', 'Product updated');
      } else {
        Get.snackbar('Error', 'Update failed');
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
