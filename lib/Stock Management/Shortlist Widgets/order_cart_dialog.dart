import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../Core/Core Utils/activity_logger.dart';
import '../stock_shorlist_and_china_order.dart';

void showOrderCartDialog({
  required BuildContext context,
  required OrderCartController cartCtrl,
}) {
  cartCtrl.companyName.value = '';
  cartCtrl.deliveryMethod.value = 'Sea';
  final bool isMobile = MediaQuery.of(context).size.width < 600;

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _OrderCartDialogContent(cartCtrl: cartCtrl, isMobile: isMobile),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Dialog Content
// ─────────────────────────────────────────────────────────────
class _OrderCartDialogContent extends StatelessWidget {
  final OrderCartController cartCtrl;
  final bool isMobile;

  const _OrderCartDialogContent({
    required this.cartCtrl,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 650,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shopping_cart, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Purchase Order Cart',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              ),
            ],
          ),
          const Divider(thickness: 1, height: 20),

          // Cart items list
          Expanded(
            child: Obx(() {
              if (cartCtrl.cartItems.isEmpty) {
                return const Center(
                  child: Text(
                    'Your cart is empty.\nAdd items from the shortlist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                );
              }
              return ListView.separated(
                itemCount: cartCtrl.cartItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder:
                    (context, i) => _CartItemRow(
                      item: cartCtrl.cartItems[i],
                      cartCtrl: cartCtrl,
                    ),
              );
            }),
          ),

          const Divider(thickness: 1, height: 24),

          // Company + delivery inputs
          isMobile
              ? Column(
                children: [
                  _CompanyInput(cartCtrl: cartCtrl),
                  const SizedBox(height: 12),
                  _DeliveryDropdown(cartCtrl: cartCtrl),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 2, child: _CompanyInput(cartCtrl: cartCtrl)),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _DeliveryDropdown(cartCtrl: cartCtrl),
                  ),
                ],
              ),

          const SizedBox(height: 20),

          // Generate PO button
          SizedBox(
            width: double.infinity,
            child: Obx(
              () => ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Generate PO & Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    cartCtrl.cartItems.isEmpty
                        ? null
                        : () => _generateOrderAndSave(cartCtrl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateOrderAndSave(OrderCartController cartCtrl) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final compName =
          cartCtrl.companyName.value.trim().isEmpty
              ? 'N/A'
              : cartCtrl.companyName.value.trim();
      final dlvry = cartCtrl.deliveryMethod.value;
      final items = cartCtrl.cartItems.toList();

      // Firestore-এ save করো
      await FirebaseFirestore.instance.collection('order_history').add({
        'date': FieldValue.serverTimestamp(),
        'company_name': compName,
        'delivery_method': dlvry,
        'status': 'Pending',
        'total_items': items.length,
        'items':
            items
                .map(
                  (e) => {
                    'product_id': e.product.id,
                    'model': e.product.model,
                    'name': e.product.name,
                    'order_qty': e.qty,
                  },
                )
                .toList(),
      });

      // PDF generate করো
      await OrderPdfGenerator.generate(items, compName, dlvry);

      // Activity log
      await ActivityLogger.log(
        action: 'CREATE_PURCHASE_ORDER',
        module: 'Stock',
        details:
            'PO created | Supplier: $compName | Delivery: $dlvry | Items: ${items.length}',
      );

      cartCtrl.clearCart();
      Get.back(); // loading বন্ধ
      Get.back(); // dialog বন্ধ

      Get.snackbar(
        'Success',
        'Purchase Order generated and saved!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to process order: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Cart Item Row — editable qty
// ─────────────────────────────────────────────────────────────
class _CartItemRow extends StatefulWidget {
  final OrderCartItem item;
  final OrderCartController cartCtrl;

  const _CartItemRow({required this.item, required this.cartCtrl});

  @override
  State<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<_CartItemRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.qty.toString() != _qtyCtrl.text) {
      _qtyCtrl.text = widget.item.qty.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _updateQty(int newQty) {
    if (newQty > 0) {
      widget.cartCtrl.updateQty(widget.item.product, newQty);
      _qtyCtrl.text = newQty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.product.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.item.product.name,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Qty controls
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _updateQty(widget.item.qty - 1),
              ),
              SizedBox(
                width: 60,
                height: 35,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final q = int.tryParse(val) ?? 0;
                    if (q > 0) {
                      widget.cartCtrl.updateQty(widget.item.product, q);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _updateQty(widget.item.qty + 1),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed:
                    () => widget.cartCtrl.removeFromCart(widget.item.product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Form inputs
// ─────────────────────────────────────────────────────────────
class _CompanyInput extends StatelessWidget {
  final OrderCartController cartCtrl;

  const _CompanyInput({required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (v) => cartCtrl.companyName.value = v,
      decoration: const InputDecoration(
        labelText: 'Company / Supplier Name',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }
}

class _DeliveryDropdown extends StatelessWidget {
  final OrderCartController cartCtrl;

  const _DeliveryDropdown({required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: cartCtrl.deliveryMethod.value,
        decoration: const InputDecoration(
          labelText: 'Delivery Via',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        items:
            [
              'Sea',
              'Air',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) {
          if (val != null) cartCtrl.deliveryMethod.value = val;
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF Generator
// ─────────────────────────────────────────────────────────────
class OrderPdfGenerator {
  static Future<void> generate(
    List<OrderCartItem> items,
    String company,
    String delivery,
  ) async {
    final pdf = pw.Document();
    double grandTotal = 0;

    for (final item in items) {
      final price =
          delivery.toLowerCase() == 'air' ? item.product.air : item.product.sea;
      grandTotal += price * item.qty;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PURCHASE ORDER',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Supplier info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Supplier: $company',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Delivery: $delivery',
                          style: const pw.TextStyle(
                            color: PdfColors.grey800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Status: PENDING',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                headers: [
                  'No.',
                  'Model',
                  'Product Name',
                  'Unit Price ($delivery)',
                  'Order Qty',
                  'Total',
                ],
                data: List.generate(items.length, (i) {
                  final item = items[i];
                  final unitPrice =
                      delivery.toLowerCase() == 'air'
                          ? item.product.air
                          : item.product.sea;
                  final total = unitPrice * item.qty;
                  return [
                    '${i + 1}',
                    item.product.model,
                    item.product.name,
                    '¥${unitPrice.toStringAsFixed(2)}',
                    '${item.qty}',
                    '¥${total.toStringAsFixed(2)}',
                  ];
                }),
              ),
              pw.SizedBox(height: 15),

              // Grand total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Total Items: ${items.length}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Grand Total: ¥${grandTotal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Prepared By',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Authorized Signature',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'PO_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }
}