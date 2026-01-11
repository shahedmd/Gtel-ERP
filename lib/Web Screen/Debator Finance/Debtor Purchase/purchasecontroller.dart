// ignore_for_file: avoid_print, empty_catches, deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart'; // Your API-based Product Controller
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';

class DebtorPurchaseController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Dependencies
  final ProductController stockCtrl = Get.find<ProductController>();
  final DebatorController debtorCtrl = Get.find<DebatorController>();

  // Observables
  var purchases = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;

  // Product Search List (Mapped from Stock Controller)
  var productSearchList = <Map<String, dynamic>>[].obs;

  // Cart
  var cartItems = <Map<String, dynamic>>[].obs;

  // Stats
  var totalPurchased = 0.0.obs;
  var totalPaid = 0.0.obs;

  // Computed Getter
  double get currentPayable => totalPurchased.value - totalPaid.value;

    final DailyExpensesController dailyExpenseCtrl = Get.isRegistered<DailyExpensesController>() 
      ? Get.find<DailyExpensesController>() 
      : Get.put(DailyExpensesController());

  // ----------------------------------------------------------------
  // 1. DATA LOADING
  // ----------------------------------------------------------------

  // Load Purchase History (From Firestore - Debtor Record)
  Future<void> loadPurchases(String debtorId) async {
    isLoading.value = true;
    try {
      final snap =
          await _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .orderBy('date', descending: true)
              .get();

      purchases.value =
          snap.docs.map((d) {
            var data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

      _calculateStats();
    } catch (e) {
      Get.snackbar("Error", "Could not load purchases: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Load Products (From ProductController / API)
  Future<void> loadProductsForSearch() async {
    try {
      // 1. Ensure products are loaded from the API
      if (stockCtrl.allProducts.isEmpty) {
        await stockCtrl.fetchProducts();
      }

      // 2. Map the API Product objects to the Map format required by the UI
      productSearchList.value =
          stockCtrl.allProducts.map((product) {
            return {
              'id': product.id, // Keep ID as int (from API)
              'name': product.name,
              'model': product.model,
              // Use avgPurchasePrice as the default 'buyingPrice'
              'buyingPrice': product.avgPurchasePrice,
            };
          }).toList();
    } catch (e) {
      print("Error loading products for search: $e");
    }
  }

  void _calculateStats() {
    double purchased = 0.0;
    double paid = 0.0;

    for (var p in purchases) {
      // Safe parsing using extension
      double amt = (p['totalAmount'] ?? p['amount'] ?? 0).toString().toDouble();

      if (p['type'] == 'invoice') {
        purchased += amt;
      } else if (p['type'] == 'payment' || p['type'] == 'adjustment') {
        paid += amt;
      }
    }
    totalPurchased.value = purchased;
    totalPaid.value = paid;
  }

  // ----------------------------------------------------------------
  // 2. PURCHASE LOGIC
  // ----------------------------------------------------------------
  void addToCart(
    Map<String, dynamic> product,
    int qty,
    double cost,
    String location,
  ) {
    String pid = product['id'].toString();

    int index = cartItems.indexWhere(
      (e) => e['productId'] == pid && e['location'] == location,
    );

    if (index >= 0) {
      var item = cartItems[index];
      item['qty'] += qty;
      item['subtotal'] = item['qty'] * cost;
      cartItems[index] = item;
      cartItems.refresh();
    } else {
      cartItems.add({
        'productId': pid,
        'name': product['name'],
        'model': product['model'],
        'qty': qty,
        'cost': cost,
        'location': location,
        'subtotal': qty * cost,
      });
    }
  }

  Future<void> finalizePurchase(String debtorId, String note) async {
    if (cartItems.isEmpty) return;
    isLoading.value = true;
    try {
      double grandTotal = cartItems.fold(
        0,
        (sumv, item) => sumv + item['subtotal'],
      );

      WriteBatch batch = _db.batch();

      // A. Create Purchase Record in Firestore (Financial Record)
      DocumentReference purchaseRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      batch.set(purchaseRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'invoice',
        'items': cartItems,
        'totalAmount': grandTotal,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Commit Firestore Batch (Financials)
      await batch.commit();

      // B. Stock Update (API Calls to Server)
      // We execute these in parallel for speed
      List<Future> stockUpdates = [];

      for (var item in cartItems) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        String loc = item['location'];
        int qty = item['qty'];
        double cost = item['cost'];

        // Call the API via ProductController
        stockUpdates.add(
          stockCtrl.addMixedStock(
            productId: pid,
            localQty: loc == "Local" ? qty : 0,
            airQty: loc == "Air" ? qty : 0,
            seaQty: loc == "Sea" ? qty : 0,
            localUnitPrice: cost,
          ),
        );
      }

      // Wait for all API calls to finish
      await Future.wait(stockUpdates);

      // Cleanup
      cartItems.clear();
      await loadPurchases(debtorId);

      Get.back();
      Get.snackbar(
        "Success",
        "Purchase Recorded & Stock Added to Server",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Transaction Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 3. NORMAL PAYMENT (CASH/BANK OUT)
  // ----------------------------------------------------------------
  Future<void> makePayment({
    required String debtorId,
    required String debtorName, // ADDED THIS to log clear expense name
    required double amount,
    required String method,
    String? note,
  }) async {
    if (amount <= 0) return;

    isLoading.value = true;
    try {
      // 1. Record in Firestore (Debtor Purchase History)
      await _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .add({
            'date': FieldValue.serverTimestamp(),
            'type': 'payment',
            'amount': amount,
            'method': method,
            'note': note,
            'isAdjustment': false,
          });

      // 2. AUTOMATIC EXPENSE ENTRY
      // Since money is leaving cash, we add it to Daily Expenses
      try {
        await dailyExpenseCtrl.addDailyExpense(
          "Payment to $debtorName", // Name: "Payment to Shop X"
          amount.toInt(), // Expense Controller expects int
          note: "Debtor Payment. Method: $method. ${note ?? ''}",
          date: DateTime.now(),
        );
      } catch (e) {
        print("Failed to auto-add expense: $e");
        // We don't stop the flow here, just log error
      }

      await loadPurchases(debtorId);
      Get.back(); // Close Dialog
      Get.snackbar(
        "Payment Successful",
        "Recorded in Ledger & Added to Daily Expenses",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 4. CONTRA ADJUSTMENT (PAYABLE OFF-SETTING)
  // ----------------------------------------------------------------
  Future<void> processContraAdjustment({
    required String debtorId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    isLoading.value = true;
    WriteBatch batch = _db.batch();

    try {
      // Step A: Record Adjustment in Purchase History (Reduces Payable)
      DocumentReference purchaseAdjRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      batch.set(purchaseAdjRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'adjustment',
        'amount': amount,
        'method': 'Contra Adjustment',
        'note': 'Adjusted against Sales Due',
        'isAdjustment': true,
      });

      // Step B: Reduce Debtor's Sales Debt (Add a 'debit' entry in transactions)
      DocumentReference ledgerRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc();

      batch.set(ledgerRef, {
        'transactionId': ledgerRef.id,
        'amount': amount,
        'type': 'debit', // 'Debit' reduces the customer balance
        'date': FieldValue.serverTimestamp(),
        'note': 'Contra Adjustment (Ref Purchase)',
        'paymentMethod': {'type': 'Contra'},
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Refresh both UI Lists
      await loadPurchases(debtorId);
      debtorCtrl.loadDebtorTransactions(debtorId);

      Get.back(); // Close dialog
      Get.snackbar(
        "Adjustment Successful",
        "Payable reduced by $amount & Debtor Balance reduced by $amount",
        backgroundColor: Colors.blueAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

// Helper Extension for safe parsing
extension StringExtension on String {
  double toDouble() => double.tryParse(this) ?? 0.0;
}
