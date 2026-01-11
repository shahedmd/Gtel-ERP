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

  // --- PAGINATION STATE (FUTURE PROOFING) ---
  final int _limit = 20; // Load 20 items at a time
  DocumentSnapshot? _lastDocument; // Track the last loaded document
  final RxBool hasMore = true.obs; // Check if more data exists in DB
  final RxBool isMoreLoading = false.obs; // Prevent multiple fetch calls

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
    loadConditionSales(); // Initial Load

    ever(selectedFilter, (_) => _applyFilters());
    ever(searchQuery, (_) => _applyFilters());
    ever(selectedCourierFilter, (_) => _applyFilters());
  }

  // --- HELPERS ---
  double toDouble(dynamic val) {
    if (val == null) return 0.0;
    double? d = double.tryParse(val.toString());
    return (d == null || d.isNaN) ? 0.0 : d;
  }

  int toInt(dynamic val) {
    if (val == null) return 0;
    int? i = int.tryParse(val.toString());
    return i ?? 0;
  }

  String toStr(dynamic val) => val?.toString() ?? "";

  // Helper to ensure Stock Location is always Capitalized (e.g. "sea" -> "Sea")
  String _normalizeLocation(String? input) {
    if (input == null || input.isEmpty) return "Sea"; // Default fallback
    String trimmed = input.trim();
    if (trimmed.isEmpty) return "Sea";
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  // ==============================================================================
  // 1. DATA LOADING & FILTERING (PAGINATED)
  // ==============================================================================

  /// Loads data. Call this without arguments for initial load/refresh.
  /// set [loadMore] to true when scrolling down.
  Future<void> loadConditionSales({bool loadMore = false}) async {
    // Prevent loading if already loading or no more data
    if (loadMore) {
      if (isMoreLoading.value || !hasMore.value) return;
      isMoreLoading.value = true;
    } else {
      isLoading.value = true;
      _lastDocument = null; // Reset for fresh load
      hasMore.value = true;
    }

    try {
      Query query = _db
          .collection('sales_orders')
          .where('isCondition', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(_limit);

      // If pagination, start after the last loaded doc
      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();

      // Check if we reached the end of the collection
      if (snap.docs.length < _limit) {
        hasMore.value = false;
      }

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;

        List<ConditionOrderModel> newOrders =
            snap.docs
                .map((doc) => ConditionOrderModel.fromFirestore(doc))
                .toList();

        if (loadMore) {
          allOrders.addAll(newOrders); // Append
        } else {
          allOrders.value = newOrders; // Overwrite
        }
      } else {
        if (!loadMore) {
          allOrders.clear();
        }
      }

      _calculateStats();
      _applyFilters();
    } catch (e) {
      Get.snackbar("Error", "Could not load condition sales: $e");
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
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

      // Refresh data to reflect changes
      await loadConditionSales(loadMore: false);

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
            // CHANGE: Default destination set to "Sea"
            returnDestinations[pid] = "Sea";
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
    // 1. VALIDATION
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
      // 2. FIRESTORE TRANSACTION FOR LEDGERS & INVOICE
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

        // F. Update Customer's Specific Order Document (Subcollection)
        DocumentReference custOrderRef = custRef
            .collection('orders')
            .doc(invoiceId);
        transaction.update(custOrderRef, {
          "grandTotal": newGT,
          "courierDue": newDue,
          "items": newItems,
          "status": newDue <= 0 ? "returned_completed" : "pending_courier",
        });

        // G. Handle Daily Sales
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

      // 3. STOCK RESTORATION (OPTIMIZED & SAFE)
      // Using Future.wait for parallel execution, with safe capitalization
      List<Future<void>> stockUpdates = [];

      for (var pid in returnQuantities.keys) {
        int qty = returnQuantities[pid]!;

        if (qty > 0) {
          // Future Proofing: Normalize "sea" to "Sea" to match Product Controller keys exactly
          String rawDest = returnDestinations[pid] ?? "Sea";
          String dest = _normalizeLocation(rawDest);

          // Get Original Cost Price
          var itemInfo = returnOrderItems.firstWhere(
            (e) => toStr(e['productId']) == pid,
            orElse: () => {},
          );
          double originalCost = toDouble(itemInfo['costRate']);

          int? parsedPid = int.tryParse(pid);

          if (parsedPid != null) {
            // Add update task to list
            stockUpdates.add(
              productCtrl
                  .addMixedStock(
                    productId: parsedPid,
                    localQty: dest == "Local" ? qty : 0,
                    airQty: dest == "Air" ? qty : 0,
                    seaQty: dest == "Sea" ? qty : 0,
                    localUnitPrice: originalCost,
                  )
                  .catchError((e) {
                    // Catch individual errors so one failure doesn't crash the whole batch
                    print("Stock Restore Error for $pid: $e");
                  }),
            );
          }
        }
      }

      // Execute all stock updates concurrently
      if (stockUpdates.isNotEmpty) {
        await Future.wait(stockUpdates);
      }

      // 4. CLEANUP
      // Refresh only the first page to see latest status
      await loadConditionSales(loadMore: false);

      returnOrderData.value = null;
      returnOrderItems.clear();
      returnSearchCtrl.clear();

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Return Complete",
        "Stock Restored to SEA & All Ledgers Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
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
