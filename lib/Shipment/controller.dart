// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'shipmodel.dart'; // Your provided ProductController


class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE ---
  final RxList<ShipmentModel> shipments = <ShipmentModel>[].obs;
  final RxBool isLoading = false.obs;

  // --- DIALOG INPUTS ---
  final Rxn<Product> selectedProduct = Rxn<Product>();
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController seaCtrl = TextEditingController(text: '0');
  final TextEditingController airCtrl = TextEditingController(text: '0');
  final Rx<DateTime> shipmentDateInput = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    bindFirestoreStream();
  }

  // 1. SYNC WITH FIRESTORE
  void bindFirestoreStream() {
    _firestore
        .collection('shipments')
        .orderBy('createdDate', descending: true)
        .snapshots()
        .listen((event) {
          shipments.value =
              event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
        });
  }

  // 2. SEARCH WRAPPER (Uses your Stock Logic)
  void onSearchChanged(String val) {
    productController.search(val);
  }

  // 3. CREATE SHIPMENT (Firestore Only)
  Future<void> createShipment() async {
    if (selectedProduct.value == null) {
      Get.snackbar("Error", "Please select a product");
      return;
    }

    int sea = int.tryParse(seaCtrl.text) ?? 0;
    int air = int.tryParse(airCtrl.text) ?? 0;

    if (sea == 0 && air == 0) {
      Get.snackbar("Error", "Enter at least one quantity (Sea or Air)");
      return;
    }

    final newShipment = ShipmentModel(
      productId: selectedProduct.value!.id,
      productName: selectedProduct.value!.name,
      productModel: selectedProduct.value!.model,
      productBrand: selectedProduct.value!.brand,
      seaQty: sea,
      airQty: air,
      createdDate: shipmentDateInput.value, // User selected "Shipment Date"
      isReceived: false,
    );

    try {
      await _firestore.collection('shipments').add(newShipment.toMap());
      Get.back(); // Close Dialog
      resetInputs();
      Get.snackbar(
        "Success",
        "Shipment Added to Manifest",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Firestore Error: $e");
    }
  }

  // 4. RECEIVE ITEM (Stock Entry + Full Product Update)
  Future<void> receiveShipment(ShipmentModel item) async {
    if (item.isReceived) return;
    isLoading.value = true;

    try {
      // STEP A: Add Stock (Calculates WAC & updates inventory on Server)
      // Note: addMixedStock calls fetchProducts() on success
      await productController.addMixedStock(
        productId: item.productId,
        seaQty: item.seaQty,
        airQty: item.airQty,
        localQty: 0,
      );

      // STEP B: Get the FRESH product data
      // We need the new stock quantities that the server just calculated
      // so we don't overwrite them in Step C.
      Product? updatedProduct = productController.allProducts.firstWhereOrNull(
        (p) => p.id == item.productId,
      );

      if (updatedProduct == null) {
        throw "Product not found locally after update";
      }

      // STEP C: Perform FULL UPDATE to set Shipment Date
      // Your server requires all fields. We use the FRESH product data.
      final DateTime now = DateTime.now(); // Arrival Date

      final Map<String, dynamic> fullUpdateBody = {
        'id': updatedProduct.id,
        'name': updatedProduct.name,
        'category': updatedProduct.category,
        'brand': updatedProduct.brand,
        'model': updatedProduct.model,
        'weight': updatedProduct.weight,
        'yuan': updatedProduct.yuan,
        'air': updatedProduct.air,
        'sea': updatedProduct.sea,
        'agent': updatedProduct.agent,
        'wholesale': updatedProduct.wholesale,
        'shipmenttax': updatedProduct.shipmentTax,
        'shipmenttaxair': updatedProduct.shipmentTaxAir,
        'shipmentno': updatedProduct.shipmentNo,
        'currency': updatedProduct.currency,

        // STOCK FIELDS (Send what we just got from server to maintain consistency)
        'stock_qty': updatedProduct.stockQty,
        'avg_purchase_price': updatedProduct.avgPurchasePrice,
        'sea_stock_qty': updatedProduct.seaStockQty,
        'air_stock_qty': updatedProduct.airStockQty,
        'local_qty': updatedProduct.localQty,

        // THE UPDATE: Set Shipment Date to NOW (Date of Entry)
        'shipmentdate': now.toIso8601String(),
      };

      await productController.updateProduct(item.productId, fullUpdateBody);

      // STEP D: Update Firestore
      await _firestore.collection('shipments').doc(item.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(now),
      });

      Get.snackbar(
        "Success",
        "Stock Received & Date Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to receive: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // 5. GENERATE PDF
  Future<void> generatePdf() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final tableData =
        shipments
            .map(
              (e) => [
                e.productName,
                "${e.productModel}\n${e.productBrand}",
                e.seaQty > 0 ? "${e.seaQty}" : "-",
                e.airQty > 0 ? "${e.airQty}" : "-",
                DateFormat('yyyy-MM-dd').format(e.createdDate), // Shipment Date
                e.arrivalDate != null
                    ? DateFormat('yyyy-MM-dd').format(e.arrivalDate!)
                    : "Pending",
              ],
            )
            .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "ONGOING SHIPMENTS",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headers: [
                  'Product',
                  'Details',
                  'Sea',
                  'Air',
                  'Ship Date',
                  'Arrival Date',
                ],
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  void resetInputs() {
    searchCtrl.clear();
    seaCtrl.text = '0';
    airCtrl.text = '0';
    selectedProduct.value = null;
    shipmentDateInput.value = DateTime.now();
    // Reset product search list
    productController.search('');
  }
}
