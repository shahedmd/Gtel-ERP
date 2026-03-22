import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../Stock/model.dart';

class ProductController extends GetxController {
  static const baseUrl = 'https://dart-server-1zun.onrender.com';

  // State Management
  final RxList<Product> allProducts = <Product>[].obs;
  final RxList<Product> shortListProducts = <Product>[].obs;
  final RxList<Map<String, dynamic>> serviceLogs = <Map<String, dynamic>>[].obs;

  final RxDouble overallTotalValuation = 0.0.obs;
  final RxInt totalProducts = 0.obs;
  final RxInt shortlistTotal = 0.obs;

  final RxString selectedBrand = 'All'.obs;
  final RxString searchText = ''.obs;
  final RxString shortlistSearchText = ''.obs;
  final RxDouble currentCurrency = 17.85.obs;
  final RxBool sortByLoss = false.obs;

  // Loaders
  final RxBool isLoading = false.obs;
  final RxBool isActionLoading = false.obs;
  final RxBool isShortListLoading = false.obs;

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt pageSize = 20.obs;
  final RxInt shortlistPage = 1.obs;
  final RxInt shortlistLimit = 20.obs;

  Timer? _searchDebounce;
  Timer? _shortlistDebounce;
  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _shortlistDebounce?.cancel();
    super.onClose();
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

  // STANDARD CREATE PRODUCT
  Future<void> createProduct(Map<String, dynamic> data) async {
    await _runAction('/products/add', 'POST', data, 'Product Created');
  }

  Future<Map<String, dynamic>?> _apiCall(
    String endpoint, {
    String method = 'GET',
    dynamic body,
    Map<String, String>? queryParams,
    bool throwError = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      http.Response res;
      final headers = {'Content-Type': 'application/json'};

      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers);
          break;
        default:
          res = await http.get(uri).timeout(const Duration(seconds: 15));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map
            ? decoded as Map<String, dynamic>
            : {'data': decoded};
      } else {
        final msg =
            jsonDecode(res.body)['error'] ?? 'Server Error ${res.statusCode}';
        if (throwError) throw msg;
        _showError(msg);
      }
    } catch (e) {
      if (throwError) throw e.toString();
      _showError('Connection Error: $e');
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

  // ==========================================
  // DATA FETCHING
  // ==========================================
  void toggleSortByLoss() {
    sortByLoss.value = !sortByLoss.value;
    currentPage.value = 1;
    fetchProducts(); // The backend now handles this perfectly! Memory saved.
  }

  Future<void> fetchProducts({int? page}) async {
    isLoading.value = true;
    final current = page ?? currentPage.value;

    final queryParams = {
      'page': current.toString(),
      'limit':
          pageSize.value
              .toString(), // Standard limit (No more fetching 10,000 items!)
      'search': searchText.value,
      'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
      if (sortByLoss.value) 'sort': 'loss', // Tells your new server to sort it!
    };

    final data = await _apiCall('/products', queryParams: queryParams);

    if (data != null) {
      // Instantly load the server-sorted data straight to the UI
      allProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      totalProducts.value = int.tryParse(data['total'].toString()) ?? 0;
      overallTotalValuation.value =
          double.tryParse(data['total_value'].toString()) ?? 0.0;
    }

    isLoading.value = false;
  }

  // ==========================================
  // SEARCH & PAGINATION CONTROLS
  // ==========================================
  void search(String text) {
    if (searchText.value == text) return;
    searchText.value = text;
    currentPage.value = 1;
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), fetchProducts);
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
      fetchProducts();
    }
  }

  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      fetchProducts();
    }
  }

  // ==========================================
  // SHORTLIST
  // ==========================================
  void searchShortlist(String query) {
    shortlistSearchText.value = query;
    if (_shortlistDebounce?.isActive ?? false) _shortlistDebounce!.cancel();
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
      shortListProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      shortlistTotal.value = int.tryParse(data['total'].toString()) ?? 0;
    }
    isShortListLoading.value = false;
  }

  Future<List<Product>> fetchAllShortListForExport() async {
    final data = await _apiCall(
      '/products/shortlist',
      queryParams: {'all': 'true'},
    );
    return data != null
        ? (data['data'] as List).map((e) => Product.fromJson(e)).toList()
        : [];
  }

  // ==========================================
  // CRUD & ACTION WRAPPERS
  // ==========================================
  Future<void> _runAction(
    String endpoint,
    String method,
    Map<String, dynamic> body,
    String successMsg, {
    Function? onSuccess,
  }) async {
    isActionLoading.value = true;
    final res = await _apiCall(endpoint, method: method, body: body);
    if (res != null) {
      if (onSuccess != null) onSuccess();
      await fetchProducts();
      Get.snackbar(
        'Success',
        successMsg,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
    isActionLoading.value = false;
  }

  Future<int?> createProductReturnId(Map<String, dynamic> data) async {
    isActionLoading.value = true;
    final res = await _apiCall('/products/add', method: 'POST', body: data);
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return res['id'];
    }
    return null;
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) =>
      _runAction('/products/$id', 'PUT', data, 'Product Updated');
  Future<void> deleteProduct(int id) =>
      _runAction('/products/$id', 'DELETE', {}, 'Product Deleted');

  Future<bool> updateStockBulk(List<Map<String, dynamic>> updates) async {
    isActionLoading.value = true;
    final res = await _apiCall(
      '/products/bulk-update-stock',
      method: 'PUT',
      body: {'updates': updates},
    );
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return true;
    }
    return false;
  }

  Future<void> addMixedStock({
    required int productId,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0.0,
    DateTime? shipmentDate,
  }) async {
    if (seaQty < 0 || airQty < 0 || localQty < 0) {
      return _showError("Quantities cannot be negative");
    }
    final body = {
      'id': productId,
      'sea_qty': seaQty,
      'air_qty': airQty,
      'local_qty': localQty,
      'local_price': localUnitPrice,
      if (shipmentDate != null) 'shipmentdate': shipmentDate.toIso8601String(),
    };
    await _runAction('/products/add-stock', 'POST', body, 'Stock Updated');
  }

  Future<void> updateCurrencyAndRecalculate(double newCurrency) async {
    await _runAction(
      '/products/recalculate-prices',
      'PUT',
      {'currency': newCurrency},
      'Currency Updated',
      onSuccess: () => currentCurrency.value = newCurrency,
    );
  }

  // Service
  Future<void> fetchServiceLogs() async {
    final data = await _apiCall('/service/list');
    if (data != null) {
      serviceLogs.assignAll(List<Map<String, dynamic>>.from(data['data']));
    }
  }

  Future<void> addToService({
    required int productId,
    required String model,
    required int qty,
    required String type,
    required double currentAvgPrice,
  }) async {
    await _runAction(
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
      onSuccess: fetchServiceLogs,
    );
  }

  Future<void> returnFromService(int logId, int qty) async {
    await _runAction(
      '/service/return',
      'POST',
      {'log_id': logId, 'qty': qty},
      'Returned to Stock',
      onSuccess: fetchServiceLogs,
    );
  }

  // ==========================================
  // RESTORED METHODS FOR SALE RETURN
  // ==========================================
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

  Future<bool> bulkAddStockMixed(List<Map<String, dynamic>> items) async {
    isActionLoading.value = true;
    final res = await _apiCall(
      '/products/bulk-add-stock',
      method: 'POST',
      body: items,
    ); // Pass list directly
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return true;
    }
    return false;
  }

  // Helpers
  List<String> get brands {
    final unique = allProducts.map((e) => e.brand).toSet().toList();
    unique.sort();
    return ['All', ...unique];
  }

  String get formattedTotalValuation => overallTotalValuation.value
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}
