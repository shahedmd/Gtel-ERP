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

  // Loaded Order Data
  var orderData = Rxn<Map<String, dynamic>>();
  var orderItems = <Map<String, dynamic>>[].obs;

  // Handling Multiple Search Results (Collision on 4 digits)
  var multipleSearchResults = <Map<String, dynamic>>[].obs;

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

  // --- 1. SMART SEARCH (Entry Point) ---
  Future<void> smartSearch(String input) async {
    if (input.trim().isEmpty) return;

    // Clear previous state
    multipleSearchResults.clear();
    orderData.value = null;
    orderItems.clear();

    String query = input.trim();

    // If input is short (4 digits), search recent docs.
    // If long (likely full ID), search directly.
    if (query.length <= 5) {
      await _searchByShortCode(query);
    } else {
      await _loadInvoiceByFullId(query);
    }
  }

  // A. Search by Last 4 Digits (Scans recent 100 orders)
  Future<void> _searchByShortCode(String shortCode) async {
    isLoading.value = true;
    try {
      // 1. Fetch last 100 orders (Optimization: Returns usually happen on recent sales)
      final snap =
          await _db
              .collection('sales_orders')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      // 2. Filter locally
      List<Map<String, dynamic>> matches = [];

      for (var doc in snap.docs) {
        String fullId = doc.id;
        if (fullId.endsWith(shortCode)) {
          Map<String, dynamic> data = doc.data();
          // Exclude already returned/cancelled if needed
          if (data['status'] != 'deleted') {
            matches.add(data);
          }
        }
      }

      if (matches.isEmpty) {
        Get.snackbar(
          "Not Found",
          "No recent invoice ending in '$shortCode' found.",
        );
      } else if (matches.length == 1) {
        // Exact match found -> Load it
        _parseOrderData(matches.first);
      } else {
        // Multiple matches -> UI should show a selection dialog
        multipleSearchResults.assignAll(matches);
        _showSelectionDialog();
      }
    } catch (e) {
      Get.snackbar("Error", "Search failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // B. Direct Load
  Future<void> _loadInvoiceByFullId(String invoiceId) async {
    isLoading.value = true;
    try {
      final doc = await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Not Found", "Invoice #$invoiceId does not exist.");
        return;
      }
      _parseOrderData(doc.data() as Map<String, dynamic>);
    } catch (e) {
      Get.snackbar("Error", "Load failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // C. Parse Data to State
  void _parseOrderData(Map<String, dynamic> data) {
    orderData.value = data;
    returnQuantities.clear();
    returnDestinations.clear();
    orderItems.clear();

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

    // Clear search list if we successfully loaded one
    multipleSearchResults.clear();
  }

  // Helper Dialog for Multiple Matches
  void _showSelectionDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Invoice",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Multiple invoices found with this code."),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: multipleSearchResults.length,
                  itemBuilder: (ctx, i) {
                    var item = multipleSearchResults[i];
                    return ListTile(
                      title: Text(item['customerName'] ?? 'Unknown'),
                      subtitle: Text(
                        "${item['invoiceId']} • ৳${item['grandTotal']}",
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Get.back(); // Close dialog
                        _parseOrderData(item); // Load selected
                      },
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
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

      // C. Calculate Reductions (Items & Cost)
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

        // Add to new list
        newItemsList.add({
          "productId": pid,
          "name": name,
          "model": model,
          "qty": dbQty, // Updated Qty
          "saleRate": sRate,
          "costRate": cRate,
          "subtotal": toDouble(dbQty * sRate), // Updated Subtotal
        });
      }

      // D. Financial Adjustment Logic
      double oldGT = toDouble(currentOrder['grandTotal']);
      double oldP = toDouble(currentOrder['profit']);
      double oldC = toDouble(currentOrder['totalCost']);

      double newGT = oldGT - refundAmt;
      double newP = oldP - profitReduce;
      double newC = oldC - costReduce;
      if (newGT < 0) newGT = 0;

      // --- PAYMENT MODIFICATION LOGIC (NEW) ---
      // Instead of calculating "changeReturned", we reduce payment methods directly.

      Map<String, dynamic> oldPay =
          currentOrder['paymentDetails'] is Map
              ? Map<String, dynamic>.from(currentOrder['paymentDetails'])
              : {};

      double paidSoFar = toDouble(oldPay['actualReceived']);

      // 1. Extract Individual Payment Amounts
      double pCash = toDouble(oldPay['cash']);
      double pBkash = toDouble(oldPay['bkash']);
      double pNagad = toDouble(oldPay['nagad']);
      double pBank = toDouble(oldPay['bank']);

      double amountToReduce = 0.0;

      // 2. Determine how much we need to "Refund" (remove from history)
      if (paidSoFar > newGT) {
        amountToReduce = paidSoFar - newGT;
      }

      // 3. Deduct from Payment Methods iteratively (Priority: Cash -> Bkash -> Nagad -> Bank)
      if (amountToReduce > 0) {
        // Reduce Cash
        if (pCash > 0) {
          if (pCash >= amountToReduce) {
            pCash -= amountToReduce;
            amountToReduce = 0;
          } else {
            amountToReduce -= pCash;
            pCash = 0;
          }
        }
        // Reduce Bkash
        if (amountToReduce > 0 && pBkash > 0) {
          if (pBkash >= amountToReduce) {
            pBkash -= amountToReduce;
            amountToReduce = 0;
          } else {
            amountToReduce -= pBkash;
            pBkash = 0;
          }
        }
        // Reduce Nagad
        if (amountToReduce > 0 && pNagad > 0) {
          if (pNagad >= amountToReduce) {
            pNagad -= amountToReduce;
            amountToReduce = 0;
          } else {
            amountToReduce -= pNagad;
            pNagad = 0;
          }
        }
        // Reduce Bank
        if (amountToReduce > 0 && pBank > 0) {
          if (pBank >= amountToReduce) {
            pBank -= amountToReduce;
            amountToReduce = 0;
          } else {
            amountToReduce -= pBank;
            pBank = 0;
          }
        }
      }

      // 4. Recalculate Totals based on reduced methods
      double newActualReceived = pCash + pBkash + pNagad + pBank;
      double newDue = newGT - newActualReceived;
      if (newDue < 0) newDue = 0;

      // 5. Construct New Payment Map
      Map<String, dynamic> newPayDetails = {
        ...oldPay,
        "cash": pCash,
        "bkash": pBkash,
        "nagad": pNagad,
        "bank": pBank,
        "actualReceived": newActualReceived,
        "totalPaidInput": newActualReceived,
        "due": newDue,
        "changeReturned": 0.0, // Explicitly set to 0 as requested
      };

      // 1. UPDATE SALES ORDER
      batch.update(orderRef, {
        'items': newItemsList,
        'grandTotal': newGT,
        'profit': newP,
        'totalCost': newC < 0 ? 0.0 : newC,
        'paymentDetails': newPayDetails,
        'status': 'returned_partial',
        'lastReturnDate': FieldValue.serverTimestamp(),
        'subtotal': newGT,
      });

      // 2. UPDATE DEBTOR LEDGER (If Applicable)
      if (debtorId.isNotEmpty) {
        DocumentReference debtorTxRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invoiceId);

        DocumentSnapshot debTxSnap = await debtorTxRef.get();

        if (debTxSnap.exists) {
          // Update transaction amount to match new bill
          batch.update(debtorTxRef, {
            'amount': newGT,
            'note': "Inv $invoiceId (Ret: ${refundAmt.toStringAsFixed(0)})",
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Update Analytics
        DocumentReference analyticsRef = _db
            .collection('debtor_transaction_history')
            .doc(invoiceId);

        batch.set(analyticsRef, {
          "saleAmount": newGT,
          "costAmount": newC,
          "profit": newP,
          "returnDate": FieldValue.serverTimestamp(),
          "itemsSummary": FieldValue.arrayUnion(returnedItemSummaries),
        }, SetOptions(merge: true));
      }

      // 3. UPDATE DAILY SALES ENTRY
      final dailyQuery =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: invoiceId)
              .limit(1)
              .get();

      if (dailyQuery.docs.isNotEmpty) {
        DocumentSnapshot dailySnap = dailyQuery.docs.first;

        // Directly sync with the new reduced values
        batch.update(dailySnap.reference, {
          'amount': newGT,
          'paid': newActualReceived, // Now matches the reduced payment
          'pending': newDue,
          'paymentMethod': newPayDetails,
        });
      }

      // 4. COMMIT DB UPDATES
      await batch.commit();

      // 5. STOCK RESTORATION
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
              // Server Calculation for WAC update
              await productCtrl.addMixedStock(
                productId: parsedPid,
                localQty: dest == "Local" ? qty : 0,
                airQty: dest == "Air" ? qty : 0,
                seaQty: dest == "Sea" ? qty : 0,
                localUnitPrice: originalCost,
              );
            } catch (e) {
              print("Stock Restore Error for $pid: $e");
            }
          }
        }
      }

      Get.back(); // Close Dialog/Screen
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
      multipleSearchResults.clear();
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
