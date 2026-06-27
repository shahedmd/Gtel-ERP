import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'stockproductmodel.dart';

bool parseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v == 1;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1';
}

/// Handles int fields that may arrive as int, double (e.g. 5.0 from SQL SUM/AVG), or String.
int safeInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  final s = v.toString();
  return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0;
}

/// Handles double fields the same defensive way.
double safeDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class Warehouse {
  final int id;
  final String name;
  final bool isActive;

  Warehouse({required this.id, required this.name, required this.isActive});

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: safeInt(json['id']),
    name: json['name']?.toString() ?? '',
    isActive: parseBool(json['is_active']),
  );
}

class WarehouseSummary {
  final int id;
  final String name;
  final bool isActive;
  final int totalQty;
  final double totalValue;
  final int productCount;

  WarehouseSummary({
    required this.id,
    required this.name,
    required this.isActive,
    required this.totalQty,
    required this.totalValue,
    required this.productCount,
  });

  factory WarehouseSummary.fromJson(Map<String, dynamic> json) =>
      WarehouseSummary(
        id: safeInt(json['id']),
        name: json['name']?.toString() ?? '',
        isActive: parseBool(json['is_active']),
        totalQty: safeInt(json['total_qty']),
        totalValue: safeDouble(json['total_value']),
        productCount: safeInt(json['product_count']),
      );
}

class ProductWarehouseStock {
  final int warehouseId;
  final String warehouseName;
  final int qty;
  final String location;

  ProductWarehouseStock({
    required this.warehouseId,
    required this.warehouseName,
    required this.qty,
    required this.location,
  });

  factory ProductWarehouseStock.fromJson(Map<String, dynamic> json) =>
      ProductWarehouseStock(
        warehouseId: safeInt(json['warehouse_id']),
        warehouseName: json['warehouse_name']?.toString() ?? '',
        qty: safeInt(json['qty']),
        location: json['location']?.toString() ?? '',
      );
}

class ProductController extends GetxController {
  static const baseUrl = 'https://dart-server-1zun.onrender.com';

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

  final RxBool isLoading = false.obs;
  final RxBool isActionLoading = false.obs;
  final RxBool isShortListLoading = false.obs;

  final RxInt currentPage = 1.obs;
  final RxInt pageSize = 20.obs;
  final RxInt shortlistPage = 1.obs;
  final RxInt shortlistLimit = 20.obs;

  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

  // Warehouse
  final RxList<Warehouse> warehouses = <Warehouse>[].obs;
  final RxList<WarehouseSummary> warehouseSummaries = <WarehouseSummary>[].obs;
  final Rx<Warehouse?> selectedWarehouse = Rx<Warehouse?>(null);
  final RxBool isWarehouseLoading = false.obs;
  final RxBool isTransferLoading = false.obs;

  Timer? _searchDebounce;
  Timer? _shortlistDebounce;

  int _productsRequestId = 0;
  int _shortlistRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    fetchWarehouses();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _shortlistDebounce?.cancel();
    super.onClose();
  }

  Future<Map<String, dynamic>?> _apiCall(
    String endpoint, {
    String method = 'GET',
    dynamic body,
    Map<String, String>? queryParams,
  }) async {
    const timeout = Duration(seconds: 15);
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      http.Response res;
      final headers = {'Content-Type': 'application/json'};

      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(timeout);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map
            ? decoded as Map<String, dynamic>
            : {'data': decoded};
      } else {
        var msg = 'Server Error ${res.statusCode}';
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['error'] != null) {
            msg = decoded['error'].toString();
          }
        } catch (_) {}
        _showError(msg);
      }
    } on TimeoutException {
      _showError('Request timed out. Please check your connection.');
    } catch (e) {
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

  void _showSuccess(String msg) => Get.snackbar(
    'Success',
    msg,
    backgroundColor: Colors.green,
    colorText: Colors.white,
  );

  // ─── Products ────────────────────────────────────────────

  void toggleSortByLoss() {
    sortByLoss.value = !sortByLoss.value;
    currentPage.value = 1;
    fetchProducts();
  }

  Future<void> fetchProducts({int? page}) async {
    isLoading.value = true;
    final current = page ?? currentPage.value;
    final requestId = ++_productsRequestId;

    final data = await _apiCall(
      '/products',
      queryParams: {
        'page': current.toString(),
        'limit': pageSize.value.toString(),
        'search': searchText.value,
        'brand': selectedBrand.value == 'All' ? '' : selectedBrand.value,
        if (sortByLoss.value) 'sort': 'loss',
        if (selectedWarehouse.value != null)
          'warehouse_id': selectedWarehouse.value!.id.toString(),
      },
    );

    if (requestId != _productsRequestId) return;

    if (data != null) {
      allProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      totalProducts.value = safeInt(data['total']);
      overallTotalValuation.value = safeDouble(data['total_value']);

      // Sync displayed exchange rate from server on every load
      final rateRef = allProducts.firstWhereOrNull(
        (p) => p.yuan > 0 && p.currency > 0,
      );
      if (rateRef != null) {
        currentCurrency.value = rateRef.currency;
      }
    }

    isLoading.value = false;
  }

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

  Future<void> createProduct(Map<String, dynamic> data) async {
    await _runAction('/products/add', 'POST', data, 'Product Created');
  }

  Future<int?> createProductReturnId(Map<String, dynamic> data) async {
    isActionLoading.value = true;
    final res = await _apiCall('/products/add', method: 'POST', body: data);
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return safeInt(res['id']);
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
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    if (seaQty < 0 || airQty < 0 || localQty < 0) {
      return _showError('Quantities cannot be negative');
    }
    await _runAction('/products/add-stock', 'POST', {
      'id': productId,
      'sea_qty': seaQty,
      'air_qty': airQty,
      'local_qty': localQty,
      'local_price': localUnitPrice,
      if (shipmentDate != null) 'shipmentdate': shipmentDate.toIso8601String(),
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (warehouseLocation != null && warehouseLocation.isNotEmpty)
        'warehouse_location': warehouseLocation,
    }, 'Stock Updated');
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

  Future<bool> bulkAddStockMixed(List<Map<String, dynamic>> items) async {
    isActionLoading.value = true;
    final res = await _apiCall(
      '/products/bulk-add-stock',
      method: 'POST',
      body: items,
    );
    isActionLoading.value = false;
    if (res != null) {
      fetchProducts();
      return true;
    }
    return false;
  }

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

  // ─── Shortlist ────────────────────────────────────────────

  void searchShortlist(String query) {
    shortlistSearchText.value = query;
    if (_shortlistDebounce?.isActive ?? false) _shortlistDebounce!.cancel();
    _shortlistDebounce = Timer(
      const Duration(milliseconds: 600),
      () => fetchShortList(page: 1),
    );
  }

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

  Future<void> fetchShortList({int page = 1}) async {
    isShortListLoading.value = true;
    shortlistPage.value = page;
    final requestId = ++_shortlistRequestId;

    final data = await _apiCall(
      '/products/shortlist',
      queryParams: {
        'page': page.toString(),
        'limit': shortlistLimit.value.toString(),
        'search': shortlistSearchText.value.trim(),
      },
    );

    if (requestId != _shortlistRequestId) return;

    if (data != null) {
      shortListProducts.assignAll(
        (data['products'] as List).map((e) => Product.fromJson(e)).toList(),
      );
      shortlistTotal.value = safeInt(data['total']);
    }
    isShortListLoading.value = false;
  }

  // FIX (bug #3): server's /products/shortlist?all=true ALWAYS returns the
  // 'products' key (never 'data'), even in the all=true branch — confirmed
  // from server.dart's fetchShortList(). Also now forwards the current
  // search filter so "export all" respects what the user searched for.
  Future<List<Product>> fetchAllShortListForExport() async {
    final data = await _apiCall(
      '/products/shortlist',
      queryParams: {'all': 'true', 'search': shortlistSearchText.value.trim()},
    );
    return data != null
        ? (data['products'] as List).map((e) => Product.fromJson(e)).toList()
        : [];
  }

  // ─── Service ──────────────────────────────────────────────

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

  Future<void> returnFromService(
    int logId,
    int qty, {
    int? warehouseId,
    String? location,
  }) async {
    await _runAction(
      '/service/return',
      'POST',
      {
        'log_id': logId,
        'qty': qty,
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (location != null && location.isNotEmpty)
          'warehouse_location': location,
      },
      'Returned to Stock',
      onSuccess: fetchServiceLogs,
    );
  }

  Future<void> fetchWarehouses() async {
    isWarehouseLoading.value = true;
    final data = await _apiCall('/warehouses');
    if (data != null) {
      warehouses.assignAll(
        (data['warehouses'] as List).map((e) => Warehouse.fromJson(e)).toList(),
      );
    }
    isWarehouseLoading.value = false;
  }

  Future<void> fetchWarehouseSummary() async {
    isWarehouseLoading.value = true;
    final data = await _apiCall('/warehouses/summary');
    if (data != null) {
      warehouseSummaries.assignAll(
        (data['warehouses'] as List)
            .map((e) => WarehouseSummary.fromJson(e))
            .toList(),
      );
    }
    isWarehouseLoading.value = false;
  }

  Future<void> createWarehouse(String name) async {
    if (name.trim().isEmpty) return _showError('Warehouse name is required');
    isActionLoading.value = true;
    final res = await _apiCall(
      '/warehouses',
      method: 'POST',
      body: {'name': name.trim()},
    );
    isActionLoading.value = false;
    if (res != null) {
      await fetchWarehouses();
      await fetchWarehouseSummary();
      _showSuccess('Warehouse "$name" created');
    }
  }

  Future<void> updateWarehouse(
    int id,
    String name, {
    bool isActive = true,
  }) async {
    if (name.trim().isEmpty) return _showError('Warehouse name is required');
    isActionLoading.value = true;
    final res = await _apiCall(
      '/warehouses/$id',
      method: 'PUT',
      body: {'name': name.trim(), 'is_active': isActive},
    );
    isActionLoading.value = false;
    if (res != null) {
      await fetchWarehouses();
      await fetchWarehouseSummary();
      _showSuccess('Warehouse updated');
    }
  }

  // FIX (real bug found against server.dart): the server's updateWarehouse
  // endpoint REQUIRES `name` in the body and returns 400 "Warehouse name is
  // required" if it's missing. The old deleteWarehouse() only sent
  // {'is_active': false}, so deactivating a warehouse was silently failing
  // every time. We now look up the warehouse's current name locally and
  // send it along with the deactivation request.
  Future<void> deleteWarehouse(int id) async {
    final existing = warehouses.firstWhereOrNull((w) => w.id == id);
    if (existing == null) {
      return _showError('Warehouse not found');
    }

    await _runAction(
      '/warehouses/$id',
      'PUT',
      {'name': existing.name, 'is_active': false},
      'Warehouse deactivated',
      onSuccess: () async {
        await fetchWarehouses();
        await fetchWarehouseSummary();
      },
    );
  }

  Future<void> setProductWarehouseLocation({
    required int productId,
    required int warehouseId,
    required String location,
  }) async {
    isActionLoading.value = true;
    final res = await _apiCall(
      '/products/$productId/warehouse-location',
      method: 'PUT',
      body: {'warehouse_id': warehouseId, 'location': location.trim()},
    );
    isActionLoading.value = false;
    if (res != null) {
      await fetchProducts();
      _showSuccess('Location updated');
    }
  }

  void selectWarehouse(Warehouse? warehouse) {
    if (selectedWarehouse.value?.id == warehouse?.id) return;
    selectedWarehouse.value = warehouse;
    currentPage.value = 1;
    fetchProducts();
  }

  void clearWarehouseFilter() {
    selectedWarehouse.value = null;
    currentPage.value = 1;
    fetchProducts();
  }

  List<Warehouse> get activeWarehouses =>
      warehouses.where((w) => w.isActive).toList();

  Future<bool> transferStock({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required int qty,
    String? toLocation,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      _showError('Source and destination must be different');
      return false;
    }
    if (qty <= 0) {
      _showError('Quantity must be greater than zero');
      return false;
    }

    isTransferLoading.value = true;
    final res = await _apiCall(
      '/products/transfer-warehouse',
      method: 'POST',
      body: {
        'product_id': productId,
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'qty': qty,
        if (toLocation != null && toLocation.trim().isNotEmpty)
          'to_location': toLocation.trim(),
      },
    );
    isTransferLoading.value = false;

    if (res != null) {
      await Future.wait([fetchProducts(), fetchWarehouseSummary()]);
      _showSuccess('Transfer completed');
      return true;
    }
    return false;
  }

  // ─── Helpers ──────────────────────────────────────────────

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
      _showSuccess(successMsg);
    }
    isActionLoading.value = false;
  }

  List<String> get brands {
    final unique = allProducts.map((e) => e.brand).toSet().toList();
    unique.sort();
    return ['All', ...unique];
  }

  String get formattedTotalValuation => overallTotalValuation.value
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  String formatCurrency(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
