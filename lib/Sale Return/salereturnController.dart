// ignore_for_file: deprecated_member_use, file_names, empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/controller.dart';

class SaleReturnController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();

  // State
  var searchController = TextEditingController();
  var isLoading = false.obs;
  var orderData = Rxn<Map<String, dynamic>>();
  var orderItems = <Map<String, dynamic>>[].obs;

  var returnQuantities = <String, int>{}.obs;
  var returnDestinations = <String, String>{}.obs;

  // --- SAFETY HELPERS ---
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

  String toStr(dynamic val) {
    return val?.toString() ?? "";
  }

  // --- 1. SEARCH INVOICE ---
  Future<void> findInvoice(String invoiceId) async {
    if (invoiceId.isEmpty) return;
    isLoading.value = true;
    orderData.value = null;
    orderItems.clear();
    returnQuantities.clear();
    returnDestinations.clear();

    try {
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

  // --- 2. UI HELPERS ---
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

  // --- 3. CALCULATE TOTAL ---
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

  // --- 4. PROCESS THE RETURN ---
  Future<void> processProductReturn() async {
    // 1. Validation
    if (totalRefundAmount <= 0) {
      Get.snackbar("Error", "No items selected for return.");
      return;
    }

    if (orderData.value == null) {
      Get.snackbar("Error", "Data missing.");
      return;
    }

    isLoading.value = true;
    String invoiceId = toStr(orderData.value!['invoiceId']);
    String debtorId = toStr(orderData.value!['debtorId']);

    // START BATCH
    WriteBatch batch = _db.batch();

    try {
      // 2. GET DOCUMENT REFERENCES
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(invoiceId);
      DocumentSnapshot orderSnap = await orderRef.get();
      if (!orderSnap.exists) throw "Order Missing";

      // 3. PREPARE DATA
      Map<String, dynamic> currentOrder =
          orderSnap.data() as Map<String, dynamic>;

      double refundAmt = 0.0;
      double profitReduce = 0.0;
      double costReduce = 0.0;

      List<dynamic> oldItemsList = currentOrder['items'] ?? [];
      List<Map<String, dynamic>> newItemsList = [];

      // --- REBUILD ITEMS ---
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
          if (retQty > dbQty) throw "Qty Mismatch for $name";

          refundAmt += (retQty * sRate);
          costReduce += (retQty * cRate);
          profitReduce += (retQty * (sRate - cRate));

          dbQty = dbQty - retQty;
        }

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

      // --- RECALCULATE FINANCIALS ---
      double oldGT = toDouble(currentOrder['grandTotal']);
      double oldP = toDouble(currentOrder['profit']);
      double oldC = toDouble(currentOrder['totalCost']);

      double newGT = oldGT - refundAmt;
      double newP = oldP - profitReduce;
      double newC = oldC - costReduce;

      // --- RECALCULATE PAYMENTS ---
      Map<String, dynamic> rawPay =
          currentOrder['paymentDetails'] is Map
              ? Map<String, dynamic>.from(currentOrder['paymentDetails'])
              : {};

      double actualRec = toDouble(rawPay['actualReceived']);
      double totalIn = toDouble(rawPay['totalPaidInput']);

      double newRec =
          (actualRec - refundAmt) < 0 ? 0.0 : (actualRec - refundAmt);
      double newIn = (totalIn - refundAmt) < 0 ? 0.0 : (totalIn - refundAmt);

      // Recalculate Due (Grand Total - Paid)
      // If user paid 500 and bill is now 400, due is 0 (overpaid logic handled via changeReturned usually, but here we floor at 0)
      // If user paid 0 and bill is now 400, due is 400.
      double newDue = newGT - newRec;
      if (newDue < 0) newDue = 0;

      Map<String, dynamic> newPayDetails = {
        "type": toStr(rawPay['type']),
        "cash": toDouble(rawPay['cash']),
        "bkash": toDouble(rawPay['bkash']),
        "nagad": toDouble(rawPay['nagad']),
        "bank": toDouble(rawPay['bank']),
        "due": newDue, // Updated Due
        "changeReturned": toDouble(rawPay['changeReturned']),
        "currency": "BDT",
        "actualReceived": newRec,
        "totalPaidInput": newIn,
      };

      // 4. ADD TO BATCH: SALES ORDER
      batch.update(orderRef, {
        'items': newItemsList,
        'grandTotal': newGT < 0 ? 0.0 : newGT,
        'profit': newP,
        'totalCost': newC < 0 ? 0.0 : newC,
        'paymentDetails': newPayDetails,
        'status': 'returned_partial',
        'lastReturnDate': DateTime.now().toIso8601String(),
        'subtotal': newGT < 0 ? 0.0 : newGT,
      });

      // 5. ADD TO BATCH: DAILY SALES
      final dailyQuery =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: invoiceId)
              .limit(1)
              .get();

      if (dailyQuery.docs.isNotEmpty) {
        DocumentSnapshot dailySnap = dailyQuery.docs.first;
        Map<String, dynamic> dData = dailySnap.data() as Map<String, dynamic>;

        Map<String, dynamic> dPayMethod =
            dData['paymentMethod'] is Map
                ? Map<String, dynamic>.from(dData['paymentMethod'])
                : {};

        dPayMethod['actualReceived'] = newRec;
        dPayMethod['cash'] = newIn;
        dPayMethod['totalPaidInput'] = newIn;

        batch.update(dailySnap.reference, {
          'paid': newRec,
          'amount': newGT, // Amount becomes the new Grand Total
          'paymentMethod': dPayMethod,
        });
      }

      // --- 6. ADD TO BATCH: DEBTOR TRANSACTION (FIXED) ---
      if (debtorId.isNotEmpty) {
        // We look for the document matching invoiceId
        DocumentReference debtorTxRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invoiceId); // <--- FIXED: Target the specific transaction ID

        DocumentSnapshot debTxSnap = await debtorTxRef.get();

        if (debTxSnap.exists) {
          // Logic from your editTransaction method:
          // We update the amount to the New Grand Total.
          // Since we calculated newGT and newPayDetails above, we simply apply them.

          Map<String, dynamic> oldTxData =
              debTxSnap.data() as Map<String, dynamic>;
          String oldNote = toStr(oldTxData['note']);

          batch.update(debtorTxRef, {
            'amount': newGT, // Update total amount
            'paymentMethod': newPayDetails, // Update payment info/due
            'note': "$oldNote (Return: -$refundAmt)", // Optional: Update note
          });
        }
      }

      // 7. COMMIT BATCH
      await batch.commit();

      // --- 8. STOCK RESTORATION ---
      for (var pid in returnQuantities.keys) {
        int qty = returnQuantities[pid]!;
        if (qty > 0) {
          String dest = returnDestinations[pid] ?? "Local";
          var itemInfo = orderItems.firstWhere(
            (e) => toStr(e['productId']) == pid,
            orElse: () => {},
          );
          double originalCost = toDouble(itemInfo['costRate']);
          int? parsedPid = int.tryParse(pid);
          if (parsedPid != null) {
            try {
              await productCtrl.addMixedStock(
                productId: parsedPid,
                localQty: dest == "Local" ? qty : 0,
                airQty: dest == "Air" ? qty : 0,
                seaQty: dest == "Sea" ? qty : 0,
                localUnitPrice: originalCost,
              );
            } catch (e) {
              print("Stock error: $e");
            }
          }
        }
      }

      Get.back();
      Get.snackbar(
        "Success",
        "Return Processed & Debtor Updated!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

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
