// ignore_for_file: deprecated_member_use
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

// --- CART ITEM MODEL ---
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

  // Payment Controllers
  final cashC = TextEditingController();
  final bkashC = TextEditingController();
  final nagadC = TextEditingController();
  final bankC = TextEditingController();

  final RxDouble totalPaidInput = 0.0.obs;
  final RxDouble changeReturn = 0.0.obs;

  // Reporting State
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
  }

  double _round(double val) => double.parse(val.toStringAsFixed(2));

  void _handleTypeChange() {
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();

    // Re-price items
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

  // --- CALCULATIONS ---
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

  // --- ACTIONS ---
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

  Future<void> calculateCourierDueFor(String courierName) async {
    try {
      final snap =
          await _db
              .collection('sales_orders')
              .where('isCondition', isEqualTo: true)
              .where('courierName', isEqualTo: courierName)
              .where('status', whereIn: ['on_delivery', 'pending_courier'])
              .get();

      double totalPending = 0.0;
      for (var doc in snap.docs) {
        double due =
            double.tryParse(doc.data()['courierDue'].toString()) ?? 0.0;
        totalPending += due;
      }
      calculatedCourierDue.value = _round(totalPending);
      Get.snackbar(
        "Courier Status",
        "Pending in $courierName: Tk $_round(totalPending)",
        backgroundColor: Colors.blueAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Check console for Index link: $e");
    }
  }

  // ==================================================================
  // 🔥 FINALIZATION LOGIC (Updated for Debtor Requirements)
  // ==================================================================
  Future<void> finalizeSale() async {
    // 1. Validations
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
      return;
    }

    if (isConditionSale.value) {
      if (addressC.text.isEmpty) {
        Get.snackbar("Required", "Delivery Address required");
        return;
      }
      if (challanC.text.isEmpty) {
        Get.snackbar("Required", "Challan No required");
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

    // 2. Financial Calculations
    double paidAmountInput = totalPaidInput.value;
    double actualReceived = 0.0;
    double dueOrConditionAmount = 0.0;

    if (isConditionSale.value) {
      actualReceived = paidAmountInput;
      dueOrConditionAmount = _round(grandTotal - actualReceived);
    } else {
      // Direct Sale
      actualReceived =
          paidAmountInput > grandTotal ? grandTotal : paidAmountInput;
      dueOrConditionAmount = _round(grandTotal - actualReceived);
    }
    if (dueOrConditionAmount < 0) dueOrConditionAmount = 0;

    Map<String, dynamic> paymentMap = {
      "type": isConditionSale.value ? "condition_partial" : "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
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

    try {
      WriteBatch batch = _db.batch();

      // A. Stock Deduction
      List<Map<String, dynamic>> stockUpdates =
          cart
              .map(
                (item) => {'id': item.product.id, 'qty': item.quantity.value},
              )
              .toList();
      bool stockSuccess = await productCtrl.updateStockBulk(stockUpdates);
      if (!stockSuccess) throw "Stock update failed";

      // B. Create Master Invoice
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
        "challanNo": challanC.text,
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
        "status": isConditionSale.value ? "on_delivery" : "completed",
      });

      // C. DAILY SALES ENTRY
      // LOGIC FIXED: We create this for EVERY sale.
      // If Debtor unpaid: paid=0, pending=total (Status: Due)
      // If Paid: paid=total, pending=0 (Status: Normal)
      DocumentReference dailyRef = _db.collection('daily_sales').doc();
      batch.set(dailyRef, {
        "name": isConditionSale.value ? "$fName (Cond)" : fName,
        "amount": grandTotal, // Total Sale Value
        "paid": actualReceived, // What we got
        "pending": dueOrConditionAmount, // What is left
        "customerType":
            isConditionSale.value
                ? "condition_advance"
                : customerType.value.toLowerCase(),
        "timestamp": Timestamp.fromDate(saleDate),
        "paymentMethod": paymentMap,
        "createdAt": FieldValue.serverTimestamp(),
        "source": "pos_sale",
        "transactionId": invNo,
        "invoiceId": invNo,
        "courierName": isConditionSale.value ? selectedCourier.value : null,
        "cartons": isConditionSale.value ? cartonsInt : 0,
      });

      // D. BRANCHING LOGIC
      if (isConditionSale.value) {
        // --- CONDITION CUSTOMER ---
        DocumentReference condCustRef = _db
            .collection('condition_customers')
            .doc(fPhone);
        batch.set(condCustRef, {
          "name": fName,
          "phone": fPhone,
          "address": addressC.text,
          "shop": shopC.text,
          "lastChallan": challanC.text,
          "lastCourier": selectedCourier.value,
          "lastUpdated": FieldValue.serverTimestamp(),
          "totalCourierDue": FieldValue.increment(dueOrConditionAmount),
        }, SetOptions(merge: true));

        DocumentReference condTxRef = condCustRef
            .collection('orders')
            .doc(invNo);
        batch.set(condTxRef, {
          "invoiceId": invNo,
          "challanNo": challanC.text,
          "grandTotal": grandTotal,
          "advance": actualReceived,
          "courierDue": dueOrConditionAmount,
          "courierName": selectedCourier.value,
          "cartons": cartonsInt,
          "items": orderItems,
          "date": Timestamp.fromDate(saleDate),
          "status": "pending_courier",
        });
      } else if (customerType.value == "Debtor" && debtorId != null) {
        // --- DEBTOR LOGIC ---

        // 1. Transaction Entry (ONLY IF DUE EXISTS)
        // If they pay full, we skip this, so it acts like a normal sale.
        if (dueOrConditionAmount > 0) {
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
        }

        // 2. Profit/Loss Tracking (Always keep record of what they bought)
        DocumentReference pnlRef = _db
            .collection('debtorProfitLoss')
            .doc(invNo);
        batch.set(pnlRef, {
          "invoiceId": invNo,
          "debtorName": fName,
          "saleAmount": grandTotal,
          "costAmount": totalInvoiceCost,
          "profit": invoiceProfit,
          "paidAmount": actualReceived,
          "dueAmount": dueOrConditionAmount,
          "items": orderItems.map((e) => "${e['model']} x${e['qty']}").toList(),
          "timestamp": FieldValue.serverTimestamp(),
        });
      } else {
        // --- RETAILER / AGENT LOGIC ---
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
      }

      await batch.commit();

      // 5. PDF
      await _generatePdf(
        invNo,
        fName,
        fPhone,
        paymentMap,
        orderItems,
        isCondition: isConditionSale.value,
        challan: challanC.text,
        address: addressC.text,
        courier: selectedCourier.value,
        cartons: cartonsInt,
      );

      _resetAll();
      Get.snackbar(
        "Success",
        "Sale Finalized & Recorded",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
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
    nagadC.clear();
    bankC.clear();
    discountVal.value = 0.0;
    totalPaidInput.value = 0.0;
    changeReturn.value = 0.0;
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();
    calculatedCourierDue.value = 0.0;
  }

  // ==================================================================
  // 🖨️ PDF GENERATION
  // ==================================================================
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
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.nunitoBold();
    final regularFont = await PdfGoogleFonts.nunitoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return _buildInvoiceLayout(
            context,
            boldFont,
            regularFont,
            invId,
            name,
            phone,
            payMap,
            items,
            isCondition,
            address,
            courier,
            cartons,
          );
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return _buildChallanLayout(
              context,
              boldFont,
              regularFont,
              invId,
              name,
              phone,
              challan,
              address,
              payMap,
              items,
              courier,
              cartons,
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildInvoiceLayout(
    pw.Context context,
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    Map payMap,
    List items,
    bool isCond,
    String addr,
    String? courier,
    int? cartons,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "G-TEL",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                isCond ? "CONDITION MEMO" : "INVOICE",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 20,
                  color: isCond ? PdfColors.orange800 : PdfColors.black,
                ),
              ),
            ],
          ),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Inv: $invId", style: pw.TextStyle(font: reg)),
                pw.Text(
                  "Date: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}",
                  style: pw.TextStyle(font: reg),
                ),
                if (isCond && courier != null)
                  pw.Text(
                    "Via: $courier",
                    style: pw.TextStyle(
                      font: bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Bill To: $name", style: pw.TextStyle(font: bold)),
                pw.Text(phone, style: pw.TextStyle(font: reg)),
                if (addr.isNotEmpty)
                  pw.Text(addr, style: pw.TextStyle(font: reg, fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey800,
          ),
          cellStyle: pw.TextStyle(font: reg),
          headers: ['Item', 'Rate', 'Qty', 'Total'],
          data:
              items
                  .map(
                    (e) => [
                      e['model'] ?? e['name'],
                      double.parse(e['saleRate'].toString()).toStringAsFixed(2),
                      e['qty'].toString(),
                      double.parse(e['subtotal'].toString()).toStringAsFixed(2),
                    ],
                  )
                  .toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _pdfRow("Grand Total", grandTotal.toStringAsFixed(2), bold, 14),
                pw.Divider(),
                _pdfRow(
                  isCond ? "Advance Paid" : "Paid Amount",
                  double.parse(
                    payMap['actualReceived'].toString(),
                  ).toStringAsFixed(2),
                  reg,
                  12,
                ),
                if (isCond) ...[
                  _pdfRow(
                    "Courier Collect",
                    double.parse(payMap['due'].toString()).toStringAsFixed(2),
                    bold,
                    12,
                    color: PdfColors.red,
                  ),
                  if (cartons != null && cartons > 0)
                    _pdfRow("Total Cartons", cartons.toString(), reg, 10),
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
        ),
      ],
    );
  }

  pw.Widget _buildChallanLayout(
    pw.Context context,
    pw.Font bold,
    pw.Font reg,
    String invId,
    String name,
    String phone,
    String challan,
    String addr,
    Map payMap,
    List items,
    String? courier,
    int? cartons,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            "DELIVERY CHALLAN",
            style: pw.TextStyle(
              font: bold,
              fontSize: 22,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Challan No: $challan",
                    style: pw.TextStyle(font: bold, fontSize: 14),
                  ),
                  pw.Text(
                    "Ref Invoice: $invId",
                    style: pw.TextStyle(font: reg, fontSize: 10),
                  ),
                  pw.Text(
                    "Date: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}",
                    style: pw.TextStyle(font: reg),
                  ),
                  if (courier != null)
                    pw.Text(
                      "Service: $courier",
                      style: pw.TextStyle(font: bold, fontSize: 12),
                    ),
                  if (cartons != null && cartons > 0)
                    pw.Text(
                      "No. of Cartons: $cartons",
                      style: pw.TextStyle(font: bold, fontSize: 12),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Receiver Details:",
                    style: pw.TextStyle(
                      font: bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.Text(name, style: pw.TextStyle(font: bold)),
                  pw.Text(phone, style: pw.TextStyle(font: reg)),
                  pw.Container(
                    width: 150,
                    child: pw.Text(
                      addr,
                      style: pw.TextStyle(font: reg),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text("Package Contents:", style: pw.TextStyle(font: bold)),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          headers: ['SL', 'Item Description', 'Qty'],
          data: List.generate(items.length, (index) {
            final item = items[index];
            return [
              (index + 1).toString(),
              "${item['model']} - ${item['name']}",
              item['qty'].toString(),
            ];
          }),
        ),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "CONDITION AMOUNT TO COLLECT:",
                style: pw.TextStyle(font: bold, fontSize: 14),
              ),
              pw.Text(
                "Tk ${double.parse(payMap['due'].toString()).toStringAsFixed(2)}",
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 50),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 100, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text("Authorized Signature"),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(width: 100, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text("Receiver Signature"),
              ],
            ),
          ],
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
    return pw.Row(
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
    );
  }
}
