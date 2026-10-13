import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'quotation_model.dart';

class QuotationCartItem {
  final Product product;
  final RxInt quantity;
  final RxDouble unitPrice;

  QuotationCartItem({
    required this.product,
    required int quantity,
    required double unitPrice,
  }) : quantity = quantity.obs,
       unitPrice = unitPrice.obs;

  double get subtotal => quantity.value * unitPrice.value;
}

class QuotationController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductController productCtrl = Get.find<ProductController>();

  final RxList<Quotation> quotations = <Quotation>[].obs;
  final RxList<QuotationCartItem> cart = <QuotationCartItem>[].obs;
  final RxList<Map<String, dynamic>> customerSuggestions =
      <Map<String, dynamic>>[].obs;
  final RxString customerType = 'WHOLESALE'.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString listSearch = ''.obs;
  final RxInt validityDays = 14.obs;

  final customerNameC = TextEditingController();
  final customerPhoneC = TextEditingController();
  final shopNameC = TextEditingController();
  final addressC = TextEditingController();
  final discountC = TextEditingController();
  final discountNoteC = TextEditingController();
  final noteC = TextEditingController();

  final RxnString editingQuotationId = RxnString();
  double discount = 0;
  Timer? _customerSearchDebounce;
  int _customerSearchRequestId = 0;

  double get subtotal =>
      _round(cart.fold(0, (total, item) => total + item.subtotal));
  double get grandTotal =>
      _round((subtotal - discount).clamp(0, double.infinity));

  List<Quotation> get filteredQuotations {
    final query = listSearch.value.trim().toLowerCase();
    if (query.isEmpty) return quotations;
    return quotations.where((quotation) {
      return quotation.quotationNo.toLowerCase().contains(query) ||
          quotation.customerName.toLowerCase().contains(query) ||
          quotation.customerPhone.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadQuotations();
  }

  @override
  void onClose() {
    _customerSearchDebounce?.cancel();
    customerNameC.dispose();
    customerPhoneC.dispose();
    shopNameC.dispose();
    addressC.dispose();
    discountC.dispose();
    discountNoteC.dispose();
    noteC.dispose();
    super.onClose();
  }

  Future<void> loadQuotations() async {
    isLoading.value = true;
    try {
      final snapshot =
          await _db
              .collection('quotations')
              .orderBy('createdAt', descending: true)
              .limit(200)
              .get();
      quotations.assignAll(
        snapshot.docs.map((doc) => Quotation.fromFirestore(doc.id, doc.data())),
      );
    } catch (error) {
      _showError('Could not load quotations: $error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteQuotation(Quotation quotation) async {
    try {
      await _db.collection('quotations').doc(quotation.id).delete();
      quotations.removeWhere((item) => item.id == quotation.id);
      Get.snackbar(
        'Deleted',
        'Quotation ${quotation.quotationNo} deleted.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (error) {
      _showError('Could not delete quotation: $error');
      return false;
    }
  }

  void startNewQuotation() {
    _customerSearchDebounce?.cancel();
    _customerSearchRequestId++;
    editingQuotationId.value = null;
    customerType.value = 'WHOLESALE';
    customerNameC.clear();
    customerPhoneC.clear();
    shopNameC.clear();
    addressC.clear();
    discountC.clear();
    discountNoteC.clear();
    noteC.clear();
    cart.clear();
    customerSuggestions.clear();
    discount = 0;
    validityDays.value = 14;
    productCtrl.search('');
  }

  void searchCustomers(String value) {
    _customerSearchDebounce?.cancel();
    final requestId = ++_customerSearchRequestId;
    final query = value.trim();
    if (query.length < 2) {
      customerSuggestions.clear();
      return;
    }
    _customerSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadCustomerSuggestions(query, requestId),
    );
  }

  Future<void> _loadCustomerSuggestions(String query, int requestId) async {
    final lower = query.toLowerCase();
    final capitalized =
        lower.isEmpty
            ? lower
            : '${lower[0].toUpperCase()}${lower.substring(1)}';
    try {
      final collections = ['customers', 'condition_customers', 'debatorbody'];
      final snapshots = await Future.wait(
        collections.expand(
          (collection) => [
            _db
                .collection(collection)
                .where('phone', isGreaterThanOrEqualTo: query)
                .where('phone', isLessThan: '$query\uf8ff')
                .limit(5)
                .get(),
            _db
                .collection(collection)
                .where('name', isGreaterThanOrEqualTo: lower)
                .where('name', isLessThan: '$lower\uf8ff')
                .limit(5)
                .get(),
            if (capitalized != lower)
              _db
                  .collection(collection)
                  .where('name', isGreaterThanOrEqualTo: capitalized)
                  .where('name', isLessThan: '$capitalized\uf8ff')
                  .limit(5)
                  .get(),
          ],
        ),
      );
      if (requestId != _customerSearchRequestId) return;

      final Map<String, Map<String, dynamic>> matches = {};
      for (
        var collectionIndex = 0;
        collectionIndex < collections.length;
        collectionIndex++
      ) {
        final collection = collections[collectionIndex];
        final queriesPerCollection = capitalized == lower ? 2 : 3;
        final start = collectionIndex * queriesPerCollection;
        for (
          var queryIndex = 0;
          queryIndex < queriesPerCollection;
          queryIndex++
        ) {
          for (final doc in snapshots[start + queryIndex].docs) {
            final data = doc.data();
            final type =
                collection == 'debatorbody'
                    ? 'AGENT'
                    : (collection == 'condition_customers'
                        ? 'CONDITION'
                        : (data['type']?.toString() ?? 'WHOLESALE'));
            final customer = <String, dynamic>{
              'id': doc.id,
              'name': data['name']?.toString() ?? '',
              'phone': data['phone']?.toString() ?? '',
              'shop': data['shop']?.toString() ?? data['des']?.toString() ?? '',
              'address': data['address']?.toString() ?? '',
              'customerType': type,
            };
            matches['$collection:${doc.id}'] = customer;
          }
        }
      }
      customerSuggestions.assignAll(matches.values.take(12));
    } catch (error) {
      if (requestId == _customerSearchRequestId) {
        customerSuggestions.clear();
        _showError('Could not search customers: $error');
      }
    }
  }

  void selectCustomerSuggestion(Map<String, dynamic> customer) {
    customerNameC.text = customer['name']?.toString() ?? '';
    customerPhoneC.text = customer['phone']?.toString() ?? '';
    shopNameC.text = customer['shop']?.toString() ?? '';
    addressC.text = customer['address']?.toString() ?? '';
    final type = (customer['customerType']?.toString() ?? '').toUpperCase();
    if (const ['WHOLESALE', 'VIP', 'AGENT'].contains(type)) {
      selectCustomerType(type);
    }
    customerSuggestions.clear();
  }

  void selectCustomerType(String type) {
    if (!const ['WHOLESALE', 'VIP', 'AGENT'].contains(type)) return;
    customerType.value = type;
    for (final item in cart) {
      item.unitPrice.value =
          type == 'AGENT' ? item.product.agent : item.product.wholesale;
    }
    cart.refresh();
  }

  void editQuotation(Quotation quotation) {
    _customerSearchDebounce?.cancel();
    _customerSearchRequestId++;
    customerSuggestions.clear();
    editingQuotationId.value = quotation.id;
    customerType.value = quotation.customerType;
    customerNameC.text = quotation.customerName;
    customerPhoneC.text = quotation.customerPhone;
    shopNameC.text = quotation.shopName;
    addressC.text = quotation.address;
    discount = quotation.discount;
    discountC.text = quotation.discount.toStringAsFixed(2);
    discountNoteC.text = quotation.discountNote;
    noteC.text = quotation.note;
    validityDays.value = quotation.validityDays;
    cart.assignAll(
      quotation.items.map((item) {
        final currentProduct = productCtrl.allProducts.firstWhereOrNull(
          (product) => product.id == item.productId,
        );
        final product =
            currentProduct ??
            Product.fromJson(Map<String, dynamic>.from(item.productSnapshot));
        return QuotationCartItem(
          product: product,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
        );
      }),
    );
  }

  void addProduct(Product product) {
    final existing = cart.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existing != null) {
      existing.quantity.value++;
      cart.refresh();
      return;
    }
    cart.insert(
      0,
      QuotationCartItem(
        product: product,
        quantity: 1,
        unitPrice:
            customerType.value == 'AGENT' ? product.agent : product.wholesale,
      ),
    );
  }

  void updateQuantity(QuotationCartItem item, String value) {
    final quantity = int.tryParse(value);
    if (quantity == null || quantity < 1) return;
    item.quantity.value = quantity;
    cart.refresh();
  }

  void updatePrice(QuotationCartItem item, String value) {
    final price = double.tryParse(value);
    if (price == null || price < 0) return;
    item.unitPrice.value = price;
    cart.refresh();
  }

  void removeItem(QuotationCartItem item) => cart.remove(item);

  void updateDiscount(String value) {
    discount = double.tryParse(value) ?? 0;
    if (discount < 0) discount = 0;
    cart.refresh();
  }

  Future<Quotation?> saveQuotation() async {
    if (customerNameC.text.trim().isEmpty ||
        customerPhoneC.text.trim().isEmpty) {
      _showError('Customer name and phone are required.');
      return null;
    }
    if (cart.isEmpty) {
      _showError('Add at least one product to the quotation.');
      return null;
    }

    isSaving.value = true;
    try {
      final now = DateTime.now();
      final document =
          editingQuotationId.value == null
              ? _db.collection('quotations').doc()
              : _db.collection('quotations').doc(editingQuotationId.value);
      final existingQuotation = quotations.firstWhereOrNull(
        (item) => item.id == editingQuotationId.value,
      );
      final quotationNo =
          editingQuotationId.value == null
              ? 'QT-${DateFormat('yyMMdd').format(now)}-${document.id.substring(0, 6).toUpperCase()}'
              : existingQuotation?.quotationNo ?? document.id;

      final quotation = Quotation(
        id: document.id,
        quotationNo: quotationNo,
        customerName: customerNameC.text.trim(),
        customerPhone: customerPhoneC.text.trim(),
        customerType: customerType.value,
        shopName: shopNameC.text.trim(),
        address: addressC.text.trim(),
        items:
            cart
                .map(
                  (item) => QuotationItem(
                    productId: item.product.id,
                    name: item.product.name,
                    model: item.product.model,
                    brand: item.product.brand,
                    quantity: item.quantity.value,
                    unitPrice: item.unitPrice.value,
                    productSnapshot: item.product.toJson(),
                  ),
                )
                .toList(),
        discount: discount,
        discountNote: discountNoteC.text.trim(),
        note: noteC.text.trim(),
        validityDays: validityDays.value,
        createdAt:
            editingQuotationId.value == null
                ? now
                : existingQuotation?.createdAt ?? now,
        createdBy:
            existingQuotation?.createdBy ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Admin',
      );

      await document.set(quotation.toFirestore());
      final existingIndex = quotations.indexWhere(
        (item) => item.id == quotation.id,
      );
      if (existingIndex == -1) {
        quotations.insert(0, quotation);
      } else {
        quotations[existingIndex] = quotation;
        quotations.refresh();
      }
      editingQuotationId.value = quotation.id;
      return quotation;
    } catch (error) {
      _showError('Could not save quotation: $error');
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<Uint8List> buildPdf(Quotation quotation) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer:
            (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Quotation only - not a tax invoice or proof of sale',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ],
            ),
        build:
            (context) => [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'G TEL',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 26,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '6/24A (6th Floor), Gulistan Shopping Complex (Hall Market)\n2 Bangabandhu Avenue, Dhaka 1000\nCell: 01720677206, 01911026222',
                        style: pw.TextStyle(font: regularFont, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfo(
                          'Quotation No.',
                          quotation.quotationNo,
                          regularFont,
                          boldFont,
                        ),
                        _pdfInfo(
                          'Date',
                          quotation.formattedDate,
                          regularFont,
                          boldFont,
                        ),
                        _pdfInfo(
                          'Valid Until',
                          DateFormat('dd/MM/yyyy').format(quotation.validUntil),
                          regularFont,
                          boldFont,
                        ),
                        _pdfInfo(
                          'Customer Type',
                          quotation.customerType,
                          regularFont,
                          boldFont,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'QUOTATION',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: PdfColors.blue900,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfo(
                      'Customer',
                      quotation.customerName,
                      regularFont,
                      boldFont,
                    ),
                    _pdfInfo(
                      'Phone',
                      quotation.customerPhone,
                      regularFont,
                      boldFont,
                    ),
                    if (quotation.shopName.isNotEmpty)
                      _pdfInfo(
                        'Shop',
                        quotation.shopName,
                        regularFont,
                        boldFont,
                      ),
                    if (quotation.address.isNotEmpty)
                      _pdfInfo(
                        'Address',
                        quotation.address,
                        regularFont,
                        boldFont,
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey600,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(32),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FixedColumnWidth(48),
                  3: const pw.FixedColumnWidth(78),
                  4: const pw.FixedColumnWidth(86),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _pdfCell('SL', boldFont, align: pw.TextAlign.center),
                      _pdfCell('Product Description', boldFont),
                      _pdfCell('Qty', boldFont, align: pw.TextAlign.center),
                      _pdfCell(
                        'Unit Price',
                        boldFont,
                        align: pw.TextAlign.right,
                      ),
                      _pdfCell('Amount', boldFont, align: pw.TextAlign.right),
                    ],
                  ),
                  ...List.generate(quotation.items.length, (index) {
                    final item = quotation.items[index];
                    return pw.TableRow(
                      children: [
                        _pdfCell(
                          '${index + 1}',
                          regularFont,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          '${item.name}${item.model.isEmpty ? '' : ' - ${item.model}'}',
                          regularFont,
                        ),
                        _pdfCell(
                          '${item.quantity}',
                          regularFont,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          item.unitPrice.toStringAsFixed(2),
                          regularFont,
                          align: pw.TextAlign.right,
                        ),
                        _pdfCell(
                          item.subtotal.toStringAsFixed(2),
                          regularFont,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _pdfSummaryRow(
                        'Subtotal',
                        quotation.subtotal,
                        regularFont,
                        boldFont,
                      ),
                      _pdfSummaryRow(
                        quotation.discountNote.isEmpty
                            ? 'Discount'
                            : 'Discount (${quotation.discountNote})',
                        -quotation.discount,
                        regularFont,
                        regularFont,
                      ),
                      pw.Divider(),
                      _pdfSummaryRow(
                        'Quoted Total',
                        quotation.grandTotal,
                        boldFont,
                        boldFont,
                      ),
                    ],
                  ),
                ),
              ),
              if (quotation.note.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Note: ${quotation.note}',
                  style: pw.TextStyle(font: regularFont, fontSize: 10),
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber700),
                ),
                child: pw.Text(
                  'This quotation is valid for ${quotation.validityDays} days. Prices and availability may change after the validity period. This document is an offer only; it is not an invoice, sale record, or confirmation of stock reservation.',
                  style: pw.TextStyle(font: regularFont, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 44),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 150,
                      height: 0.5,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Authorized Signature',
                      style: pw.TextStyle(font: regularFont, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
      ),
    );
    return pdf.save();
  }

  Future<void> printQuotation(Quotation quotation) async {
    try {
      final bytes = await buildPdf(quotation);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${quotation.quotationNo}.pdf',
      );
    } catch (error) {
      _showError('Could not print quotation: $error');
    }
  }

  Future<void> downloadQuotation(Quotation quotation) async {
    try {
      final bytes = await buildPdf(quotation);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${quotation.quotationNo}.pdf',
      );
    } catch (error) {
      _showError('Could not export quotation PDF: $error');
    }
  }

  pw.Widget _pdfInfo(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: regular, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _pdfSummaryRow(
    String label,
    double amount,
    pw.Font labelFont,
    pw.Font amountFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(font: labelFont, fontSize: 9),
            ),
          ),
          pw.Text(
            amount.toStringAsFixed(2),
            style: pw.TextStyle(font: amountFont, fontSize: 9),
          ),
        ],
      ),
    );
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  void _showError(String message) {
    Get.snackbar(
      'Quotation error',
      message,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
