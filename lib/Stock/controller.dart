// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'model.dart';

class ProductController extends GetxController {
  // ==========================================
  // CONFIGURATION
  // ==========================================
  static const baseUrl = 'https://dart-server-1zun.onrender.com';

  // ==========================================
  // STATE VARIABLES
  // ==========================================
  final RxList<Product> allProducts = <Product>[].obs;
  // NEW: Internal list to hold ALL data when sorting by loss
  List<Product> _masterList = [];

  final RxList<Product> shortListProducts = <Product>[].obs;
  final RxList<Map<String, dynamic>> serviceLogs = <Map<String, dynamic>>[].obs;
  final RxDouble potentialProfitTotal = 0.0.obs;

  // Statistics
  final RxDouble overallTotalValuation = 0.0.obs;
  final RxInt totalProducts = 0.obs;
  final RxInt shortlistTotal = 0.obs;

  // Filters & Settings
  final RxString selectedBrand = 'All'.obs;
  final RxString searchText = ''.obs;
  final RxDouble currentCurrency = 17.85.obs; // BDT to CNY

  // NEW: Sort State
  final RxBool sortByLoss = false.obs;

  // Loading States
  final RxBool isLoading = false.obs;
  final RxBool isActionLoading = false.obs;
  final RxBool isShortListLoading = false.obs;

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt pageSize = 20.obs;
  final RxInt shortlistPage = 1.obs;
  final RxInt shortlistLimit = 20.obs;

  // Timers
  Timer? _mainSearchDebounce;
  Timer? _shortlistSearchDebounce;

  // On Way Stock Data
  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

  // Shortlist Specific Search
  final RxString shortlistSearchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  @override
  void onClose() {
    _mainSearchDebounce?.cancel();
    _shortlistSearchDebounce?.cancel();
    super.onClose();
  }

  // =========================================================
  // 1. DATA FETCHING (Main List & Dropdowns)
  // =========================================================

  // NEW: Toggle Sort Method
  void toggleSortByLoss() {
    sortByLoss.value = !sortByLoss.value;
    currentPage.value = 1; // Reset to page 1
    fetchProducts();
  }

  Future<List<Map<String, dynamic>>> searchProductsForDropdown(
    String query,
  ) async {
    if (query.isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$baseUrl/products',
      ).replace(queryParameters: {'page': '1', 'limit': '20', 'search': query});

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List products = data['products'] ?? [];
        return products.map((e) {
          final p = Product.fromJson(e);
          return {
            'id': p.id,
            'name': p.name,
            'model': p.model,
            'buyingPrice': p.avgPurchasePrice,
          };
        }).toList();
      }
    } catch (e) {}
    return [];
  }

  Future<void> fetchProducts({int? page}) async {
    isLoading.value = true;
    try {
      final current = page ?? currentPage.value;

      // ============================================================
      // LOGIC BRANCH: IF SORTING BY LOSS, FETCH ALL DATA FIRST
      // ============================================================
      if (sortByLoss.value) {
        // We request a huge limit to ensure we get products from "Page 16"
        final queryParams = {
          'page': '1',
          'limit': '10000', // Fetch all to sort locally
          'search': searchText.value,
          'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
        };

        final uri = Uri.parse(
          '$baseUrl/products',
        ).replace(queryParameters: queryParams);

        // Increased timeout for large data fetch
        final res = await http.get(uri).timeout(const Duration(seconds: 40));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List productsJson = data['products'] ?? [];

          // 1. Parse ALL products
          _masterList = productsJson.map((e) => Product.fromJson(e)).toList();

          // 2. Sort Locally (Worst Loss First)
          // Checks both Agent and Wholesale prices.
          _masterList.sort((a, b) {
            // --- CALCULATION FOR PRODUCT A ---
            // Safety check: ensure values default to 0.0 if null
            double buyPriceA = (a.avgPurchasePrice).toDouble();
            double agentPriceA = (a.agent).toDouble();
            double wholePriceA = (a.wholesale).toDouble();

            double agentProfitA = agentPriceA - buyPriceA;
            double wholeProfitA = wholePriceA - buyPriceA;

            // Get the "worst case" for A (whichever is lower/more negative)
            double worstScenarioA =
                agentProfitA < wholeProfitA ? agentProfitA : wholeProfitA;

            // --- CALCULATION FOR PRODUCT B ---
            double buyPriceB = (b.avgPurchasePrice).toDouble();
            double agentPriceB = (b.agent).toDouble();
            double wholePriceB = (b.wholesale).toDouble();

            double agentProfitB = agentPriceB - buyPriceB;
            double wholeProfitB = wholePriceB - buyPriceB;

            // Get the "worst case" for B
            double worstScenarioB =
                agentProfitB < wholeProfitB ? agentProfitB : wholeProfitB;

            // Sort Ascending (Lowest negative numbers first)
            return worstScenarioA.compareTo(worstScenarioB);
          });

          // 3. Update Totals
          totalProducts.value = _masterList.length;
          overallTotalValuation.value =
              double.tryParse(data['total_value'].toString()) ?? 0.0;

          // 4. Slice the master list for the current view (Simulate Pagination)
          _updateLocalPagination();
        } else {
          _handleErrorResponse(res);
        }
      }
      // ============================================================
      // LOGIC BRANCH: NORMAL SERVER PAGINATION (Standard Mode)
      // ============================================================
      else {
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
          final data = jsonDecode(res.body);
          final List productsJson = data['products'] ?? [];

          allProducts.assignAll(
            productsJson.map((e) => Product.fromJson(e)).toList(),
          );
          totalProducts.value = int.tryParse(data['total'].toString()) ?? 0;
          overallTotalValuation.value =
              double.tryParse(data['total_value'].toString()) ?? 0.0;
        } else {
          _handleErrorResponse(res);
        }
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Helper to slice the big list into pages
  void _updateLocalPagination() {
    if (_masterList.isEmpty) {
      allProducts.clear();
      return;
    }
    int start = (currentPage.value - 1) * pageSize.value;
    int end = start + pageSize.value;

    // Safety checks
    if (start >= _masterList.length) start = 0;
    if (end > _masterList.length) end = _masterList.length;

    // Update the UI list with just this slice
    allProducts.assignAll(_masterList.sublist(start, end));
  }

  // ==========================================
  // 2. SHORTLIST (Low Stock)
  // ==========================================

  void searchShortlist(String query) {
    shortlistSearchText.value = query;
    if (_shortlistSearchDebounce?.isActive ?? false) {
      _shortlistSearchDebounce!.cancel();
    }
    _shortlistSearchDebounce = Timer(const Duration(milliseconds: 600), () {
      fetchShortList(page: 1);
    });
  }

  Future<void> fetchShortList({int page = 1}) async {
    isShortListLoading.value = true;
    shortlistPage.value = page;

    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': shortlistLimit.value.toString(),
        'search': shortlistSearchText.value.trim(),
      };

      final uri = Uri.parse(
        '$baseUrl/products/shortlist',
      ).replace(queryParameters: queryParams);
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final List list = data['products'] ?? [];
          shortlistTotal.value = int.tryParse(data['total'].toString()) ?? 0;
          shortListProducts.assignAll(
            list.map((e) => Product.fromJson(e)).toList(),
          );
        }
      } else {
        _handleErrorResponse(res);
      }
    } catch (e) {
      _showError('Shortlist Load Error: $e');
    } finally {
      isShortListLoading.value = false;
    }
  }

  Future<List<Product>> fetchAllShortListForExport() async {
    try {
      final uri = Uri.parse('$baseUrl/products/shortlist?all=true');
      final res = await http.get(uri).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Product.fromJson(e)).toList();
      } else {
        _handleErrorResponse(res);
      }
    } catch (e) {
      _showError('Export Failed: $e');
    }
    return [];
  }

  // ==========================================
  // 3. PRODUCT CRUD
  // ==========================================

  Future<void> createProduct(Map<String, dynamic> data) async {
    await _performAction(
      () => http.post(
        Uri.parse('$baseUrl/products/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ),
      successMsg: 'Product Created',
    );
  }

  Future<void> bulkCreateProducts(List<Map<String, dynamic>> products) async {
    await _performAction(
      () => http.post(
        Uri.parse('$baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(products),
      ),
      successMsg: '${products.length} Products Imported',
    );
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await _performAction(
      () => http.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ),
      successMsg: 'Product Updated',
    );
  }

  Future<void> deleteProduct(int id) async {
    await _performAction(
      () => http.delete(Uri.parse('$baseUrl/products/$id')),
      successMsg: 'Product Deleted',
    );
  }

  // ==========================================
  // 4. STOCK MANAGEMENT
  // ==========================================

  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0.0,
    DateTime? shipmentDate,
  }) async {
    if (seaQty < 0 || airQty < 0 || localQty < 0) {
      _showError("Quantities cannot be negative");
      return;
    }
    final Map<String, dynamic> body = {
      'id': productId,
      'sea_qty': seaQty,
      'air_qty': airQty,
      'local_qty': localQty,
      'local_price': localUnitPrice,
    };
    if (shipmentDate != null) {
      body['shipmentdate'] = shipmentDate.toIso8601String();
    }

    await _performAction(
      () => http.post(
        Uri.parse('$baseUrl/products/add-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      successMsg: 'Stock Updated',
    );
  }

  Future<bool> bulkAddStockMixed(List<Map<String, dynamic>> items) async {
    isActionLoading.value = true;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/products/bulk-add-stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(items),
      );
      if (res.statusCode == 200) {
        await fetchProducts();
        Get.snackbar(
          'Success',
          'Bulk Stock Added Successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        _handleErrorResponse(res);
        return false;
      }
    } catch (e) {
      _showError("Network Error: $e");
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  // ==========================================
  // 5. SALES / BULK UPDATE
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
        for (var update in updates) {
          int id = update['id'];
          int qtySold = update['qty'];
          int index = allProducts.indexWhere((p) => p.id == id);
          if (index != -1) {
            var product = allProducts[index];
            product.stockQty = (product.stockQty - qtySold).clamp(0, 999999);
            allProducts[index] = product;
          }
        }
        allProducts.refresh();
        return true;
      } else {
        _handleErrorResponse(res);
        return false;
      }
    } catch (e) {
      _showError("Connection Error");
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> updateCurrencyAndRecalculate(double newCurrency) async {
    await _performAction(
      () => http.put(
        Uri.parse('$baseUrl/products/recalculate-prices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currency': newCurrency}),
      ),
      successMsg: 'Currency Updated & Prices Recalculated',
      onSuccess: () => currentCurrency.value = newCurrency,
    );
  }

  // ==========================================
  // 7. SERVICE & LOGS
  // ==========================================
  Future<void> fetchServiceLogs() async {
    isActionLoading.value = true;
    try {
      final res = await http.get(Uri.parse('$baseUrl/service/list'));
      if (res.statusCode == 200) {
        List data = jsonDecode(res.body);
        serviceLogs.assignAll(data.cast<Map<String, dynamic>>());
      } else {
        _handleErrorResponse(res);
      }
    } catch (e) {
      _showError('Fetch Logs Failed: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> addToService({
    required int productId,
    required String model,
    required int qty,
    required String type,
    required double currentAvgPrice,
  }) async {
    final body = {
      'product_id': productId,
      'model': model,
      'qty': qty,
      'type': type,
      'current_avg_price': currentAvgPrice,
    };
    await _performAction(
      () => http.post(
        Uri.parse('$baseUrl/service/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      successMsg: 'Added to Service',
      onSuccess: () => fetchServiceLogs(),
    );
  }

  Future<void> returnFromService(int logId, int qty) async {
    final body = {'log_id': logId, 'qty': qty};
    await _performAction(
      () => http.post(
        Uri.parse('$baseUrl/service/return'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      successMsg: 'Returned to Stock',
      onSuccess: () => fetchServiceLogs(),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Future<void> _performAction(
    Future<http.Response> Function() action, {
    required String successMsg,
    Function? onSuccess,
  }) async {
    isActionLoading.value = true;
    try {
      final res = await action();
      if (res.statusCode == 200) {
        if (onSuccess != null) onSuccess();
        await fetchProducts();
        Get.snackbar(
          'Success',
          successMsg,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        _handleErrorResponse(res);
      }
    } catch (e) {
      _showError('Network Error: $e');
    } finally {
      isActionLoading.value = false;
    }
  }

  void _handleErrorResponse(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      String msg = body['error'] ?? 'Server Error: ${res.statusCode}';
      _showError(msg);
    } catch (_) {
      _showError('Server Error: ${res.statusCode}');
    }
  }

  void _showError(String msg) {
    Get.snackbar(
      'Error',
      msg,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  // Pagination & Search Logic (MAIN LIST)
  void search(String text) {
    if (searchText.value == text) return;
    searchText.value = text;
    currentPage.value = 1;

    if (_mainSearchDebounce?.isActive ?? false) _mainSearchDebounce!.cancel();
    _mainSearchDebounce = Timer(
      const Duration(milliseconds: 600),
      fetchProducts,
    );
  }

  void selectBrand(String brand) {
    if (selectedBrand.value == brand) return;
    selectedBrand.value = brand;
    currentPage.value = 1;
    fetchProducts();
  }

  void nextPage() {
    if ((currentPage.value * pageSize.value) < totalProducts.value) {
      currentPage.value++;
      if (sortByLoss.value) {
        _updateLocalPagination(); // Slice local list
      } else {
        fetchProducts(); // Call server
      }
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      if (sortByLoss.value) {
        _updateLocalPagination(); // Slice local list
      } else {
        fetchProducts(); // Call server
      }
    }
  }

  // Pagination (SHORTLIST)
  void nextShortlistPage() {
    if ((shortlistPage.value * shortlistLimit.value) < shortlistTotal.value) {
      fetchShortList(page: shortlistPage.value + 1);
    }
  }

  void prevShortlistPage() {
    if (shortlistPage.value > 1) {
      fetchShortList(page: shortlistPage.value - 1);
    }
  }

  // RESTORED: Brands Getter
  List<String> get brands {
    // If we are locally sorting (having fetched all), we can technically derive all brands.
    // However, to keep it simple and consistent with your old code:
    final unique = allProducts.map((e) => e.brand).toSet().toList();
    unique.sort();
    return ['All', ...unique];
  }

  String get formattedTotalValuation {
    return overallTotalValuation.value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  List<List<String>> formatForPdf(List<Product> products) {
    List<List<String>> rows = [
      ['Product Name', 'Model', 'Stock', 'On Way', 'Alert', 'Shortage'],
    ];
    for (var p in products) {
      final onWay = onWayStockMap[p.id] ?? 0;
      rows.add([
        p.name,
        p.model,
        p.stockQty.toString(),
        onWay > 0 ? onWay.toString() : '-',
        p.alertQty.toString(),
        (p.alertQty - p.stockQty).toString(),
      ]);
    }
    return rows;
  }

  // ==========================================
  // ADD THIS NEW METHOD TO ProductController
  // ==========================================
  Future<int?> createProductReturnId(Map<String, dynamic> data) async {
    isActionLoading.value = true;
    try {
      // 1. Send POST request
      final res = await http.post(
        Uri.parse('$baseUrl/products/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Refresh the main list in background so UI updates
        fetchProducts();

        final body = jsonDecode(res.body);

        // 2. ATTEMPT 1: Check if Server returned the ID directly
        if (body is Map) {
          if (body.containsKey('id')) return body['id'];
          if (body.containsKey('productId')) return body['productId'];
          if (body.containsKey('product') && body['product'] is Map) {
            return body['product']['id'];
          }
        }

        // 3. ATTEMPT 2: Fallback - Search specifically for this model via API
        // We bypass local list pagination issues by asking the server directly.
        final String model = data['model'];
        final searchUri = Uri.parse('$baseUrl/products').replace(
          queryParameters: {'page': '1', 'limit': '5', 'search': model},
        );

        final searchRes = await http.get(searchUri);
        if (searchRes.statusCode == 200) {
          final searchData = jsonDecode(searchRes.body);
          final List products = searchData['products'] ?? [];

          // Find exact match on model
          final match = products.firstWhere(
            (p) => p['model'].toString().toLowerCase() == model.toLowerCase(),
            orElse: () => null,
          );

          if (match != null) {
            return match['id'];
          }
        }
      } else {
        _handleErrorResponse(res);
      }
    } catch (e) {
      _showError('Creation Failed: $e');
    } finally {
      isActionLoading.value = false;
    }
    return null; // ID not found
  }
}
