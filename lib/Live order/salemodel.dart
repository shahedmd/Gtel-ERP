// ignore_for_file: deprecated_member_use, avoid_print, empty_catches
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Stock/controller.dart';
import '../Stock/model.dart';
import '../Web Screen/Debator Finance/debatorcontroller.dart';
import '../Web Screen/Debator Finance/model.dart';
import '../Web Screen/Sales/controller.dart';

class SalesCartItem {
  final Product product;
  RxInt quantity;
  double priceAtSale;

  SalesCartItem({
    required this.product,
    required int initialQty,
    required this.priceAtSale,
  }) : quantity = initialQty.obs;

  double get subtotal => priceAtSale * quantity.value;
}

class LiveSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // External Controllers
  final productCtrl = Get.find<ProductController>();
  final debtorCtrl = Get.find<DebatorController>();
  final dailyCtrl = Get.find<DailySalesController>();

  // --- STATE VARIABLES ---
  final RxString customerType = "Retailer".obs;
  final RxBool isConditionSale = false.obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();
  final List<String> courierList = [
    'A.J.R',
    'Pathao',
    'Korutoya',
    'Sundarban',
    'Afjal',
    'S.A.P',
    'Steadfast',
    'RedX',
  ];

  // --- PACKAGER VARIABLES ---
  final List<String> packagerList = [
    'Noyon',
    'Riad',
    'Foysal',
    'Mahim Mal',
    'Alif',
    'Raihan',
    'Hossain',
  ];
  final RxnString selectedPackager = RxnString();

  // ** DEBTOR BALANCES **
  final RxDouble debtorOldDue = 0.0.obs;
  final RxDouble debtorRunningDue = 0.0.obs;

  // Combined Due for UI Display
  double get totalPreviousDue => debtorOldDue.value + debtorRunningDue.value;

  // --- TEXT CONTROLLERS ---
  final debtorPhoneSearch = TextEditingController();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();
  final addressC = TextEditingController();
  final challanC = TextEditingController();
  final cartonsC = TextEditingController();
  final RxnString selectedCourier = RxnString();
  final discountC = TextEditingController();
  final RxDouble discountVal = 0.0.obs;

  // Payment Controllers
  final cashC = TextEditingController();
  final bkashC = TextEditingController();
  final bkashNumberC = TextEditingController();
  final nagadC = TextEditingController();
  final nagadNumberC = TextEditingController();
  final bankC = TextEditingController();
  final bankNameC = TextEditingController();
  final bankAccC = TextEditingController();

  final RxDouble totalPaidInput = 0.0.obs;
  final RxDouble changeReturn = 0.0.obs;
  final RxDouble calculatedCourierDue = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    cashC.addListener(updatePaymentCalculations);
    bkashC.addListener(updatePaymentCalculations);
    nagadC.addListener(updatePaymentCalculations);
    bankC.addListener(updatePaymentCalculations);

    ever(customerType, (_) => _handleTypeChange());
    ever(isConditionSale, (_) => updatePaymentCalculations());
    ever(selectedCourier, (val) {
      if (val != null) fetchCourierTotalDue(val);
    });

    if (productCtrl.allProducts.isEmpty) {
      productCtrl.fetchProducts();
    }

    ever(selectedDebtor, (DebtorModel? debtor) async {
      if (debtor != null) {
        var breakdown = await debtorCtrl.getInstantDebtorBreakdown(debtor.id);
        debtorOldDue.value = breakdown['loan'] ?? 0.0;
        debtorRunningDue.value = breakdown['running'] ?? 0.0;
      } else {
        debtorOldDue.value = 0.0;
        debtorRunningDue.value = 0.0;
      }
    });
  }

  // --- HELPER METHODS ---
  int get currentPage => productCtrl.currentPage.value;
  int get totalPages =>
      (productCtrl.totalProducts.value / productCtrl.pageSize.value).ceil();
  void nextPage() => productCtrl.nextPage();
  void prevPage() => productCtrl.previousPage();
  double _round(double val) => double.parse(val.toStringAsFixed(2));

  void _handleTypeChange() {
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();
    debtorOldDue.value = 0.0;
    debtorRunningDue.value = 0.0;

    for (var item in cart) {
      double newPrice =
          (customerType.value == "Debtor" || customerType.value == "Agent")
              ? item.product.agent
              : item.product.wholesale;
      item.priceAtSale = newPrice;
    }
    cart.refresh();
    updatePaymentCalculations();
  }

  void updatePaymentCalculations() {
    double cash = double.tryParse(cashC.text) ?? 0;
    double bkash = double.tryParse(bkashC.text) ?? 0;
    double nagad = double.tryParse(nagadC.text) ?? 0;
    double bank = double.tryParse(bankC.text) ?? 0;

    totalPaidInput.value = _round(cash + bkash + nagad + bank);

    if (!isConditionSale.value) {
      // For Debtor, we don't automatically calculate change if they owe money
      // But for Retailers, anything above total is change.
      if (totalPaidInput.value > grandTotal && customerType.value != "Debtor") {
        changeReturn.value = _round(totalPaidInput.value - grandTotal);
      } else {
        changeReturn.value = 0.0;
      }
    } else {
      changeReturn.value = 0.0;
    }
  }

  double get subtotalAmount =>
      _round(cart.fold(0, (sumv, item) => sumv + item.subtotal));

  double get grandTotal {
    double total = subtotalAmount - discountVal.value;
    return total < 0 ? 0 : _round(total);
  }

  double get totalInvoiceCost => _round(
    cart.fold(
      0,
      (sumv, item) =>
          sumv + (item.product.avgPurchasePrice * item.quantity.value),
    ),
  );

  double get invoiceProfit => _round(grandTotal - totalInvoiceCost);

  void addToCart(Product p) {
    if (p.stockQty <= 0) {
      Get.snackbar(
        "Stock Alert",
        "Product is out of stock",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    double price =
        (customerType.value == "Debtor" || customerType.value == "Agent")
            ? p.agent
            : p.wholesale;
    var existingItem = cart.firstWhereOrNull((item) => item.product.id == p.id);

    if (existingItem != null) {
      if (existingItem.quantity.value < p.stockQty) {
        existingItem.quantity.value++;
        cart.refresh();
      } else {
        Get.snackbar("Limit", "Max stock reached");
      }
    } else {
      cart.add(SalesCartItem(product: p, initialQty: 1, priceAtSale: price));
    }
    updatePaymentCalculations();
  }

  void updateQuantity(int index, String val) {
    int? newQty = int.tryParse(val);
    if (newQty == null || newQty <= 0) return;
    Product p = cart[index].product;
    if (newQty <= p.stockQty) {
      cart[index].quantity.value = newQty;
      cart.refresh();
    } else {
      cart[index].quantity.value = p.stockQty;
      cart.refresh();
      Get.snackbar("Limit", "Cannot exceed stock quantity: ${p.stockQty}");
    }
    updatePaymentCalculations();
  }

  String _generateInvoiceID() {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return "GTEL-${DateFormat('yyMMdd').format(now)}-$random";
  }

  Future<void> fetchCourierTotalDue(String courierName) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('courier_ledgers').doc(courierName).get();
      if (doc.exists && doc.data() != null) {
        calculatedCourierDue.value = _round(
          double.tryParse(doc.get('totalDue').toString()) ?? 0.0,
        );
      } else {
        calculatedCourierDue.value = 0.0;
      }
    } catch (e) {
      print("Courier Fetch Error: $e");
    }
  }

  // ==============================================================================
  // FINALIZE SALE (FIXED WITH 3-STEP PRIORITY)
  // ==============================================================================
  Future<void> finalizeSale() async {
    // 1. VALIDATION
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
      return;
    }
    if (selectedPackager.value == null) {
      Get.snackbar(
        "Required",
        "Please select a Packager Name (Packed By)",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    if (isConditionSale.value) {
      if (addressC.text.isEmpty) {
        Get.snackbar("Required", "Delivery Address required");
        return;
      }
      if (selectedCourier.value == null) {
        Get.snackbar("Required", "Select Courier");
        return;
      }
      if (cartonsC.text.isEmpty) {
        Get.snackbar("Required", "Enter Cartons");
        return;
      }
    }

    String finalChallan =
        challanC.text.trim().isEmpty ? "0" : challanC.text.trim();
    String fName = "";
    String fPhone = "";
    String? debtorId;

    if (customerType.value == "Debtor" && !isConditionSale.value) {
      if (selectedDebtor.value == null) {
        Get.snackbar("Required", "Select a Debtor");
        return;
      }
      fName = selectedDebtor.value!.name;
      fPhone = selectedDebtor.value!.phone;
      debtorId = selectedDebtor.value!.id;
    } else {
      if (nameC.text.isEmpty || phoneC.text.isEmpty) {
        Get.snackbar("Required", "Name & Phone required");
        return;
      }
      fName = nameC.text;
      fPhone = phoneC.text;
    }

    isProcessing.value = true;
    final String invNo = _generateInvoiceID();
    final DateTime saleDate = DateTime.now();

    // 2. FINANCIAL LOGIC (3-STEP PRIORITY)
    double totalPaidInputVal = totalPaidInput.value;
    double allocatedToOldDue = 0.0;
    double allocatedToInvoice = 0.0;
    double allocatedToPrevRunningDue =
        0.0; // Surplus amount for previous running due

    // Snapshots
    double oldDueSnap = debtorOldDue.value;
    double runningDueSnap = debtorRunningDue.value;

    if (customerType.value == "Debtor" &&
        !isConditionSale.value &&
        debtorId != null) {
      double remaining = totalPaidInputVal;

      // PRIORITY 1: Clear Old Due (Loan)
      if (oldDueSnap > 0 && remaining > 0) {
        if (remaining >= oldDueSnap) {
          allocatedToOldDue = oldDueSnap;
          remaining = _round(remaining - oldDueSnap);
        } else {
          allocatedToOldDue = remaining;
          remaining = 0.0;
        }
      }

      // PRIORITY 2: Clear Current Invoice (Sales)
      if (remaining > 0) {
        if (remaining >= grandTotal) {
          allocatedToInvoice = grandTotal;
          remaining = _round(remaining - grandTotal);
        } else {
          allocatedToInvoice = remaining;
          remaining = 0.0;
        }
      }

      // PRIORITY 3: Clear Previous Running Due (Surplus)
      // If there is still money left, and the debtor has previous running due
      if (remaining > 0 && runningDueSnap > 0) {
        // We apply the surplus to running due.
        // We generally apply all remaining surplus, assuming user meant to pay debt.
        // If remaining > runningDueSnap, the excess effectively becomes an advance.
        allocatedToPrevRunningDue = remaining;
      }
    } else {
      // Retailer / Condition: All money goes to Invoice (up to total bill)
      allocatedToInvoice =
          totalPaidInputVal > grandTotal ? grandTotal : totalPaidInputVal;
    }

    double invoiceDueAmount = _round(grandTotal - allocatedToInvoice);
    if (invoiceDueAmount < 0) invoiceDueAmount = 0;

    // 3. PREPARE DATA MAPS
    Map<String, dynamic> rawPaymentDetails = {
      "type": isConditionSale.value ? "condition_partial" : "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
      "bkashNumber": bkashNumberC.text.trim(),
      "nagadNumber": nagadNumberC.text.trim(),
      "bankName": bankNameC.text.trim(),
      "accountNumber": bankAccC.text.trim(),
    };

    // This map stores the breakdown for future reference (and PDF)
    Map<String, dynamic> invoicePaymentMap = {
      ...rawPaymentDetails,
      "totalPaidInput": totalPaidInputVal,
      "paidForOldDue": allocatedToOldDue,
      "paidForInvoice": allocatedToInvoice,
      "paidForPrevRunning": allocatedToPrevRunningDue, // NEW FIELD
      "due": invoiceDueAmount,
      "currency": "BDT",
    };

    List<Map<String, dynamic>> orderItems =
        cart.map((item) {
          return {
            "productId": item.product.id,
            "name": item.product.name,
            "model": item.product.model,
            "brand": item.product.brand,
            "qty": item.quantity.value,
            "saleRate": item.priceAtSale,
            "costRate": item.product.avgPurchasePrice,
            "subtotal": item.subtotal,
          };
        }).toList();

    List<Map<String, dynamic>> stockUpdates =
        cart
            .map((item) => {'id': item.product.id, 'qty': item.quantity.value})
            .toList();

    // 4. EXECUTE BATCH
    bool stockSuccess = await productCtrl.updateStockBulk(stockUpdates);
    if (!stockSuccess) {
      isProcessing.value = false;
      Get.snackbar("Stock Error", "Stock update failed. Sale canceled.");
      return;
    }

    try {
      WriteBatch batch = _db.batch();
      int cartonsInt = int.tryParse(cartonsC.text) ?? 0;

      // Master Sales Order
      DocumentReference orderRef = _db.collection('sales_orders').doc(invNo);
      batch.set(orderRef, {
        "invoiceId": invNo,
        "timestamp": FieldValue.serverTimestamp(),
        "date": DateFormat('yyyy-MM-dd HH:mm:ss').format(saleDate),
        "customerType": customerType.value,
        "customerName": fName,
        "customerPhone": fPhone,
        "debtorId": debtorId,
        "shopName": shopC.text,
        "isCondition": isConditionSale.value,
        "deliveryAddress": addressC.text,
        "challanNo": finalChallan,
        "cartons": isConditionSale.value ? cartonsInt : 0,
        "courierName": isConditionSale.value ? selectedCourier.value : null,
        "courierDue": isConditionSale.value ? invoiceDueAmount : 0,
        "packagerName": selectedPackager.value,
        "items": orderItems,
        "subtotal": subtotalAmount,
        "discount": discountVal.value,
        "grandTotal": grandTotal,
        "totalCost": totalInvoiceCost,
        "profit": invoiceProfit,
        "paymentDetails": invoicePaymentMap,
        "isFullyPaid": invoiceDueAmount <= 0,
        "snapshotOldDue": oldDueSnap,
        "snapshotRunningDue": runningDueSnap,
        "status":
            isConditionSale.value
                ? (invoiceDueAmount <= 0 ? "completed" : "on_delivery")
                : "completed",
      });

      // --- BRANCH LOGIC ---

      if (isConditionSale.value) {
        // Condition Sale Logic (Unchanged)
        DocumentReference condCustRef = _db
            .collection('condition_customers')
            .doc(fPhone);
        batch.set(condCustRef, {
          "name": fName,
          "phone": fPhone,
          "address": addressC.text,
          "shop": shopC.text,
          "lastChallan": finalChallan,
          "lastCourier": selectedCourier.value,
          "lastUpdated": FieldValue.serverTimestamp(),
          "totalCourierDue": FieldValue.increment(invoiceDueAmount),
        }, SetOptions(merge: true));

        DocumentReference condTxRef = condCustRef
            .collection('orders')
            .doc(invNo);
        batch.set(condTxRef, {
          "invoiceId": invNo,
          "challanNo": finalChallan,
          "grandTotal": grandTotal,
          "advance": allocatedToInvoice,
          "courierDue": invoiceDueAmount,
          "courierName": selectedCourier.value,
          "cartons": cartonsInt,
          "items": orderItems,
          "date": Timestamp.fromDate(saleDate),
          "status": invoiceDueAmount <= 0 ? "completed" : "pending_courier",
        });

        if (selectedCourier.value != null && invoiceDueAmount > 0) {
          DocumentReference courierRef = _db
              .collection('courier_ledgers')
              .doc(selectedCourier.value);
          batch.set(courierRef, {
            "name": selectedCourier.value,
            "totalDue": FieldValue.increment(invoiceDueAmount),
            "lastUpdated": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (allocatedToInvoice > 0) {
          DocumentReference dailyRef = _db.collection('daily_sales').doc();
          batch.set(dailyRef, {
            "name": "$fName (Condition)",
            "amount": grandTotal,
            "paid": allocatedToInvoice,
            "pending": invoiceDueAmount,
            "customerType": "condition_advance",
            "timestamp": Timestamp.fromDate(saleDate),
            "paymentMethod": invoicePaymentMap,
            "createdAt": FieldValue.serverTimestamp(),
            "source": "pos_condition_sale",
            "transactionId": invNo,
            "invoiceId": invNo,
            "status": invoiceDueAmount <= 0 ? "paid" : "partial",
            "packagerName": selectedPackager.value,
          });
        }
      } else if (customerType.value == "Debtor" && debtorId != null) {
        // --- DEBTOR SALE LOGIC (UPDATED WITH 3-STEP) ---

        // A. Debtor Analytics
        DocumentReference analyticsRef = _db
            .collection('debtor_transaction_history')
            .doc(invNo);
        batch.set(analyticsRef, {
          "invoiceId": invNo,
          "debtorId": debtorId,
          "debtorName": fName,
          "date": FieldValue.serverTimestamp(),
          "saleAmount": grandTotal,
          "costAmount": totalInvoiceCost,
          "profit": invoiceProfit,
          "itemsSummary":
              orderItems.map((e) => "${e['model']} x${e['qty']}").toList(),
        });

        // B. PAY OLD DUE (Priority 1)
        if (allocatedToOldDue > 0) {
          DocumentReference oldPayRef =
              _db
                  .collection('debatorbody')
                  .doc(debtorId)
                  .collection('transactions')
                  .doc();
          batch.set(oldPayRef, {
            "amount": allocatedToOldDue,
            "transactionId": oldPayRef.id,
            "type": "loan_payment",
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Payment via Inv $invNo",
            "paymentMethod": invoicePaymentMap,
          });

          DocumentReference cashRef = _db.collection('cash_ledger').doc();
          batch.set(cashRef, {
            'type': 'deposit',
            'amount': allocatedToOldDue,
            'method': 'multi', 'details': invoicePaymentMap,
            'description': "Loan Repayment: $fName (Inv $invNo)",
            'timestamp': FieldValue.serverTimestamp(),
            'linkedDebtorId': debtorId, 'linkedTxId': oldPayRef.id,
            'source': 'pos_old_due', // Unique Source
          });
        }

        // C. CREATE INVOICE DEBT (Credit)
        DocumentReference creditRef = _db
            .collection('debatorbody')
            .doc(debtorId)
            .collection('transactions')
            .doc(invNo);
        batch.set(creditRef, {
          "amount": grandTotal,
          "transactionId": invNo,
          "type": "credit",
          "date": Timestamp.fromDate(saleDate),
          "createdAt": FieldValue.serverTimestamp(),
          "note": "Invoice $invNo",
        });

        // D. PAY INVOICE (Priority 2 - Debit)
        if (allocatedToInvoice > 0) {
          DocumentReference debitRef = _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc("${invNo}_pay");
          batch.set(debitRef, {
            "amount": allocatedToInvoice,
            "transactionId": "${invNo}_pay",
            "type": "debit",
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Payment for Inv $invNo",
            "paymentMethod": invoicePaymentMap,
          });
        }

        // E. PAY PREVIOUS RUNNING DUE (Priority 3 - Debit Surplus)
        // This is the missing piece you asked for!
        if (allocatedToPrevRunningDue > 0) {
          // 1. Transaction in Debtor History (Reduces Balance)
          DocumentReference surplusRef = _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc("${invNo}_surplus");
          batch.set(surplusRef, {
            "amount": allocatedToPrevRunningDue,
            "transactionId": "${invNo}_surplus",
            "type": "debit", // Reduces Running Balance
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Surplus Pay from Inv $invNo",
            "paymentMethod": invoicePaymentMap,
          });

          // 2. Cash Ledger Entry (Money In)
          // We treat this as "Due Collection" separate from the invoice sale
          DocumentReference cashRef2 = _db.collection('cash_ledger').doc();
          batch.set(cashRef2, {
            'type': 'deposit',
            'amount': allocatedToPrevRunningDue,
            'method': 'multi', 'details': invoicePaymentMap,
            'description': "Prev Due Collection: $fName (Inv $invNo)",
            'timestamp': FieldValue.serverTimestamp(),
            'linkedDebtorId': debtorId, 'linkedTxId': surplusRef.id,
            'source':
                'pos_running_collection', // Unique Source for Ledger Reports
          });
        }

        // F. DAILY SALES ENTRY
        // IMPORTANT: Only record 'paid' as 'allocatedToInvoice'.
        // 'allocatedToOldDue' and 'allocatedToPrevRunningDue' are handled in Ledger.
        DocumentReference dailyRef = _db.collection('daily_sales').doc();
        batch.set(dailyRef, {
          "name": fName,
          "amount": grandTotal,
          "paid": allocatedToInvoice,
          "pending": invoiceDueAmount,
          "customerType": "debtor",
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": invoicePaymentMap,
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
          "status": invoiceDueAmount <= 0 ? "paid" : "due",
          "packagerName": selectedPackager.value,
        });
      } else {
        // Retailer Sale
        DocumentReference custRef = _db.collection('customers').doc(fPhone);
        batch.set(custRef, {
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "lastInv": invNo,
          "lastShopDate": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        DocumentReference custOrdRef = custRef.collection('orders').doc(invNo);
        batch.set(custOrdRef, {
          "invoiceId": invNo,
          "grandTotal": grandTotal,
          "timestamp": FieldValue.serverTimestamp(),
          "link": "sales_orders/$invNo",
        });

        DocumentReference dailyRef = _db.collection('daily_sales').doc();
        batch.set(dailyRef, {
          "name": fName,
          "amount": grandTotal,
          "paid": allocatedToInvoice,
          "pending": 0.0,
          "customerType": "retailer",
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": rawPaymentDetails,
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
          "packagerName": selectedPackager.value,
        });
      }

      await batch.commit();

      User? currentUser = FirebaseAuth.instance.currentUser;
      String authName = "Authorized Officer";
      String authPhone = "01720677206";
      if (currentUser != null && currentUser.displayName != null) {
        String rawData = currentUser.displayName!;
        if (rawData.contains('|')) {
          List<String> parts = rawData.split('|');
          authName = parts[0].trim();
          if (parts.length > 1) authPhone = parts[1].trim();
        } else {
          authName = rawData;
        }
      }

      if (debtorId != null) debtorCtrl.loadDebtorTransactions(debtorId);

      await _generatePdf(
        invNo,
        fName,
        fPhone,
        invoicePaymentMap,
        orderItems,
        isCondition: isConditionSale.value,
        challan: finalChallan,
        address: addressC.text,
        courier: selectedCourier.value,
        cartons: cartonsInt,
        shopName: shopC.text,
        oldDueSnap: oldDueSnap,
        runningDueSnap: runningDueSnap,
        authorizedName: authName,
        authorizedPhone: authPhone,
        discount: discountVal.value,
        packagerName: selectedPackager.value,
      );

      _resetAll();
      Get.snackbar(
        "Success",
        "Sale Finalized Successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      List<Map<String, dynamic>> rollbackStock =
          cart
              .map(
                (item) => {'id': item.product.id, 'qty': -item.quantity.value},
              )
              .toList();
      await productCtrl.updateStockBulk(rollbackStock);
      Get.snackbar(
        "Error",
        "Transaction Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  void _resetAll() {
    cart.clear();
    nameC.clear();
    phoneC.clear();
    shopC.clear();
    addressC.clear();
    challanC.clear();
    cartonsC.clear();
    selectedCourier.value = null;
    discountC.clear();
    cashC.clear();
    bkashC.clear();
    bkashNumberC.clear();
    nagadC.clear();
    nagadNumberC.clear();
    bankC.clear();
    bankNameC.clear();
    bankAccC.clear();
    discountVal.value = 0.0;
    totalPaidInput.value = 0.0;
    changeReturn.value = 0.0;
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();
    calculatedCourierDue.value = 0.0;
    debtorOldDue.value = 0.0;
    debtorRunningDue.value = 0.0;
    selectedPackager.value = null;
  }

  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items, {
    bool isCondition = false,
    String challan = "",
    String address = "",
    String? courier,
    int? cartons,
    String shopName = "",
    double oldDueSnap = 0.0,
    double runningDueSnap = 0.0,
    required String authorizedName,
    required String authorizedPhone,
    double discount = 0.0,
    String? packagerName,
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidInv =
        double.tryParse(payMap['paidForInvoice'].toString()) ?? 0.0;
    // Include surplus in paid total for PDF
    double paidPrevRun =
        double.tryParse(payMap['paidForPrevRunning'].toString()) ?? 0.0;

    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );

    // Balance Math for PDF
    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;

    // Previous Running Due calculation
    double remainingPrevRunning = runningDueSnap - paidPrevRun;
    if (remainingPrevRunning < 0) remainingPrevRunning = 0;

    double netTotalDue = remainingOldDue + remainingPrevRunning + invDue;
    double totalPaidCurrent = paidOld + paidInv + paidPrevRun;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(20),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) {
          return [
            _buildCompanyHeader(boldFont, regularFont),
            pw.SizedBox(height: 15),
            _buildInvoiceInfo(
              boldFont,
              regularFont,
              invId,
              name,
              phone,
              isCondition,
              address,
              courier,
              shopName,
              packagerName,
            ),
            pw.SizedBox(height: 15),
            _buildProfessionalTable(boldFont, regularFont, italicFont, items),
            pw.SizedBox(height: 10),
            _buildDetailedSummary(
              boldFont,
              regularFont,
              payMap,
              isCondition,
              cartons,
              totalPreviousBalance,
              totalPaidCurrent,
              netTotalDue,
              subTotal,
              discount,
            ),
            pw.SizedBox(height: 25),
            _buildSignatures(
              regularFont,
              boldFont,
              authorizedName,
              authorizedPhone,
            ),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          build: (context) {
            return [
              _buildCompanyHeader(boldFont, regularFont),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                color: PdfColors.grey200,
                child: pw.Center(
                  child: pw.Text(
                    "DELIVERY CHALLAN",
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              _buildChallanInfo(
                boldFont,
                regularFont,
                invId,
                name,
                phone,
                challan,
                address,
                courier,
                cartons,
                shopName,
              ),
              pw.SizedBox(height: 10),
              pw.Spacer(),
              _buildConditionBox(boldFont, regularFont, payMap),
              pw.SizedBox(height: 30),
              _buildSignatures(
                regularFont,
                boldFont,
                authorizedName,
                authorizedPhone,
              ),
            ];
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildCompanyHeader(pw.Font bold, pw.Font reg) {
    return pw.Center(
      child: pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 2)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              "G TEL JOY EXPRESS",
              style: pw.TextStyle(font: bold, fontSize: 24, letterSpacing: 1),
            ),
            pw.Text(
              "Mobile Parts Wholesaler",
              style: pw.TextStyle(font: reg, fontSize: 10, letterSpacing: 3),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Gulistan Shopping Complex (Hall Market), 2 Bangabandu Avenue, Dhaka 1000",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "Hotline: 01720677206, 01911026222 | Email: gtel01720677206@gmail.com",
              style: pw.TextStyle(font: bold, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInvoiceInfo(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    bool isCond,
    String addr,
    String? courier,
    String shopName,
    String? packagerName,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionHeader("INVOICE DETAILS", bold),
              pw.SizedBox(height: 5),
              _infoRow("Invoice #", invId, bold, reg),
              _infoRow(
                "Date",
                DateFormat('dd-MMM-yyyy').format(DateTime.now()),
                bold,
                reg,
              ),
              _infoRow("Type", isCond ? "Condition" : "Cash/Credit", bold, reg),
              if (isCond && courier != null)
                _infoRow("Courier", courier, bold, reg),
              if (packagerName != null)
                _infoRow("Packed By", packagerName, bold, reg),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionHeader("BILL TO", bold),
              pw.SizedBox(height: 5),
              pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11)),
              if (shopName.isNotEmpty)
                pw.Text(shopName, style: pw.TextStyle(font: reg, fontSize: 10)),
              pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 10)),
              if (addr.isNotEmpty)
                pw.Text(addr, style: pw.TextStyle(font: reg, fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionHeader(String title, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
      color: PdfColors.grey300,
      child: pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  pw.Widget _infoRow(String label, String value, pw.Font bold, pw.Font reg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 50,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(font: bold, fontSize: 9),
            ),
          ),
          pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalTable(
    pw.Font bold,
    pw.Font reg,
    pw.Font italic,
    List<Map<String, dynamic>> items,
  ) {
    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey),
        horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(45),
        3: const pw.FixedColumnWidth(30),
        4: const pw.FixedColumnWidth(50),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th("SL", bold),
            _th("DESCRIPTION", bold, align: pw.TextAlign.left),
            _th("RATE", bold, align: pw.TextAlign.right),
            _th("QTY", bold, align: pw.TextAlign.center),
            _th("TOTAL", bold, align: pw.TextAlign.right),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item['name'],
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    if (item['model'] != null)
                      pw.Text(
                        "${item['model'] ?? ''}",
                        style: pw.TextStyle(
                          font: italic,
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              _td(item['saleRate'].toString(), reg, align: pw.TextAlign.right),
              _td(item['qty'].toString(), bold, align: pw.TextAlign.center),
              _td(item['subtotal'].toString(), bold, align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: 8),
    ),
  );
  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: 9),
    ),
  );

  pw.Widget _buildDetailedSummary(
    pw.Font bold,
    pw.Font reg,
    Map payMap,
    bool isCond,
    int? cartons,
    double prevDue,
    double totalPaid,
    double netDue,
    double subTotal,
    double discount,
  ) {
    double currentInvTotal = subTotal - discount;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "PAYMENT METHOD",
                  style: pw.TextStyle(font: bold, fontSize: 8),
                ),
                pw.Divider(thickness: 0.5),
                _buildCompactPaymentLines(payMap, reg),
                if (cartons != null && cartons > 0) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Packaged: $cartons Cartons",
                    style: pw.TextStyle(font: bold, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              _summaryRow("Subtotal", subTotal.toStringAsFixed(2), reg),
              if (discount > 0)
                _summaryRow(
                  "Discount",
                  "- ${discount.toStringAsFixed(2)}",
                  reg,
                ),
              pw.Divider(),
              _summaryRow(
                "INVOICE TOTAL",
                currentInvTotal.toStringAsFixed(2),
                bold,
                size: 10,
              ),
              if (!isCond) ...[
                pw.SizedBox(height: 5),
                _summaryRow("Prev. Balance", prevDue.toStringAsFixed(2), reg),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                _summaryRow(
                  "TOTAL PAYABLE",
                  (prevDue + currentInvTotal).toStringAsFixed(2),
                  bold,
                ),
                if (totalPaid > 0)
                  _summaryRow("Paid", "(${totalPaid.toStringAsFixed(2)})", reg),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 5),
                  padding: const pw.EdgeInsets.all(5),
                  color: PdfColors.black,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "NET DUE",
                        style: pw.TextStyle(
                          font: bold,
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        netDue.toStringAsFixed(2),
                        style: pw.TextStyle(
                          font: bold,
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _summaryRow("Paid", totalPaid.toStringAsFixed(2), reg),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: _summaryRow(
                    "COLLECTABLE",
                    double.parse(payMap['due'].toString()).toStringAsFixed(2),
                    bold,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font font, {
    double size = 9,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
      ],
    ),
  );

  pw.Widget _buildSignatures(
    pw.Font reg,
    pw.Font bold,
    String authName,
    String authPhone,
  ) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(authName, style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.Text(authPhone, style: pw.TextStyle(font: reg, fontSize: 9)),
          pw.Container(
            width: 120,
            height: 1,
            color: PdfColors.black,
            margin: const pw.EdgeInsets.only(top: 2),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            "Authorized Signature",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(width: 120, height: 1, color: PdfColors.black),
          pw.SizedBox(height: 2),
          pw.Text(
            "Receiver Signature",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ],
      ),
    ],
  );

  pw.Widget _buildCompactPaymentLines(Map payMap, pw.Font reg) {
    List<String> lines = [];
    double cash = double.tryParse(payMap['cash'].toString()) ?? 0;
    double bkash = double.tryParse(payMap['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(payMap['nagad'].toString()) ?? 0;
    double bank = double.tryParse(payMap['bank'].toString()) ?? 0;

    if (cash > 0) lines.add("Cash: $cash");
    if (bkash > 0) lines.add("Bkash: $bkash");
    if (nagad > 0) lines.add("Nagad: $nagad");
    if (bank > 0) lines.add("Bank: $bank");

    if (lines.isEmpty) {
      return pw.Text(
        "Unpaid / Due",
        style: pw.TextStyle(font: reg, fontSize: 8),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children:
          lines
              .map(
                (l) => pw.Text(l, style: pw.TextStyle(font: reg, fontSize: 8)),
              )
              .toList(),
    );
  }

  pw.Widget _buildChallanInfo(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    String challan,
    String addr,
    String? courier,
    int? cartons,
    String shopName,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "LOGISTICS / COURIER",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                pw.Divider(thickness: 0.5),
                pw.Text(
                  "Name: ${courier ?? 'N/A'}",
                  style: pw.TextStyle(font: reg, fontSize: 9),
                ),
                pw.Text(
                  "Challan: $challan",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                if (cartons != null)
                  pw.Text(
                    "Total Cartons: $cartons",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "DELIVER TO",
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                pw.Divider(thickness: 0.5),
                pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 10)),
                pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 9)),
                pw.Text(
                  addr,
                  style: pw.TextStyle(font: reg, fontSize: 8),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildConditionBox(pw.Font bold, pw.Font reg, Map payMap) {
    double due = double.parse(payMap['due'].toString());
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "CONDITION PAYMENT INSTRUCTION",
            style: pw.TextStyle(font: reg, fontSize: 8),
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                "PLEASE COLLECT:  ",
                style: pw.TextStyle(font: bold, fontSize: 12),
              ),
              pw.Text(
                "Tk ${due.toStringAsFixed(0)} /=",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
              pw.Text(
                "+CHARGES",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
