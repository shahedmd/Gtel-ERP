import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class CashDrawerController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Observables
  final RxList<Map<String, dynamic>> filteredSales =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  // Selected Date Filters
  final RxInt selectedYear = DateTime.now().year.obs;
  final RxInt selectedMonth = DateTime.now().month.obs;

  // Totals for the selected period
  final RxDouble cashTotal = 0.0.obs;
  final RxDouble bkashTotal = 0.0.obs;
  final RxDouble nagadTotal = 0.0.obs;
  final RxDouble bankTotal = 0.0.obs;
  final RxDouble grandTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDrawerData();
  }

  Future<void> fetchDrawerData() async {
    isLoading.value = true;
    try {
      // Calculate Start and End of the selected month
      DateTime startOfMonth = DateTime(
        selectedYear.value,
        selectedMonth.value,
        1,
      );
      DateTime endOfMonth = DateTime(
        selectedYear.value,
        selectedMonth.value + 1,
        0,
        23,
        59,
        59,
      );

      QuerySnapshot snap =
          await _db
              .collection('daily_sales')
              .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
              .where('timestamp', isLessThanOrEqualTo: endOfMonth)
              .orderBy('timestamp', descending: true)
              .get();

      double cash = 0, bkash = 0, nagad = 0, bank = 0;
      List<Map<String, dynamic>> tempList = [];

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tempList.add(data);

        // Access nested paymentMethod -> type
        String method =
            (data['paymentMethod']?['type'] ?? 'cash').toString().toLowerCase();
        double amount = (data['paid'] ?? 0.0).toDouble();

        if (method == 'cash') {
          cash += amount;
        }  if (method == 'bkash'){
          bkash += amount;}
         if (method == 'nagad') {
           nagad += amount;
         }
         if (method == 'bank') {
           bank += amount;
         }
      }

      filteredSales.assignAll(tempList);
      cashTotal.value = cash;
      bkashTotal.value = bkash;
      nagadTotal.value = nagad;
      bankTotal.value = bank;
      grandTotal.value = cash + bkash + nagad + bank;
    } catch (e) {
      print("Drawer Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void changeDate(int month, int year) {
    selectedMonth.value = month;
    selectedYear.value = year;
    fetchDrawerData();
  }
}
