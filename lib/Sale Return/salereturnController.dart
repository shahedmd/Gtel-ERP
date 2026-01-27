// ignore_for_file: deprecated_member_use, file_names, empty_catches, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/controller.dart';

class SaleReturnController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();

  // --- STATE ---
  var searchController = TextEditingController();
  var isLoading = false.obs;

  // Invoice Data
  var orderData = Rxn<Map<String, dynamic>>(); // Holds the full invoice map
  var orderItems = <Map<String, dynamic>>[].obs;

  // Search Collisions
  var multipleSearchResults = <Map<String, dynamic>>[].obs;

  // Return Inputs
  var returnQuantities = <String, int>{}.obs;
  var returnDestinations = <String, String>{}.obs;

  // --- HELPERS ---
  double toDouble(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int toInt(dynamic val) {
    if (val == null) return 0;
    return int.tryParse(val.toString()) ?? 0;
  }

  String toStr(dynamic val) => val?.toString() ?? "";

  // ========================================================================
  // 1. SEARCH LOGIC
  // ========================================================================

  Future<void> smartSearch(String input) async {
    if (input.trim().isEmpty) return;
    multipleSearchResults.clear();
    orderData.value = null;
    orderItems.clear();
    String query = input.trim();

    if (query.length <= 5) {
      await _searchByShortCode(query);
    } else {
      await _loadInvoiceByFullId(query);
    }
  }

  Future<void> _searchByShortCode(String shortCode) async {
    isLoading.value = true;
    try {
      final snap =
          await _db
              .collection('sales_orders')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      List<Map<String, dynamic>> matches = [];
      for (var doc in snap.docs) {
        if (doc.id.endsWith(shortCode)) {
          var data = doc.data();
          // Filter out deleted orders
          if (data['status'] != 'deleted') {
            matches.add(data);
          }
        }
      }

      if (matches.isEmpty) {
        Get.snackbar("Not Found", "No invoice ending in '$shortCode' found.");
      } else if (matches.length == 1) {
        _parseOrderData(matches.first);
      } else {
        multipleSearchResults.assignAll(matches);
        _showSelectionDialog();
      }
    } catch (e) {
      Get.snackbar("Error", "Search error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadInvoiceByFullId(String invoiceId) async {
    isLoading.value = true;
    try {
      final doc = await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Not Found", "Invoice #$invoiceId not found.");
        return;
      }
      _parseOrderData(doc.data() as Map<String, dynamic>);
    } catch (e) {
      Get.snackbar("Error", "Load error: $e");
    } finally {
      isLoading.value = false;
    }
  }

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
        String pid = safeItem['productId'];
        if (pid.isNotEmpty) {
          returnQuantities[pid] = 0;
          returnDestinations[pid] = "Local";
        }
      }
    }
    multipleSearchResults.clear();
  }

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
              SizedBox(
                height: 250,
                child: ListView.separated(
                  itemCount: multipleSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    var item = multipleSearchResults[i];
                    return ListTile(
                      title: Text(item['customerName'] ?? 'Unknown'),
                      subtitle: Text(
                        "Inv: ${item['invoiceId']}\nTotal: ৳${item['grandTotal']}",
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Get.back();
                        _parseOrderData(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // 2. INPUT HANDLERS
  // ========================================================================

  void incrementReturn(String productId, int maxQty) {
    int current = returnQuantities[productId] ?? 0;
    if (current < maxQty) returnQuantities[productId] = current + 1;
  }

  void decrementReturn(String productId) {
    int current = returnQuantities[productId] ?? 0;
    if (current > 0) returnQuantities[productId] = current - 1;
  }

  void setDestination(String productId, String dest) {
    returnDestinations[productId] = dest;
  }

  // Value of items currently selected for return
  double get currentReturnTotal {
    double total = 0.0;
    for (var item in orderItems) {
      String pid = toStr(item['productId']);
      int qty = returnQuantities[pid] ?? 0;
      double rate = toDouble(item['saleRate']);
      total += (qty * rate);
    }
    return total;
  }

  // ========================================================================
  // 3. RETURN PROCESSING (The Critical Part)
  // ========================================================================

  Future<void> processProductReturn() async {
    // A. Validation
    if (currentReturnTotal <= 0) {
      Get.snackbar("Error", "No items selected for return.");
      return;
    }
    if (orderData.value == null) return;

    isLoading.value = true;
    String invoiceId = toStr(orderData.value!['invoiceId']);
    String debtorId = toStr(orderData.value!['debtorId']);

    WriteBatch batch = _db.batch();

    try {
      // B. Fetch Latest Invoice Data (Concurrency Safety)
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(invoiceId);
      DocumentSnapshot orderSnap = await orderRef.get();
      if (!orderSnap.exists) throw "Invoice not found in database.";

      Map<String, dynamic> currentOrder =
          orderSnap.data() as Map<String, dynamic>;

      // C. Calculate New Item List & Financial Reductions
      double refundAmt = 0.0;
      double profitReduce = 0.0;
      double costReduce = 0.0;
      List<String> returnLog = [];

      List<dynamic> oldItemsList = currentOrder['items'] ?? [];
      List<Map<String, dynamic>> newItemsList = [];

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
          if (retQty > dbQty) {
            throw "Return qty ($retQty) exceeds purchased qty ($dbQty) for $name";
          }

          refundAmt += (retQty * sRate);
          costReduce += (retQty * cRate);
          profitReduce += ((sRate - cRate) * retQty);

          dbQty -= retQty; // Reduce qty
          returnLog.add("$model (Ret x$retQty)");
        }

        // Add (potentially updated) item to new list
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

      // D. Financial Recalculation
      double oldGT = toDouble(currentOrder['grandTotal']);
      double oldP = toDouble(currentOrder['profit']);
      double oldC = toDouble(currentOrder['totalCost']);

      double newGT = oldGT - refundAmt;
      double newP = oldP - profitReduce;
      double newC = oldC - costReduce;
      if (newGT < 0) newGT = 0;
      if (newC < 0) newC = 0;

      // E. Payment Logic Refactoring (Ensures Paid == New Total if fully paid)
      Map<String, dynamic> oldPay = Map<String, dynamic>.from(
        currentOrder['paymentDetails'] ?? {},
      );

      double oldTotalPaid = toDouble(
        oldPay['actualReceived'],
      ); // Or 'totalPaidInput' depending on your schema
      if (oldTotalPaid == 0) {
        oldTotalPaid = toDouble(oldPay['totalPaidInput']); // Fallback
      }

      // Extract Methods
      double pCash = toDouble(oldPay['cash']);
      double pBkash = toDouble(oldPay['bkash']);
      double pNagad = toDouble(oldPay['nagad']);
      double pBank = toDouble(oldPay['bank']);

      double amountToSlash = 0.0;

      // LOGIC:
      // If (Old Paid > New Bill): We gave cash back. Reduce recorded payment to match New Bill.
      // If (Old Paid <= New Bill): We just reduced the Due. Recorded payment stays same.
      if (oldTotalPaid > newGT) {
        amountToSlash = oldTotalPaid - newGT;
      }

      // Reduce from methods (Priority: Cash -> Bkash -> Nagad -> Bank)
      if (amountToSlash > 0) {
        if (pCash >= amountToSlash) {
          pCash -= amountToSlash;
          amountToSlash = 0;
        } else {
          amountToSlash -= pCash;
          pCash = 0;
        }

        if (amountToSlash > 0 && pBkash >= amountToSlash) {
          pBkash -= amountToSlash;
          amountToSlash = 0;
        } else if (amountToSlash > 0) {
          amountToSlash -= pBkash;
          pBkash = 0;
        }

        if (amountToSlash > 0 && pNagad >= amountToSlash) {
          pNagad -= amountToSlash;
          amountToSlash = 0;
        } else if (amountToSlash > 0) {
          amountToSlash -= pNagad;
          pNagad = 0;
        }

        if (amountToSlash > 0 && pBank >= amountToSlash) {
          pBank -= amountToSlash;
          amountToSlash = 0;
        } else if (amountToSlash > 0) {
          amountToSlash -= pBank;
          pBank = 0;
        }
      }

      // Recalculate Final Payment Status
      double newTotalPaid = pCash + pBkash + pNagad + pBank;
      double newDue = newGT - newTotalPaid;
      if (newDue < 0) newDue = 0;

      Map<String, dynamic> newPayDetails = {
        ...oldPay,
        "cash": pCash,
        "bkash": pBkash,
        "nagad": pNagad,
        "bank": pBank,
        "actualReceived": newTotalPaid,
        "totalPaidInput": newTotalPaid,
        "due": newDue,
        "paidForInvoice" : newTotalPaid
      };

      // F. Database Updates

      // 1. Sales Order
      batch.update(orderRef, {
        'items': newItemsList,
        'grandTotal': newGT,
        'subtotal':
            newGT, // Usually subtotal tracks grandTotal closely unless tax involved
        'profit': newP,
        'totalCost': newC,
        'paymentDetails': newPayDetails,
        'status': newDue <= 0 ? 'returned_completed' : 'returned_partial',
        'lastReturnDate': FieldValue.serverTimestamp(),
      });

      // 2. Daily Sales (Find & Fix)
      QuerySnapshot dailySnap =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: invoiceId)
              .limit(1)
              .get();

      if (dailySnap.docs.isNotEmpty) {
        DocumentReference dailyRef = dailySnap.docs.first.reference;
        batch.update(dailyRef, {
          'amount': newGT,
          'paid': newTotalPaid,
          'pending': newDue,
          'paymentMethod': newPayDetails,
        });
      }

      // 3. Debtor Updates (If applicable)
      if (debtorId.isNotEmpty) {
        // Adjust Transaction Log
        DocumentReference debtorTxRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invoiceId);
        DocumentSnapshot dtSnap = await debtorTxRef.get();
        if (dtSnap.exists) {
          batch.update(debtorTxRef, {
            'amount': newGT,
            'note': "Inv $invoiceId (Ret: -${refundAmt.toStringAsFixed(0)})",
          });
        }

        // Add History Log
        DocumentReference analyticsRef = _db
            .collection('debtor_transaction_history')
            .doc(invoiceId);
        batch.set(analyticsRef, {
          "saleAmount": newGT,
          "costAmount": newC,
          "profit": newP,
          "returnLog": FieldValue.arrayUnion(returnLog),
        }, SetOptions(merge: true));
      }

      // G. Commit
      await batch.commit();

      // H. Stock Restoration (Independent of Batch)
      for (var pid in returnQuantities.keys) {
        int qty = returnQuantities[pid]!;
        if (qty > 0) {
          String dest = returnDestinations[pid] ?? "Local";

          // Get original cost for WAC accuracy
          var itemInfo = orderItems.firstWhere(
            (e) => toStr(e['productId']) == pid,
          );
          double cost = toDouble(itemInfo['costRate']);

          await productCtrl.addMixedStock(
            productId: int.tryParse(pid) ?? 0,
            localQty: dest == "Local" ? qty : 0,
            airQty: dest == "Air" ? qty : 0,
            seaQty: dest == "Sea" ? qty : 0,
            localUnitPrice: cost, // Restores using original cost
          );
        }
      }

      Get.back(); // Close Dialog/Screen
      Get.snackbar(
        "Return Processed",
        "Adjusted Bill: ৳${newGT.toStringAsFixed(0)}\nRecorded Paid: ৳${newTotalPaid.toStringAsFixed(0)}",
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
      Get.snackbar(
        "Failure",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
