// ignore_for_file: deprecated_member_use, avoid_print, empty_catches, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// IMPORTANT: Update these imports to match your actual file structure
import '../Stock/controller.dart';
import '../Stock/model.dart';
import '../Web Screen/Debator Finance/debatorcontroller.dart';
import '../Web Screen/Debator Finance/model.dart';
import '../Web Screen/Sales/controller.dart';

// --- SALES CART ITEM MODEL ---
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
  bool get isLoss => priceAtSale < product.avgPurchasePrice;
}

// --- LIVE SALES CONTROLLER ---
class LiveSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // External Controllers
  final productCtrl = Get.find<ProductController>();
  final debtorCtrl = Get.find<DebatorController>();
  final dailyCtrl = Get.find<DailySalesController>();

  // --- STATE VARIABLES ---
  final RxString customerType = "WHOLESALE".obs;
  final RxBool isConditionSale = false.obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;

  // Debtor Selection & Search State
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();
  final RxList<DebtorModel> filteredDebtors = <DebtorModel>[].obs;

  // Search Debounce Timer
  Timer? _searchDebounce;

  final List<String> customerTypesList = ['WHOLESALE', 'VIP', 'AGENT'];

  final List<String> courierList = [
    'A.J.R',
    'Pathao',
    'Korutoya',
    'Sundarban',
    'Afjal',
    'S.A.P',
    'Steadfast',
    'RedX',
    'Other',
  ];

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
  double get totalPreviousDue => debtorOldDue.value + debtorRunningDue.value;

  // --- TEXT CONTROLLERS ---
  final debtorPhoneSearch = TextEditingController();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();
  final addressC = TextEditingController();
  final challanC = TextEditingController();
  final cartonsC = TextEditingController();
  final otherCourierC = TextEditingController();
  final discountC = TextEditingController();

  // Payment Controllers
  final cashC = TextEditingController();
  final bkashC = TextEditingController();
  final bkashNumberC = TextEditingController();
  final nagadC = TextEditingController();
  final nagadNumberC = TextEditingController();
  final bankC = TextEditingController();
  final bankNameC = TextEditingController();
  final bankAccC = TextEditingController();

  final RxDouble discountVal = 0.0.obs;
  final RxnString selectedCourier = RxnString();
  final RxDouble totalPaidInput = 0.0.obs;
  final RxDouble changeReturn = 0.0.obs;
  final RxDouble calculatedCourierDue = 0.0.obs;

  // --- PAGINATION HELPERS ---
  int get currentPage => productCtrl.currentPage.value;
  int get totalPages =>
      (productCtrl.totalProducts.value / productCtrl.pageSize.value).ceil();
  void nextPage() => productCtrl.nextPage();
  void prevPage() => productCtrl.previousPage();

  @override
  void onInit() {
    super.onInit();
    cashC.addListener(updatePaymentCalculations);
    bkashC.addListener(updatePaymentCalculations);
    nagadC.addListener(updatePaymentCalculations);
    bankC.addListener(updatePaymentCalculations);

    // --- DEBTOR SEARCH LISTENER ---
    debtorPhoneSearch.addListener(() {
      if (customerType.value != 'AGENT') return;

      String query = debtorPhoneSearch.text.trim();

      if (selectedDebtor.value != null &&
          query != selectedDebtor.value!.phone) {
        selectedDebtor.value = null;
      }

      if (query.isEmpty) {
        filteredDebtors.clear();
        return;
      }

      if (selectedDebtor.value != null &&
          query == selectedDebtor.value!.phone) {
        filteredDebtors.clear();
        return;
      }

      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _searchGlobalAgent(query);
      });
    });

    ever(customerType, (_) => _handleTypeChange());
    ever(isConditionSale, (_) => updatePaymentCalculations());
    ever(selectedCourier, (val) {
      if (val != null && val != 'Other') {
        fetchCourierTotalDue(val);
      } else {
        calculatedCourierDue.value = 0.0;
      }
    });

    if (productCtrl.allProducts.isEmpty) productCtrl.fetchProducts();

    ever(selectedDebtor, (DebtorModel? debtor) async {
      if (debtor != null && customerType.value == 'AGENT') {
        nameC.text = debtor.name;
        phoneC.text = debtor.phone;
        addressC.text = debtor.address;

        var breakdown = await debtorCtrl.getInstantDebtorBreakdown(debtor.id);
        debtorOldDue.value = breakdown['loan'] ?? 0.0;
        debtorRunningDue.value = breakdown['running'] ?? 0.0;
      } else {
        debtorOldDue.value = 0.0;
        debtorRunningDue.value = 0.0;
      }
    });
  }

  Future<void> _searchGlobalAgent(String queryText) async {
    try {
      String q = queryText.trim();
      String qLower = q.toLowerCase();
      String qCap = qLower.capitalizeFirst ?? qLower;

      Map<String, DebtorModel> results = {};

      var kwSnap =
          await _db
              .collection('debatorbody')
              .where('searchKeywords', arrayContains: qLower)
              .limit(10)
              .get();

      var phoneSnap =
          await _db
              .collection('debatorbody')
              .where('phone', isGreaterThanOrEqualTo: q)
              .where('phone', isLessThan: '$q\uf8ff')
              .limit(10)
              .get();

      var nameCapSnap =
          await _db
              .collection('debatorbody')
              .where('name', isGreaterThanOrEqualTo: qCap)
              .where('name', isLessThan: '$qCap\uf8ff')
              .limit(10)
              .get();

      var nameLowerSnap =
          await _db
              .collection('debatorbody')
              .where('name', isGreaterThanOrEqualTo: qLower)
              .where('name', isLessThan: '$qLower\uf8ff')
              .limit(10)
              .get();

      for (var doc in kwSnap.docs) {
        results[doc.id] = DebtorModel.fromFirestore(doc);
      }
      for (var doc in phoneSnap.docs) {
        results[doc.id] = DebtorModel.fromFirestore(doc);
      }
      for (var doc in nameCapSnap.docs) {
        results[doc.id] = DebtorModel.fromFirestore(doc);
      }
      for (var doc in nameLowerSnap.docs) {
        results[doc.id] = DebtorModel.fromFirestore(doc);
      }

      var localMatches =
          debtorCtrl.bodies
              .where(
                (d) =>
                    d.name.toLowerCase().contains(qLower) ||
                    d.phone.contains(q) ||
                    d.nid.contains(q) ||
                    d.address.toLowerCase().contains(qLower),
              )
              .toList();

      for (var m in localMatches) {
        results[m.id] = m;
      }

      filteredDebtors.value = results.values.toList();
    } catch (e) {
      print("Global Agent Search Error: $e");
    }
  }

  void selectDebtorFromDropdown(DebtorModel debtor) {
    selectedDebtor.value = debtor;
    debtorPhoneSearch.text = debtor.phone;
    filteredDebtors.clear();
  }

  void refreshPage() {
    _resetAll();
    productCtrl.fetchProducts();
    Get.snackbar(
      "Refreshed",
      "Page data has been reset.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blueAccent,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _handleTypeChange() {
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();
    filteredDebtors.clear();
    debtorOldDue.value = 0.0;
    debtorRunningDue.value = 0.0;

    for (var item in cart) {
      item.priceAtSale =
          customerType.value == "AGENT"
              ? item.product.agent
              : item.product.wholesale;
    }
    cart.refresh();
    updatePaymentCalculations();
  }

  void updateItemPrice(int index, String val) {
    if (customerType.value == "VIP" || customerType.value == "AGENT") {
      Get.snackbar(
        "Action Denied",
        "Price is fixed for ${customerType.value} customers.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      cart.refresh();
      return;
    }

    double? newPrice = double.tryParse(val);
    if (newPrice == null) return;
    if (newPrice < 0) newPrice = 0.0;

    if (customerType.value == "WHOLESALE") {
      double minAllowedPrice = cart[index].product.agent;
      if (newPrice < minAllowedPrice) {
        Get.snackbar(
          "Price Constraint",
          "Wholesale price cannot be less than Agent price (৳$minAllowedPrice).",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        cart.refresh();
        return;
      }
    }

    cart[index].priceAtSale = newPrice;
    cart.refresh();
    updatePaymentCalculations();
  }

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

    double price = customerType.value == "AGENT" ? p.agent : p.wholesale;
    var existingItem = cart.firstWhereOrNull((item) => item.product.id == p.id);

    if (existingItem != null) {
      cart.remove(existingItem);
      cart.insert(0, existingItem);
      if (existingItem.quantity.value < p.stockQty) {
        existingItem.quantity.value++;
      } else {
        Get.snackbar("Limit", "Max stock reached");
      }
      cart.refresh();
    } else {
      cart.insert(
        0,
        SalesCartItem(product: p, initialQty: 1, priceAtSale: price),
      );
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

  void updatePaymentCalculations() {
    double cash = double.tryParse(cashC.text) ?? 0;
    double bkash = double.tryParse(bkashC.text) ?? 0;
    double nagad = double.tryParse(nagadC.text) ?? 0;
    double bank = double.tryParse(bankC.text) ?? 0;

    totalPaidInput.value = _round(cash + bkash + nagad + bank);

    if (!isConditionSale.value) {
      if (totalPaidInput.value > grandTotal && customerType.value != "AGENT") {
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
  double _round(double val) => double.parse(val.toStringAsFixed(2));

  Future<void> finalizeSale() async {
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
      return;
    }
    if (selectedPackager.value == null) {
      Get.snackbar("Required", "Select Packager Name");
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
    if (nameC.text.isEmpty || phoneC.text.isEmpty) {
      Get.snackbar("Required", "Customer Name & Phone required");
      return;
    }

    String finalChallan =
        challanC.text.trim().isEmpty ? "0" : challanC.text.trim();
    String? finalCourierName =
        (isConditionSale.value && selectedCourier.value == 'Other')
            ? otherCourierC.text.trim()
            : selectedCourier.value;

    String fName = nameC.text.trim();
    String fPhone = phoneC.text.trim();
    String? finalDebtorId;

    if (customerType.value == "AGENT") {
      if (selectedDebtor.value != null) {
        finalDebtorId = selectedDebtor.value!.id;
        fName = selectedDebtor.value!.name;
        fPhone = selectedDebtor.value!.phone;
      } else {
        try {
          isProcessing.value = true;
          DocumentReference newDebtorRef = _db.collection('debatorbody').doc();
          finalDebtorId = newDebtorRef.id;

          await newDebtorRef.set({
            'id': finalDebtorId,
            'name': fName,
            'phone': fPhone,
            'address': addressC.text,
            'des': shopC.text,
            'nid': '',
            'balance': 0.0,
            'purchaseDue': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
            'lastTransactionDate': FieldValue.serverTimestamp(),
            'searchKeywords': _generateSearchKeywords(fName, fPhone),
          });
          await debtorCtrl.loadBodies();
          Get.snackbar("New Agent", "Created account for $fName");
        } catch (e) {
          isProcessing.value = false;
          Get.snackbar("Error", "Failed to create new Agent: $e");
          return;
        }
      }
    }

    User? currentUser = FirebaseAuth.instance.currentUser;
    String sellerUid = currentUser?.uid ?? 'unknown';
    String sellerName =
        currentUser?.displayName?.split('|')[0].trim() ?? 'Admin';
    String sellerPhone =
        (currentUser?.displayName?.contains('|') ?? false)
            ? currentUser!.displayName!.split('|')[1].trim()
            : "01720677206";

    if (totalPaidInput.value <= 0) {
      Get.defaultDialog(
        title: "No Payment Details",
        middleText: "No payment entered. Proceed as Due/Credit sale?",
        textConfirm: "PROCEED",
        textCancel: "CANCEL",
        confirmTextColor: Colors.white,
        buttonColor: Colors.redAccent,
        onConfirm: () {
          Get.back();
          _processTransaction(
            finalCourierName: finalCourierName,
            finalChallan: finalChallan,
            fName: fName,
            fPhone: fPhone,
            debtorId: finalDebtorId,
            sellerUid: sellerUid,
            sellerName: sellerName,
            sellerPhone: sellerPhone,
          );
        },
      );
      return;
    }

    _processTransaction(
      finalCourierName: finalCourierName,
      finalChallan: finalChallan,
      fName: fName,
      fPhone: fPhone,
      debtorId: finalDebtorId,
      sellerUid: sellerUid,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
    );
  }

  List<String> _generateSearchKeywords(String name, String phone) {
    List<String> keywords = [];
    String lowerName = name.toLowerCase();
    for (int i = 1; i <= lowerName.length; i++) {
      keywords.add(lowerName.substring(0, i));
    }
    for (int i = 1; i <= phone.length; i++) {
      keywords.add(phone.substring(0, i));
    }
    List<String> parts = lowerName.split(' ');
    for (String part in parts) {
      if (part.isNotEmpty) {
        for (int i = 1; i <= part.length; i++) {
          keywords.add(part.substring(0, i));
        }
      }
    }
    return keywords.toSet().toList();
  }

  // --- CASH LEDGER: Helper method to perfectly split & map Cash records ---
  void _insertCashLedgerRecords({
    required WriteBatch batch,
    required Map<String, dynamic> payMap,
    required String description,
    required String debtorId,
    required String txId,
    required String sellerUid,
  }) {
    double c = double.tryParse(payMap['cash']?.toString() ?? '0') ?? 0;
    double b = double.tryParse(payMap['bkash']?.toString() ?? '0') ?? 0;
    double n = double.tryParse(payMap['nagad']?.toString() ?? '0') ?? 0;
    double bankAmt = double.tryParse(payMap['bank']?.toString() ?? '0') ?? 0;

    void addRecord(String methodType, double amt, Map<String, dynamic> extra) {
      if (amt <= 0) return;
      DocumentReference ref = _db.collection('cash_ledger').doc();
      batch.set(ref, {
        'amount': amt,
        'description': description,
        'details': {'type': methodType, ...extra},
        'linkedDebtorId': debtorId,
        'linkedTxId': txId,
        'method': methodType,
        'source': 'debtor_collection',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'deposit',
        'userUid': sellerUid,
      });
    }

    addRecord('cash', c, {});
    addRecord('bkash', b, {'bkashNumber': payMap['bkashNumber'] ?? ''});
    addRecord('nagad', n, {'nagadNumber': payMap['nagadNumber'] ?? ''});
    addRecord('bank', bankAmt, {
      'bankName': payMap['bankName'] ?? '',
      'accountNo': payMap['accountNumber'] ?? '', // EXACT MATCH for accountNo
    });
  }

  Future<void> _processTransaction({
    String? finalCourierName,
    required String finalChallan,
    required String fName,
    required String fPhone,
    String? debtorId,
    required String sellerUid,
    required String sellerName,
    required String sellerPhone,
  }) async {
    isProcessing.value = true;
    final String invNo = _generateInvoiceID();
    final DateTime saleDate = DateTime.now();
    double totalPaidInputVal = totalPaidInput.value;

    double allocatedToOldDue = 0.0,
        allocatedToInvoice = 0.0,
        allocatedToPrevRunningDue = 0.0;
    double oldDueSnap = debtorOldDue.value,
        runningDueSnap = debtorRunningDue.value;

    // ==============================================================================
    // NEW PRIORITY LOGIC: CURRENT INVOICE -> OLD DUE -> PREV RUNNING DUE
    // ==============================================================================
    double remaining = totalPaidInputVal;

    // 1. Pay Current Invoice FIRST
    if (remaining > 0) {
      if (remaining >= grandTotal) {
        allocatedToInvoice = grandTotal;
        remaining = _round(remaining - grandTotal);
      } else {
        allocatedToInvoice = remaining;
        remaining = 0.0;
      }
    }

    if (customerType.value == "AGENT" &&
        !isConditionSale.value &&
        debtorId != null) {
      // 2. Pay Old Due (Historic Loan) NEXT
      if (oldDueSnap > 0 && remaining > 0) {
        if (remaining >= oldDueSnap) {
          allocatedToOldDue = oldDueSnap;
          remaining = _round(remaining - oldDueSnap);
        } else {
          allocatedToOldDue = remaining;
          remaining = 0.0;
        }
      }

      // 3. Pay Running Due (Previous Unpaid Bills) LAST
      if (runningDueSnap > 0 && remaining > 0) {
        if (remaining >= runningDueSnap) {
          allocatedToPrevRunningDue = runningDueSnap;
          remaining = _round(remaining - runningDueSnap);
        } else {
          allocatedToPrevRunningDue = remaining;
          remaining = 0.0;
        }
      }
    } else {
      allocatedToInvoice =
          totalPaidInputVal > grandTotal ? grandTotal : totalPaidInputVal;
    }
    // ==============================================================================

    double invoiceDueAmount = _round(grandTotal - allocatedToInvoice);
    if (invoiceDueAmount < 0) invoiceDueAmount = 0;

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
    bool stockSuccess = await productCtrl.updateStockBulk(stockUpdates);
    if (!stockSuccess) {
      isProcessing.value = false;
      Get.snackbar("Stock Error", "Stock update failed. Sale canceled.");
      return;
    }

    try {
      WriteBatch batch = _db.batch();
      DocumentReference orderRef = _db.collection('sales_orders').doc(invNo);

      Map<String, dynamic> masterPaymentMap = _createPaymentMap(
        allocatedToOldDue,
        allocatedToInvoice,
        allocatedToPrevRunningDue,
        invoiceDueAmount,
        totalPaidInputVal,
      );

      // --- EXACT SALES_ORDER SCHEMA ---
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
        "cartons":
            isConditionSale.value ? (int.tryParse(cartonsC.text) ?? 0) : 0,
        "courierName": isConditionSale.value ? finalCourierName : null,
        "courierDue": isConditionSale.value ? invoiceDueAmount : 0,
        "packagerName": selectedPackager.value,
        "soldBy": {"uid": sellerUid, "name": sellerName, "phone": sellerPhone},
        "items": orderItems,
        "subtotal": subtotalAmount,
        "discount": discountVal.value,
        "grandTotal": grandTotal,
        "paid": allocatedToInvoice, // ROOT PAID FIELD ADDED
        "totalCost": totalInvoiceCost,
        "profit": invoiceProfit,
        "paymentDetails": masterPaymentMap, // EXACT NESTED MAP STRUCTURE
        "isFullyPaid": invoiceDueAmount <= 0,
        "snapshotOldDue": oldDueSnap,
        "snapshotRunningDue": runningDueSnap,
        "status":
            isConditionSale.value
                ? (invoiceDueAmount <= 0 ? "completed" : "on_delivery")
                : "completed",
      });

      if (isConditionSale.value) {
        _handleConditionSale(
          batch,
          fName,
          fPhone,
          finalChallan,
          finalCourierName,
          invoiceDueAmount,
          invNo,
          saleDate,
          orderItems,
          sellerName,
          sellerUid,
          sellerPhone,
          masterPaymentMap,
        );
      } else if (customerType.value == "AGENT" && debtorId != null) {
        // Handle Agent Transaction (Ledgers, Running Due payment, etc.)
        await _handleAgentTransaction(
          batch,
          debtorId,
          invNo,
          fName,
          saleDate,
          orderItems,
          sellerName,
          sellerPhone,
          allocatedToOldDue,
          allocatedToInvoice,
          allocatedToPrevRunningDue,
          masterPaymentMap,
          sellerUid,
        );
      } else {
        DocumentReference custRef = _db.collection('customers').doc(fPhone);
        batch.set(custRef, {
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "address": addressC.text,
          "type": customerType.value,
          "lastInv": invNo,
          "lastShopDate": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        DocumentReference custOrdRef = custRef.collection('orders').doc(invNo);
        batch.set(custOrdRef, {
          "invoiceId": invNo,
          "grandTotal": grandTotal,
          "timestamp": FieldValue.serverTimestamp(),
          "link": "sales_orders/$invNo",
          "soldBy": sellerName,
        });

        DocumentReference dailyRef = _db.collection('daily_sales').doc();

        // --- EXACT DAILY_SALES SCHEMA (Non-Agent) ---
        double invoiceDue = _round(grandTotal - allocatedToInvoice);
        Map<String, dynamic> methodMap = _extractPaymentFor(allocatedToInvoice);
        methodMap['pending'] = invoiceDue;

        batch.set(dailyRef, {
          "name": fName,
          "amount": grandTotal,
          "paid": allocatedToInvoice,
          "pending": invoiceDue,
          "customerType": customerType.value.toLowerCase(),
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": methodMap,
          "paymentHistory":
              allocatedToInvoice > 0
                  ? [
                    {
                      "amount": allocatedToInvoice,
                      "note": "Initial Payment",
                      // CRITICAL FIX: Timestamp.fromDate instead of serverTimestamp inside Array
                      "timestamp": Timestamp.fromDate(saleDate),
                      "type": methodMap['method'],
                      "bkashNumber": methodMap['bkashNumber'] ?? "",
                      "nagadNumber": methodMap['nagadNumber'] ?? "",
                      "bankName": methodMap['bankName'] ?? "",
                      "accountNumber": methodMap['accountNumber'] ?? "",
                    },
                  ]
                  : [],
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
          "status": invoiceDue <= 0.5 ? "paid" : "due", // ADDED STATUS FIELD
          "packagerName": selectedPackager.value ?? "Admin",
          "soldByUid": sellerUid,
          "soldByName": sellerName,
          "soldByNumber": sellerPhone,
        });
      }

      await batch.commit();

      if (debtorId != null) debtorCtrl.loadTxPage(debtorId, 1);

      await _generatePdf(
        invNo,
        fName,
        fPhone,
        masterPaymentMap,
        orderItems,
        isCondition: isConditionSale.value,
        challan: finalChallan,
        address: addressC.text,
        courier: finalCourierName,
        cartons: int.tryParse(cartonsC.text),
        shopName: shopC.text,
        oldDueSnap: oldDueSnap,
        runningDueSnap: runningDueSnap,
        authorizedName: sellerName,
        authorizedPhone: sellerPhone,
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

  void _handleConditionSale(
    WriteBatch batch,
    String fName,
    String fPhone,
    String finalChallan,
    String? finalCourierName,
    double invoiceDueAmount,
    String invNo,
    DateTime saleDate,
    List orderItems,
    String sellerName,
    String sellerUid,
    String sellerPhone,
    Map masterPaymentMap,
  ) {
    DocumentReference condCustRef = _db
        .collection('condition_customers')
        .doc(fPhone);
    batch.set(condCustRef, {
      "name": fName,
      "phone": fPhone,
      "address": addressC.text,
      "shop": shopC.text,
      "lastChallan": finalChallan,
      "lastCourier": finalCourierName,
      "lastUpdated": FieldValue.serverTimestamp(),
      "totalCourierDue": FieldValue.increment(invoiceDueAmount),
    }, SetOptions(merge: true));

    DocumentReference condTxRef = condCustRef.collection('orders').doc(invNo);
    batch.set(condTxRef, {
      "invoiceId": invNo,
      "challanNo": finalChallan,
      "grandTotal": grandTotal,
      "advance": masterPaymentMap['paidForInvoice'],
      "courierDue": invoiceDueAmount,
      "courierName": finalCourierName,
      "cartons": int.tryParse(cartonsC.text) ?? 0,
      "items": orderItems,
      "date": Timestamp.fromDate(saleDate),
      "status": invoiceDueAmount <= 0 ? "completed" : "pending_courier",
      "soldBy": sellerName,
    });

    if (finalCourierName != null && invoiceDueAmount > 0) {
      DocumentReference courierRef = _db
          .collection('courier_ledgers')
          .doc(finalCourierName);
      batch.set(courierRef, {
        "name": finalCourierName,
        "totalDue": FieldValue.increment(invoiceDueAmount),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if ((masterPaymentMap['paidForInvoice'] as double) > 0) {
      DocumentReference dailyRef = _db.collection('daily_sales').doc();

      Map<String, dynamic> condMethodMap = _extractPaymentFor(
        masterPaymentMap['paidForInvoice'],
      );
      condMethodMap['pending'] = invoiceDueAmount;

      batch.set(dailyRef, {
        "name": "$fName (Condition)",
        "amount": grandTotal,
        "paid": masterPaymentMap['paidForInvoice'],
        "pending": invoiceDueAmount,
        "customerType": "condition_advance",
        "timestamp": Timestamp.fromDate(saleDate),
        "paymentMethod": condMethodMap,
        "paymentHistory": [
          {
            "amount": masterPaymentMap['paidForInvoice'],
            "note": "Advance Payment",
            // CRITICAL FIX: Timestamp.fromDate instead of serverTimestamp inside Array
            "timestamp": Timestamp.fromDate(saleDate),
            "type": condMethodMap['method'],
            "bkashNumber": condMethodMap['bkashNumber'] ?? "",
            "nagadNumber": condMethodMap['nagadNumber'] ?? "",
            "bankName": condMethodMap['bankName'] ?? "",
            "accountNumber": condMethodMap['accountNumber'] ?? "",
          },
        ],
        "createdAt": FieldValue.serverTimestamp(),
        "source": "pos_condition_sale",
        "transactionId": invNo,
        "invoiceId": invNo,
        "status": invoiceDueAmount <= 0 ? "paid" : "partial",
        "packagerName": selectedPackager.value ?? "Admin",
        "soldByUid": sellerUid,
        "soldByName": sellerName,
        "soldByNumber": sellerPhone,
      });
    }
  }

  Future<void> _handleAgentTransaction(
    WriteBatch batch,
    String debtorId,
    String invNo,
    String fName,
    DateTime saleDate,
    List orderItems,
    String sellerName,
    String sellerPhone,
    double allocatedToOldDue,
    double allocatedToInvoice,
    double allocatedToPrevRunningDue,
    Map masterPaymentMap,
    String sellerUid,
  ) async {
    // 1. Analytics / History
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
      "soldBy": sellerName,
      "soldByPhone": sellerPhone,
    });

    // 2. Handle Old Loan Payment (If any)
    if (allocatedToOldDue > 0) {
      DocumentReference oldPayRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc();

      String oldPayTxId = oldPayRef.id;

      batch.set(oldPayRef, {
        "amount": allocatedToOldDue,
        "transactionId": oldPayTxId,
        "type": "loan_payment",
        "date": Timestamp.fromDate(saleDate),
        "createdAt": FieldValue.serverTimestamp(),
        "note": "Payment via Inv $invNo",
        "paymentMethod": _extractPaymentFor(allocatedToOldDue),
        "collectedBy": sellerName,
        "collectedByPhone": sellerPhone,
      });

      // --- EXACT CASH LEDGER SCHEMA ---
      _insertCashLedgerRecords(
        batch: batch,
        payMap: _extractPaymentFor(allocatedToOldDue),
        description: "Collection from $fName",
        debtorId: debtorId,
        txId: oldPayTxId,
        sellerUid: sellerUid,
      );
    }

    // 3. Record the Current Sale (Credit)
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
      "soldBy": sellerName,
      "soldByPhone": sellerPhone,
    });

    // 4. Record Payment for Current Sale (Debit)
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
        "paymentMethod": _extractPaymentFor(allocatedToInvoice),
        "collectedBy": sellerName,
        "collectedByPhone": sellerPhone,
      });
    }

    // 5. Handle Surplus / Running Due Payment (IMMUNE TO NAME CHANGES NOW!)
    if (allocatedToPrevRunningDue > 0) {
      String surplusTxId = "${invNo}_surplus";

      DocumentReference surplusRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('transactions')
          .doc(surplusTxId);

      batch.set(surplusRef, {
        "amount": allocatedToPrevRunningDue,
        "transactionId": surplusTxId,
        "type": "debit",
        "date": Timestamp.fromDate(saleDate),
        "createdAt": FieldValue.serverTimestamp(),
        "note": "Surplus Pay from Inv $invNo",
        "paymentMethod": _extractPaymentFor(allocatedToPrevRunningDue),
        "collectedBy": sellerName,
      });

      _insertCashLedgerRecords(
        batch: batch,
        payMap: _extractPaymentFor(allocatedToPrevRunningDue),
        description: "Collection from $fName",
        debtorId: debtorId,
        txId: surplusTxId,
        sellerUid: sellerUid,
      );

      // --- LOGIC: FIND AND PAY PREVIOUS BILLS (BY ID INSTEAD OF NAME) ---
      try {
        QuerySnapshot ordersSnap =
            await _db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();

        List<DocumentSnapshot> pendingOrders =
            ordersSnap.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double pending = 0.0;
              if (data['paymentDetails'] != null &&
                  data['paymentDetails']['due'] != null) {
                pending =
                    double.tryParse(data['paymentDetails']['due'].toString()) ??
                    0.0;
              } else {
                pending =
                    (double.tryParse(data['grandTotal']?.toString() ?? '0') ??
                        0.0) -
                    (double.tryParse(data['paid']?.toString() ?? '0') ?? 0.0);
              }
              return pending > 0.5; // Small tolerance
            }).toList();

        pendingOrders.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp t1 =
              dataA['timestamp'] is Timestamp
                  ? dataA['timestamp']
                  : Timestamp.now();
          Timestamp t2 =
              dataB['timestamp'] is Timestamp
                  ? dataB['timestamp']
                  : Timestamp.now();
          return t1.compareTo(t2);
        });

        double remainingToAllocate = allocatedToPrevRunningDue;

        for (var orderDoc in pendingOrders) {
          if (remainingToAllocate <= 0.01) break;

          Map<String, dynamic> oData = orderDoc.data() as Map<String, dynamic>;
          String saleTxId = oData['invoiceId'] ?? orderDoc.id;

          // --- 🚨 CRITICAL FIX: Fetch Daily Sales FIRST to avoid Ghost Dues ---
          QuerySnapshot dailySnap =
              await _db
                  .collection('daily_sales')
                  .where('transactionId', isEqualTo: saleTxId)
                  .limit(1)
                  .get();

          double currentPendingD = 0.0;
          double currentPaidD = 0.0;
          double currentLedgerPaidD = 0.0;
          DocumentSnapshot? dailyDoc;

          if (dailySnap.docs.isNotEmpty) {
            dailyDoc = dailySnap.docs.first;
            Map<String, dynamic> dData =
                dailyDoc.data() as Map<String, dynamic>;
            currentPendingD =
                double.tryParse(dData['pending'].toString()) ?? 0.0;
            currentPaidD = double.tryParse(dData['paid'].toString()) ?? 0.0;
            currentLedgerPaidD =
                double.tryParse(dData['ledgerPaid']?.toString() ?? '0') ?? 0.0;
          }

          // Ghost Due Check
          double salesOrderPending =
              oData['paymentDetails'] != null &&
                      oData['paymentDetails']['due'] != null
                  ? (double.tryParse(
                        oData['paymentDetails']['due'].toString(),
                      ) ??
                      0.0)
                  : ((double.tryParse(oData['grandTotal']?.toString() ?? '0') ??
                          0.0) -
                      (double.tryParse(oData['paid']?.toString() ?? '0') ??
                          0.0));

          // 👉 TRUE PENDING
          double actualPending =
              dailyDoc != null ? currentPendingD : salesOrderPending;

          if (actualPending <= 0.5) {
            // 🚑 AUTO-HEAL
            if (salesOrderPending > 0.5) {
              batch.update(orderDoc.reference, {
                "paid":
                    double.tryParse(oData['grandTotal']?.toString() ?? '0') ??
                    0.0,
                "paymentDetails.due": 0.0,
                "isFullyPaid": true,
                "status": "completed",
              });
            }
            continue; // Move to next order!
          }

          double take =
              (remainingToAllocate >= actualPending)
                  ? actualPending
                  : remainingToAllocate;
          bool isNowFullyPaid = (actualPending - take) <= 0.5;

          Map<String, dynamic> surplusMethodMap = _extractPaymentFor(take);
          double sCash = surplusMethodMap['cash'] ?? 0.0;
          double sBkash = surplusMethodMap['bkash'] ?? 0.0;
          double sNagad = surplusMethodMap['nagad'] ?? 0.0;
          double sBank = surplusMethodMap['bank'] ?? 0.0;

          String bNum = surplusMethodMap['bkashNumber'] ?? '';
          String nNum = surplusMethodMap['nagadNumber'] ?? '';
          String bankName = surplusMethodMap['bankName'] ?? '';
          String accNum = surplusMethodMap['accountNumber'] ?? '';

          // A. UPDATE SALES_ORDERS
          Map<String, dynamic> orderUpdate = {
            "paid": FieldValue.increment(take),
            "paymentDetails.due": FieldValue.increment(-take),
          };

          if (oData['customerName'] != fName) {
            orderUpdate['customerName'] = fName;
          }

          if (sCash > 0) {
            orderUpdate["paymentDetails.cash"] = FieldValue.increment(sCash);
          }
          if (sBkash > 0) {
            orderUpdate["paymentDetails.bkash"] = FieldValue.increment(sBkash);
            if (bNum.isNotEmpty) {
              orderUpdate["paymentDetails.bkashNumber"] = bNum;
            }
          }
          if (sNagad > 0) {
            orderUpdate["paymentDetails.nagad"] = FieldValue.increment(sNagad);
            if (nNum.isNotEmpty) {
              orderUpdate["paymentDetails.nagadNumber"] = nNum;
            }
          }
          if (sBank > 0) {
            orderUpdate["paymentDetails.bank"] = FieldValue.increment(sBank);
            if (bankName.isNotEmpty) {
              orderUpdate["paymentDetails.bankName"] = bankName;
            }
            if (accNum.isNotEmpty) {
              orderUpdate["paymentDetails.accountNumber"] = accNum;
            }
          }

          if (isNowFullyPaid) {
            orderUpdate["isFullyPaid"] = true;
            orderUpdate["status"] = "completed";
          }
          batch.update(orderDoc.reference, orderUpdate);

          // B. FIND AND UPDATE STRICTLY LINKED DAILY_SALES
          if (dailyDoc != null) {
            final newHistoryEntry = {
              'amount': take,
              'note': 'Surplus from $invNo',
              'timestamp': Timestamp.fromDate(saleDate),
              'type': surplusMethodMap['method'],
              'bkashNumber': bNum,
              'nagadNumber': nNum,
              'bankName': bankName,
              'accountNumber': accNum,
            };

            Map<String, dynamic> dailyUpdate = {
              "paid": currentPaidD + take,
              "pending": currentPendingD - take,
              "ledgerPaid": currentLedgerPaidD + take,
              "status": (currentPendingD - take) <= 0.5 ? "paid" : "partial",
              "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
            };

            if (dailyDoc.get('name') != fName) dailyUpdate['name'] = fName;

            if (sCash > 0) {
              dailyUpdate["paymentMethod.cash"] = FieldValue.increment(sCash);
            }
            if (sBkash > 0) {
              dailyUpdate["paymentMethod.bkash"] = FieldValue.increment(sBkash);
              if (bNum.isNotEmpty) {
                dailyUpdate["paymentMethod.bkashNumber"] = bNum;
              }
            }
            if (sNagad > 0) {
              dailyUpdate["paymentMethod.nagad"] = FieldValue.increment(sNagad);
              if (nNum.isNotEmpty) {
                dailyUpdate["paymentMethod.nagadNumber"] = nNum;
              }
            }
            if (sBank > 0) {
              dailyUpdate["paymentMethod.bank"] = FieldValue.increment(sBank);
              if (bankName.isNotEmpty) {
                dailyUpdate["paymentMethod.bankName"] = bankName;
              }
              if (accNum.isNotEmpty) {
                dailyUpdate["paymentMethod.accountNumber"] = accNum;
              }
            }

            batch.update(dailyDoc.reference, dailyUpdate);
          }

          remainingToAllocate -= take;
        }
      } catch (e) {
        print("Error allocating surplus to old bills: $e");
      }
    }

    // 6. Create Daily Sales Entry for CURRENT Invoice
    DocumentReference dailyRef = _db.collection('daily_sales').doc();
    double due = grandTotal - allocatedToInvoice;

    // --- EXACT DAILY_SALES SCHEMA (AGENT) ---
    Map<String, dynamic> agentMethodMap = _extractPaymentFor(
      allocatedToInvoice,
    );
    agentMethodMap['pending'] = due;

    batch.set(dailyRef, {
      "name": fName,
      "amount": grandTotal,
      "paid": allocatedToInvoice,
      "pending": due,
      "customerType": "agent",
      "timestamp": Timestamp.fromDate(saleDate),
      "paymentMethod": agentMethodMap,
      "paymentHistory":
          allocatedToInvoice > 0
              ? [
                {
                  "amount": allocatedToInvoice,
                  "note": "Initial Payment",
                  // CRITICAL FIX: Timestamp.fromDate instead of serverTimestamp inside Array
                  "timestamp": Timestamp.fromDate(saleDate),
                  "type": agentMethodMap['method'],
                  "bkashNumber": agentMethodMap['bkashNumber'] ?? "",
                  "nagadNumber": agentMethodMap['nagadNumber'] ?? "",
                  "bankName": agentMethodMap['bankName'] ?? "",
                  "accountNumber": agentMethodMap['accountNumber'] ?? "",
                },
              ]
              : [],
      "createdAt": FieldValue.serverTimestamp(),
      "source": "pos_sale",
      "transactionId": invNo,
      "invoiceId": invNo,
      "status": due <= 0.5 ? "paid" : "due",
      "packagerName": selectedPackager.value ?? "Admin",
      "soldByUid": sellerUid,
      "soldByName": sellerName,
      "soldByNumber": sellerPhone,
    });
  }

  Map<String, dynamic> _extractPaymentFor(double targetAmount) {
    double rawCash = double.tryParse(cashC.text) ?? 0;
    double rawBkash = double.tryParse(bkashC.text) ?? 0;
    double rawNagad = double.tryParse(nagadC.text) ?? 0;
    double rawBank = double.tryParse(bankC.text) ?? 0;

    double totalInput = rawCash + rawBkash + rawNagad + rawBank;

    double finalCash = 0.0;
    double finalBkash = 0.0;
    double finalNagad = 0.0;
    double finalBank = 0.0;

    if (totalInput > 0 && targetAmount > 0) {
      double ratio = targetAmount / totalInput;

      if ((targetAmount - totalInput).abs() < 0.01) {
        finalCash = rawCash;
        finalBkash = rawBkash;
        finalNagad = rawNagad;
        finalBank = rawBank;
      } else {
        finalCash = _round(rawCash * ratio);
        finalBkash = _round(rawBkash * ratio);
        finalNagad = _round(rawNagad * ratio);
        finalBank = _round(rawBank * ratio);
        double currentSum = finalCash + finalBkash + finalNagad + finalBank;
        double diff = targetAmount - currentSum;
        if (diff.abs() > 0.001) {
          if (finalCash > 0) {
            finalCash += diff;
          } else if (finalBkash > 0) {
            finalBkash += diff;
          } else if (finalNagad > 0) {
            finalNagad += diff;
          } else {
            finalBank += diff;
          }
        }
      }
    }

    int types = 0;
    if (finalCash > 0) types++;
    if (finalBkash > 0) types++;
    if (finalNagad > 0) types++;
    if (finalBank > 0) types++;

    String type = "Cash";
    if (types > 1) {
      type = "Multi";
    } else if (finalBkash > 0) {
      type = "bkash";
    } else if (finalNagad > 0) {
      type = "nagad";
    } else if (finalBank > 0) {
      type = "bank";
    }

    if (targetAmount <= 0.01) type = "Due";

    return {
      "method": type.toLowerCase(), // Safe for DB rules
      "cash": _round(finalCash),
      "bkash": _round(finalBkash),
      "nagad": _round(finalNagad),
      "bank": _round(finalBank),
      "currency": "BDT",
      "bkashNumber": bkashNumberC.text.trim(),
      "nagadNumber": nagadNumberC.text.trim(),
      "bankName": bankNameC.text.trim(),
      "accountNumber": bankAccC.text.trim(),
      "pending": 0.0, // Matches daily_sales schema correctly
    };
  }

  // --- EXACT PAYMENT DETAILS SCHEMA FOR SALES_ORDERS ---
  Map<String, dynamic> _createPaymentMap(
    double oldDue,
    double inv,
    double prevRun,
    double due,
    double totalInput,
  ) {
    return {
      "type": isConditionSale.value ? "condition_partial" : "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
      "bkashNumber": bkashNumberC.text.trim(),
      "nagadNumber": nagadNumberC.text.trim(),
      "bankName": bankNameC.text.trim(),
      "accountNumber": bankAccC.text.trim(),
      "totalPaidInput": totalInput,
      "paidForOldDue": oldDue,
      "paidForInvoice": inv,
      "paidForPrevRunning": prevRun,
      "due": due,
      "currency": "BDT",
    };
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
      print(e);
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
    otherCourierC.clear();
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
    selectedCourier.value = null;
    calculatedCourierDue.value = 0.0;
    selectedDebtor.value = null;
    filteredDebtors.clear();
    debtorPhoneSearch.clear();
    debtorOldDue.value = 0.0;
    debtorRunningDue.value = 0.0;
    selectedPackager.value = null;
    customerType.value = "WHOLESALE";
  }

  String _numberToWords(double number) {
    if (number == 0) return "Zero";
    int num = number.floor();
    if (num < 0) return "Negative ${_numberToWords(-number)}";

    const units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen",
    ];
    const tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety",
    ];

    String convertLessThanOneThousand(int n) {
      String result = "";
      if (n >= 100) {
        result += "${units[n ~/ 100]} Hundred ";
        n %= 100;
      }
      if (n >= 20) {
        result += "${tens[n ~/ 10]} ";
        n %= 10;
      }
      if (n > 0) result += "${units[n]} ";
      return result;
    }

    String result = "";
    int crore = num ~/ 10000000;
    num %= 10000000;
    int lakh = num ~/ 100000;
    num %= 100000;
    int thousand = num ~/ 1000;
    num %= 1000;
    int remainder = num;

    if (crore > 0) result += "${convertLessThanOneThousand(crore)}Crore ";
    if (lakh > 0) result += "${convertLessThanOneThousand(lakh)}Lakh ";
    if (thousand > 0) {
      result += "${convertLessThanOneThousand(thousand)}Thousand ";
    }
    if (remainder > 0) result += convertLessThanOneThousand(remainder);

    return result.trim();
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

    // Calculate Paid Amounts
    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidPrevRun =
        double.tryParse(payMap['paidForPrevRunning'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double totalPaidForInvoice =
        double.tryParse(payMap['paidForInvoice']?.toString() ?? '0') ?? 0.0;

    // Detect Payment Methods for String Generation
    List<String> methodsUsed = [];
    if ((double.tryParse(payMap['cash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Cash');
    }
    if ((double.tryParse(payMap['bkash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bkash');
    }
    if ((double.tryParse(payMap['nagad']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Nagad');
    }
    if ((double.tryParse(payMap['bank']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bank');
    }

    String paymentMethodsStr =
        methodsUsed.isNotEmpty ? methodsUsed.join(', ') : "None/Credit";

    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );

    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;

    double remainingPrevRunning = runningDueSnap - paidPrevRun;
    if (remainingPrevRunning < 0) remainingPrevRunning = 0;

    double netTotalDue = remainingOldDue + remainingPrevRunning + invDue;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;
    double currentInvTotal = subTotal - discount;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (pw.Context context) => _buildNewFooter(context, regularFont),
        build: (pw.Context context) {
          return [
            _buildNewHeader(
              boldFont,
              regularFont,
              invId,
              "Sales Invoice",
              packagerName,
              authorizedName,
              invDue,
              false,
              null,
              "",
              paymentMethodsStr,
            ),
            _buildNewCustomerBox(
              name,
              address,
              phone,
              shopName,
              regularFont,
              boldFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewTable(items, boldFont, regularFont),
            _buildNewSummary(
              subTotal,
              discount,
              currentInvTotal,
              totalPaidForInvoice,
              paymentMethodsStr,
              items,
              boldFont,
              regularFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewDues(totalPreviousBalance, netTotalDue, regularFont),
            if (invDue <= 0 && !isCondition)
              _buildPaidStamp(boldFont, regularFont),
            if (invDue > 0 || isCondition) pw.SizedBox(height: 15),
            _buildWordsBox(currentInvTotal, boldFont),
            pw.SizedBox(height: 40),
            _buildNewSignatures(regularFont),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: (pw.Context context) => _buildNewFooter(context, regularFont),
          build: (context) {
            return [
              _buildNewHeader(
                boldFont,
                regularFont,
                invId,
                "DELIVERY CHALLAN",
                packagerName,
                authorizedName,
                invDue,
                isCondition,
                courier,
                challan,
                paymentMethodsStr,
              ),
              _buildNewCustomerBox(
                name,
                address,
                phone,
                shopName,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 20),
              _buildCourierBox(
                courier,
                challan,
                cartons,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 60),
              _buildChallanCenterBox(boldFont, regularFont, invDue),
              pw.SizedBox(height: 100),
              _buildNewSignatures(regularFont),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  // --- COMPONENT: TOP HEADER ---
  pw.Widget _buildNewHeader(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String title,
    String? packager,
    String authorizedName,
    double invDue,
    bool isCondition,
    String? courier,
    String challan,
    String paymentMethodsStr,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "G TEL",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "6/24A(7th Floor) Gulistan Shopping Complex (Hall Market)\n2 Bangabandu Avenue, Dhaka 1000",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "Cell : 01720677206, 01911026222",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "E-mail : gtel01720677206@gmail.com",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(right: 40),
                child: pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              children: [
                _infoRow("Invoice No.", ": $invId", reg, bold),
                _infoRow(
                  "Date",
                  ": ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
                  reg,
                  bold,
                ),
                _infoRow("Ref: No", ": ", reg, bold),
                _infoRow(
                  "Prepared/Packged By",
                  ": ${packager ?? 'Admin'}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Entry Time",
                  ": ${DateFormat('h:mm:ss a').format(DateTime.now())}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Bill Type",
                  ": ${invDue <= 0 ? 'PAID' : 'DUE'}",
                  reg,
                  bold,
                ),
                _infoRow("Payment Via", ": $paymentMethodsStr", reg, bold),
                _infoRow("Sales Person", ": $authorizedName", reg, bold),
                if (isCondition) ...[
                  _infoRow("Courier", ": ${courier ?? 'N/A'}", reg, bold),
                  _infoRow("Challan No", ": $challan", reg, bold),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- COMPONENT: CUSTOMER BOX ---
  pw.Widget _buildNewCustomerBox(
    String name,
    String address,
    String phone,
    String shopName,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow("To", ": $name", reg, bold, col1Width: 60),
          _infoRow("Address", address, reg, bold, col1Width: 60),
          _infoRow("Contact No.", ": $phone", reg, bold, col1Width: 60),
        ],
      ),
    );
  }

  // --- COMPONENT: COURIER BOX (NEW FOR CHALLAN) ---
  pw.Widget _buildCourierBox(
    String? courier,
    String challan,
    int? cartons,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Courier Information",
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          _infoRow(
            "Courier Name",
            ": ${courier ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Booking/Challan No",
            ": $challan",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Total Cartons",
            ": ${cartons?.toString() ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
        ],
      ),
    );
  }

  // --- COMPONENT: ITEMS TABLE ---
  pw.Widget _buildNewTable(
    List<Map<String, dynamic>> items,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          children: [
            _th("SL", bold),
            _th("Product Description", bold, align: pw.TextAlign.left),
            _th("Qty", bold),
            _th("Unit Price", bold),
            _th("Amount", bold),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              _td(
                "${item['name']}${item['model'] != null ? ' - ' + item['model'] : ''}",
                reg,
              ),
              _td(item['qty'].toString(), reg, align: pw.TextAlign.center),
              _td(
                double.parse(item['saleRate'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
              _td(
                double.parse(item['subtotal'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildNewSummary(
    double subTotal,
    double discount,
    double currentInvTotal,
    double paidForInvoice,
    String paymentMethodsStr,
    List items,
    pw.Font bold,
    pw.Font reg,
  ) {
    int totalQty = items.fold(
      0,
      (sumv, item) => sumv + ((item['qty'] as num?)?.toInt() ?? 0),
    );
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Total Qty : $totalQty",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Narration:",
                    style: pw.TextStyle(font: reg, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                children: [
                  _sumRow(
                    "Total Amount",
                    subTotal.toStringAsFixed(2),
                    bold,
                    reg,
                  ),
                  _sumRow(
                    "Less Discount",
                    discount.toStringAsFixed(2),
                    reg,
                    reg,
                  ),
                  _sumRow("Add VAT", "0.00", reg, reg),
                  _sumRow("Add Extra Charges", "0.00", reg, reg),
                  pw.Divider(thickness: 0.5, height: 8),
                  _sumRow(
                    "Net Payable Amount",
                    currentInvTotal.toStringAsFixed(2),
                    bold,
                    bold,
                  ),
                  pw.SizedBox(height: 2),
                  _sumRow(
                    "Paid Amount",
                    paidForInvoice.toStringAsFixed(2),
                    reg,
                    bold,
                  ),
                  if (paymentMethodsStr != "None/Credit")
                    _sumRow("Payment Method", paymentMethodsStr, reg, reg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT: DUES SECTION ---
  pw.Widget _buildNewDues(double prevDue, double netDue, pw.Font reg) {
    return pw.Container(
      width: 200,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        children: [
          _sumRow(
            "Previous Due Amount :",
            prevDue.toStringAsFixed(2),
            reg,
            reg,
          ),
          pw.Divider(thickness: 0.5, height: 5),
          _sumRow("Present Due Amount :", netDue.toStringAsFixed(2), reg, reg),
        ],
      ),
    );
  }

  // --- COMPONENT: PAID STAMP ---
  pw.Widget _buildPaidStamp(pw.Font bold, pw.Font reg) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 20),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              "P A I D",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              DateFormat('dd MMM yyyy').format(DateTime.now()),
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 12,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "G TEL",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT: TAKA IN WORDS BOX ---
  pw.Widget _buildWordsBox(double currentInvTotal, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        "Taka in word : ${_numberToWords(currentInvTotal)} Only",
        style: pw.TextStyle(font: bold, fontSize: 9),
      ),
    );
  }

  // --- COMPONENT: SIGNATURES ---
  pw.Widget _buildNewSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Client Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Goods Delivery/Prepare",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Authorized Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  // --- COMPONENT: FOOTER ---
  pw.Widget _buildNewFooter(pw.Context context, pw.Font reg) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            "Terms & Conditions: 1. Goods once sold will not be refunded and changed, 2. Warranty will be void if any sticker removed, physically damaged and burn case, 3. Please keep this invoice/bill for warranty support.",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Sales Billing Software By G TEL : 01720677206",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Print Date & Time : ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  // --- COMPONENT: NEW CHALLAN CENTER BOX ---
  pw.Widget _buildChallanCenterBox(pw.Font bold, pw.Font reg, double due) {
    bool isPaid = due <= 0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isPaid ? PdfColors.green700 : PdfColors.deepOrange700,
          width: 2,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: isPaid ? PdfColors.green50 : PdfColors.deepOrange50,
      ),
      child: pw.Column(
        children: [
          if (isPaid) ...[
            pw.Text(
              "NON CONDITION",
              style: pw.TextStyle(
                font: bold,
                fontSize: 24,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "+ Courier Charges",
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: PdfColors.green800,
              ),
            ),
          ] else ...[
            pw.Text(
              "CONDITION PAYMENT INSTRUCTION FOR COURIER",
              style: pw.TextStyle(
                font: reg,
                fontSize: 11,
                color: PdfColors.deepOrange800,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "PLEASE COLLECT: ",
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                pw.Text(
                  "BDT ${due.toStringAsFixed(0)}",
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 24,
                    color: PdfColors.deepOrange900,
                  ),
                ),
                pw.Text(
                  " + Courier Charges",
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    double col1Width = 75,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: col1Width,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sumRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: valFont, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }
}
