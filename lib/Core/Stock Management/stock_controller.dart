import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'stockproductmodel.dart';

class ProductController extends GetxController {
  static const baseUrl = 'https://dart-server-1zun.onrender.com';
  static const _timeout = Duration(seconds: 15);

  // ── Observable state ────────────────────────────────────────
  final allProducts           = <Product>[].obs;
  final shortListProducts     = <Product>[].obs;
  final serviceLogs           = <Map<String, dynamic>>[].obs;
  final brandOptions          = <String>[].obs; // ← replaces broken `brands` getter

  final overallTotalValuation = 0.0.obs;
  final totalProducts         = 0.obs;
  final shortlistTotal        = 0.obs;

  final selectedBrand         = 'All'.obs;
  final searchText            = ''.obs;
  final shortlistSearchText   = ''.obs;
  final currentCurrency       = 17.85.obs;
  final sortByLoss            = false.obs;

  // ── Loaders ─────────────────────────────────────────────────
  final isLoading             = false.obs;
  final isActionLoading       = false.obs;
  final isShortListLoading    = false.obs;

  // ── Pagination ───────────────────────────────────────────────
  final currentPage     = 1.obs;
  final pageSize        = 20.obs;
  final shortlistPage   = 1.obs;
  final shortlistLimit  = 20.obs;

  Timer? _searchDebounce;
  Timer? _shortlistDebounce;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    _fetchBrands();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _shortlistDebounce?.cancel();
    super.onClose();
  }

  // ── Low-level HTTP (all methods have a timeout) ──────────────
  Future<Map<String, dynamic>?> _apiCall(
    String endpoint, {
    String method = 'GET',
    dynamic body,
    Map<String, String>? queryParams,
    bool throwError = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint')
          .replace(queryParameters: queryParams);
      final headers = {'Content-Type': 'application/json'};

      final http.Response res;
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          res = await http
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(_timeout);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map<String, dynamic>
            ? decoded
            : {'data': decoded};
      }

      final msg = (jsonDecode(res.body) as Map?)?['error']
              as String? ??
          'Server error ${res.statusCode}';
      if (throwError) throw msg;
      _showError(msg);
    } on TimeoutException {
      const msg = 'Request timed out. Please try again.';
      if (throwError) throw msg;
      _showError(msg);
    } catch (e) {
      final msg = 'Connection error: $e';
      if (throwError) throw msg;
      _showError(msg);
    }
    return null;
  }

  void _showError(String msg) => Get.snackbar(
    'Error',
    msg,
    backgroundColor: Colors.redAccent,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
  );

  // ── Brands (fetched independently — not from paginated list) ──
  Future<void> _fetchBrands() async {
    final data = await _apiCall('/products/brands');
    if (data != null) {
      final raw = (data['brands'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      raw.sort();
      brandOptions.assignAll(['All', ...raw]);
    }
  }

  // ── Products ─────────────────────────────────────────────────
  void toggleSortByLoss() {
    sortByLoss.value = !sortByLoss.value;
    currentPage.value = 1;
    fetchProducts();
  }

  Future<void> fetchProducts({int? page}) async {
    // Guard: skip if a fetch is already in progress
    if (isLoading.value) return;
    isLoading.value = true;

    final current = page ?? currentPage.value;
    currentPage.value = current;

    final data = await _apiCall(
      '/products',
      queryParams: {
        'page': current.toString(),
        'limit': pageSize.value.toString(),
        'search': searchText.value,
        'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
        if (sortByLoss.value) 'sort': 'loss',
      },
    );

    if (data != null) {
      allProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      totalProducts.value = int.tryParse(data['total'].toString()) ?? 0;
      overallTotalValuation.value =
          double.tryParse(data['total_value'].toString()) ?? 0.0;
    }

    isLoading.value = false;
  }

  // ── Search & pagination ────────────────────────────────────────
  void search(String text) {
    if (searchText.value == text) return;
    searchText.value = text;
    currentPage.value = 1;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
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
    if (currentPage.value * pageSize.value < totalProducts.value) {
      fetchProducts(page: currentPage.value + 1);
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      fetchProducts(page: currentPage.value - 1);
    }
  }

  // ── Shortlist ─────────────────────────────────────────────────
  void searchShortlist(String query) {
    shortlistSearchText.value = query;
    _shortlistDebounce?.cancel();
    _shortlistDebounce = Timer(
      const Duration(milliseconds: 600),
      () => fetchShortList(page: 1),
    );
  }

  Future<void> fetchShortList({int page = 1}) async {
    isShortListLoading.value = true;
    shortlistPage.value = page;

    final data = await _apiCall(
      '/products/shortlist',
      queryParams: {
        'page': page.toString(),
        'limit': shortlistLimit.value.toString(),
        'search': shortlistSearchText.value.trim(),
      },
    );

    if (data != null) {
      // Use consistent 'products' key
      shortListProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      shortlistTotal.value = int.tryParse(data['total'].toString()) ?? 0;
    }
    isShortListLoading.value = false;
  }

  // Fixed: consistent key ('products') and no page limit for export
  Future<List<Product>> fetchAllShortListForExport() async {
    final data = await _apiCall(
      '/products/shortlist',
      queryParams: {'all': 'true'},
    );
    return data != null
        ? (data['products'] as List).map((e) => Product.fromJson(e)).toList()
        : [];
  }

  void nextShortlistPage() {
    if (shortlistPage.value * shortlistLimit.value < shortlistTotal.value) {
      fetchShortList(page: shortlistPage.value + 1);
    }
  }

  void prevShortlistPage() {
    if (shortlistPage.value > 1) {
      fetchShortList(page: shortlistPage.value - 1);
    }
  }

  // ── CRUD wrappers ──────────────────────────────────────────────
  /// [refreshProducts] — set false for service/shortlist ops that don't
  /// need to reload the main product list.
  Future<bool> _runAction(
    String endpoint,
    String method,
    Map<String, dynamic> body,
    String successMsg, {
    bool refreshProducts = true,
    VoidCallback? onSuccess,
  }) async {
    isActionLoading.value = true;
    final res = await _apiCall(endpoint, method: method, body: body);
    final success = res != null;

    if (success) {
      onSuccess?.call();
      if (refreshProducts) await fetchProducts();
      Get.snackbar(
        'Success',
        successMsg,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    isActionLoading.value = false;
    return success;
  }

  Future<void> createProduct(Map<String, dynamic> data) =>
      _runAction('/products/add', 'POST', data, 'Product Created');

  Future<int?> createProductReturnId(Map<String, dynamic> data) async {
    isActionLoading.value = true;
    final res = await _apiCall('/products/add', method: 'POST', body: data);
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return res['id'] as int?;
    }
    return null;
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) =>
      _runAction('/products/$id', 'PUT', data, 'Product Updated');

  Future<void> deleteProduct(int id) =>
      _runAction('/products/$id', 'DELETE', {}, 'Product Deleted');

  Future<bool> updateStockBulk(List<Map<String, dynamic>> updates) =>
      _runAction(
        '/products/bulk-update-stock',
        'PUT',
        {'updates': updates},
        'Stock Updated',
      );

  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0.0,
    DateTime? shipmentDate,
  }) async {
    if (seaQty < 0 || airQty < 0 || localQty < 0) {
      return _showError('Quantities cannot be negative');
    }
    await _runAction(
      '/products/add-stock',
      'POST',
      {
        'id': productId,
        'sea_qty': seaQty,
        'air_qty': airQty,
        'local_qty': localQty,
        'local_price': localUnitPrice,
        if (shipmentDate != null) 'shipmentdate': shipmentDate.toIso8601String(),
      },
      'Stock Updated',
    );
  }

  Future<void> updateCurrencyAndRecalculate(double newCurrency) => _runAction(
    '/products/recalculate-prices',
    'PUT',
    {'currency': newCurrency},
    'Currency Updated',
    onSuccess: () => currentCurrency.value = newCurrency,
  );

  // ── Service ───────────────────────────────────────────────────
  Future<void> fetchServiceLogs() async {
    final data = await _apiCall('/service/list');
    if (data != null) {
      serviceLogs.assignAll(
        List<Map<String, dynamic>>.from(data['data'] as List),
      );
    }
  }

  Future<void> addToService({
    required int productId,
    required String model,
    required int qty,
    required String type,
    required double currentAvgPrice,
  }) => _runAction(
    '/service/add',
    'POST',
    {
      'product_id': productId,
      'model': model,
      'qty': qty,
      'type': type,
      'current_avg_price': currentAvgPrice,
    },
    'Added to Service',
    refreshProducts: false, // service op — don't reload products
    onSuccess: fetchServiceLogs,
  );

  Future<void> returnFromService(int logId, int qty) => _runAction(
    '/service/return',
    'POST',
    {'log_id': logId, 'qty': qty},
    'Returned to Stock',
    onSuccess: fetchServiceLogs,
  );

  // ── Sale Return dropdown helper ────────────────────────────────
  Future<List<Map<String, dynamic>>> searchProductsForDropdown(
    String query,
  ) async {
    if (query.isEmpty) return [];
    final res = await _apiCall(
      '/products',
      queryParams: {'page': '1', 'limit': '20', 'search': query},
    );
    if (res != null) {
      return (res['products'] as List).map((e) {
        final p = Product.fromJson(e);
        return {
          'id': p.id,
          'name': p.name,
          'model': p.model,
          'buyingPrice': p.avgPurchasePrice,
        };
      }).toList();
    }
    return [];
  }

  Future<bool> bulkAddStockMixed(List<Map<String, dynamic>> items) =>
      _runAction(
        '/products/bulk-add-stock',
        'POST',
        {'items': items},
        'Stock Added',
      );

  // ── Formatted helpers ─────────────────────────────────────────
  String get formattedTotalValuation =>
      overallTotalValuation.value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}