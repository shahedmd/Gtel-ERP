import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ProfitLossController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<Map<String, dynamic>> customerOrders =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> debtorOrders =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  // Analytics Totals
  final RxDouble totalRevenue = 0.0.obs; // What customers paid you
  final RxDouble totalCost = 0.0.obs; // What you paid vendors (buying price)
  final RxDouble totalProfit = 0.0.obs; // Your take-home money

  @override
  void onInit() {
    super.onInit();
    fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    isLoading.value = true;
    try {
      // 1. Fetch ALL Customer Orders from the sub-collections
      // This looks into customers/{phone}/orders/{id}
      QuerySnapshot customerSnap =
          await _db
              .collectionGroup('orders')
              .orderBy('timestamp', descending: true)
              .get();

      // 2. Fetch ALL Debtor Orders (from the flat collection)
      QuerySnapshot debtorSnap =
          await _db
              .collection('debtorProfitLoss')
              .orderBy('timestamp', descending: true)
              .get();

      customerOrders.clear();
      debtorOrders.clear();

      double rev = 0;
      double cost = 0;
      double prof = 0;

      // Process Normal Customer Data
      for (var doc in customerSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        customerOrders.add(data);
        rev += (data['totalAmount'] ?? 0).toDouble();
        cost += (data['costAmount'] ?? 0).toDouble();
        prof += (data['profit'] ?? 0).toDouble();
      }

      // Process Debtor Data
      for (var doc in debtorSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        debtorOrders.add(data);
        rev += (data['saleAmount'] ?? 0).toDouble(); // Debtors use 'saleAmount'
        cost += (data['costAmount'] ?? 0).toDouble();
        prof += (data['profit'] ?? 0).toDouble();
      }

      totalRevenue.value = rev;
      totalCost.value = cost;
      totalProfit.value = prof;
    } catch (e) {
      print("ERROR FETCHING PROFITS: $e");
      Get.snackbar(
        "Index Required",
        "Please check your debug console to create a Firestore Index.",
      );
    } finally {
      isLoading.value = false;
    }
  }
}
