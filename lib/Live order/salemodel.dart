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

    // Listen to customer type changes to reset relevant fields
    ever(customerType, (_) {
      selectedDebtor.value = null;
      debtorPhoneSearch.clear();
      updatePaymentCalculations(); // Recalculate prices if logic depends on type
    });
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

  // Safe calculation preventing negative total
  double get grandTotal {
    double total = subtotalAmount - discountVal.value;
    return total < 0 ? 0 : total;
  }

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
    // Recalculate payments
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
      Get.snackbar("Limit", "Cannot exceed stock quantity: ${p.stockQty}");
    }
    updatePaymentCalculations();
  }

  // Generate a robust unique ID
  String _generateInvoiceID() {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return "GTEL-${DateFormat('yyMMdd').format(now)}-$random";
  }

  // --- FINALIZE SALE (UPDATED LOGIC) ---
  Future<void> finalizeSale() async {
    // 1. Basic Validations
    if (cart.isEmpty) {
      Get.snackbar("Error", "Cart is empty");
      return;
    }
    if (grandTotal < 0) {
      Get.snackbar("Error", "Negative total not allowed");
      return;
    }

    // 2. Customer Validation
    String fName = "";
    String fPhone = "";
    String? debtorId;

    if (customerType.value == "Debtor") {
      if (selectedDebtor.value == null) {
        Get.snackbar("Required", "Please select a Debtor");
        return;
      }
      fName = selectedDebtor.value!.name;
      fPhone = selectedDebtor.value!.phone;
      debtorId = selectedDebtor.value!.id;
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
    final DateTime saleDate = DateTime.now();

    // Calculate Financials
    // If user paid MORE than total, the actual money received is capped at Grand Total
    // for accounting purposes (since the rest is change returned).
    // However, we track the raw input for the payment breakdown.
    double paidAmountInput = totalPaidInput.value;
    double actualMoneyReceived =
        paidAmountInput > grandTotal ? grandTotal : paidAmountInput;
    double dueAmount = grandTotal - actualMoneyReceived;
    if (dueAmount < 0) {
      dueAmount = 0; // Should be handled by change logic, but safe guard.
    }

    // Payment Breakdown Map
    Map<String, dynamic> paymentMap = {
      "type": "multi",
      "cash": double.tryParse(cashC.text) ?? 0,
      "bkash": double.tryParse(bkashC.text) ?? 0,
      "nagad": double.tryParse(nagadC.text) ?? 0,
      "bank": double.tryParse(bankC.text) ?? 0,
      "totalPaidInput": paidAmountInput,
      "actualReceived": actualMoneyReceived,
      "due": dueAmount,
      "changeReturned": changeReturn.value,
      "currency": "BDT",
    };

    // Prepare Items List for Storage (Snapshot of current state)
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
      // A. Update Stock (Decrease)
      List<Map<String, dynamic>> stockUpdates =
          cart
              .map(
                (item) => {'id': item.product.id, 'qty': item.quantity.value},
              )
              .toList();
      bool stockSuccess = await productCtrl.updateStockBulk(stockUpdates);
      if (!stockSuccess) throw "Stock update failed";

      // B. Create Centralized Sales Order (CRITICAL FOR RETURNS/EDIT/PDF)
      // This is the "Master Record" of the sale
      await _db.collection('sales_orders').doc(invNo).set({
        "invoiceId": invNo,
        "timestamp": FieldValue.serverTimestamp(),
        "date": DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(saleDate), // Searchable string date
        // Customer Info
        "customerType": customerType.value,
        "customerName": fName,
        "customerPhone": fPhone,
        "debtorId": debtorId, // Null if retailer
        "shopName": shopC.text,

        // Product Details
        "items": orderItems,

        // Financials
        "subtotal": subtotalAmount,
        "discount": discountVal.value,
        "grandTotal": grandTotal,
        "totalCost": totalInvoiceCost,
        "profit": invoiceProfit,

        // Payment
        "paymentDetails": paymentMap,
        "isFullyPaid": dueAmount <= 0,
        "status": "completed", // Can be 'returned', 'cancelled' later
      });

      // C. Logic Split: Debtor vs Retailer Handlers
      if (customerType.value == "Debtor") {
        // 1. Record Money In (Daily Sales) - Only if money was actually paid
        if (actualMoneyReceived > 0) {
          await dailyCtrl.addSale(
            name: "$fName (Debtor)",
            amount: actualMoneyReceived,
            customerType: "debtor",
            isPaid: true,
            date: saleDate,
            paymentMethod: paymentMap,
            transactionId: invNo,
            source: "debtor_instant_sale",
          );
        }

        // 2. Record Debt (Ledger) - Only if there is due
        if (dueAmount > 0) {
          await debtorCtrl.addTransaction(
            debtorId: debtorId!,
            amount: dueAmount,
            note: "Due for Inv: $invNo (Items: ${cart.length})",
            type: "credit", // Increases debt
            date: saleDate,
          );
        }

        // 3. Profit Log (Legacy/Analytics support)
        await _db.collection('debtorProfitLoss').doc(invNo).set({
          "invoiceId": invNo,
          "debtorName": fName,
          "saleAmount": grandTotal,
          "costAmount": totalInvoiceCost,
          "profit": invoiceProfit,
          "paidAmount": actualMoneyReceived,
          "dueAmount": dueAmount,
          "items": orderItems.map((e) => "${e['model']} x${e['qty']}").toList(),
          "timestamp": FieldValue.serverTimestamp(),
        });
      } else {
        // Retailer Logic

        // 1. Record Money In (Daily Sales)
        // Assuming Daily Sales tracks cash flow, we log what was received.
        // If it tracks Revenue, log grandTotal. Using actualMoneyReceived for consistency with cash drawer.
        await dailyCtrl.addSale(
          name: "$fName (${shopC.text})",
          amount: actualMoneyReceived,
          customerType: customerType.value.toLowerCase(),
          isPaid: true,
          date: saleDate,
          paymentMethod: paymentMap,
          transactionId: invNo,
        );

        // 2. Update Customer Record (For CRM)
        await _db.collection('customers').doc(fPhone).set({
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "lastInv": invNo,
          "lastShopDate": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Add to Customer's Sub-collection (Optional, if you want redundant access)
        await _db
            .collection('customers')
            .doc(fPhone)
            .collection('orders')
            .doc(invNo)
            .set({
              "invoiceId": invNo,
              "grandTotal": grandTotal,
              "timestamp": FieldValue.serverTimestamp(),
              // We store minimal info here since full info is in 'sales_orders'
              "link": "sales_orders/$invNo",
            });
      }

      // D. Print PDF
      await _generatePdf(invNo, fName, fPhone, paymentMap, orderItems);

      _resetAll();
      Get.snackbar(
        "Success",
        "Sale Finalized & Recorded",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print("Sale Error: $e");
      Get.snackbar(
        "Error",
        "Failed to finalize sale: $e",
        backgroundColor: Colors.red,
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
    discountC.clear();
    cashC.clear();
    bkashC.clear();
    nagadC.clear();
    bankC.clear();
    discountVal.value = 0.0;
    totalPaidInput.value = 0.0;
    changeReturn.value = 0.0;
    // Do not clear customer type, keep user preference
    selectedDebtor.value = null;
    debtorPhoneSearch.clear();
  }

  // --- PDF GENERATION (UPDATED WITH FULL DETAILS) ---
  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.nunitoBold();
    final regularFont = await PdfGoogleFonts.nunitoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "G-TEL MOBILE",
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 24,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      "INVOICE",
                      style: pw.TextStyle(font: boldFont, fontSize: 20),
                    ),
                  ],
                ),
              ),

              // INFO ROW
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Invoice ID: $invId",
                        style: pw.TextStyle(font: regularFont),
                      ),
                      pw.Text(
                        "Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}",
                        style: pw.TextStyle(font: regularFont),
                      ),
                      pw.Text(
                        double.parse(payMap['due'].toString()) > 0
                            ? "STATUS: UNPAID/DUE"
                            : "STATUS: PAID",
                        style: pw.TextStyle(
                          font: boldFont,
                          color:
                              double.parse(payMap['due'].toString()) > 0
                                  ? PdfColors.red
                                  : PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Bill To:", style: pw.TextStyle(font: boldFont)),
                      pw.Text(name, style: pw.TextStyle(font: regularFont)),
                      pw.Text(phone, style: pw.TextStyle(font: regularFont)),
                      if (shopC.text.isNotEmpty)
                        pw.Text(
                          "Shop: ${shopC.text}",
                          style: pw.TextStyle(font: regularFont),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // ITEMS TABLE
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: regularFont),
                headers: ['Item / Model', 'Rate', 'Qty', 'Total'],
                data:
                    items
                        .map(
                          (e) => [
                            e['model'] ?? e['name'],
                            double.parse(
                              e['saleRate'].toString(),
                            ).toStringAsFixed(2),
                            e['qty'].toString(),
                            double.parse(
                              e['subtotal'].toString(),
                            ).toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 10),

              // TOTALS
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildSummaryRow(
                        "Subtotal",
                        subtotalAmount.toStringAsFixed(2),
                        boldFont,
                      ),
                      if (discountVal.value > 0)
                        _buildSummaryRow(
                          "Discount",
                          "-${discountVal.value.toStringAsFixed(2)}",
                          boldFont,
                          color: PdfColors.red,
                        ),
                      pw.Divider(),
                      _buildSummaryRow(
                        "Grand Total",
                        grandTotal.toStringAsFixed(2),
                        boldFont,
                        fontSize: 16,
                      ),
                      pw.SizedBox(height: 10),

                      _buildSummaryRow(
                        "Paid Amount",
                        double.parse(
                          payMap['actualReceived'].toString(),
                        ).toStringAsFixed(2),
                        regularFont,
                      ),
                      if (double.parse(payMap['changeReturned'].toString()) > 0)
                        _buildSummaryRow(
                          "Change Given",
                          double.parse(
                            payMap['changeReturned'].toString(),
                          ).toStringAsFixed(2),
                          regularFont,
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
              ),

              // FOOTER
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  "Thank you for your business!",
                  style: pw.TextStyle(
                    font: regularFont,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font font, {
    PdfColor color = PdfColors.black,
    double fontSize = 12,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
        ),
      ],
    );
  }
}
