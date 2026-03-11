import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';

class HotSalesData {
  final Product product;
  final int totalSold;
  final double totalRevenue;

  HotSalesData(this.product, this.totalSold, this.totalRevenue);
}

class HotSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();

  // --- DATA VARIABLES ---
  var allHotProducts = <HotSalesData>[].obs;
  var filteredList = <HotSalesData>[].obs;
  var displayList = <HotSalesData>[].obs;
  var isLoading = false.obs;
  var searchQuery = ''.obs;

  // --- PAGINATION ---
  var currentPage = 1.obs;
  var itemsPerPage = 20; // Increased default to see more rows

  // --- FILTER ---
  var filterType = 'All'.obs;
  var selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    fetchSalesData();

    // Debounce search for better performance
    debounce(
      searchQuery,
      (_) => _applySearchAndPagination(),
      time: const Duration(milliseconds: 500),
    );
  }

  // --- 1. FETCH AND CALCULATE ---
  Future<void> fetchSalesData() async {
    isLoading.value = true;

    // Maps for aggregation (Grouped by Name + Model to avoid duplicate rows)
    Map<String, int> qtyMap = {};
    Map<String, double> revMap = {};

    // Backup details for virtual/deleted products
    Map<String, String> backupNameMap = {};
    Map<String, String> backupModelMap = {};
    Map<String, int> backupIdMap = {};

    try {
      // 1. Always ensure we have products loaded
      if (productCtrl.allProducts.isEmpty) {
        await productCtrl.fetchProducts();
      }

      // 2. Create a robust lookup map using a Composite Key (Name + Model)
      // This forces exact matches of products to merge, even if their productId changed.
      Map<String, Product> productLookup = {};
      for (var p in productCtrl.allProducts) {
        String pName = p.name.trim().toUpperCase();
        String pModel = p.model.trim().toUpperCase();
        String compositeKey = "${pName}_||_$pModel";

        productLookup[compositeKey] = p;
        productLookup[p.id.toString()] = p; // Fallback by ID
      }

      // 3. Fetch Orders
      QuerySnapshot snapshot =
          await _db
              .collection('sales_orders')
              .orderBy('timestamp', descending: true)
              .limit(2000)
              .get();

      // 4. Loop Orders
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // FIX 1: Allow all statuses (Due, Pending, Completed)
        // We ONLY block "cancelled" or "returned" so they don't falsely inflate your qty.
        String? status = data['status']?.toString().toLowerCase();
        if (status == 'cancelled' || status == 'returned') {
          continue;
        }

        // Apply Date Filter
        if (!_shouldIncludeOrder(data)) continue;

        List<dynamic> items = data['items'] ?? [];

        for (var item in items) {
          // Extract text safely and remove trailing spaces
          String rawName = item['name']?.toString().trim() ?? '';
          String rawModel = item['model']?.toString().trim() ?? '';

          int parsedId =
              num.tryParse(item['productId']?.toString() ?? '0')?.toInt() ?? 0;

          // Skip completely empty items
          if (rawName.isEmpty && parsedId == 0) continue;

          // FIX 2: Build a Composite Key. This forces items with the exact
          // same name and model to merge into ONE row, even if IDs changed.
          String groupKey;
          if (rawName.isNotEmpty) {
            groupKey = "${rawName.toUpperCase()}_||_${rawModel.toUpperCase()}";
          } else {
            groupKey =
                parsedId
                    .toString(); // Fallback to ID if name is completely missing
          }

          // FIX 3: Safely parse num first to prevent database decimals like "10.0" from breaking
          int qty = num.tryParse(item['qty']?.toString() ?? '0')?.toInt() ?? 0;
          double subtotal =
              num.tryParse(item['subtotal']?.toString() ?? '0')?.toDouble() ??
              0.0;

          if (qty <= 0) continue; // Skip negative or zero quantities

          // Aggregate the Data
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

      // 5. Build Final Display List
      List<HotSalesData> tempList = [];

      qtyMap.forEach((groupKey, qty) {
        // Try finding the product by Name+Model first, then fallback to finding it by ID
        Product? realProduct = productLookup[groupKey];
        if (realProduct == null && backupIdMap[groupKey] != 0) {
          realProduct = productLookup[backupIdMap[groupKey].toString()];
        }

        if (realProduct != null) {
          tempList.add(HotSalesData(realProduct, qty, revMap[groupKey] ?? 0.0));
        } else {
          // Product was deleted from inventory completely (Virtual Product)
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

      // Sort heavily sold items to the top
      tempList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
      allHotProducts.assignAll(tempList);
      currentPage.value = 1;

      _applySearchAndPagination();
    }  finally {
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
    fetchSalesData();
  }

  void updateDate(DateTime newDate) {
    selectedDate.value = newDate;
    fetchSalesData();
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
}
