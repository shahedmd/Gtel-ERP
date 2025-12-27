// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Your Project Imports
import '../Stock/controller.dart';
import '../Stock/model.dart';
import '../Live order/salemodel.dart'; // Ensure this contains SalesCartItem class
import '../Web Screen/Debator Finance/debatorcontroller.dart';
import '../Web Screen/Debator Finance/model.dart';
import '../Web Screen/Sales/controller.dart';

class LiveOrderSalesPage extends StatefulWidget {
  const LiveOrderSalesPage({super.key});

  @override
  State<LiveOrderSalesPage> createState() => _LiveOrderSalesPageState();
}

class _LiveOrderSalesPageState extends State<LiveOrderSalesPage> {
  // --- CONTROLLER INJECTION ---
  final productCtrl = Get.find<ProductController>();
  final debtorCtrl = Get.find<DebatorController>();
  final dailyCtrl = Get.find<DailySalesController>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MODERN POS THEME COLORS ---
  static const Color posBg = Color(0xFFF9FAFB);
  static const Color posPrimary = Color(0xFF2563EB); // GTEL Blue
  static const Color posText = Color(0xFF111827);
  static const Color posBorder = Color(0xFFE5E7EB);
  static const Color posSuccess = Color(0xFF10B981);

  // --- REACTIONAL STATE ---
  final RxString customerType = "Retailer".obs;
  final RxString paymentMethod = "Cash".obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;

  // --- INPUT CONTROLLERS ---
  final debtorPhoneSearch = TextEditingController();
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();
  final addressC = TextEditingController();
  final paymentInfoC = TextEditingController(); // For bKash/Nagad/Bank details

  double get totalAmount =>
      cart.fold(0, (sumval, item) => sumval + item.subtotal);

  // --- INVOICE ID GENERATOR ---
  String _generateInvoiceID() {
    final now = DateTime.now();
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    return "GTEL-${DateFormat('yyyyMMdd').format(now)}-$random";
  }

  // --- CART MANAGEMENT ---
  void _addToCart(Product p) {
    if (p.stockQty <= 0) {
      Get.snackbar(
        "Stock Alert",
        "Out of stock",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    // Pricing Logic based on requirements
    double price =
        (customerType.value == "Debtor" || customerType.value == "Agent")
            ? p.agent
            : p.wholesale;

    int index = cart.indexWhere((item) => item.product.id == p.id);
    if (index != -1) {
      if (cart[index].quantity < p.stockQty) {
        cart[index].quantity++;
        cart.refresh();
      }
    } else {
      cart.add(SalesCartItem(product: p, quantity: 1, priceAtSale: price));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: posBg,
      body: Row(
        children: [
          // LEFT PANE: PRODUCT TABLE
          Expanded(flex: 7, child: _buildProductTableSection()),

          // RIGHT PANE: CHECKOUT DETAILS
          Container(
            width: 400,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: posBorder)),
            ),
            child: _buildCheckoutSection(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT SIDE: PRODUCT TABLE
  // ---------------------------------------------------------------------------
  Widget _buildProductTableSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          _buildTopHeader(),
          const SizedBox(height: 15),
          _buildTableHeader(),
          Expanded(
            child: Obx(() {
              if (productCtrl.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: posPrimary),
                );
              }
              return ListView.builder(
                itemCount: productCtrl.allProducts.length,
                itemBuilder:
                    (context, index) =>
                        _buildProductRow(productCtrl.allProducts[index]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "G-TEL ERP",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: posText,
                ),
              ),
              Text(
                "Sales & Inventory Management",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          width: 350,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: posBorder),
          ),
          child: Center(
            // Added Center wrapper for safety
            child: TextField(
              onChanged: (v) => productCtrl.search(v),
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: "Search Product or Scan Barcode...",
                prefixIcon: Icon(Icons.search, size: 20, color: posPrimary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero, // Zeroing out internal padding
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "ITEM DESCRIPTION",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "STOCK",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "UNIT PRICE",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: posBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.model,
                  style: const TextStyle(
                    fontSize: 11,
                    color: posPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "${p.stockQty}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: p.stockQty < 5 ? Colors.red : posSuccess,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Obx(() {
              double price =
                  (customerType.value == "Retailer") ? p.wholesale : p.agent;
              return Text(
                "৳ ${price.toStringAsFixed(0)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            }),
          ),
          const SizedBox(width: 15),
          IconButton(
            onPressed: () => _addToCart(p),
            icon: const Icon(Icons.add_circle, color: posPrimary, size: 28),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT SIDE: CHECKOUT
  // ---------------------------------------------------------------------------
  Widget _buildCheckoutSection() {
    return Column(
      children: [
        _buildCustomerTypeTabs(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildCustomerForm(),
                const Divider(height: 1),
                _buildCartHeader(),
                _buildCartList(),
              ],
            ),
          ),
        ),
        _buildSummaryFooter(),
      ],
    );
  }

  Widget _buildCustomerTypeTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Obx(
        () => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: posBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children:
                ["Retailer", "Agent", "Debtor"].map((type) {
                  bool isSelected = customerType.value == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        customerType.value = type;
                        cart.clear();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? posPrimary : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (customerType.value == "Debtor") ...[
              _posTextField(
                debtorPhoneSearch,
                "Find Debtor Phone",
                Icons.person_search,
                (v) {
                  if (v.length > 9) {
                    selectedDebtor.value = debtorCtrl.bodies.firstWhereOrNull(
                      (e) => e.phone.contains(v),
                    );
                  }
                },
              ),
              if (selectedDebtor.value != null)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                  leading: const Icon(
                    Icons.verified_user,
                    color: posSuccess,
                    size: 22,
                  ),
                  title: Text(
                    selectedDebtor.value!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    selectedDebtor.value!.des,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _posTextField(
                      nameC,
                      "Full Name",
                      Icons.person,
                      null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _posTextField(phoneC, "Phone No", Icons.phone, null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _posTextField(shopC, "Shop/Company Name", Icons.store, null),
              const SizedBox(height: 10),
              _posTextField(addressC, "Address", Icons.location_on, null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: paymentMethod.value,
                style: const TextStyle(fontSize: 13, color: posText),
                decoration: InputDecoration(
                  labelText: "Payment Method",
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                items:
                    ["Cash", "bKash", "Nagad", "Bank"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) {
                  paymentMethod.value = v!;
                  paymentInfoC.clear();
                },
              ),
              if (paymentMethod.value != "Cash") ...[
                const SizedBox(height: 10),
                _posTextField(
                  paymentInfoC,
                  paymentMethod.value == "Bank"
                      ? "Bank A/C Number"
                      : "Mobile Wallet Number",
                  Icons.payment,
                  null,
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  Widget _posTextField(
    TextEditingController c,
    String hint,
    IconData icon,
    Function(String)? onCh,
  ) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: c,
        onChanged: onCh,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildCartHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: posBg,
    child: const Text(
      "ORDER DETAILS",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1,
        color: Colors.grey,
      ),
    ),
  );

  Widget _buildCartList() {
    return Obx(
      () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cart.length,
        itemBuilder: (context, index) {
          final item = cart[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "৳${item.priceAtSale.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (item.quantity > 1) {
                          cart[index].quantity--;
                          cart.refresh();
                        } else {
                          cart.removeAt(index);
                        }
                      },
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      "${item.quantity}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () {
                        if (item.quantity < item.product.stockQty) {
                          cart[index].quantity++;
                          cart.refresh();
                        }
                      },
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: posSuccess,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  "৳${item.subtotal.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: posBorder)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Grand Total",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Obx(
                () => Text(
                  "৳ ${totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: posPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: posPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing.value ? null : _finalizeSale,
                child:
                    isProcessing.value
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          "FINALIZE & PRINT INVOICE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FINAL TRANSACTION LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _finalizeSale() async {
    if (cart.isEmpty) return;

    // Validations
    if (customerType.value != "Debtor") {
      if (nameC.text.isEmpty || phoneC.text.isEmpty) {
        Get.snackbar(
          "Missing Info",
          "Name and Phone are mandatory",
          backgroundColor: Colors.orange,
        );
        return;
      }
      if (paymentMethod.value != "Cash" && paymentInfoC.text.isEmpty) {
        Get.snackbar(
          "Payment Details",
          "Please enter ${paymentMethod.value} info",
          backgroundColor: Colors.orange,
        );
        return;
      }
    } else if (selectedDebtor.value == null) {
      Get.snackbar(
        "No Debtor",
        "Lookup and select a debtor first",
        backgroundColor: Colors.orange,
      );
      return;
    }

    isProcessing.value = true;
    final String invNo = _generateInvoiceID();

    try {
      // 1. PostgreSQL Stock Decrement
      for (var item in cart) {
        await productCtrl.updateProduct(item.product.id, {
          'stock_qty': item.product.stockQty - item.quantity,
          'name': item.product.name,
          'category': item.product.category,
          'brand': item.product.brand,
          'model': item.product.model,
          'weight': item.product.weight,
          'yuan': item.product.yuan,
          'air': item.product.air,
          'sea': item.product.sea,
          'agent': item.product.agent,
          'wholesale': item.product.wholesale,
          'shipmenttax': item.product.shipmentTax,
          'shipmentno': item.product.shipmentNo,
          'currency': item.product.currency,
        });
      }

      String fName = "";
      String fPhone = "";

      if (customerType.value == "Debtor") {
        fName = selectedDebtor.value!.name;
        fPhone = selectedDebtor.value!.phone;
        // Ledger Entry
        await debtorCtrl.addTransaction(
          debtorId: selectedDebtor.value!.id,
          amount: totalAmount,
          note: "Invoice: $invNo",
          type: "credit",
          date: DateTime.now(),
        );
      } else {
        fName = nameC.text;
        fPhone = phoneC.text;
        // Customer History
        await _db.collection('customers').doc(fPhone).set({
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "address": addressC.text,
          "type": customerType.value,
          "lastInv": invNo,
          "lastOrder": DateTime.now(),
        }, SetOptions(merge: true));

        // Daily Sales Audit
        await dailyCtrl.addSale(
          name: "$fName (${shopC.text})",
          amount: totalAmount,
          customerType: customerType.value.toLowerCase(),
          isPaid: true,
          date: DateTime.now(),
          paymentMethod: {
            "type": paymentMethod.value,
            "number": paymentInfoC.text,
          },
          transactionId: invNo,
        );
      }

      // 3. Generate A3 Professional Invoice
      await _generateA3Invoice(invNo, fName, fPhone);

      _resetAll();
      Get.snackbar(
        "Success",
        "Invoice $invNo Processed",
        backgroundColor: posSuccess,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
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
    paymentInfoC.clear();
    debtorPhoneSearch.clear();
    selectedDebtor.value = null;
  }

  // ---------------------------------------------------------------------------
  // A3 PROFESSIONAL INVOICE GENERATOR
  // ---------------------------------------------------------------------------
  Future<void> _generateA3Invoice(String id, String name, String phone) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a3,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "G-TEL ERP SOLUTIONS",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 30,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Dhaka, Bangladesh | Phone: +880 1700-000000",
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        "Email: support@gtel.com.bd",
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "OFFICIAL INVOICE",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 35,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "Invoice ID: $id",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      pw.Text(
                        "Date: $date",
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(thickness: 2),

              // Billing Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "BILL TO:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          "Customer: $name",
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "Mobile: $phone",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Shop: ${shopC.text}",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "Address: ${addressC.text}",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "PAYMENT DETAILS:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          "Method: ${paymentMethod.value}",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        if (paymentInfoC.text.isNotEmpty)
                          pw.Text(
                            "Account/Ref: ${paymentInfoC.text}",
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // Item Table
              pw.Table.fromTextArray(
                headerAlignment:
                    pw.Alignment.center, // Centers the column headings
                cellAlignment: pw.Alignment.center, // Centers the data cells
                context: context,
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellStyle: const pw.TextStyle(fontSize: 14),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2.5),
                },
                data: [
                  ['SL', 'Item & Model', 'Unit Price', 'Qty', 'Total'],
                  ...cart.asMap().entries.map(
                    (entry) => [
                      (entry.key + 1).toString(),
                      "${entry.value.product.name} (${entry.value.product.model})",
                      entry.value.priceAtSale.toStringAsFixed(2),
                      entry.value.quantity.toString(),
                      entry.value.subtotal.toStringAsFixed(2),
                    ],
                  ),
                ],
              ),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 300,
                    padding: const pw.EdgeInsets.all(15),
                    child: pw.Column(
                      children: [
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "GRAND TOTAL:",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 20,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.Text(
                              "Tk ${totalAmount.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 20,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  "This is an electronically generated invoice. Signature not required.",
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  "Thank you for your business! Powered by G-TEL ERP",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
