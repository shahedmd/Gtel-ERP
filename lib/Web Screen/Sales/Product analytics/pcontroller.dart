import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';

class HotSalesData {
  final Product product;
  final int totalSold;
  final double totalRevenue;

  HotSalesData(this.product, this.totalSold, this.totalRevenue);
}

class HotSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();
  var allHotProducts = <HotSalesData>[].obs;
  var filteredList = <HotSalesData>[].obs;
  var displayList = <HotSalesData>[].obs;
  var isLoading = false.obs;
  var searchQuery = ''.obs;

  var currentPage = 1.obs;
  var itemsPerPage = 20;

  var filterType = 'All'.obs;
  var selectedDate = DateTime.now().obs;

  // Cache control: avoids re-reading the whole sales_orders collection
  // every time this screen opens. Increased from 15 min -> 2 hours to
  // significantly cut Firestore read costs. This does NOT affect qty
  // accuracy — it only controls how often the (unchanged) full scan runs.
  // Use refreshNow() to force fresh data at any time.
  DateTime? _lastFetchedAt;
  static const Duration _cacheTtl = Duration(hours: 2);

  @override
  void onInit() {
    super.onInit();
    fetchSalesData();

    debounce(
      searchQuery,
      (_) => _applySearchAndPagination(),
      time: const Duration(milliseconds: 500),
    );
  }

  // --- 1. FETCH AND CALCULATE ---
  // Pass forceRefresh: true (e.g. from a pull-to-refresh or manual button)
  // to bypass the cache and re-read from Firestore.
  Future<void> fetchSalesData({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) < _cacheTtl &&
        allHotProducts.isNotEmpty) {
      // Cache still fresh — just re-apply date/type filters and search
      // locally instead of hitting Firestore again.
      _applySearchAndPagination();
      return;
    }

    isLoading.value = true;

    Map<String, int> qtyMap = {};
    Map<String, double> revMap = {};
    Map<String, String> backupNameMap = {};
    Map<String, String> backupModelMap = {};
    Map<String, int> backupIdMap = {};

    try {
      if (productCtrl.allProducts.isEmpty) {
        await productCtrl.fetchProducts();
      }

      Map<int, Product> productById = {};
      Map<String, Product> productByComposite = {};

      String normalize(String s) =>
          s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

      for (var p in productCtrl.allProducts) {
        productById[p.id] = p;
        productByComposite["${normalize(p.name)}_||_${normalize(p.model)}"] = p;
      }

      // Paginated fetch — reads everything once per cache window,
      // not on every screen visit. No artificial doc limit, so old
      // orders are never silently dropped.
      List<QueryDocumentSnapshot> allDocs = [];
      Query query = _db
          .collection('sales_orders')
          .orderBy('timestamp', descending: true)
          .limit(500);
      QuerySnapshot snapshot = await query.get();
      allDocs.addAll(snapshot.docs);

      while (snapshot.docs.length == 500) {
        query = _db
            .collection('sales_orders')
            .orderBy('timestamp', descending: true)
            .startAfterDocument(snapshot.docs.last)
            .limit(500);
        snapshot = await query.get();
        allDocs.addAll(snapshot.docs);
      }

      for (var doc in allDocs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String? status = data['status']?.toString().toLowerCase();
        if (status == 'cancelled' || status == 'returned') continue;
        if (!_shouldIncludeOrder(data)) continue;

        List<dynamic> items = data['items'] ?? [];

        for (var item in items) {
          String rawName = item['name']?.toString().trim() ?? '';
          String rawModel = item['model']?.toString().trim() ?? '';

          int parsedId =
              num.tryParse(item['productId']?.toString() ?? '0')?.toInt() ?? 0;

          if (rawName.isEmpty && parsedId == 0) continue;

          int qty = num.tryParse(item['qty']?.toString() ?? '0')?.toInt() ?? 0;
          double subtotal =
              num.tryParse(item['subtotal']?.toString() ?? '0')?.toDouble() ??
              0.0;

          if (qty <= 0) continue;

          // Resolve to the canonical product: productId first (reliable —
          // confirmed present on every item in your real data), normalized
          // name+model as fallback for items with no productId.
          Product? resolvedProduct;
          if (parsedId != 0 && productById.containsKey(parsedId)) {
            resolvedProduct = productById[parsedId];
          } else {
            resolvedProduct =
                productByComposite["${normalize(rawName)}_||_${normalize(rawModel)}"];
          }

          String groupKey;
          if (resolvedProduct != null) {
            groupKey = "PID_${resolvedProduct.id}";
          } else if (rawName.isNotEmpty) {
            groupKey = "${normalize(rawName)}_||_${normalize(rawModel)}";
          } else {
            groupKey = "RAWID_$parsedId";
          }

          if (qtyMap.containsKey(groupKey)) {
            qtyMap[groupKey] = qtyMap[groupKey]! + qty;
            revMap[groupKey] = revMap[groupKey]! + subtotal;
          } else {
            qtyMap[groupKey] = qty;
            revMap[groupKey] = subtotal;
            backupNameMap[groupKey] =
                rawName.isEmpty ? 'Unknown Item' : rawName;
            backupModelMap[groupKey] = rawModel;
            backupIdMap[groupKey] = parsedId;
          }
        }
      }

      List<HotSalesData> tempList = [];

      qtyMap.forEach((groupKey, qty) {
        Product? realProduct;
        if (groupKey.startsWith('PID_')) {
          int id = int.tryParse(groupKey.substring(4)) ?? 0;
          realProduct = productById[id];
        } else {
          realProduct = productByComposite[groupKey];
          if (realProduct == null && backupIdMap[groupKey] != 0) {
            realProduct = productById[backupIdMap[groupKey]];
          }
        }

        if (realProduct != null) {
          tempList.add(HotSalesData(realProduct, qty, revMap[groupKey] ?? 0.0));
        } else {
          Product virtualProduct = Product(
            id: backupIdMap[groupKey] ?? 0,
            name: backupNameMap[groupKey] ?? 'Deleted Product',
            category: 'Archived',
            brand: '-',
            model: backupModelMap[groupKey] ?? '-',
            weight: 0,
            yuan: 0,
            air: 0,
            sea: 0,
            agent: 0,
            wholesale: 0,
            shipmentTax: 0,
            shipmentNo: 0,
            currency: 0,
            stockQty: 0,
            avgPurchasePrice: 0,
            seaStockQty: 0,
            airStockQty: 0,
            localQty: 0,
          );
          tempList.add(
            HotSalesData(virtualProduct, qty, revMap[groupKey] ?? 0.0),
          );
        }
      });

      tempList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
      allHotProducts.assignAll(tempList);
      currentPage.value = 1;
      _lastFetchedAt = DateTime.now();

      _applySearchAndPagination();
    } finally {
      isLoading.value = false;
    }
  }

  bool _shouldIncludeOrder(Map<String, dynamic> data) {
    if (filterType.value == 'All') return true;

    DateTime orderDate;
    if (data['timestamp'] != null) {
      orderDate = (data['timestamp'] as Timestamp).toDate();
    } else if (data['date'] != null) {
      orderDate = DateTime.tryParse(data['date']) ?? DateTime.now();
    } else {
      return false;
    }
    DateTime target = selectedDate.value;
    if (filterType.value == 'Daily') {
      return orderDate.year == target.year &&
          orderDate.month == target.month &&
          orderDate.day == target.day;
    } else if (filterType.value == 'Monthly') {
      return orderDate.year == target.year && orderDate.month == target.month;
    } else if (filterType.value == 'Yearly') {
      return orderDate.year == target.year;
    }
    return true;
  }

  void setFilter(String type) {
    filterType.value = type;
    fetchSalesData(forceRefresh: true);
  }

  void updateDate(DateTime newDate) {
    selectedDate.value = newDate;
    fetchSalesData(forceRefresh: true);
  }

  void search(String query) {
    searchQuery.value = query;
    currentPage.value = 1;
    _applySearchAndPagination();
  }

  void _applySearchAndPagination() {
    List<HotSalesData> temp;
    if (searchQuery.value.isEmpty) {
      temp = allHotProducts;
    } else {
      temp =
          allHotProducts.where((item) {
            return item.product.name.toLowerCase().contains(
                  searchQuery.value.toLowerCase(),
                ) ||
                item.product.model.toLowerCase().contains(
                  searchQuery.value.toLowerCase(),
                );
          }).toList();
    }
    filteredList.assignAll(temp);
    updatePageData();
  }

  void updatePageData() {
    int start = (currentPage.value - 1) * itemsPerPage;
    int end = start + itemsPerPage;

    if (start >= filteredList.length) {
      start = 0;
      currentPage.value = 1;
    }
    if (end > filteredList.length) end = filteredList.length;

    if (filteredList.isNotEmpty) {
      displayList.assignAll(filteredList.sublist(start, end));
    } else {
      displayList.clear();
    }
  }

  void nextPage() {
    if (currentPage.value < totalPages) {
      currentPage.value++;
      updatePageData();
    }
  }

  void prevPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      updatePageData();
    }
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  // Call this from a manual "Refresh" button in the UI whenever the
  // user wants the absolute latest numbers, bypassing the cache.
  void refreshNow() => fetchSalesData(forceRefresh: true);
}
