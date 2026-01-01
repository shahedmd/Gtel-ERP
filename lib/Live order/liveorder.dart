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
import '../Live order/salemodel.dart';
import '../Web Screen/Debator Finance/debatorcontroller.dart';
import '../Web Screen/Debator Finance/model.dart';
import '../Web Screen/Sales/controller.dart';

class LiveOrderSalesPage extends StatefulWidget {
  const LiveOrderSalesPage({super.key});

  @override
  State<LiveOrderSalesPage> createState() => _LiveOrderSalesPageState();
}

class _LiveOrderSalesPageState extends State<LiveOrderSalesPage> {
  final productCtrl = Get.find<ProductController>();
  final debtorCtrl = Get.find<DebatorController>();
  final dailyCtrl = Get.find<DailySalesController>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Color posBg = Color(0xFFF9FAFB);
  static const Color posPrimary = Color(0xFF2563EB);
  static const Color posText = Color(0xFF111827);
  static const Color posBorder = Color(0xFFE5E7EB);
  static const Color posSuccess = Color(0xFF10B981);

  final RxString customerType = "Retailer".obs;
  final RxString paymentMethod = "Cash".obs;
  final RxList<SalesCartItem> cart = <SalesCartItem>[].obs;
  final RxBool isProcessing = false.obs;

  final debtorPhoneSearch = TextEditingController();
  final Rxn<DebtorModel> selectedDebtor = Rxn<DebtorModel>();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final shopC = TextEditingController();
  final addressC = TextEditingController();
  final paymentInfoC = TextEditingController();
  final bankNameC = TextEditingController();

  final discountC = TextEditingController();
  final RxDouble discountVal = 0.0.obs;

  // --- REFINED CALCULATIONS ---
  double get subtotalAmount =>
      cart.fold(0, (sumvalue, item) => sumvalue + item.subtotal);

  double get grandTotal => subtotalAmount - discountVal.value;

  // NEW: Calculation for Profit and Loss
  // Based on (Selling Price - Buying Rate) - Discount
  double get totalInvoiceCost => cart.fold(
    0,
    (sumval, item) => sumval + (item.product.avgPurchasePrice * item.quantity),
  );
  double get invoiceProfit => grandTotal - totalInvoiceCost;

  String _generateInvoiceID() {
    final now = DateTime.now();
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    return "GTEL-${DateFormat('yyyyMMdd').format(now)}-$random";
  }

  void _addToCart(Product p) {
    if (p.stockQty <= 0) {
      Get.snackbar(
        "Stock Alert",
        "Product is out of stock",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    // Determine price based on customer type
    double price =
        (customerType.value == "Debtor" || customerType.value == "Agent")
            ? p.agent
            : p.wholesale;

    int index = cart.indexWhere((item) => item.product.id == p.id);
    if (index != -1) {
      if (cart[index].quantity < p.stockQty) {
        cart[index].quantity++;
        cart.refresh();
      } else {
        Get.snackbar("Stock Limit", "Cannot add more than available stock");
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
          Expanded(flex: 7, child: _buildProductTableSection()),
          Container(
            width: 450,
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
                "G-TEL POS SYSTEM",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: posText,
                ),
              ),
              Text(
                "Profit & Loss Tracking Enabled",
                style: TextStyle(
                  fontSize: 12,
                  color: posPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 400,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: posBorder),
          ),
          child: Center(
            child: TextField(
              onChanged: (v) => productCtrl.search(v),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: "Search Product by Model or Name...",
                prefixIcon: Icon(Icons.search, size: 20, color: posPrimary),
                border: InputBorder.none,
                isDense: true,
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
              "AVAIL. STOCK",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "RATE (BDT)",
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
              p.stockQty.toDouble().toStringAsFixed(2),
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
                "৳ ${price.toStringAsFixed(2)}",
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
            icon: const Icon(
              Icons.add_shopping_cart_rounded,
              color: posPrimary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

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
                "Find Debtor (Type Phone)",
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
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: posBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: posSuccess.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: posSuccess,
                      child: Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                    title: Text(
                      selectedDebtor.value!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Current Due Balance Tracking Active",
                      style: const TextStyle(fontSize: 10, color: posSuccess),
                    ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod.value,
                style: const TextStyle(fontSize: 13, color: posText),
                decoration: InputDecoration(
                  labelText: "Payment Method",
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items:
                    ["Cash", "bKash", "Nagad", "Bank"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) {
                  paymentMethod.value = v!;
                  paymentInfoC.clear();
                  bankNameC.clear();
                },
              ),
              if (paymentMethod.value == "Bank") ...[
                const SizedBox(height: 10),
                _posTextField(bankNameC, "Bank Name", Icons.business, null),
                const SizedBox(height: 10),
                _posTextField(
                  paymentInfoC,
                  "Account Number",
                  Icons.numbers,
                  null,
                ),
              ] else if (paymentMethod.value != "Cash") ...[
                const SizedBox(height: 10),
                _posTextField(
                  paymentInfoC,
                  "${paymentMethod.value} Number",
                  Icons.phone_android,
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
      height: 48,
      child: TextField(
        controller: c,
        onChanged: onCh,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildCartHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: posBg,
    child: const Text(
      "SHOPPING CART",
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
                        "৳ ${item.priceAtSale.toStringAsFixed(2)} | Cost: ৳${item.product.avgPurchasePrice.toStringAsFixed(2)}",
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
                Text(
                  "৳${item.subtotal.toStringAsFixed(2)}",
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
                "Subtotal",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Obx(
                () => Text(
                  "৳ ${subtotalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                "Discount",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                height: 40,
                child: TextField(
                  controller: discountC,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  onChanged:
                      (v) => discountVal.value = double.tryParse(v) ?? 0.0,
                  decoration: InputDecoration(
                    hintText: "0.00",
                    prefixText: "৳ ",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // NEW: PROFIT DISPLAY FOR OWNER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Est. Profit",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Obx(
                () => Text(
                  "৳ ${invoiceProfit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: invoiceProfit >= 0 ? posSuccess : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Grand Total",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Obx(
                () => Text(
                  "৳ ${grandTotal.toStringAsFixed(2)}",
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
                        ? const CircularProgressIndicator(color: Colors.white)
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

  Future<void> _finalizeSale() async {
    if (cart.isEmpty) return;
    if (grandTotal < 0) {
      Get.snackbar("Error", "Total cannot be negative");
      return;
    }

    if (customerType.value != "Debtor") {
      if (nameC.text.isEmpty || phoneC.text.isEmpty) {
        Get.snackbar("Missing Info", "Name/Phone required");
        return;
      }
    } else if (selectedDebtor.value == null) {
      Get.snackbar("Missing Info", "Search and select a debtor");
      return;
    }

    isProcessing.value = true;
    final String invNo = _generateInvoiceID();

    // Captured Profit and Cost values for storage
    final double finalInvoiceCost = totalInvoiceCost;
    final double finalInvoiceProfit = invoiceProfit;

    try {
      // 1. Prepare Bulk Stock Update for API
      List<Map<String, dynamic>> updates =
          cart
              .map((item) => {'id': item.product.id, 'qty': item.quantity})
              .toList();

      // 2. Execute Bulk Stock Deduction via Product Controller
      bool stockSuccess = await productCtrl.updateStockBulk(updates);
      if (!stockSuccess) throw "Server inventory sync failed.";

      String fName = "";
      String fPhone = "";

      if (customerType.value == "Debtor") {
        fName = selectedDebtor.value!.name;
        fPhone = selectedDebtor.value!.phone;

        // Update Debtor Transaction
        await debtorCtrl.addTransaction(
          debtorId: selectedDebtor.value!.id,
          amount: grandTotal,
          note: "POS Invoice: $invNo",
          type: "credit",
          date: DateTime.now(),
        );

        // NEW: Store Profit/Loss in new 'debtorProfitLoss' collection
        await _db.collection('debtorProfitLoss').doc(invNo).set({
          "invoiceId": invNo,
          "debtorId": selectedDebtor.value!.id,
          "debtorName": fName,
          "debtorPhone": fPhone,
          "saleAmount": grandTotal,
          "costAmount": finalInvoiceCost,
          "profit": finalInvoiceProfit,
          "discount": discountVal.value,
          "timestamp": FieldValue.serverTimestamp(),
          "date": DateFormat('dd-MM-yyyy').format(DateTime.now()),
        });
      } else {
        fName = nameC.text;
        fPhone = phoneC.text;

        // Save Sale to Daily Records
        await dailyCtrl.addSale(
          name: "$fName (${shopC.text})",
          amount: grandTotal,
          customerType: customerType.value.toLowerCase(),
          isPaid: true,
          date: DateTime.now(),
          paymentMethod: {"type": paymentMethod.value.toLowerCase()},
          transactionId: invNo,
        );

        // NEW: Update Customer Record with Order history and Profit/Loss
        await _db.collection('customers').doc(fPhone).set({
          "name": fName,
          "phone": fPhone,
          "shop": shopC.text,
          "type": customerType.value,
          "lastInv": invNo,
          "lastOrder": DateTime.now(),
        }, SetOptions(merge: true));

        // Save individual order details with profit in customer sub-collection
        await _db
            .collection('customers')
            .doc(fPhone)
            .collection('orders')
            .doc(invNo)
            .set({
              "invoiceId": invNo,
              "totalAmount": grandTotal,
              "costAmount": finalInvoiceCost,
              "profit": finalInvoiceProfit,
              "discount": discountVal.value,
              "timestamp": FieldValue.serverTimestamp(),
              "items":
                  cart
                      .map(
                        (e) => {
                          "name": e.product.name,
                          "qty": e.quantity,
                          "salePrice": e.priceAtSale,
                          "buyPrice": e.product.avgPurchasePrice,
                        },
                      )
                      .toList(),
            });
      }

      // 3. Trigger Professional A3 PDF Invoice
      await _generateA3Invoice(invNo, fName, fPhone);

      _resetAll();
      Get.snackbar(
        "Success",
        "Stock Deducted and Profit Recorded",
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
    bankNameC.clear();
    discountC.clear();
    discountVal.value = 0.0;
    debtorPhoneSearch.clear();
    selectedDebtor.value = null;
  }

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
                          fontSize: 26,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Dhaka, Bangladesh | Phone: +880 1700-000000",
                        style: const pw.TextStyle(fontSize: 12),
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
                          fontSize: 30,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "Invoice ID: $id",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.Text(
                        "Date: $date",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "BILL TO:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          "Customer: $name",
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "Mobile: $phone",
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          "Shop: ${shopC.text}",
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "PAYMENT SUMMARY:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          "Method: ${paymentMethod.value}",
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellAlignment: pw.Alignment.center,
                data: [
                  ['SL', 'Item & Model', 'Rate (BDT)', 'Qty', 'Total'],
                  ...cart.asMap().entries.map(
                    (entry) => [
                      (entry.key + 1).toString(),
                      "${entry.value.product.name} (${entry.value.product.model})",
                      entry.value.priceAtSale.toStringAsFixed(2),
                      entry.value.quantity.toDouble().toStringAsFixed(2),
                      entry.value.subtotal.toStringAsFixed(2),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Spacer(flex: 3),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      children: [
                        _pdfRow("SUBTOTAL", subtotalAmount),
                        _pdfRow(
                          "DISCOUNT",
                          discountVal.value,
                          isNegative: true,
                        ),
                        pw.Divider(),
                        _pdfRow("GRAND TOTAL", grandTotal, isBold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  "This is an electronically generated invoice.",
                  style: const pw.TextStyle(fontSize: 10),
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

  pw.Widget _pdfRow(
    String label,
    double val, {
    bool isBold = false,
    bool isNegative = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isBold ? 14 : 12,
            ),
          ),
          pw.Text(
            "${isNegative ? '- ' : ''}Tk ${val.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isBold ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
