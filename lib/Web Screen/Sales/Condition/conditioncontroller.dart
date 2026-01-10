// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';

class ConditionSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DailySalesController dailyCtrl = Get.find<DailySalesController>();

  // --- OBSERVABLES ---
  final RxList<ConditionOrderModel> allOrders = <ConditionOrderModel>[].obs;
  final RxList<ConditionOrderModel> filteredOrders =
      <ConditionOrderModel>[].obs;
  final RxBool isLoading = false.obs;

  // Stats
  final RxDouble totalPendingAmount = 0.0.obs;
  final RxMap<String, double> courierBalances = <String, double>{}.obs;

  // Filters
  final RxString selectedFilter =
      "All Time".obs; // Today, This Month, This Year, All Time
  final RxString searchQuery = "".obs;
  final RxString selectedCourierFilter = "All".obs;

  @override
  void onInit() {
    super.onInit();
    loadConditionSales();

    // React to filter changes
    ever(selectedFilter, (_) => _applyFilters());
    ever(searchQuery, (_) => _applyFilters());
    ever(selectedCourierFilter, (_) => _applyFilters());
  }

  // 1. LOAD DATA
  Future<void> loadConditionSales() async {
    isLoading.value = true;
    try {
      // Fetch ONLY condition sales
      final snap =
          await _db
              .collection('sales_orders')
              .where('isCondition', isEqualTo: true)
              .orderBy('timestamp', descending: true)
              .get();

      allOrders.value =
          snap.docs
              .map((doc) => ConditionOrderModel.fromFirestore(doc))
              .toList();
      _calculateStats();
      _applyFilters();
    } catch (e) {
      print(e.toString());
      Get.snackbar("Error", "Could not load condition sales: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 2. APPLY LOCAL FILTERS (Date & Search)
  void _applyFilters() {
    DateTime now = DateTime.now();
    List<ConditionOrderModel> temp = List.from(allOrders);

    // A. Date Filter
    if (selectedFilter.value == "Today") {
      temp =
          temp
              .where(
                (o) =>
                    o.date.year == now.year &&
                    o.date.month == now.month &&
                    o.date.day == now.day,
              )
              .toList();
    } else if (selectedFilter.value == "This Month") {
      temp =
          temp
              .where(
                (o) => o.date.year == now.year && o.date.month == now.month,
              )
              .toList();
    } else if (selectedFilter.value == "This Year") {
      temp = temp.where((o) => o.date.year == now.year).toList();
    }

    // B. Courier Filter
    if (selectedCourierFilter.value != "All") {
      temp =
          temp
              .where((o) => o.courierName == selectedCourierFilter.value)
              .toList();
    }

    // C. Search Filter
    if (searchQuery.value.isNotEmpty) {
      String q = searchQuery.value.toLowerCase();
      temp =
          temp
              .where(
                (o) =>
                    o.customerName.toLowerCase().contains(q) ||
                    o.invoiceId.toLowerCase().contains(q) ||
                    o.customerPhone.contains(q) ||
                    o.challanNo.contains(q),
              )
              .toList();
    }

    filteredOrders.value = temp;
  }

  // 3. CALCULATE STATS (Live Debt)
  void _calculateStats() {
    double total = 0.0;
    Map<String, double> cBalances = {};

    // We calculate stats on ALL outstanding orders, not just filtered ones
    // to give the owner a true picture of debt.
    for (var order in allOrders) {
      if (order.courierDue > 0) {
        total += order.courierDue;

        if (cBalances.containsKey(order.courierName)) {
          cBalances[order.courierName] =
              cBalances[order.courierName]! + order.courierDue;
        } else {
          cBalances[order.courierName] = order.courierDue;
        }
      }
    }

    totalPendingAmount.value = total;
    courierBalances.value = cBalances;
  }

  // 4. PROCESS PAYMENT (The Critical Part)
  Future<void> receiveConditionPayment({
    required ConditionOrderModel order,
    required double receivedAmount,
    required String method, // Cash, Bank, etc.
    String? refNumber,
  }) async {
    if (receivedAmount <= 0) return;
    if (receivedAmount > order.courierDue) {
      Get.snackbar("Error", "Amount exceeds due balance");
      return;
    }

    isLoading.value = true;
    try {
      // STEP 1: Update the Invoice Logic
      double newDue = order.courierDue - receivedAmount;
      String newStatus = newDue <= 0 ? "completed" : "on_delivery";

      // Create a history entry for the invoice
      Map<String, dynamic> collectionEntry = {
        "amount": receivedAmount,
        "date": Timestamp.now(),
        "method": method,
        "ref": refNumber,
        "type": "courier_collection",
      };

      await _db.collection('sales_orders').doc(order.invoiceId).update({
        "courierDue": newDue,
        "status": newStatus,
        "isFullyPaid": newDue <= 0,
        // Append to history
        "collectionHistory": FieldValue.arrayUnion([collectionEntry]),
      });

      // STEP 2: Add to Daily Sales Ledger (Cash Flow)
      // This ensures your daily accounts match the cash in hand
      await dailyCtrl.addSale(
        name: "${order.courierName} (Ref: ${order.invoiceId})",
        amount: receivedAmount,
        customerType: "courier_payment", // Special tag for reporting
        date: DateTime.now(),
        source: "condition_recovery",
        isPaid: true,
        paymentMethod: {
          "type": method.toLowerCase(),
          "details": refNumber ?? "Collection from ${order.courierName}",
          "courier": order.courierName,
        },
        transactionId: order.invoiceId,
        // Optional: If you want to link specific debits
        appliedDebits: [
          {"id": order.invoiceId, "amount": receivedAmount},
        ],
      );

      // STEP 3: Update local state
      await loadConditionSales();
      Get.back(); // Close dialog
      Get.snackbar(
        "Success",
        "Payment received & added to Daily Sales",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print(e.toString());
      Get.snackbar("Error", "Transaction failed: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
