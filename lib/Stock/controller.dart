import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'model.dart'; // Ensure this model supports local_qty, sea_stock_qty, air_stock_qty, shipmentTaxAir

class ProductController extends GetxController {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  final RxList<Product> allProducts = <Product>[].obs;

  // State for Service/Damage Logs
  final RxList<Map<String, dynamic>> serviceLogs = <Map<String, dynamic>>[].obs;

  // Filters
  final RxString selectedBrand = 'All'.obs;
  final RxString searchText = ''.obs;

  // Loading States
  final RxBool isLoading = false.obs;
  final RxBool isActionLoading =
      false.obs; // Unified loading for Create/Update/Stock/Service

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
    isLoading.value = true;

    try {
      final current = page ?? currentPage.value;

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

        // Parse using the updated Model
        final List<Product> loadedProducts =
            productsJson.map<Product>((e) => Product.fromJson(e)).toList();

        allProducts.assignAll(loadedProducts);

        // Handle total count
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
    if (searchText.value == text) return;
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
  // 3. STOCK MANAGEMENT (ADD STOCK)
  // ==========================================

  /// Adds stock (Sea/Air/Local) and refreshes WAC from server.
  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0.0,
  }) async {
    isActionLoading.value = true;
    try {
      if (seaQty < 0 || airQty < 0 || localQty < 0) {
        _showError("Quantities cannot be negative");
        return;
      }

      final body = {
        'id': productId,
        'sea_qty': seaQty,
        'air_qty': airQty,
        'local_qty': localQty,
        'local_price': localUnitPrice.toDouble(),
      };

      final res = await http.post(
        Uri.parse('$baseUrl/products/add-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        await fetchProducts(); // Refresh UI with server's calculation
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

  /// CLIENT-SIDE PREDICTION HELPER
  /// Matches Server Logic:
  /// Sea = Tax from DB Column (shipmentTax)
  /// Air = Tax Air from DB Column (shipmentTaxAir)
  double predictNewWAC(
    Product product,
    int addSea,
    int addAir,
    int addLocal,
    double localPrice,
  ) {
    // 1. Current Value
    double oldValue = product.stockQty * product.avgPurchasePrice;

    // 2. Incoming Value Calculation
    // Sea Cost: (Yuan * Curr) + (Weight * ShipmentTax)
    double seaUnitCost =
        (product.yuan * product.currency) +
        (product.weight * product.shipmentTax);

    // [UPDATED] Air Cost: Now uses shipmentTaxAir from DB (dynamic)
    double airUnitCost =
        (product.yuan * product.currency) +
        (product.weight * product.shipmentTaxAir);

    double newBatchValue =
        (addSea * seaUnitCost) +
        (addAir * airUnitCost) +
        (addLocal * localPrice);

    // 3. Average
    int totalNewQty = product.stockQty + addSea + addAir + addLocal;
    if (totalNewQty == 0) return 0.0;

    return (oldValue + newBatchValue) / totalNewQty;
  }

  // ==========================================
  // 4. BULK OPERATIONS (POS CHECKOUT)
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
        currentPage.value = 1;
        await fetchProducts(); // Fetch fresh data

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
  // 6. CRUD OPERATIONS
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
  // 7. SERVICE & DAMAGE MANAGEMENT
  // ==========================================

  /// Fetch Service Logs
  Future<void> fetchServiceLogs() async {
    isActionLoading.value = true;
    try {
      final res = await http.get(Uri.parse('$baseUrl/service/list'));
      if (res.statusCode == 200) {
        List<dynamic> data = jsonDecode(res.body);
        serviceLogs.assignAll(data.cast<Map<String, dynamic>>());
      } else {
        _showError('Failed to fetch logs');
      }
    } catch (e) {
      _showError('Network Error: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Add product to Service or Damage
  /// [type] should be 'service' or 'damage'
  Future<void> addToService({
    required int productId,
    required String model,
    required int qty,
    required String type,
    required double currentAvgPrice,
  }) async {
    isActionLoading.value = true;
    try {
      final body = {
        'product_id': productId,
        'model': model,
        'qty': qty,
        'type': type,
        'current_avg_price': currentAvgPrice,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/service/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        await fetchProducts(); // Stock decreased on server
        await fetchServiceLogs(); // Update log list
        Get.snackbar(
          'Success',
          'Item added to $type list',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        _showError('Failed to add to service: ${res.body}');
      }
    } catch (e) {
      _showError('Network Error: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Return product from Service (Restores stock to Local)
  Future<void> returnFromService(int logId) async {
    isActionLoading.value = true;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/service/return'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'log_id': logId}),
      );

      if (res.statusCode == 200) {
        await fetchProducts(); // Stock increased on server
        await fetchServiceLogs(); // Log status updated
        Get.snackbar(
          'Success',
          'Item returned to stock',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        _showError('Return Failed: ${res.body}');
      }
    } catch (e) {
      _showError('Network Error: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================
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
