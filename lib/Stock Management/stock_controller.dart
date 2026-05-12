import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'stock_model.dart';

class ProductController extends GetxController {
static const String baseUrl = 'https://dart-server-1zun.onrender.com';
  static const _timeout = Duration(seconds: 15);

  final products = <Product>[].obs;
  final shortListProducts = <Product>[].obs;
  final brands = <String>[].obs;
  final warehouses = <Map<String, dynamic>>[].obs;
  final warehouseSummaries = <Map<String, dynamic>>[].obs;
  final serviceLogs = <Map<String, dynamic>>[].obs;

  final isLoading = false.obs;
  final isActionLoading = false.obs;
  final isShortListLoading = false.obs;
  final isLoadingServiceLogs = false.obs;

  final currentPage = 1.obs;
  final totalProducts = 0.obs;
  final itemsPerPage = 20.obs;

  final shortlistPage = 1.obs;
  final shortlistLimit = 20.obs;
  final shortlistTotal = 0.obs;

  final searchQuery = ''.obs;
  final shortlistSearchText = ''.obs;
  final selectedBrand = 'All'.obs;
  final selectedWarehouseId = RxnInt();
  final sortByLoss = false.obs;
  final totalValuation = 0.0.obs;
  final currentCurrency = 17.85.obs;

  Timer? _searchDebounce;
  Timer? _shortlistDebounce;
  String? _lastError;

  // Compatibility aliases for your existing UI.
  RxList<Product> get allProducts => products;
  RxList<String> get brandOptions => brands;
  RxList<Map<String, dynamic>> get warehouseSummary => warehouseSummaries;
  RxDouble get overallTotalValuation => totalValuation;
  RxInt get pageSize => itemsPerPage;

  int get totalPages {
    final pages = (totalProducts.value / itemsPerPage.value).ceil();
    return pages < 1 ? 1 : pages;
  }

  int get selectedWarehouseIdOrZero => selectedWarehouseId.value ?? 0;
  String get lastError => _lastError ?? '';

  String get selectedWarehouseName {
    final id = selectedWarehouseId.value;
    if (id == null) return 'All Warehouses';

    final warehouse = warehouses.firstWhereOrNull(
      (item) => _toInt(item['id']) == id,
    );

    return (warehouse?['name'] ?? 'Selected Warehouse').toString();
  }

  String get formattedTotalValuation {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: 'Tk ',
      decimalDigits: 0,
    ).format(totalValuation.value);
  }

  List<Map<String, dynamic>> get activeWarehouses {
    return warehouses
        .where((item) => item['is_active'] != false)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    fetchBrands();
    fetchWarehouses();
    fetchWarehouseSummary();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _shortlistDebounce?.cancel();
    super.onClose();
  }

  Future<dynamic> _apiCall(
    Future<http.Response> Function() request, {
    String fallbackError = 'Request failed',
  }) async {
    try {
      final response = await request().timeout(_timeout);

      dynamic decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = response.body.trim();
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded ?? <String, dynamic>{};
      }

      String message = fallbackError;
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      } else if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded is String && decoded.isNotEmpty) {
        message = decoded;
      }

      throw Exception(message);
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      debugPrint('Stock API Error: $_lastError');
      rethrow;
    }
  }

  List<dynamic> _listFrom(dynamic data, String key) {
    if (data is Map && data[key] is List) return data[key] as List;
    if (data is List) return data;
    return [];
  }

  Future<void> fetchProducts({int? page, int? warehouseId}) async {
    try {
      isLoading.value = true;

      if (page != null) currentPage.value = page;
      if (warehouseId != null) {
        selectedWarehouseId.value = warehouseId > 0 ? warehouseId : null;
      }

      final params = <String, String>{
        'page': currentPage.value.toString(),
        'limit': itemsPerPage.value.toString(),
      };

      if (searchQuery.value.trim().isNotEmpty) {
        params['search'] = searchQuery.value.trim();
      }

      if (selectedBrand.value.trim().isNotEmpty &&
          selectedBrand.value != 'All') {
        params['brand'] = selectedBrand.value.trim();
      }

      if (sortByLoss.value) params['sort'] = 'loss';

      final selectedWh = selectedWarehouseId.value;
      if (selectedWh != null && selectedWh > 0) {
        params['warehouse_id'] = selectedWh.toString();
      }

      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);

      final data = await _apiCall(
        () => http.get(uri),
        fallbackError: 'Failed to load products',
      );

      final rawProducts = _listFrom(data, 'products');

      products.assignAll(
        rawProducts
            .whereType<Map>()
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );

      totalProducts.value = _toInt(data is Map ? data['total'] : 0);
      totalValuation.value = _toDouble(data is Map ? data['total_value'] : 0);
    } catch (_) {
      products.clear();
      totalProducts.value = 0;
      totalValuation.value = 0;
      Get.snackbar('Stock Error', lastError);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchBrands() async {
    try {
      final data = await _apiCall(
        () => http.get(Uri.parse('$baseUrl/products/brands')),
        fallbackError: 'Failed to load brands',
      );

      final parsed = _listFrom(data, 'brands')
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();

      parsed.sort();
      brands.assignAll(['All', ...parsed]);
    } catch (_) {
      brands.assignAll(['All']);
    }
  }

  Future<void> fetchWarehouses() async {
    try {
      final data = await _apiCall(
        () => http.get(Uri.parse('$baseUrl/warehouses')),
        fallbackError: 'Failed to load warehouses',
      );

      warehouses.assignAll(
        _listFrom(data, 'warehouses')
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    } catch (_) {
      warehouses.clear();
    }
  }

  Future<void> fetchWarehouseSummary() async {
    try {
      final data = await _apiCall(
        () => http.get(Uri.parse('$baseUrl/warehouses/summary')),
        fallbackError: 'Failed to load warehouse summary',
      );

      warehouseSummaries.assignAll(
        _listFrom(data, 'warehouses')
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    } catch (_) {
      warehouseSummaries.clear();
    }
  }

  Future<void> refreshStockData() async {
    await Future.wait([
      fetchProducts(),
      fetchBrands(),
      fetchWarehouses(),
      fetchWarehouseSummary(),
    ]);
  }

  void searchProducts(String value) {
    searchQuery.value = value;
    currentPage.value = 1;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), fetchProducts);
  }

  void search(String value) => searchProducts(value);

  void selectBrand(String value) {
    selectedBrand.value = value;
    currentPage.value = 1;
    fetchProducts();
  }

  void selectWarehouseFilter(int? warehouseId) {
    selectedWarehouseId.value =
        warehouseId != null && warehouseId > 0 ? warehouseId : null;
    currentPage.value = 1;
    fetchProducts();
  }

  void selectWarehouse(int? warehouseId) => selectWarehouseFilter(warehouseId);

  void toggleLossSort() {
    sortByLoss.value = !sortByLoss.value;
    currentPage.value = 1;
    fetchProducts();
  }

  void toggleSortByLoss() => toggleLossSort();

  void clearFilters() {
    searchQuery.value = '';
    selectedBrand.value = 'All';
    selectedWarehouseId.value = null;
    sortByLoss.value = false;
    currentPage.value = 1;
    fetchProducts();
  }

  void changePage(int page) {
    if (page < 1 || page > totalPages || page == currentPage.value) return;
    currentPage.value = page;
    fetchProducts();
  }

  void nextPage() => changePage(currentPage.value + 1);
  void previousPage() => changePage(currentPage.value - 1);

  void searchShortlist(String query) {
    shortlistSearchText.value = query;
    _shortlistDebounce?.cancel();
    _shortlistDebounce = Timer(
      const Duration(milliseconds: 600),
      () => fetchShortList(page: 1),
    );
  }

  Future<void> fetchShortList({int page = 1}) async {
    try {
      isShortListLoading.value = true;
      shortlistPage.value = page;

      final data = await _apiCall(
        () => http.get(
          Uri.parse('$baseUrl/products/shortlist').replace(
            queryParameters: {
              'page': page.toString(),
              'limit': shortlistLimit.value.toString(),
              'search': shortlistSearchText.value.trim(),
            },
          ),
        ),
        fallbackError: 'Failed to load shortlist',
      );

      shortListProducts.assignAll(
        _listFrom(data, 'products')
            .whereType<Map>()
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );

      shortlistTotal.value = _toInt(data is Map ? data['total'] : 0);
    } catch (_) {
      shortListProducts.clear();
      shortlistTotal.value = 0;
    } finally {
      isShortListLoading.value = false;
    }
  }

  Future<List<Product>> fetchAllShortListForExport() async {
    try {
      final data = await _apiCall(
        () => http.get(
          Uri.parse('$baseUrl/products/shortlist').replace(
            queryParameters: {'all': 'true'},
          ),
        ),
        fallbackError: 'Failed to export shortlist',
      );

      return _listFrom(data, 'products')
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
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

  Future<void> createWarehouse(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      Get.snackbar('Warehouse', 'Warehouse name is required');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/warehouses'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': cleanName}),
        ),
        fallbackError: 'Failed to create warehouse',
      ),
      successMessage: 'Warehouse created',
      refreshProducts: false,
      refreshWarehouses: true,
    );
  }

  Future<void> updateWarehouseName({
    required int warehouseId,
    required String name,
    bool isActive = true,
  }) async {
    final cleanName = name.trim();
    if (warehouseId <= 0 || cleanName.isEmpty) {
      Get.snackbar('Warehouse', 'Valid warehouse name is required');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.put(
          Uri.parse('$baseUrl/warehouses/$warehouseId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': cleanName, 'is_active': isActive}),
        ),
        fallbackError: 'Failed to update warehouse',
      ),
      successMessage: 'Warehouse updated',
      refreshProducts: true,
      refreshWarehouses: true,
    );
  }

  Future<void> createProduct(
    Map<String, dynamic> product, {
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    final body = Map<String, dynamic>.from(product);

    if (warehouseId != null && warehouseId > 0) body['warehouse_id'] = warehouseId;
    if ((warehouseLocation ?? '').trim().isNotEmpty) {
      body['warehouse_location'] = warehouseLocation!.trim();
    }

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/products/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        fallbackError: 'Failed to create product',
      ),
      successMessage: 'Product created',
      refreshBrands: true,
    );
  }

  Future<int?> createProductReturnId(
    Map<String, dynamic> product, {
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    final body = Map<String, dynamic>.from(product);

    if (warehouseId != null && warehouseId > 0) body['warehouse_id'] = warehouseId;
    if ((warehouseLocation ?? '').trim().isNotEmpty) {
      body['warehouse_location'] = warehouseLocation!.trim();
    }

    try {
      isActionLoading.value = true;

      final data = await _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/products/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        fallbackError: 'Failed to create product',
      );

      await Future.wait([
        fetchProducts(),
        fetchBrands(),
        fetchWarehouses(),
        fetchWarehouseSummary(),
      ]);

      Get.snackbar('Stock', 'Product created');
      return _toInt(data is Map ? data['id'] : 0);
    } catch (_) {
      Get.snackbar('Stock Error', lastError);
      return null;
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> updateProduct(
    int id,
    Map<String, dynamic> product, {
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    final body = Map<String, dynamic>.from(product);

    if (warehouseId != null && warehouseId > 0) {
      body['warehouse_id'] = warehouseId;
      body['warehouse_location'] = (warehouseLocation ?? '').trim();
    }

    await _runAction(
      () => _apiCall(
        () => http.put(
          Uri.parse('$baseUrl/products/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        fallbackError: 'Failed to update product',
      ),
      successMessage: 'Product updated',
      refreshBrands: true,
    );
  }

  Future<void> deleteProduct(int id) async {
    await _runAction(
      () => _apiCall(
        () => http.delete(Uri.parse('$baseUrl/products/$id')),
        fallbackError: 'Failed to delete product',
      ),
      successMessage: 'Product deleted',
      refreshBrands: true,
    );
  }

  Future<void> addMixedStock({
    int? productId,
    int? id,
    int seaQty = 0,
    int airQty = 0,
    int localQty = 0,
    double localUnitPrice = 0,
    double localPrice = 0,
    DateTime? shipmentDate,
    int? warehouseId,
    String warehouseLocation = '',
  }) async {
    final productKey = productId ?? id ?? 0;
    final price = localUnitPrice != 0 ? localUnitPrice : localPrice;

    if (productKey <= 0) {
      Get.snackbar('Stock', 'Valid product is required');
      return;
    }

    if (seaQty < 0 || airQty < 0 || localQty < 0) {
      Get.snackbar('Stock', 'Quantities cannot be negative');
      return;
    }

    final body = {
      'id': productKey,
      'sea_qty': seaQty,
      'air_qty': airQty,
      'local_qty': localQty,
      'local_price': price,
      if (shipmentDate != null) 'shipmentdate': shipmentDate.toIso8601String(),
      if (warehouseId != null && warehouseId > 0) 'warehouse_id': warehouseId,
      if (warehouseLocation.trim().isNotEmpty)
        'warehouse_location': warehouseLocation.trim(),
    };

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/products/add-stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        fallbackError: 'Failed to add stock',
      ),
      successMessage: 'Stock added',
    );
  }

  Future<bool> bulkAddStockMixed(List<Map<String, dynamic>> items) async {
    return _runBoolAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/products/bulk-add-stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'items': items}),
        ),
        fallbackError: 'Failed to bulk add stock',
      ),
      successMessage: 'Bulk stock updated',
    );
  }

  Future<bool> updateStockBulk(List<Map<String, dynamic>> updates) async {
    return _runBoolAction(
      () => _apiCall(
        () => http.put(
          Uri.parse('$baseUrl/products/bulk-update-stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'updates': updates}),
        ),
        fallbackError: 'Failed to update stock',
      ),
      successMessage: 'Stock updated',
    );
  }

  Future<void> transferWarehouseStock({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required int qty,
    String toLocation = '',
  }) async {
    if (productId <= 0 || fromWarehouseId <= 0 || toWarehouseId <= 0) {
      Get.snackbar('Transfer', 'Valid product and warehouse are required');
      return;
    }

    if (fromWarehouseId == toWarehouseId) {
      Get.snackbar('Transfer', 'Source and destination warehouse cannot be same');
      return;
    }

    if (qty <= 0) {
      Get.snackbar('Transfer', 'Transfer quantity must be greater than 0');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/products/transfer-warehouse'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'product_id': productId,
            'from_warehouse_id': fromWarehouseId,
            'to_warehouse_id': toWarehouseId,
            'qty': qty,
            'to_location': toLocation.trim(),
          }),
        ),
        fallbackError: 'Failed to transfer stock',
      ),
      successMessage: 'Stock transferred',
    );
  }

  Future<void> updateProductWarehouseLocation({
    required int productId,
    required int warehouseId,
    required String location,
  }) async {
    await _runAction(
      () => _apiCall(
        () => http.put(
          Uri.parse('$baseUrl/products/$productId/warehouse-location'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'warehouse_id': warehouseId,
            'location': location.trim(),
          }),
        ),
        fallbackError: 'Failed to update location',
      ),
      successMessage: 'Location updated',
    );
  }

  Future<void> updateCurrencyAndRecalculate(double newCurrency) async {
    if (newCurrency <= 0) {
      Get.snackbar('Currency', 'Currency must be greater than 0');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.put(
          Uri.parse('$baseUrl/products/recalculate-prices'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'currency': newCurrency}),
        ),
        fallbackError: 'Failed to recalculate prices',
      ),
      successMessage: 'Prices recalculated',
      afterSuccess: () => currentCurrency.value = newCurrency,
    );
  }

  Future<void> fetchServiceLogs() async {
    try {
      isLoadingServiceLogs.value = true;

      final data = await _apiCall(
        () => http.get(Uri.parse('$baseUrl/service/list')),
        fallbackError: 'Failed to load service logs',
      );

      serviceLogs.assignAll(
        _listFrom(data, 'data')
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    } catch (_) {
      serviceLogs.clear();
      Get.snackbar('Service Error', lastError);
    } finally {
      isLoadingServiceLogs.value = false;
    }
  }

  Future<void> addToService({
    required int productId,
    required int qty,
    required double currentAvgPrice,
    required String type,
    required String model,
    int? warehouseId,
  }) async {
    if (productId <= 0 || qty <= 0) {
      Get.snackbar('Service', 'Valid product and quantity are required');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/service/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'product_id': productId,
            'qty': qty,
            'current_avg_price': currentAvgPrice,
            'type': type,
            'model': model,
            if (warehouseId != null && warehouseId > 0)
              'warehouse_id': warehouseId,
          }),
        ),
        fallbackError: 'Failed to send product to service',
      ),
      successMessage: 'Product moved to service',
      afterSuccess: fetchServiceLogs,
    );
  }

  Future<void> returnFromService({
    required int logId,
    required int qty,
    int? warehouseId,
    String warehouseLocation = '',
  }) async {
    if (logId <= 0 || qty <= 0) {
      Get.snackbar('Service', 'Valid return information is required');
      return;
    }

    await _runAction(
      () => _apiCall(
        () => http.post(
          Uri.parse('$baseUrl/service/return'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'log_id': logId,
            'qty': qty,
            if (warehouseId != null && warehouseId > 0)
              'warehouse_id': warehouseId,
            if (warehouseLocation.trim().isNotEmpty)
              'warehouse_location': warehouseLocation.trim(),
          }),
        ),
        fallbackError: 'Failed to return product from service',
      ),
      successMessage: 'Product returned from service',
      afterSuccess: fetchServiceLogs,
    );
  }

  Future<List<Map<String, dynamic>>> searchProductsForDropdown(
    String keyword,
  ) async {
    try {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };

      if (keyword.trim().isNotEmpty) {
        params['search'] = keyword.trim();
      }

      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);

      final data = await _apiCall(
        () => http.get(uri),
        fallbackError: 'Failed to search products',
      );

      return _listFrom(data, 'products').whereType<Map>().map((item) {
        final product = Product.fromJson(Map<String, dynamic>.from(item));
        return {
          'id': product.id,
          'name': product.name,
          'model': product.model,
          'buyingPrice': product.avgPurchasePrice,
          'stockQty': product.stockQty,
          'warehouseStocks':
              product.warehouseStocks.map((stock) => stock.toJson()).toList(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? warehouseSummaryById(int warehouseId) {
    return warehouseSummaries.firstWhereOrNull((item) {
      final id = _toInt(item['warehouse_id'] ?? item['id']);
      return id == warehouseId;
    });
  }

  int warehouseProductCount(int warehouseId) {
    final summary = warehouseSummaryById(warehouseId);
    return _toInt(summary?['product_count']);
  }

  int warehouseTotalQty(int warehouseId) {
    final summary = warehouseSummaryById(warehouseId);
    return _toInt(summary?['total_qty']);
  }

  double warehouseTotalValue(int warehouseId) {
    final summary = warehouseSummaryById(warehouseId);
    return _toDouble(summary?['total_value']);
  }

  String formatMoney(dynamic value) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: 'Tk ',
      decimalDigits: 0,
    ).format(_toDouble(value));
  }

  Future<void> _runAction(
    Future<dynamic> Function() action, {
    required String successMessage,
    bool refreshProducts = true,
    bool refreshWarehouses = false,
    bool refreshBrands = false,
    FutureOr<void> Function()? afterSuccess,
  }) async {
    try {
      isActionLoading.value = true;

      await action();
      await afterSuccess?.call();

      final futures = <Future<void>>[
        fetchWarehouseSummary(),
      ];

      if (refreshProducts) futures.add(fetchProducts());
      if (refreshWarehouses) futures.add(fetchWarehouses());
      if (refreshBrands) futures.add(fetchBrands());

      await Future.wait(futures);

      Get.snackbar('Stock', successMessage);
    } catch (_) {
      Get.snackbar('Stock Error', lastError);
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<bool> _runBoolAction(
    Future<dynamic> Function() action, {
    required String successMessage,
    bool refreshProducts = true,
    bool refreshWarehouses = false,
    bool refreshBrands = false,
  }) async {
    try {
      await _runAction(
        action,
        successMessage: successMessage,
        refreshProducts: refreshProducts,
        refreshWarehouses: refreshWarehouses,
        refreshBrands: refreshBrands,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  int _toInt(dynamic value) {
    return Product.parseInt(value);
  }

  double _toDouble(dynamic value) {
    return Product.parseDouble(value);
  }
}
