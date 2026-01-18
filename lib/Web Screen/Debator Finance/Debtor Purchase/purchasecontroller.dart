// ignore_for_file: avoid_print, empty_catches, deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
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

  final DailyExpensesController dailyExpenseCtrl =
      Get.isRegistered<DailyExpensesController>()
          ? Get.find<DailyExpensesController>()
          : Get.put(DailyExpensesController());

  // ----------------------------------------------------------------
  // 1. DATA LOADING & AUTO-SYNC
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

      // Calculate Stats
      await _calculateStatsAndSync(
        debtorId,
      ); // <--- UPDATED: Syncs to parent doc
    } catch (e) {
      Get.snackbar("Error", "Could not load purchases: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Calculate stats locally AND update the Main Firestore Document
  // This ensures the Financial Controller sees the correct liability.
  Future<void> _calculateStatsAndSync(String debtorId) async {
    double purchased = 0.0;
    double paid = 0.0;

    for (var p in purchases) {
      double amt = (p['totalAmount'] ?? p['amount'] ?? 0).toString().toDouble();

      if (p['type'] == 'invoice') {
        purchased += amt;
      } else if (p['type'] == 'payment' || p['type'] == 'adjustment') {
        paid += amt;
      }
    }

    // Update Local State
    totalPurchased.value = purchased;
    totalPaid.value = paid;
    double due = purchased - paid;

    // --- THE FIX: Write this value to the parent document ---
    try {
      await _db.collection('debatorbody').doc(debtorId).update({
        'purchaseDue': due, // Financial Controller listens to this field
        'lastPurchaseUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Sync Error: Could not update parent debtor doc: $e");
    }
  }

  // Load Products (From ProductController / API)
  Future<void> loadProductsForSearch() async {
    try {
      if (stockCtrl.allProducts.isEmpty) {
        await stockCtrl.fetchProducts();
      }
      productSearchList.value =
          stockCtrl.allProducts.map((product) {
            return {
              'id': product.id,
              'name': product.name,
              'model': product.model,
              'buyingPrice': product.avgPurchasePrice,
            };
          }).toList();
    } catch (e) {
      print("Error loading products for search: $e");
    }
  }

  // ----------------------------------------------------------------
  // 2. PURCHASE LOGIC (UPDATED)
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

      // A. Create Purchase Record
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

      // B. --- THE FIX: Increment Global Liability on Parent Doc ---
      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(grandTotal),
      });

      // Commit Financials
      await batch.commit();

      // C. Stock Update (API Calls)
      List<Future> stockUpdates = [];
      for (var item in cartItems) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        String loc = item['location'];
        int qty = item['qty'];
        double cost = item['cost'];

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
      await Future.wait(stockUpdates);

      cartItems.clear();
      await loadPurchases(debtorId); // Will re-sync exact value

      Get.back();
      Get.snackbar(
        "Success",
        "Purchase Recorded. Payable Updated.",
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
  // 3. NORMAL PAYMENT (UPDATED)
  // ----------------------------------------------------------------
  Future<void> makePayment({
    required String debtorId,
    required String debtorName,
    required double amount,
    required String method,
    String? note,
  }) async {
    if (amount <= 0) return;

    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();

      // 1. Record in Purchase History
      DocumentReference histRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      batch.set(histRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'payment',
        'amount': amount,
        'method': method,
        'note': note,
        'isAdjustment': false,
      });

      // 2. --- THE FIX: Decrement Liability on Parent Doc ---
      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});

      await batch.commit();

      // 3. Auto Expense Entry
      try {
        await dailyExpenseCtrl.addDailyExpense(
          "Payment to $debtorName",
          amount.toInt(),
          note: "Debtor Payment. Method: $method. ${note ?? ''}",
          date: DateTime.now(),
        );
      } catch (e) {
        print("Failed to auto-add expense: $e");
      }

      await loadPurchases(debtorId);
      Get.back();
      Get.snackbar(
        "Payment Successful",
        "Liability Reduced & Expense Recorded",
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
  // 4. CONTRA ADJUSTMENT (UPDATED)
  // ----------------------------------------------------------------
  Future<void> processContraAdjustment({
    required String debtorId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    isLoading.value = true;
    WriteBatch batch = _db.batch();

    try {
      // Step A: Record Adjustment in Purchase History (Reduces Purchase Payable)
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

      // --- THE FIX: Decrement Purchase Liability on Parent Doc ---
      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});

      // Step B: Reduce Debtor's Sales Debt (Add a 'debit' entry in sales transactions)
      DocumentReference ledgerRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc();

      batch.set(ledgerRef, {
        'transactionId': ledgerRef.id,
        'amount': amount,
        'type': 'debit',
        'date': FieldValue.serverTimestamp(),
        'note': 'Contra Adjustment (Ref Purchase)',
        'paymentMethod': {'type': 'Contra'},
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update Sales Balance (Handled by DebatorController Usually, but safe to force recalculate)
      // Note: DebatorController usually recalculates balance on load, so strictly updating transaction is enough for logic,
      // but 'balance' field on parent doc should also be updated ideally.
      // Since DebatorController handles sales balance, we let it handle that part via transaction stream.
      batch.update(debtorRef, {
        'balance': FieldValue.increment(-amount), // Reducing Sales Debt
      });

      await batch.commit();

      await loadPurchases(debtorId);
      debtorCtrl.loadDebtorTransactions(debtorId);

      Get.back();
      Get.snackbar(
        "Adjustment Successful",
        "Payable & Receivable both reduced by $amount",
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
