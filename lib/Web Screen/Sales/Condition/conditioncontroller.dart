// ignore_for_file: deprecated_member_use, avoid_print, empty_catches
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';



class ConditionSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Dependencies
  final DailySalesController dailyCtrl = Get.find<DailySalesController>();
  final ProductController productCtrl = Get.find<ProductController>();

  // --- OBSERVABLES ---
  final RxList<ConditionOrderModel> allOrders = <ConditionOrderModel>[].obs;
  final RxList<ConditionOrderModel> filteredOrders =
      <ConditionOrderModel>[].obs;
  final RxBool isLoading = false.obs;

  // Stats
  final RxDouble totalPendingAmount = 0.0.obs;
  final RxMap<String, double> courierBalances = <String, double>{}.obs;

  // Filters
  final RxString selectedFilter = "All Time".obs;
  final RxString searchQuery = "".obs;
  final RxString selectedCourierFilter = "All".obs;

  // --- RETURN LOGIC STATE ---
  final returnSearchCtrl = TextEditingController();
  final Rxn<Map<String, dynamic>> returnOrderData = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> returnOrderItems =
      <Map<String, dynamic>>[].obs;
  final RxMap<String, int> returnQuantities = <String, int>{}.obs;
  final RxMap<String, String> returnDestinations = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadConditionSales();

    ever(selectedFilter, (_) => _applyFilters());
    ever(searchQuery, (_) => _applyFilters());
    ever(selectedCourierFilter, (_) => _applyFilters());
  }

  // ==============================================================================
  // 1. DATA LOADING & FILTERING
  // ==============================================================================

  Future<void> loadConditionSales() async {
    isLoading.value = true;
    try {
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
      Get.snackbar("Error", "Could not load condition sales: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _applyFilters() {
    DateTime now = DateTime.now();
    List<ConditionOrderModel> temp = List.from(allOrders);

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

    if (selectedCourierFilter.value != "All") {
      temp =
          temp
              .where((o) => o.courierName == selectedCourierFilter.value)
              .toList();
    }

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

  void _calculateStats() {
    double total = 0.0;
    Map<String, double> cBalances = {};

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

  // ==============================================================================
  // 2. PAYMENT RECEIVING
  // ==============================================================================


  Future<void> receiveConditionPayment({
    required ConditionOrderModel order,
    required double receivedAmount,
    required String method,
    String? refNumber,
  }) async {
    if (receivedAmount <= 0) return;
    if (receivedAmount > order.courierDue) {
      Get.snackbar("Error", "Amount exceeds due balance");
      return;
    }

    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();

      // 1. Update Invoice
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(order.invoiceId);
      double newDue = order.courierDue - receivedAmount;

      batch.update(orderRef, {
        "courierDue": newDue,
        "status": newDue <= 0 ? "completed" : "on_delivery",
        "isFullyPaid": newDue <= 0,
        "collectionHistory": FieldValue.arrayUnion([
          {
            "amount": receivedAmount,
            "date": Timestamp.now(),
            "method": method,
            "ref": refNumber,
            "type": "courier_collection",
          },
        ]),
      });

      // 2. Update Courier Ledger
      DocumentReference courierRef = _db
          .collection('courier_ledgers')
          .doc(order.courierName);
      batch.set(courierRef, {
        "totalDue": FieldValue.increment(-receivedAmount),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update Customer Condition Ledger
      DocumentReference custRef = _db
          .collection('condition_customers')
          .doc(order.customerPhone);
      batch.update(custRef, {
        "totalCourierDue": FieldValue.increment(-receivedAmount),
      });

      await batch.commit();

      // 4. Add to Daily Sales
      await dailyCtrl.addSale(
        name: "${order.courierName} (Ref: ${order.invoiceId})",
        amount: receivedAmount,
        customerType: "courier_payment",
        date: DateTime.now(),
        source: "condition_recovery",
        isPaid: true,
        paymentMethod: {
          "type": method.toLowerCase(),
          "details": refNumber ?? "Collection from ${order.courierName}",
          "courier": order.courierName,
        },
        transactionId: order.invoiceId,
      );

      await loadConditionSales();
      Get.back();
      Get.snackbar(
        "Success",
        "Payment received & Ledgers Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Transaction failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==============================================================================
  // 3. RETURN LOGIC
  // ==============================================================================

  double toDouble(dynamic val) => double.tryParse(val.toString()) ?? 0.0;
  int toInt(dynamic val) => int.tryParse(val.toString()) ?? 0;
  String toStr(dynamic val) => val?.toString() ?? "";

  Future<void> findInvoiceForReturn(String invoiceId) async {
    if (invoiceId.isEmpty) return;
    isLoading.value = true;
    returnOrderData.value = null;
    returnOrderItems.clear();
    returnQuantities.clear();
    returnDestinations.clear();

    try {
      final doc =
          await _db.collection('sales_orders').doc(invoiceId.trim()).get();

      if (!doc.exists) {
        Get.snackbar("Not Found", "Invoice not found.");
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data['isCondition'] != true) {
        Get.snackbar("Invalid Type", "This is not a Condition Sale invoice.");
        return;
      }

      returnOrderData.value = data;
      List<dynamic> rawItems = data['items'] ?? [];

      for (var item in rawItems) {
        if (item is Map) {
          Map<String, dynamic> safeItem = {
            "productId": toStr(item['productId']),
            "name": toStr(item['name']),
            "model": toStr(item['model']),
            "qty": toInt(item['qty']),
            "saleRate": toDouble(item['saleRate']),
            "costRate": toDouble(item['costRate']),
            "subtotal": toDouble(item['subtotal']),
          };
          returnOrderItems.add(safeItem);
          String pid = safeItem['productId'];
          if (pid.isNotEmpty) {
            returnQuantities[pid] = 0;
            returnDestinations[pid] = "Local";
          }
        }
      }
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void incrementReturn(String pid, int max) {
    int cur = returnQuantities[pid] ?? 0;
    if (cur < max) returnQuantities[pid] = cur + 1;
  }

  void decrementReturn(String pid) {
    int cur = returnQuantities[pid] ?? 0;
    if (cur > 0) returnQuantities[pid] = cur - 1;
  }

  void setDestination(String pid, String dest) {
    returnDestinations[pid] = dest;
  }

  double get totalRefundValue {
    double total = 0.0;
    for (var item in returnOrderItems) {
      String pid = toStr(item['productId']);
      int qty = returnQuantities[pid] ?? 0;
      double rate = toDouble(item['saleRate']);
      total += (qty * rate);
    }
    return total;
  }

  Future<void> processConditionReturn() async {
    if (totalRefundValue <= 0) {
      Get.snackbar("Alert", "Select items to return");
      return;
    }
    if (returnOrderData.value == null) return;

    isLoading.value = true;
    String invoiceId = toStr(returnOrderData.value!['invoiceId']);
    String courierName = toStr(returnOrderData.value!['courierName']);
    String custPhone = toStr(returnOrderData.value!['customerPhone']);

    try {
      // 1. RESTORE STOCK (HTTP)
      List<Map<String, dynamic>> restockUpdates = [];
      for (var item in returnOrderItems) {
        String pid = item['productId'];
        int qty = returnQuantities[pid] ?? 0;
        if (qty > 0) {
          restockUpdates.add({'id': pid, 'qty': -qty}); // Negative to Add stock
        }
      }

      bool stockSuccess = await productCtrl.updateStockBulk(restockUpdates);
      if (!stockSuccess) throw "Stock restoration failed";

      // 2. FIRESTORE TRANSACTION
      await _db.runTransaction((transaction) async {
        // A. Read Master Sales Order
        DocumentReference orderRef = _db
            .collection('sales_orders')
            .doc(invoiceId);
        DocumentSnapshot orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) throw "Order missing";

        Map<String, dynamic> currentData =
            orderSnap.data() as Map<String, dynamic>;

        // B. Rebuild Items & Financials
        List<dynamic> oldItems = currentData['items'] ?? [];
        List<Map<String, dynamic>> newItems = [];
        double refundAmt = 0.0;
        double profitReduce = 0.0;
        double costReduce = 0.0;

        for (var rawItem in oldItems) {
          String pid = toStr(rawItem['productId']);
          int dbQty = toInt(rawItem['qty']);
          double sRate = toDouble(rawItem['saleRate']);
          double cRate = toDouble(rawItem['costRate']);

          int retQty = returnQuantities[pid] ?? 0;

          if (retQty > 0) {
            refundAmt += (retQty * sRate);
            costReduce += (retQty * cRate);
            profitReduce += (retQty * (sRate - cRate));
            dbQty -= retQty;
          }

          newItems.add({...rawItem, "qty": dbQty, "subtotal": dbQty * sRate});
        }

        double oldGT = toDouble(currentData['grandTotal']);
        double newGT = oldGT - refundAmt;
        double oldDue = toDouble(currentData['courierDue']);
        double newDue = oldDue - refundAmt;
        if (newDue < 0) newDue = 0;

        // C. Update Master Sales Order
        transaction.update(orderRef, {
          "items": newItems,
          "grandTotal": newGT,
          "courierDue": newDue,
          "profit": toDouble(currentData['profit']) - profitReduce,
          "totalCost": toDouble(currentData['totalCost']) - costReduce,
          "status": newDue <= 0 ? "returned_completed" : "returned_partial",
          "subtotal": newGT,
          "lastReturnDate": FieldValue.serverTimestamp(),
        });

        // D. Update Courier Ledger (Reduce Debt)
        DocumentReference courierRef = _db
            .collection('courier_ledgers')
            .doc(courierName);
        transaction.update(courierRef, {
          "totalDue": FieldValue.increment(-refundAmt),
          "lastUpdated": FieldValue.serverTimestamp(),
        });

        // E. Update Condition Customer Ledger (Parent Total)
        DocumentReference custRef = _db
            .collection('condition_customers')
            .doc(custPhone);
        transaction.update(custRef, {
          "totalCourierDue": FieldValue.increment(-refundAmt),
        });

        // F. Update Customer's Specific Order Document (Subcollection) - 🔥 NEW REQ
        DocumentReference custOrderRef = custRef
            .collection('orders')
            .doc(invoiceId);
        transaction.update(custOrderRef, {
          "grandTotal": newGT,
          "courierDue": newDue,
          "items": newItems, // Update the array inside the customer history too
          "status":
              newDue <= 0
                  ? "returned_completed"
                  : "pending_courier", // Status match
        });

        // G. Handle Daily Sales (if applicable)
        final dailyQuery =
            await _db
                .collection('daily_sales')
                .where('transactionId', isEqualTo: invoiceId)
                .limit(1)
                .get();

        if (dailyQuery.docs.isNotEmpty) {
          DocumentSnapshot dailySnap = dailyQuery.docs.first;
          transaction.update(dailySnap.reference, {
            "amount": newGT,
            "pending": newDue,
            "note": "Adjusted via Return (-$refundAmt)",
          });
        }
      });

      await loadConditionSales();
      returnOrderData.value = null;
      returnOrderItems.clear();
      returnSearchCtrl.clear();
      Get.back();
      Get.snackbar(
        "Return Complete",
        "Stock Restored & All Ledgers (Main, Courier, Customer) Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Return Failed",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
