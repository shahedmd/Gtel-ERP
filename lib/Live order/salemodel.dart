// ignore_for_file: deprecated_member_use, avoid_print, empty_catches
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// --- CONTROLLER ---
class LiveSalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // External Controllers
  final productCtrl = Get.find<ProductController>();
  final debtorCtrl = Get.find<DebatorController>();
  final dailyCtrl = Get.find<DailySalesController>();

  // --- CONSTANTS ---
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

  // --- STATE VARIABLES ---
  final RxString customerType = "Retailer".obs;
  final RxBool isConditionSale = false.obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();

  // --- TEXT CONTROLLERS ---
  final debtorPhoneSearch = TextEditingController();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();

  // Condition Sale Specifics
  final addressC = TextEditingController();
  final challanC = TextEditingController();
  final cartonsC = TextEditingController();
  final RxnString selectedCourier = RxnString();

  // Financials
  final discountC = TextEditingController();
  final RxDouble discountVal = 0.0.obs;

  // --- PAYMENT CONTROLLERS ---
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

    // Auto-fetch courier dues
    ever(selectedCourier, (val) {
      if (val != null) fetchCourierTotalDue(val);
    });
  }

  double _round(double val) => double.parse(val.toStringAsFixed(2));

  void _handleTypeChange() {
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();

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
      if (totalPaidInput.value > grandTotal) {
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

  // ==================================================================
  // 🔥 FINALIZATION LOGIC
  // ==================================================================
  Future<void> finalizeSale() async {
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
      return;
    }

    // --- Validation ---
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

    // 1. DEFAULT CHALLAN LOGIC
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

    // Prepare Data
    final String invNo = _generateInvoiceID();
    final DateTime saleDate = DateTime.now();
    double paidAmountInput = totalPaidInput.value;
    double actualReceived = 0.0;
    double dueOrConditionAmount = 0.0;

    if (isConditionSale.value) {
      actualReceived = paidAmountInput;
      dueOrConditionAmount = _round(grandTotal - actualReceived);
    } else {
      actualReceived =
          paidAmountInput > grandTotal ? grandTotal : paidAmountInput;
      dueOrConditionAmount = _round(grandTotal - actualReceived);
    }
    if (dueOrConditionAmount < 0) dueOrConditionAmount = 0;

    Map<String, dynamic> paymentMap = {
      "type": isConditionSale.value ? "condition_partial" : "multi",

      // Amounts
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,

      // Details
      "bkashNumber": bkashNumberC.text.trim(),
      "nagadNumber": nagadNumberC.text.trim(),
      "bankName": bankNameC.text.trim(),
      "accountNumber": bankAccC.text.trim(),

      "totalPaidInput": paidAmountInput,
      "actualReceived": actualReceived,
      "due": dueOrConditionAmount,
      "changeReturned": isConditionSale.value ? 0 : changeReturn.value,
      "currency": "BDT",
    };

    List<Map<String, dynamic>> orderItems =
        cart.map((item) {
          return {
            "productId": item.product.id,
            "name": item.product.name,
            "model": item.product.model,
            "qty": item.quantity.value,
            "saleRate": item.priceAtSale,
            "costRate": item.product.avgPurchasePrice,
            "subtotal": item.subtotal,
          };
        }).toList();

    // 2. UPDATE STOCK
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

      // 3. MASTER INVOICE (Always Created)
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
        "courierDue": isConditionSale.value ? dueOrConditionAmount : 0,
        "items": orderItems,
        "subtotal": subtotalAmount,
        "discount": discountVal.value,
        "grandTotal": grandTotal,
        "totalCost": totalInvoiceCost,
        "profit": invoiceProfit,
        "paymentDetails": paymentMap,
        "isFullyPaid": dueOrConditionAmount <= 0,
        "status":
            isConditionSale.value
                ? (dueOrConditionAmount <= 0 ? "completed" : "on_delivery")
                : "completed",
      });

      // 4. LOGIC BRANCHING
      if (isConditionSale.value) {
        // --- CONDITION SALE ---
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
          "totalCourierDue": FieldValue.increment(dueOrConditionAmount),
        }, SetOptions(merge: true));

        DocumentReference condTxRef = condCustRef
            .collection('orders')
            .doc(invNo);
        batch.set(condTxRef, {
          "invoiceId": invNo,
          "challanNo": finalChallan,
          "grandTotal": grandTotal,
          "advance": actualReceived,
          "courierDue": dueOrConditionAmount,
          "courierName": selectedCourier.value,
          "cartons": cartonsInt,
          "items": orderItems,
          "date": Timestamp.fromDate(saleDate),
          "status": dueOrConditionAmount <= 0 ? "completed" : "pending_courier",
        });

        if (selectedCourier.value != null && dueOrConditionAmount > 0) {
          DocumentReference courierRef = _db
              .collection('courier_ledgers')
              .doc(selectedCourier.value);
          batch.set(courierRef, {
            "name": selectedCourier.value,
            "totalDue": FieldValue.increment(dueOrConditionAmount),
            "lastUpdated": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (actualReceived > 0) {
          DocumentReference dailyRef = _db.collection('daily_sales').doc();
          batch.set(dailyRef, {
            "name": "$fName (Condition Sales)",
            "amount": grandTotal,
            "paid": actualReceived,
            "pending": dueOrConditionAmount,
            "customerType": "condition_advance",
            "timestamp": Timestamp.fromDate(saleDate),
            "paymentMethod": paymentMap,
            "createdAt": FieldValue.serverTimestamp(),
            "source": "pos_condition_sale",
            "transactionId": invNo,
            "invoiceId": invNo,
            "status": dueOrConditionAmount <= 0 ? "paid" : "partial",
          });
        }
      } else if (customerType.value == "Debtor" && debtorId != null) {
        // --- DEBTOR SALE ---
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

        if (dueOrConditionAmount > 0) {
          // Unpaid/Partial
          DocumentReference debTxRef = _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc(invNo);
          batch.set(debTxRef, {
            "amount": dueOrConditionAmount,
            "transactionId": invNo,
            "type": "credit",
            "date": Timestamp.fromDate(saleDate),
            "createdAt": FieldValue.serverTimestamp(),
            "note": "Invoice $invNo",
          });

          DocumentReference dailyRef = _db.collection('daily_sales').doc();
          batch.set(dailyRef, {
            "name": fName,
            "amount": grandTotal,
            "paid": actualReceived,
            "pending": dueOrConditionAmount,
            "customerType": "debtor",
            "timestamp": Timestamp.fromDate(saleDate),
            "paymentMethod": paymentMap,
            "createdAt": FieldValue.serverTimestamp(),
            "source": "pos_sale",
            "transactionId": invNo,
            "invoiceId": invNo,
            "status": "due",
          });
        } else {
          // Paid
          DocumentReference dailyRef = _db.collection('daily_sales').doc();
          batch.set(dailyRef, {
            "name": fName,
            "amount": grandTotal,
            "paid": grandTotal,
            "pending": 0.0,
            "customerType": "debtor",
            "timestamp": Timestamp.fromDate(saleDate),
            "paymentMethod": paymentMap,
            "createdAt": FieldValue.serverTimestamp(),
            "source": "pos_sale",
            "transactionId": invNo,
            "invoiceId": invNo,
            "status": "paid",
          });
        }
      } else {
        // --- RETAILER SALE ---
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
          "paid": actualReceived,
          "pending": 0.0,
          "customerType": "retailer",
          "timestamp": Timestamp.fromDate(saleDate),
          "paymentMethod": paymentMap,
          "createdAt": FieldValue.serverTimestamp(),
          "source": "pos_sale",
          "transactionId": invNo,
          "invoiceId": invNo,
        });
      }

      await batch.commit();

      // --- PDF & CLEANUP ---
      await _generatePdf(
        invNo,
        fName,
        fPhone,
        paymentMap,
        orderItems,
        isCondition: isConditionSale.value,
        challan: finalChallan,
        address: addressC.text,
        courier: selectedCourier.value,
        cartons: cartonsInt,
        shopName: shopC.text,
      );

      _resetAll();
      Get.snackbar(
        "Success",
        "Sale Finalized Successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // ⚠️ ROLLBACK LOGIC
      print("Transaction failed. Attempting stock rollback...");
      try {
        List<Map<String, dynamic>> rollbackStock =
            cart
                .map(
                  (item) => {
                    'id': item.product.id,
                    'qty': -item.quantity.value,
                  },
                )
                .toList();
        await productCtrl.updateStockBulk(rollbackStock);
      } catch (rollbackErr) {
        print("CRITICAL: Stock rollback failed: $rollbackErr");
        Get.defaultDialog(
          title: "CRITICAL ERROR",
          middleText: "Database failed & Stock rollback failed.\nError: $e",
        );
      }

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

    // Clear Payment Fields
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
  }

  // ==========================================
  // PDF GENERATION (Multi-Page Supported)
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
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.nunitoBold();
    final regularFont = await PdfGoogleFonts.nunitoRegular();

    // --- 1. INVOICE PDF (MultiPage) ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // Footer appears on every page at the bottom
        footer: (context) => _buildFooter(regularFont),
        build: (context) {
          return [
            // Header (Company Info)
            _buildCompanyHeader(boldFont, regularFont),
            pw.SizedBox(height: 10),

            // Invoice Details (Bill To, etc.)
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
            pw.SizedBox(height: 15),

            // Items Table (Will split across pages automatically)
            _buildItemTable(boldFont, regularFont, items),
            pw.SizedBox(height: 15),

            // Totals & Payment Section
            pw.Wrap(
              children: [
                _buildInvoiceTotalSection(
                  boldFont,
                  regularFont,
                  payMap,
                  isCondition,
                  cartons,
                ),
              ],
            ),
          ];
        },
      ),
    );

    // --- 2. CHALLAN PDF (MultiPage) ---
    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (context) => _buildFooter(regularFont),
          build: (context) {
            return [
              _buildCompanyHeader(boldFont, regularFont),
              pw.SizedBox(height: 10),

              // Title
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(20),
                    ),
                  ),
                  child: pw.Text(
                    "DELIVERY CHALLAN",
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Receiver & Courier Info
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
              pw.SizedBox(height: 20),

              pw.Text("Package Contents:", style: pw.TextStyle(font: boldFont)),

              // Table
              _buildChallanTable(boldFont, regularFont, items),
              pw.SizedBox(height: 30),

              // Condition Box & Signatures
              pw.Wrap(
                children: [
                  _buildConditionBox(boldFont, regularFont, payMap),
                  pw.SizedBox(height: 60),
                  _buildSignatures(regularFont),
                ],
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  // --- WIDGET BUILDERS ---

  pw.Widget _buildCompanyHeader(pw.Font bold, pw.Font reg) {
    return pw.Column(
      children: [
        pw.Text(
          "G TEL JOY EXPRESS",
          style: pw.TextStyle(
            font: bold,
            fontSize: 26,
            color: PdfColors.blue900,
          ),
        ),
        pw.Text(
          "MOBILE PART WHOLESALER",
          style: pw.TextStyle(
            font: reg,
            fontSize: 12,
            letterSpacing: 2,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          "Mobile: 01720677206, 01911026222, 01911026033",
          style: pw.TextStyle(font: bold, fontSize: 10),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          "Showroom 1: 4/119 (5th floor) lift-4  |  Showroom 2: 6/24A (7th floor) lift-6",
          style: pw.TextStyle(font: reg, fontSize: 9),
        ),
        pw.Text(
          "Gulistan Shopping Complex (Hall Market), 2 Bangabandu Avenue, Dhaka 1000",
          style: pw.TextStyle(font: reg, fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          "Web: www.gtelbd.com  |  Email: gtel01720677206@gmail.com",
          style: pw.TextStyle(font: reg, fontSize: 9, color: PdfColors.blue800),
        ),
        pw.Divider(color: PdfColors.grey400, thickness: 1),
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
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              isCond ? "CONDITION INVOICE" : "SALES INVOICE",
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: isCond ? PdfColors.orange800 : PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text("Invoice #: $invId", style: pw.TextStyle(font: bold)),
            pw.Text(
              "Date: ${DateFormat('dd-MMM-yyyy h:mm a').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 10),
            ),
            if (isCond && courier != null)
              pw.Text(
                "Via: $courier",
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.grey100,
          ),
          width: 220,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("BILL TO:", style: pw.TextStyle(font: bold, fontSize: 8)),
              pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 12)),
              if (shopName.isNotEmpty)
                pw.Text(shopName, style: pw.TextStyle(font: reg)),
              pw.Text(phone, style: pw.TextStyle(font: reg)),
              if (addr.isNotEmpty)
                pw.Text(
                  addr,
                  style: pw.TextStyle(font: reg, fontSize: 9),
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemTable(
    pw.Font bold,
    pw.Font reg,
    List<Map<String, dynamic>> items,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(
        font: bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(font: reg, fontSize: 10),
      cellPadding: const pw.EdgeInsets.all(5),
      headers: ['SL', 'Item Description', 'Rate', 'Qty', 'Total'],
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(70),
      },
      data: List.generate(items.length, (index) {
        final item = items[index];
        return [
          (index + 1).toString(),
          "${item['model']} - ${item['name']}",
          double.parse(item['saleRate'].toString()).toStringAsFixed(2),
          item['qty'].toString(),
          double.parse(item['subtotal'].toString()).toStringAsFixed(2),
        ];
      }),
    );
  }

  pw.Widget _buildInvoiceTotalSection(
    pw.Font bold,
    pw.Font reg,
    Map payMap,
    bool isCond,
    int? cartons,
  ) {
    // --- UPDATED PAYMENT DETAILS LOGIC ---
    List<String> getPaymentLines() {
      List<String> lines = [];
      double cash = double.tryParse(payMap['cash'].toString()) ?? 0;
      double bkash = double.tryParse(payMap['bkash'].toString()) ?? 0;
      double nagad = double.tryParse(payMap['nagad'].toString()) ?? 0;
      double bank = double.tryParse(payMap['bank'].toString()) ?? 0;

      // Cash
      if (cash > 0) {
        lines.add("Cash: ${cash.toStringAsFixed(0)}");
      }

      // Bkash with Number
      if (bkash > 0) {
        String num = payMap['bkashNumber'] ?? "";
        String detail = num.isNotEmpty ? " ($num)" : "";
        lines.add("Bkash$detail: ${bkash.toStringAsFixed(0)}");
      }

      // Nagad with Number
      if (nagad > 0) {
        String num = payMap['nagadNumber'] ?? "";
        String detail = num.isNotEmpty ? " ($num)" : "";
        lines.add("Nagad$detail: ${nagad.toStringAsFixed(0)}");
      }

      // Bank with Name + Account
      if (bank > 0) {
        String bName = payMap['bankName'] ?? "Bank";
        String bAcc = payMap['accountNumber'] ?? "";
        String detail = bAcc.isNotEmpty ? " ($bName - $bAcc)" : " ($bName)";
        lines.add("Bank$detail: ${bank.toStringAsFixed(0)}");
      }

      return lines;
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Payment Details:",
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children:
                    getPaymentLines()
                        .map(
                          (l) => pw.Text(
                            l,
                            style: pw.TextStyle(
                              font: reg,
                              fontSize: 9,
                              color: PdfColors.grey800,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
        pw.Container(
          width: 220,
          child: pw.Column(
            children: [
              _pdfRow("Subtotal", subtotalAmount.toStringAsFixed(2), reg, 10),
              _pdfRow(
                "Discount",
                "-${discountVal.value.toStringAsFixed(2)}",
                reg,
                10,
              ),
              pw.Divider(),
              _pdfRow(
                "Grand Total",
                grandTotal.toStringAsFixed(2),
                bold,
                14,
                color: PdfColors.blue900,
              ),
              pw.SizedBox(height: 5),
              _pdfRow(
                isCond ? "Advance Paid" : "Paid Amount",
                double.parse(
                  payMap['actualReceived'].toString(),
                ).toStringAsFixed(2),
                reg,
                11,
              ),
              if (isCond) ...[
                pw.SizedBox(height: 5),
                pw.Container(
                  color: PdfColors.red50,
                  padding: const pw.EdgeInsets.all(3),
                  child: _pdfRow(
                    "Courier Collect",
                    double.parse(payMap['due'].toString()).toStringAsFixed(2),
                    bold,
                    12,
                    color: PdfColors.red900,
                  ),
                ),
                if (cartons != null && cartons > 0)
                  _pdfRow("Cartons", cartons.toString(), reg, 10),
              ],
              if (!isCond && double.parse(payMap['due'].toString()) > 0)
                _pdfRow(
                  "Due Amount",
                  double.parse(payMap['due'].toString()).toStringAsFixed(2),
                  bold,
                  12,
                  color: PdfColors.red,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- CHALLAN SPECIFIC WIDGETS ---

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
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Courier Info
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "SHIPPING DETAILS",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text("Courier: $courier", style: pw.TextStyle(font: bold)),
              pw.Text("Challan No: $challan", style: pw.TextStyle(font: bold)),
              if (cartons != null && cartons > 0)
                pw.Text(
                  "No. of Cartons: $cartons",
                  style: pw.TextStyle(font: bold),
                ),
              pw.SizedBox(height: 4),
              pw.Text("Ref Inv: $invId", style: pw.TextStyle(font: reg)),
              pw.Text(
                "Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
                style: pw.TextStyle(font: reg),
              ),
            ],
          ),
        ),

        // Right: Receiver Info
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "RECEIVER / CUSTOMER",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 12)),
              if (shopName.isNotEmpty)
                pw.Text(shopName, style: pw.TextStyle(font: bold)),
              pw.Text(phone, style: pw.TextStyle(font: bold)),
              pw.Text(addr, style: pw.TextStyle(font: reg)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildChallanTable(pw.Font bold, pw.Font reg, List items) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: bold, color: PdfColors.black),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headers: ['SL', 'Item Description', 'Qty'],
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(60),
      },
      data: List.generate(items.length, (index) {
        final item = items[index];
        return [
          (index + 1).toString(),
          "${item['model']} - ${item['name']}",
          item['qty'].toString(),
        ];
      }),
    );
  }

  pw.Widget _buildConditionBox(pw.Font bold, pw.Font reg, Map payMap) {
    double conditionAmount = double.parse(payMap['due'].toString());
    bool hasCondition = conditionAmount > 0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2),
        color: hasCondition ? PdfColors.white : PdfColors.green50,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            hasCondition ? "CONDITION AMOUNT + CHARGES:" : "PAYMENT STATUS:",
            style: pw.TextStyle(font: bold, fontSize: 14),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            hasCondition
                ? "Tk ${conditionAmount.toStringAsFixed(0)} /="
                : "NO CONDITION / PREPAID",
            style: pw.TextStyle(
              font: bold,
              fontSize: 24,
              color: hasCondition ? PdfColors.red900 : PdfColors.green900,
            ),
          ),
          if (hasCondition)
            pw.Text(
              "(Please collect this amount from receiver)",
              style: pw.TextStyle(font: reg, fontSize: 10),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text("Authorized Signature", style: pw.TextStyle(font: reg)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text("Receiver Signature", style: pw.TextStyle(font: reg)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font reg) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Center(
          child: pw.Text(
            "Software by G-TEL ERP",
            style: pw.TextStyle(font: reg, fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfRow(
    String label,
    String value,
    pw.Font font,
    double size, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: size, color: color),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: size, color: color),
          ),
        ],
      ),
    );
  }
}
