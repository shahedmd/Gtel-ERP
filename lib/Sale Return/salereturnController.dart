// ignore_for_file: deprecated_member_use, file_names, empty_catches, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/controller.dart';

class SaleReturnController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Inject Product Controller for Stock updates
  final ProductController productCtrl = Get.find<ProductController>();

  // --- STATE ---
  var searchController = TextEditingController();
  var isLoading = false.obs;
  var orderData = Rxn<Map<String, dynamic>>();
  var orderItems = <Map<String, dynamic>>[].obs;

  // Track quantities to return
  var returnQuantities = <String, int>{}.obs;
  // Track where the returned stock goes (Local/Air/Sea)
  var returnDestinations = <String, String>{}.obs;

  // --- HELPERS (Safe Parsing) ---
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

  // --- 1. SEARCH INVOICE ---
  Future<void> findInvoice(String invoiceId) async {
    if (invoiceId.isEmpty) return;
    isLoading.value = true;

    // Reset State
    orderData.value = null;
    orderItems.clear();
    returnQuantities.clear();
    returnDestinations.clear();

    try {
      // Trim to prevent whitespace errors
      final doc =
          await _db.collection('sales_orders').doc(invoiceId.trim()).get();

      if (!doc.exists) {
        Get.snackbar("Not Found", "Invoice #$invoiceId does not exist.");
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      orderData.value = data;

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

          orderItems.add(safeItem);

          // Initialize return tracking
          String pid = safeItem['productId'];
          if (pid.isNotEmpty) {
            returnQuantities[pid] = 0;
            returnDestinations[pid] = "Local"; // Default destination
          }
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Search Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- 2. UI LOGIC ---
  void incrementReturn(String productId, int maxQty) {
    int current = returnQuantities[productId] ?? 0;
    if (current < maxQty) {
      returnQuantities[productId] = current + 1;
    }
  }

  void decrementReturn(String productId) {
    int current = returnQuantities[productId] ?? 0;
    if (current > 0) {
      returnQuantities[productId] = current - 1;
    }
  }

  void setDestination(String productId, String destination) {
    returnDestinations[productId] = destination;
  }

  // Calculate value of items being returned
  double get totalRefundAmount {
    double total = 0.0;
    for (var item in orderItems) {
      String pid = toStr(item['productId']);
      int qty = returnQuantities[pid] ?? 0;
      double rate = toDouble(item['saleRate']);
      total += (qty * rate);
    }
    return total;
  }

  // --- 3. PROCESS RETURN (CORE LOGIC) ---
  Future<void> processProductReturn() async {
    // A. Validation
    if (totalRefundAmount <= 0) {
      Get.snackbar("Alert", "No items selected for return.");
      return;
    }
    if (orderData.value == null) return;

    isLoading.value = true;
    String invoiceId = toStr(orderData.value!['invoiceId']);
    String debtorId = toStr(orderData.value!['debtorId']);

    // Safety check for ID
    if (invoiceId.isEmpty) {
      isLoading.value = false;
      Get.snackbar("Error", "Invalid Invoice ID in data.");
      return;
    }

    WriteBatch batch = _db.batch();

    try {
      // B. Fetch Current Invoice State
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(invoiceId);
      DocumentSnapshot orderSnap = await orderRef.get();
      if (!orderSnap.exists) throw "Order Document disappeared!";

      Map<String, dynamic> currentOrder =
          orderSnap.data() as Map<String, dynamic>;

      // C. Calculate Reductions
      double refundAmt = 0.0;
      double profitReduce = 0.0;
      double costReduce = 0.0;

      List<dynamic> oldItemsList = currentOrder['items'] ?? [];
      List<Map<String, dynamic>> newItemsList = [];
      List<String> returnedItemSummaries = [];

      for (var rawItem in oldItemsList) {
        if (rawItem is! Map) continue;

        String pid = toStr(rawItem['productId']);
        String name = toStr(rawItem['name']);
        String model = toStr(rawItem['model']);

        int dbQty = toInt(rawItem['qty']);
        double sRate = toDouble(rawItem['saleRate']);
        double cRate = toDouble(rawItem['costRate']);

        int retQty = returnQuantities[pid] ?? 0;

        if (retQty > 0) {
          if (retQty > dbQty) throw "Cannot return more than purchased: $name";

          double itemRefund = retQty * sRate;
          double itemCost = retQty * cRate;
          double itemProfit = (sRate - cRate) * retQty;

          refundAmt += itemRefund;
          costReduce += itemCost;
          profitReduce += itemProfit;

          dbQty = dbQty - retQty; // Reduce qty in Invoice
          returnedItemSummaries.add("$model (Returned x$retQty)");
        }

        // Add to new list (even if qty is 0, we keep it to show it was returned)
        newItemsList.add({
          "productId": pid,
          "name": name,
          "model": model,
          "qty": dbQty,
          "saleRate": sRate,
          "costRate": cRate,
          "subtotal": toDouble(dbQty * sRate),
        });
      }

      // D. Financial Adjustment Logic (CRITICAL)
      double oldGT = toDouble(currentOrder['grandTotal']);
      double oldP = toDouble(currentOrder['profit']);
      double oldC = toDouble(currentOrder['totalCost']);

      double newGT = oldGT - refundAmt;
      double newP = oldP - profitReduce;
      double newC = oldC - costReduce;

      Map<String, dynamic> oldPay =
          currentOrder['paymentDetails'] is Map
              ? Map<String, dynamic>.from(currentOrder['paymentDetails'])
              : {};

      double paidSoFar = toDouble(oldPay['actualReceived']);

      // Logic:
      // If I bought 5000, paid 2000 (Due 3000). Return 1000.
      // New Total: 4000. Paid is still 2000. New Due: 2000.
      //
      // If I bought 5000, paid 5000 (Due 0). Return 1000.
      // New Total: 4000. Paid 5000. Change/Credit: 1000.
      // We do NOT reduce 'actualReceived' usually, unless you literally gave them cash back.
      // Assuming for Debtor/System, we adjust the BILL, not the cash flow history.

      double newDue = newGT - paidSoFar;
      if (newDue < 0)
        newDue = 0; // Negative due implies we owe them money (Credit)

      Map<String, dynamic> newPayDetails = {
        ...oldPay, // Keep method types
        "due": newDue,
        "changeReturned": (paidSoFar > newGT) ? (paidSoFar - newGT) : 0,
        // Note: We don't change 'actualReceived' because that money was historically received.
        // We just change the 'Due' obligation.
      };

      // 1. UPDATE SALES ORDER
      batch.update(orderRef, {
        'items': newItemsList,
        'grandTotal': newGT < 0 ? 0.0 : newGT,
        'profit': newP,
        'totalCost': newC < 0 ? 0.0 : newC,
        'paymentDetails': newPayDetails,
        'status': 'returned_partial',
        'lastReturnDate': FieldValue.serverTimestamp(),
        'subtotal': newGT < 0 ? 0.0 : newGT,
      });

      // 2. UPDATE DEBTOR LEDGER (If Applicable)
      if (debtorId.isNotEmpty) {
        // Find the specific transaction document for this invoice
        DocumentReference debtorTxRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invoiceId);

        DocumentSnapshot debTxSnap = await debtorTxRef.get();

        if (debTxSnap.exists) {
          // We update the transaction 'amount' to the New Grand Total.
          // This automatically fixes the balance calculation when you fetch debtor details.
          batch.update(debtorTxRef, {
            'amount': newGT,
            'note':
                "Inv $invoiceId (Returned: ${refundAmt.toStringAsFixed(0)})",
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Also update the Analytics History (Profit/Loss tracking)
        DocumentReference analyticsRef = _db
            .collection('debtor_transaction_history')
            .doc(invoiceId);
        // We use set with merge just in case the doc doesn't exist (legacy data)
        batch.set(analyticsRef, {
          "saleAmount": newGT,
          "costAmount": newC,
          "profit": newP,
          "returnDate": FieldValue.serverTimestamp(),
          "itemsSummary": FieldValue.arrayUnion(
            returnedItemSummaries,
          ), // Add return logs
        }, SetOptions(merge: true));
      }

      // 3. UPDATE DAILY SALES ENTRY
      // We need to find the daily sales entry to reduce the 'Amount' (Revenue)
      final dailyQuery =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: invoiceId)
              .limit(1)
              .get();

      if (dailyQuery.docs.isNotEmpty) {
        DocumentSnapshot dailySnap = dailyQuery.docs.first;
        // Reduce the recorded sales amount
        batch.update(dailySnap.reference, {
          'amount': newGT,
          // If pending was positive, recalculate it
          'pending': newDue,
        });
      }

      // 4. COMMIT DB UPDATES
      await batch.commit();

      // 5. STOCK RESTORATION (Separate from DB Batch if using Custom Logic)
      // Iterating through returns to restore stock
      for (var pid in returnQuantities.keys) {
        int qty = returnQuantities[pid]!;
        if (qty > 0) {
          String dest = returnDestinations[pid] ?? "Local";

          // Get Cost Price for restoration logic
          var itemInfo = orderItems.firstWhere(
            (e) => toStr(e['productId']) == pid,
            orElse: () => {},
          );
          double originalCost = toDouble(itemInfo['costRate']);

          int? parsedPid = int.tryParse(pid);

          if (parsedPid != null) {
            try {
              // Using your existing stock method
              await productCtrl.addMixedStock(
                productId: parsedPid,
                localQty: dest == "Local" ? qty : 0,
                airQty: dest == "Air" ? qty : 0,
                seaQty: dest == "Sea" ? qty : 0,
                localUnitPrice: originalCost,
              );
            } catch (e) {
              print("Stock Restore Error for $pid: $e");
              Get.snackbar(
                "Warning",
                "Stock update failed for ID $pid (Check Connection)",
              );
            }
          }
        }
      }

      Get.back(); // Close Dialog if open
      Get.snackbar(
        "Return Successful",
        "Invoice adjusted & Stock restored.\nNew Bill Total: ৳$newGT",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      // Cleanup
      orderData.value = null;
      searchController.clear();
      orderItems.clear();
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
