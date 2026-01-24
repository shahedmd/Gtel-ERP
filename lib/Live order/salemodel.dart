// ignore_for_file: deprecated_member_use, avoid_print, empty_catches
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Stock/controller.dart'; // Your ProductController path
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

    // Ensure products are fetched initially
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

  // --- PAGINATION HELPERS (Delegates to ProductController) ---
  int get currentPage => productCtrl.currentPage.value;
  int get totalPages =>
      (productCtrl.totalProducts.value / productCtrl.pageSize.value).ceil();

  void nextPage() => productCtrl.nextPage();
  void prevPage() => productCtrl.previousPage();
  // -----------------------------------------------------------

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

  Future<void> finalizeSale() async {
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
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

    // CALCULATIONS
    double totalCashInput = totalPaidInput.value;
    double paidAmountForOldDue = 0.0;
    double paidAmountForCurrentInvoice = 0.0;
    double oldDueSnapshot = debtorOldDue.value;

    if (customerType.value == "Debtor" &&
        !isConditionSale.value &&
        debtorId != null) {
      double remainingCash = totalCashInput;
      if (oldDueSnapshot > 0) {
        if (remainingCash >= oldDueSnapshot) {
          paidAmountForOldDue = oldDueSnapshot;
          remainingCash -= oldDueSnapshot;
        } else {
          paidAmountForOldDue = remainingCash;
          remainingCash = 0;
        }
      }
      if (remainingCash > 0) {
        if (remainingCash >= grandTotal) {
          paidAmountForCurrentInvoice = grandTotal;
          remainingCash -= grandTotal;
        } else {
          paidAmountForCurrentInvoice = remainingCash;
          remainingCash = 0;
        }
      }
    } else {
      paidAmountForCurrentInvoice =
          totalCashInput > grandTotal ? grandTotal : totalCashInput;
    }

    double invoiceDueAmount = _round(grandTotal - paidAmountForCurrentInvoice);
    if (invoiceDueAmount < 0) invoiceDueAmount = 0;

    Map<String, dynamic> fullPaymentMap = {
      "type": isConditionSale.value ? "condition_partial" : "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
      "bkashNumber": bkashNumberC.text.trim(),
      "nagadNumber": nagadNumberC.text.trim(),
      "bankName": bankNameC.text.trim(),
      "accountNumber": bankAccC.text.trim(),
      "totalPaidInput": totalCashInput,
      "paidForOldDue": paidAmountForOldDue,
      "paidForInvoice": paidAmountForCurrentInvoice,
      "due": invoiceDueAmount,
      "currency": "BDT",
    };

    Map<String, dynamic> dailySalesPaymentMap = Map.from(fullPaymentMap);
    if (paidAmountForOldDue > 0) {
      double amountToRemove = paidAmountForOldDue;
      double pCash = double.tryParse(cashC.text) ?? 0;
      if (amountToRemove > 0 && pCash > 0) {
        if (pCash >= amountToRemove) {
          pCash -= amountToRemove;
          amountToRemove = 0;
        } else {
          amountToRemove -= pCash;
          pCash = 0;
        }
      }
      dailySalesPaymentMap['cash'] = pCash;
    }

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

    // Use bulk update via controller wrapper if available, or call API directly
    // Assuming productCtrl has updateStockBulk exposed (as per your previous snippets)
    bool stockSuccess = await productCtrl.updateStockBulk(stockUpdates);
    if (!stockSuccess) {
      isProcessing.value = false;
      Get.snackbar("Stock Error", "Stock update failed. Sale canceled.");
      return;
    }

    try {
      WriteBatch batch = _db.batch();
      int cartonsInt = int.tryParse(cartonsC.text) ?? 0;
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
        "items": orderItems,
        "subtotal": subtotalAmount,
        "discount": discountVal.value,
        "grandTotal": grandTotal,
        "totalCost": totalInvoiceCost,
        "profit": invoiceProfit,
        "paymentDetails": fullPaymentMap,
        "isFullyPaid": invoiceDueAmount <= 0,
        "status":
            isConditionSale.value
                ? (invoiceDueAmount <= 0 ? "completed" : "on_delivery")
                : "completed",
      });

      if (isConditionSale.value) {
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
          "advance": paidAmountForCurrentInvoice,
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
        if (paidAmountForCurrentInvoice > 0) {
          DocumentReference dailyRef = _db.collection('daily_sales').doc();
          batch.set(dailyRef, {
            "name": "$fName (Condition)",
            "amount": grandTotal,
            "paid": paidAmountForCurrentInvoice,
            "pending": invoiceDueAmount,
            "customerType": "condition_advance",
            "timestamp": Timestamp.fromDate(saleDate),
            "paymentMethod": dailySalesPaymentMap,
            "createdAt": FieldValue.serverTimestamp(),
            "source": "pos_condition_sale",
            "transactionId": invNo,
            "invoiceId": invNo,
            "status": invoiceDueAmount <= 0 ? "paid" : "partial",
          });
        }
      } else if (customerType.value == "Debtor" && debtorId != null) {
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

        if (paidAmountForOldDue > 0) {
          DocumentReference oldPayRef =
              _db
                  .collection('debatorbody')
                  .doc(debtorId)
                  .collection('transactions')
                  .doc();
          batch.set(oldPayRef, {
            "amount": paidAmountForOldDue,
            "transactionId": oldPayRef.id,
            "type": "loan_payment",
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Payment via Inv $invNo",
            "paymentMethod": fullPaymentMap,
          });
          DocumentReference cashRef = _db.collection('cash_ledger').doc();
          batch.set(cashRef, {
            'type': 'deposit',
            'amount': paidAmountForOldDue,
            'method': 'cash',
            'description': "Loan Repayment: $fName (Inv $invNo)",
            'timestamp': FieldValue.serverTimestamp(),
            'linkedDebtorId': debtorId,
            'linkedTxId': oldPayRef.id,
          });
        }

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

        if (paidAmountForCurrentInvoice > 0) {
          DocumentReference debitRef = _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc("${invNo}_pay");
          batch.set(debitRef, {
            "amount": paidAmountForCurrentInvoice,
            "transactionId": "${invNo}_pay",
            "type": "debit",
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Payment for Inv $invNo",
            "paymentMethod": dailySalesPaymentMap,
          });
        }
        DocumentReference dailyRef = _db.collection('daily_sales').doc();
        batch.set(dailyRef, {
          "name": fName,
          "amount": grandTotal,
          "paid": paidAmountForCurrentInvoice,
          "pending": invoiceDueAmount,
          "customerType": "debtor",
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": dailySalesPaymentMap,
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
          "status": invoiceDueAmount <= 0 ? "paid" : "due",
        });
      } else {
        // Retailer Logic
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
          "paid": paidAmountForCurrentInvoice,
          "pending": 0.0,
          "customerType": "retailer",
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": fullPaymentMap,
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
        });
      }

      await batch.commit();
      if (debtorId != null) debtorCtrl.loadDebtorTransactions(debtorId);

      await _generatePdf(
        invNo,
        fName,
        fPhone,
        fullPaymentMap,
        orderItems,
        isCondition: isConditionSale.value,
        challan: finalChallan,
        address: addressC.text,
        courier: selectedCourier.value,
        cartons: cartonsInt,
        shopName: shopC.text,
        oldDueSnap: oldDueSnapshot,
        runningDueSnap: debtorRunningDue.value,
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
  }

  // ==========================================
  // UPDATED PDF GENERATION (PROFESSIONAL BLACK)
  // ==========================================
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
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidInv =
        double.tryParse(payMap['paidForInvoice'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;

    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;
    double netTotalDue = remainingOldDue + runningDueSnap + invDue;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5, // HALF A4
        margin: const pw.EdgeInsets.all(20),
        footer: (context) => _buildFooter(regularFont),
        build: (context) {
          return [
            _buildCompanyHeader(boldFont, regularFont),
            pw.SizedBox(height: 10),
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
            ),
            pw.SizedBox(height: 10),
            _buildProfessionalTable(boldFont, regularFont, italicFont, items),
            pw.SizedBox(height: 10),
            _buildDetailedSummary(
              boldFont,
              regularFont,
              payMap,
              isCondition,
              cartons,
              totalPreviousBalance,
              paidOld + paidInv,
              netTotalDue,
            ),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(20),
          footer: (context) => _buildFooter(regularFont),
          build: (context) {
            return [
              _buildCompanyHeader(boldFont, regularFont),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "DELIVERY CHALLAN",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                    decoration: pw.TextDecoration.underline,
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
              _buildChallanTable(boldFont, regularFont, italicFont, items),
              pw.SizedBox(height: 20),
              _buildConditionBox(boldFont, regularFont, payMap),
              pw.SizedBox(height: 40),
              _buildSignatures(regularFont),
            ];
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildCompanyHeader(pw.Font bold, pw.Font reg) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          "G TEL",
          style: pw.TextStyle(font: bold, fontSize: 28, color: PdfColors.black),
        ),
        pw.Text(
          "JOY EXPRESS",
          style: pw.TextStyle(
            font: bold,
            fontSize: 14,
            letterSpacing: 3,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          "Mobile Parts Wholesaler",
          style: pw.TextStyle(
            font: reg,
            fontSize: 10,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          "Gulistan Shopping Complex (Hall Market), 2 Bangabandu Avenue, Dhaka 1000",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: reg, fontSize: 8),
        ),
        pw.Text(
          "01720677206, 01911026222 | gtel01720677206@gmail.com",
          style: pw.TextStyle(font: bold, fontSize: 8),
        ),
        pw.Divider(color: PdfColors.black, thickness: 1),
      ],
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
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              isCond ? "CONDITION INVOICE" : "SALES INVOICE",
              style: pw.TextStyle(font: bold, fontSize: 12),
            ),
            pw.Text(
              "INV#: $invId",
              style: pw.TextStyle(font: reg, fontSize: 10),
            ),
            pw.Text(
              "Date: ${DateFormat('dd-MMM-yy').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
            if (isCond)
              pw.Text(
                "Via: $courier",
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("CUSTOMER", style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11)),
            if (shopName.isNotEmpty)
              pw.Text(shopName, style: pw.TextStyle(font: reg, fontSize: 9)),
            pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 9)),
            if (addr.isNotEmpty)
              pw.Text(addr, style: pw.TextStyle(font: reg, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildProfessionalTable(
    pw.Font bold,
    pw.Font reg,
    pw.Font italic,
    List<Map<String, dynamic>> items,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(35),
        3: const pw.FixedColumnWidth(25),
        4: const pw.FixedColumnWidth(40),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th("SL", bold),
            _th("ITEM DESCRIPTION", bold, align: pw.TextAlign.left),
            _th("RATE", bold),
            _th("QTY", bold),
            _th("TOTAL", bold),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _td((index + 1).toString(), reg),
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item['name'],
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    pw.Text(
                      "${item['brand']} - ${item['model']}",
                      style: pw.TextStyle(
                        font: italic,
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              _td(item['saleRate'].toString(), reg),
              _td(item['qty'].toString(), bold),
              _td(item['subtotal'].toString(), bold),
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
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  pw.Widget _td(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  pw.Widget _buildDetailedSummary(
    pw.Font bold,
    pw.Font reg,
    Map payMap,
    bool isCond,
    int? cartons,
    double prevDue,
    double totalPaid,
    double netDue,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          width: 140,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Payment Details:",
                style: pw.TextStyle(font: bold, fontSize: 8),
              ),
              _buildCompactPaymentLines(payMap, reg),
              if (cartons != null && cartons > 0)
                pw.Text(
                  "Cartons: $cartons",
                  style: pw.TextStyle(font: bold, fontSize: 8),
                ),
            ],
          ),
        ),
        pw.Container(
          width: 160,
          child: pw.Column(
            children: [
              _pdfRow("Subtotal", subtotalAmount.toStringAsFixed(2), reg, 9),
              if (discountVal.value > 0)
                _pdfRow("Discount", "-${discountVal.value}", reg, 9),
              pw.Divider(thickness: 0.5),
              _pdfRow("THIS INVOICE", grandTotal.toStringAsFixed(2), bold, 10),
              if (!isCond && customerType.value == "Debtor") ...[
                pw.SizedBox(height: 4),
                _pdfRow("Previous Balance", prevDue.toStringAsFixed(2), reg, 9),
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                _pdfRow(
                  "TOTAL PAYABLE",
                  (prevDue + grandTotal).toStringAsFixed(2),
                  bold,
                  10,
                ),
                if (totalPaid > 0)
                  _pdfRow("Paid Amount", "-$totalPaid", reg, 9),
                pw.Divider(thickness: 0.5),
                _pdfRow("NET TOTAL DUE", netDue.toStringAsFixed(2), bold, 11),
              ] else ...[
                _pdfRow("Paid", totalPaid.toStringAsFixed(2), reg, 9),
                if (isCond)
                  _pdfRow(
                    "Courier Collect",
                    double.parse(payMap['due'].toString()).toStringAsFixed(2),
                    bold,
                    11,
                  ),
              ],
            ],
          ),
        ),
      ],
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
        pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "COURIER INFO",
                style: pw.TextStyle(font: bold, fontSize: 8),
              ),
              pw.Text(
                "Name: $courier",
                style: pw.TextStyle(font: reg, fontSize: 8),
              ),
              pw.Text(
                "Challan: $challan",
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
              if (cartons != null)
                pw.Text(
                  "Cartons: $cartons",
                  style: pw.TextStyle(font: bold, fontSize: 8),
                ),
            ],
          ),
        ),
        pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("RECEIVER", style: pw.TextStyle(font: bold, fontSize: 8)),
              pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 9)),
              pw.Text(phone, style: pw.TextStyle(font: reg, fontSize: 8)),
              pw.Text(
                addr,
                style: pw.TextStyle(font: reg, fontSize: 8),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildChallanTable(
    pw.Font bold,
    pw.Font reg,
    pw.Font italic,
    List items,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(),
        1: const pw.FixedColumnWidth(40),
      },
      children: [
        pw.TableRow(children: [_th("ITEM", bold), _th("QTY", bold)]),
        ...items
            .map(
              (i) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          i['name'],
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                        pw.Text(
                          "${i['brand']} - ${i['model']}",
                          style: pw.TextStyle(font: italic, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  _td(i['qty'].toString(), bold),
                ],
              ),
            )
            ,
      ],
    );
  }

  pw.Widget _buildConditionBox(pw.Font bold, pw.Font reg, Map payMap) {
    double due = double.parse(payMap['due'].toString());
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            "COLLECT FROM RECEIVER:  ",
            style: pw.TextStyle(font: bold, fontSize: 10),
          ),
          pw.Text(
            "Tk ${due.toStringAsFixed(0)} /=",
            style: pw.TextStyle(font: bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _sigLine("Authorized Signature", reg),
        _sigLine("Receiver Signature", reg),
      ],
    );
  }

  pw.Widget _sigLine(String title, pw.Font reg) {
    return pw.Column(
      children: [
        pw.Container(width: 80, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 2),
        pw.Text(title, style: pw.TextStyle(font: reg, fontSize: 7)),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font reg) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.black, thickness: 0.5),
        pw.Center(
          child: pw.Text(
            "Software by G-TEL ERP",
            style: pw.TextStyle(
              font: reg,
              fontSize: 6,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCompactPaymentLines(Map payMap, pw.Font reg) {
    List<String> lines = [];
    double cash = double.tryParse(payMap['cash'].toString()) ?? 0;
    double bkash = double.tryParse(payMap['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(payMap['nagad'].toString()) ?? 0;
    double bank = double.tryParse(payMap['bank'].toString()) ?? 0;
    if (cash > 0) lines.add("Cash: ${cash.toInt()}");
    if (bkash > 0) lines.add("Bkash: ${bkash.toInt()}");
    if (nagad > 0) lines.add("Nagad: ${nagad.toInt()}");
    if (bank > 0) lines.add("Bank: ${bank.toInt()}");
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

  pw.Widget _pdfRow(String label, String value, pw.Font font, double size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
        ],
      ),
    );
  }
}
