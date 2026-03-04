// ignore_for_file: deprecated_member_use, avoid_print, empty_catches, file_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Stock/controller.dart'; // Ensure correct path to ProductController

class SaleReturnController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();

  // --- STATE ---
  var searchController = TextEditingController();
  var isLoading = false.obs;

  // Invoice Data
  var orderData = Rxn<Map<String, dynamic>>();

  // The interactive list of items
  var modifiedItems = <Map<String, dynamic>>[].obs;
  var multipleSearchResults = <Map<String, dynamic>>[].obs;

  // Maps productId to a Destination ("Local", "Sea", "Air") for returned items
  var returnDestinations = <String, String>{}.obs;

  // --- HELPERS ---
  double toDouble(dynamic val) =>
      double.tryParse(val?.toString() ?? '0') ?? 0.0;
  int toInt(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;
  String toStr(dynamic val) => val?.toString() ?? "";

  // ========================================================================
  // 1. SEARCH INVOICE LOGIC
  // ========================================================================

  Future<void> smartSearch(String input) async {
    if (input.trim().isEmpty) return;
    multipleSearchResults.clear();
    orderData.value = null;
    modifiedItems.clear();
    returnDestinations.clear();
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
          if (data['status'] != 'deleted') matches.add(data);
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
    modifiedItems.clear();
    returnDestinations.clear();

    List<dynamic> rawItems = data['items'] ?? [];
    for (var item in rawItems) {
      if (item is Map) {
        String pid = toStr(item['productId'] ?? item['id']);
        returnDestinations[pid] = "Local"; // Default return destination

        modifiedItems.add({
          "productId": pid,
          "name": toStr(item['name']),
          "model": toStr(item['model']),
          "qty": toInt(item['qty']),
          "saleRate": toDouble(item['saleRate']),
          "costRate": toDouble(item['costRate']),
          "subtotal": toDouble(item['subtotal']),
        });
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
  // 2. EDIT INVOICE UI HANDLERS
  // ========================================================================

  void setDestination(String productId, String dest) {
    returnDestinations[productId] = dest;
  }

  void increaseQty(int index) {
    var item = modifiedItems[index];
    item['qty'] = (item['qty'] as int) + 1;
    item['subtotal'] = item['qty'] * item['saleRate'];
    modifiedItems[index] = item;
  }

  void decreaseQty(int index) {
    var item = modifiedItems[index];
    if (item['qty'] > 0) {
      item['qty'] = (item['qty'] as int) - 1;
      item['subtotal'] = item['qty'] * item['saleRate'];
      modifiedItems[index] = item;
    }
  }

  void removeProduct(int index) {
    var item = modifiedItems[index];
    item['qty'] = 0;
    item['subtotal'] = 0.0;
    modifiedItems[index] = item;
  }

  double get currentModifiedTotal {
    return modifiedItems.fold(
      0.0,
      (sumv, item) => sumv + (item['subtotal'] as double),
    );
  }

  // ========================================================================
  // 3. ADDING NEW / EXISTING PRODUCTS TO INVOICE
  // ========================================================================

  Future<List<Map<String, dynamic>>> searchStockProducts(String query) async {
    return await productCtrl.searchProductsForDropdown(query);
  }

  void addNewProductToInvoice(
    Map<String, dynamic> product,
    int addQty,
    double saleRate,
    double costRate,
  ) {
    String pid = toStr(product['id'] ?? product['productId']);
    int existingIndex = modifiedItems.indexWhere(
      (element) => element['productId'] == pid,
    );

    if (existingIndex != -1) {
      var item = modifiedItems[existingIndex];
      item['qty'] = (item['qty'] as int) + addQty;
      item['subtotal'] = item['qty'] * item['saleRate'];
      modifiedItems[existingIndex] = item;
    } else {
      returnDestinations[pid] = "Local"; // Default return behavior
      modifiedItems.add({
        "productId": pid,
        "name": toStr(product['name']),
        "model": toStr(product['model']),
        "qty": addQty,
        "saleRate": saleRate,
        "costRate": costRate,
        "subtotal": addQty * saleRate,
      });
    }
  }

  Future<void> createAndAddNewProductToInvoice({
    required String name,
    required String model,
    required int qty,
    required double saleRate,
    required double costRate,
  }) async {
    isLoading.value = true;
    try {
      Map<String, dynamic> newProductData = {
        'name': name,
        'model': model,
        'brand': 'LOCAL',
        'category_id': 1,
        'supplier_id': 1,
        'stock_qty': 0,
        'alert_qty': 5,
        'avg_purchase_price': costRate,
        'agent': saleRate,
        'wholesale': saleRate,
        'retail': saleRate,
      };

      int? newId = await productCtrl.createProductReturnId(newProductData);

      if (newId != null) {
        addNewProductToInvoice(
          {'id': newId.toString(), 'name': name, 'model': model},
          qty,
          saleRate,
          costRate,
        );
        Get.snackbar(
          "Success",
          "New product created and added to invoice.",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          "Error",
          "Failed to get ID from server. Product not added.",
        );
      }
    } catch (e) {
      Get.snackbar("Creation Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ========================================================================
  // 4. MASTER PROCESSING: PROCESS EDITS / RETURNS
  // ========================================================================

  Future<void> processEditInvoice({
    double extraCollectedAmount = 0.0,
    String extraCollectedMethod = 'Cash',
  }) async {
    if (orderData.value == null) return;
    isLoading.value = true;

    String invoiceId = toStr(orderData.value!['invoiceId']);
    String debtorId = toStr(orderData.value!['debtorId']);
    bool isCondition = orderData.value!['isCondition'] == true;
    String courierName = toStr(orderData.value!['courierName']);
    String customerPhone = toStr(orderData.value!['customerPhone']);

    WriteBatch batch = _db.batch();

    try {
      // A. Fetch Latest DB Documents
      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(invoiceId);
      DocumentSnapshot orderSnap = await orderRef.get();
      if (!orderSnap.exists) throw "Invoice not found in database.";
      Map<String, dynamic> currentOrder =
          orderSnap.data() as Map<String, dynamic>;

      QuerySnapshot dailySnap =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: invoiceId)
              .limit(1)
              .get();
      DocumentReference? dailyRef =
          dailySnap.docs.isNotEmpty ? dailySnap.docs.first.reference : null;
      Map<String, dynamic>? dailyData =
          dailySnap.docs.isNotEmpty
              ? dailySnap.docs.first.data() as Map<String, dynamic>
              : null;

      // B. Build the Clean "Final Items" List (Excludes 0 Qty)
      List<Map<String, dynamic>> finalItemsList = [];
      double newGT = 0.0, newCost = 0.0, newProfit = 0.0;

      for (var item in modifiedItems) {
        int qty = toInt(item['qty']);
        if (qty > 0) {
          double sRate = toDouble(item['saleRate']);
          double cRate = toDouble(item['costRate']);
          item['subtotal'] = qty * sRate;
          newGT += qty * sRate;
          newCost += qty * cRate;
          newProfit += (sRate - cRate) * qty;
          finalItemsList.add(item);
        }
      }

      // Apply existing discount
      double discount = toDouble(currentOrder['discount']);
      newGT -= discount;
      if (newGT < 0) newGT = 0;

      double oldGT = toDouble(currentOrder['grandTotal']);
      double deltaGT = newGT - oldGT;

      // Payment logic base
      Map<String, dynamic> oldPayDetails = Map<String, dynamic>.from(
        currentOrder['paymentDetails'] ?? {},
      );
      double realPaidAmount = toDouble(oldPayDetails['actualReceived']);
      if (realPaidAmount == 0) {
        realPaidAmount = toDouble(oldPayDetails['totalPaidInput']);
      }

      if (dailyData != null && toDouble(dailyData['paid']) > realPaidAmount) {
        realPaidAmount = toDouble(dailyData['paid']);
      }

      double pCash = toDouble(oldPayDetails['cash']);
      double pBkash = toDouble(oldPayDetails['bkash']);
      double pNagad = toDouble(oldPayDetails['nagad']);
      double pBank = toDouble(oldPayDetails['bank']);

      if (deltaGT > 0 && extraCollectedAmount > 0) {
        String method = extraCollectedMethod.toLowerCase();
        if (method == 'bkash') {
          pBkash += extraCollectedAmount;
        } else if (method == 'nagad') {
          pNagad += extraCollectedAmount;
        } else if (method == 'bank') {
          pBank += extraCollectedAmount;
        } else {
          pCash += extraCollectedAmount; // Default to cash
        }

        realPaidAmount += extraCollectedAmount;
      }

      double newDue = newGT - realPaidAmount;
      double refundToCustomer = 0.0;

      if (newDue < 0) {
        refundToCustomer = newDue.abs();
        realPaidAmount = newGT;
        newDue = 0.0;
      }

      // If returning items (Delta < 0), slash payments down
      double amountToSlash = refundToCustomer;
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

      // -----------------------------------------------------------------
      // FIX 1 & 2: CORRECT CONDITION PAYMENT / LEDGER CALCULATION
      // -----------------------------------------------------------------
      double newCourierDue = 0.0;
      double deltaCourierDue =
          0.0; // Tracks EXACTLY how much the courier's ledger should change

      if (isCondition) {
        double oldCourierDue = toDouble(currentOrder['courierDue']);

        if (oldCourierDue > 0) {
          // Condition is ONGOING. Adjust based on added/removed items,
          // MINUS what was paid directly to the shop during this edit.
          newCourierDue = oldCourierDue + deltaGT - extraCollectedAmount;
          if (newCourierDue < 0) newCourierDue = 0; // Floor at 0

          deltaCourierDue = newCourierDue - oldCourierDue;
        } else {
          // Condition sale was ALREADY COMPLETED (Courier already paid us).
          // Returns/Edits here are handled by the shop directly.
          // The courier ledger DOES NOT CHANGE.
          newCourierDue = 0.0;
          deltaCourierDue = 0.0;
        }
      }

      Map<String, dynamic> newPayDetails = {
        ...oldPayDetails,
        "cash": pCash,
        "bkash": pBkash,
        "nagad": pNagad,
        "bank": pBank,
        "actualReceived": realPaidAmount,
        "totalPaidInput": realPaidAmount,
        "due": newDue,
        "paidForInvoice": realPaidAmount,
      };

      // 1. Update sales_orders Master
      Map<String, dynamic> updateData = {
        'items': finalItemsList,
        'grandTotal': newGT,
        'subtotal': newGT + discount,
        'profit': newProfit,
        'totalCost': newCost,
        'paymentDetails': newPayDetails,
        // FIX 3: Match ConditionSalesController status tags exactly
        'status':
            isCondition
                ? (newCourierDue <= 1 ? 'completed' : 'on_delivery')
                : (newDue <= 1 ? 'completed' : 'partial'),
        'lastModifiedAt': FieldValue.serverTimestamp(),
      };

      if (isCondition) {
        updateData['courierDue'] = newCourierDue;
        updateData['isFullyPaid'] = newCourierDue <= 1;
      }

      batch.update(orderRef, updateData);

      // 2. Update daily_sales (And inject payment history if extra cash was paid)
      if (dailyRef != null) {
        // FIX 4: Update fields gracefully without overwriting the specific paymentMethod schema
        Map<String, dynamic> dailyUpdate = {
          'amount': newGT,
          'paid': realPaidAmount,
          'pending': newDue,
          'paymentMethod.cash': pCash,
          'paymentMethod.bkash': pBkash,
          'paymentMethod.nagad': pNagad,
          'paymentMethod.bank': pBank,
        };

        // Push the extra payment into today's accounting
        if (deltaGT > 0 && extraCollectedAmount > 0) {
          dailyUpdate['paymentHistory'] = FieldValue.arrayUnion([
            {
              'type': extraCollectedMethod.toLowerCase(),
              'amount': extraCollectedAmount,
              'timestamp': Timestamp.now(),
              'note': 'Invoice Edit: Extra Payment Added',
            },
          ]);
        }
        batch.update(dailyRef, dailyUpdate);
      }

      // 3. Update Debtor Ledger
      if (debtorId.isNotEmpty) {
        DocumentReference debtorTxRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invoiceId);
        DocumentSnapshot dtSnap = await debtorTxRef.get();
        if (dtSnap.exists) {
          batch.update(debtorTxRef, {
            'amount': newGT,
            'note':
                "Inv $invoiceId (Edited: Delta ${deltaGT > 0 ? '+' : ''}${deltaGT.toStringAsFixed(0)})",
          });
        }
        batch.set(
          _db.collection('debtor_transaction_history').doc(invoiceId),
          {"saleAmount": newGT, "costAmount": newCost, "profit": newProfit},
          SetOptions(merge: true),
        );
      }

      // 4. Update Courier & Condition Ledger
      // FIX: ONLY update ledgers if there is an actual change in Courier Due (deltaCourierDue != 0)
      if (isCondition && courierName.isNotEmpty && deltaCourierDue != 0) {
        batch.update(_db.collection('courier_ledgers').doc(courierName), {
          "totalDue": FieldValue.increment(deltaCourierDue),
          "lastUpdated": FieldValue.serverTimestamp(),
        });

        DocumentReference custRef = _db
            .collection('condition_customers')
            .doc(customerPhone);
        batch.update(custRef, {
          "totalCourierDue": FieldValue.increment(deltaCourierDue),
        });

        batch.set(custRef.collection('orders').doc(invoiceId), {
          "grandTotal": newGT,
          "courierDue": newCourierDue,
          "status": newCourierDue <= 1 ? 'completed' : 'on_delivery',
        }, SetOptions(merge: true));
      }

      // G. BUG FIX: SEPARATE DEDUCTIONS (SALES) AND ADDITIONS (RETURNS TO BUCKETS)
      List<Map<String, dynamic>> salesDeductions = [];
      List<Map<String, dynamic>> returnAdditions = [];

      Map<String, int> oldQtyMap = {
        for (var e in (currentOrder['items'] ?? []))
          toStr(e['productId']): toInt(e['qty']),
      };
      Map<String, int> newQtyMap = {
        for (var e in finalItemsList) toStr(e['productId']): toInt(e['qty']),
      };

      Set<String> allPids = {...oldQtyMap.keys, ...newQtyMap.keys};
      for (var pid in allPids) {
        if (pid.isEmpty) continue;
        int oldQ = oldQtyMap[pid] ?? 0;
        int newQ = newQtyMap[pid] ?? 0;
        int diff = newQ - oldQ;

        int safePidInt = int.tryParse(pid) ?? 0;
        if (safePidInt > 0) {
          if (diff > 0) {
            salesDeductions.add({'id': safePidInt, 'qty': diff});
          } else if (diff < 0) {
            int returnQty = diff.abs();
            String dest = returnDestinations[pid] ?? "Local";

            double cRate = 0.0;
            var itemInFinal = finalItemsList.firstWhere(
              (e) => toStr(e['productId']) == pid,
              orElse: () => <String, dynamic>{},
            );
            if (itemInFinal.isEmpty) {
              List rawItems = currentOrder['items'] ?? [];
              var oldItem = rawItems.firstWhere(
                (e) => toStr(e['productId'] ?? e['id']) == pid,
                orElse: () => {},
              );
              cRate = toDouble(oldItem['costRate']);
            } else {
              cRate = toDouble(itemInFinal['costRate']);
            }

            returnAdditions.add({
              'id': safePidInt,
              'sea_qty': dest == 'Sea' ? returnQty : 0,
              'air_qty': dest == 'Air' ? returnQty : 0,
              'local_qty': dest == 'Local' ? returnQty : 0,
              'local_price': cRate,
            });
          }
        }
      }

      if (salesDeductions.isNotEmpty) {
        bool restockSuccess = await productCtrl.updateStockBulk(
          salesDeductions,
        );
        if (!restockSuccess) {
          throw "Failed to deduct extra stock from general inventory.";
        }
      }

      if (returnAdditions.isNotEmpty) {
        bool addSuccess = await productCtrl.bulkAddStockMixed(returnAdditions);
        if (!addSuccess) {
          throw "Failed to restore returned items to their stock buckets.";
        }
      }

      // H. Commit to Database
      await batch.commit();

      Get.back();
      Get.snackbar(
        "Invoice Updated Successfully",
        "New Total: ৳${newGT.toStringAsFixed(0)} | Paid: ৳${realPaidAmount.toStringAsFixed(0)}",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      // Cleanup
      orderData.value = null;
      searchController.clear();
      modifiedItems.clear();
      multipleSearchResults.clear();
      returnDestinations.clear();
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