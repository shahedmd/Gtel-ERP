// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Import your existing models
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

  // State Variables
  final RxString customerType = "Retailer".obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();

  // --- TEXT CONTROLLERS ---
  // Customer Info
  final debtorPhoneSearch = TextEditingController();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();

  // Financials
  final discountC = TextEditingController();
  final RxDouble discountVal = 0.0.obs;

  // MULTI-PAYMENT CONTROLLERS
  final cashC = TextEditingController();
  final bkashC = TextEditingController();
  final nagadC = TextEditingController();
  final bankC = TextEditingController();

  final RxDouble totalPaidInput = 0.0.obs;
  final RxDouble changeReturn = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to payment inputs to calculate totals in real-time
    cashC.addListener(updatePaymentCalculations);
    bkashC.addListener(updatePaymentCalculations);
    nagadC.addListener(updatePaymentCalculations);
    bankC.addListener(updatePaymentCalculations);
  }

  void updatePaymentCalculations() {
    double cash = double.tryParse(cashC.text) ?? 0;
    double bkash = double.tryParse(bkashC.text) ?? 0;
    double nagad = double.tryParse(nagadC.text) ?? 0;
    double bank = double.tryParse(bankC.text) ?? 0;

    totalPaidInput.value = cash + bkash + nagad + bank;

    // Calculate Change (Only relevant if paid > total)
    if (totalPaidInput.value > grandTotal) {
      changeReturn.value = totalPaidInput.value - grandTotal;
    } else {
      changeReturn.value = 0.0;
    }
  }

  // --- CALCULATIONS ---
  double get subtotalAmount =>
      cart.fold(0, (sumv, item) => sumv + item.subtotal);
  double get grandTotal => subtotalAmount - discountVal.value;

  // Cost & Profit Tracking
  double get totalInvoiceCost => cart.fold(
    0,
    (sumv, item) =>
        sumv + (item.product.avgPurchasePrice * item.quantity.value),
  );
  double get invoiceProfit => grandTotal - totalInvoiceCost;

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
    // Recalculate if discount exists
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
      cart[index].quantity.value = p.stockQty; // Max out
      cart.refresh();
    }
    updatePaymentCalculations();
  }

  String _generateInvoiceID() {
    final now = DateTime.now();
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    return "GTEL-${DateFormat('yyyyMMdd').format(now)}-$random";
  }

  // --- FINALIZE SALE (CORRECTED DEBTOR LOGIC) ---
  Future<void> finalizeSale() async {
    // 1. Basic Validations
    if (cart.isEmpty) return;
    if (grandTotal < 0) {
      Get.snackbar("Error", "Negative total not allowed");
      return;
    }

    // 2. Customer Validation
    String fName = "";
    String fPhone = "";

    if (customerType.value == "Debtor") {
      if (selectedDebtor.value == null) {
        Get.snackbar("Required", "Please select a Debtor");
        return;
      }
      fName = selectedDebtor.value!.name;
      fPhone = selectedDebtor.value!.phone;
    } else {
      if (nameC.text.isEmpty || phoneC.text.isEmpty) {
        Get.snackbar("Required", "Customer Name & Phone are needed");
        return;
      }
      fName = nameC.text;
      fPhone = phoneC.text;
    }

    isProcessing.value = true;
    final String invNo = _generateInvoiceID();

    // Calculate Financials
    double paidAmount = totalPaidInput.value;
    double dueAmount = grandTotal - paidAmount;
    if (dueAmount < 0) dueAmount = 0;

    // Payment Breakdown Map
    Map<String, dynamic> paymentMap = {
      "type": "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
      "totalPaid": paidAmount,
      "due": dueAmount,
      "changeReturned": changeReturn.value,
      "currency": "BDT",
    };

    try {
      // A. Update Stock (Common)
      List<Map<String, dynamic>> updates =
          cart
              .map(
                (item) => {'id': item.product.id, 'qty': item.quantity.value},
              )
              .toList();
      bool stockSuccess = await productCtrl.updateStockBulk(updates);
      if (!stockSuccess) throw "Stock update failed";

      // B. Logic Split: Debtor vs Retailer
      if (customerType.value == "Debtor") {
        // --- DEBTOR LOGIC (UPDATED AS REQUESTED) ---

        // 1. The Bill Entry (Unpaid/Due Amount) -> CREDIT ENTRY
        // "if the bill is unpaid you should entry a credit entry"
        // We record the FULL Invoice amount as Credit (Increasing their Due)
        await debtorCtrl.addTransaction(
          debtorId: selectedDebtor.value!.id,
          amount: grandTotal,
          note: "Invoice: $invNo",
          type: "credit", // <--- CHANGED TO CREDIT (Bill/Due)
          date: DateTime.now(),
        );

        // 2. The Payment Entry (If they paid anything) -> DEBIT ENTRY
        // "if the bill is paid then you will entry a debit entry"
        if (paidAmount > 0) {
          await debtorCtrl.addTransaction(
            debtorId: selectedDebtor.value!.id,
            amount: paidAmount,
            note: "Payment for Inv: $invNo",
            type: "debit", // <--- CHANGED TO DEBIT (Payment/Collection)
            date: DateTime.now(),
          );
        }


        // 4. Profit Log
        await _db.collection('debtorProfitLoss').doc(invNo).set({
          "invoiceId": invNo,
          "debtorName": fName,
          "saleAmount": grandTotal,
          "costAmount": totalInvoiceCost,
          "profit": invoiceProfit,
          "paidAmount": paidAmount,
          "dueAmount": dueAmount,
          "timestamp": FieldValue.serverTimestamp(),
        });
      } else {
        // --- RETAILER LOGIC (UNCHANGED) ---
        await dailyCtrl.addSale(
          name: "$fName (${shopC.text})",
          amount: grandTotal,
          customerType: customerType.value.toLowerCase(),
          isPaid: true,
          date: DateTime.now(),
          paymentMethod: paymentMap,
          transactionId: invNo,
        );

        await _db.collection('customers').doc(fPhone).set({
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "lastInv": invNo,
        }, SetOptions(merge: true));

        await _db
            .collection('customers')
            .doc(fPhone)
            .collection('orders')
            .doc(invNo)
            .set({
              "invoiceId": invNo,
              "items":
                  cart
                      .map(
                        (e) => {
                          "name": e.product.name,
                          "qty": e.quantity.value,
                          "rate": e.priceAtSale,
                        },
                      )
                      .toList(),
              "paymentDetails": paymentMap,
              "profit": invoiceProfit,
              "timestamp": FieldValue.serverTimestamp(),
            });
      }

      // C. Print PDF
      await _generatePdf(invNo, fName, fPhone, paymentMap);

      _resetAll();
      Get.snackbar(
        "Success",
        "Sale Finalized",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString(), backgroundColor: Colors.red);
    } finally {
      isProcessing.value = false;
    }
  }

  void _resetAll() {
    cart.clear();
    nameC.clear();
    phoneC.clear();
    shopC.clear();
    discountC.clear();
    cashC.clear();
    bkashC.clear();
    nagadC.clear();
    bankC.clear();
    discountVal.value = 0.0;
    totalPaidInput.value = 0.0;
    selectedDebtor.value = null;
  }

  // --- PDF GENERATION ---
  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
  ) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "G-TEL INVOICE",
                  style: pw.TextStyle(font: boldFont, fontSize: 24),
                ),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Invoice ID: $invId"),
                  // Show status on PDF
                  pw.Text(
                    double.parse(payMap['due'].toString()) > 0
                        ? "STATUS: UNPAID/DUE"
                        : "STATUS: PAID",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color:
                          double.parse(payMap['due'].toString()) > 0
                              ? PdfColors.red
                              : PdfColors.green,
                    ),
                  ),
                ],
              ),
              pw.Text(
                "Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}",
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Bill To:", style: pw.TextStyle(font: boldFont)),
                      pw.Text(name),
                      pw.Text(phone),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Shop:", style: pw.TextStyle(font: boldFont)),
                      pw.Text(shopC.text.isEmpty ? "N/A" : shopC.text),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                headers: ['Item', 'Rate', 'Qty', 'Total'],
                data:
                    cart
                        .map(
                          (e) => [
                            e.product.name,
                            e.priceAtSale.toStringAsFixed(2),
                            e.quantity.value.toString(),
                            e.subtotal.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Subtotal: ${subtotalAmount.toStringAsFixed(2)}"),
                    if (discountVal.value > 0)
                      pw.Text(
                        "Discount: -${discountVal.value.toStringAsFixed(2)}",
                        style: const pw.TextStyle(color: PdfColors.red),
                      ),
                    pw.Divider(),
                    pw.Text(
                      "Grand Total: ${grandTotal.toStringAsFixed(2)}",
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                    pw.SizedBox(height: 10),
                    // Payment Details for PDF
                    pw.Text(
                      "Paid Amount: ${double.parse(payMap['totalPaid'].toString()).toStringAsFixed(2)}",
                    ),
                    if (double.parse(payMap['due'].toString()) > 0)
                      pw.Text(
                        "DUE AMOUNT: ${double.parse(payMap['due'].toString()).toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.red,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }
}
