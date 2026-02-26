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

    // Maps for aggregation
    Map<String, int> qtyMap = {};
    Map<String, double> revMap = {};

    // Maps to store "Backup" details from the order itself
    // (In case the product is deleted from inventory, we still have its name)
    Map<String, String> backupNameMap = {};
    Map<String, String> backupModelMap = {};

    try {
      // 1. Always ensure we have products loaded
      if (productCtrl.allProducts.isEmpty) {
        await productCtrl.fetchProducts();
      }

      // Create a lookup map for speed
      Map<String, Product> productLookup = {
        for (var p in productCtrl.allProducts) p.id.toString(): p,
      };

      // 2. Fetch Orders
      QuerySnapshot snapshot =
          await _db
              .collection('sales_orders')
              .orderBy('timestamp', descending: true)
              .limit(2000)
              .get();

      // 3. Loop Orders
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Apply Date Filter
        if (!_shouldIncludeOrder(data)) continue;

        List<dynamic> items = data['items'] ?? [];

        for (var item in items) {
          String pId = item['productId'].toString();
          if (pId == 'null' || pId.isEmpty || pId == '0') continue;

          int qty = int.tryParse(item['qty'].toString()) ?? 0;
          double subtotal = double.tryParse(item['subtotal'].toString()) ?? 0.0;
          if (qtyMap.containsKey(pId)) {
            qtyMap[pId] = qtyMap[pId]! + qty;
            revMap[pId] = revMap[pId]! + subtotal;
          } else {
            qtyMap[pId] = qty;
            revMap[pId] = subtotal;
            backupNameMap[pId] = item['name']?.toString() ?? 'Unknown Item';
            backupModelMap[pId] = item['model']?.toString() ?? '-';
          }
        }
      }
      List<HotSalesData> tempList = [];
      qtyMap.forEach((id, qty) {
        Product? realProduct = productLookup[id];

        if (realProduct != null) {
          tempList.add(HotSalesData(realProduct, qty, revMap[id] ?? 0.0));
        } else {
          Product virtualProduct = Product(
            id: int.tryParse(id) ?? 0,
            name: backupNameMap[id] ?? 'Deleted Product ($id)',
            category: 'Archived',
            brand: '-',
            model: backupModelMap[id] ?? '-',
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
          tempList.add(HotSalesData(virtualProduct, qty, revMap[id] ?? 0.0));
        }
      });
      tempList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
      allHotProducts.assignAll(tempList);
      currentPage.value = 1;
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