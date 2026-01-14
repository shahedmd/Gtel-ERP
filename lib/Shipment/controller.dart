// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'shipmodel.dart';

class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE ---
  final RxList<ShipmentModel> shipments = <ShipmentModel>[].obs;
  final RxBool isLoading = false.obs;

  // --- MANIFEST INPUTS ---
  final RxList<ShipmentItem> currentManifestItems = <ShipmentItem>[].obs;
  final Rx<DateTime> shipmentDateInput = DateTime.now().obs;
  final TextEditingController totalCartonCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController totalWeightCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController shipmentNameCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();

  // --- DASHBOARD TOTALS ---
  double get totalOnWayValue => shipments
      .where((s) => !s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get totalCompletedValue => shipments
      .where((s) => s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get currentManifestTotalCost =>
      currentManifestItems.fold(0.0, (sumv, item) => sumv + item.totalItemCost);

  @override
  void onInit() {
    super.onInit();
    bindFirestoreStream();
  }

  void bindFirestoreStream() {
    _firestore
        .collection('shipments')
        .orderBy('createdDate', descending: true)
        .limit(50)
        .snapshots()
        .listen((event) {
          shipments.value =
              event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
        });
  }

  void onSearchChanged(String val) => productController.search(val);

  // --- 1. ADD TO MANIFEST ---
  Future<void> addToManifestAndVerify({
    required Product product,
    required Map<String, dynamic> updates,
    required int seaQty,
    required int airQty,
    required String cartonNo,
  }) async {
    isLoading.value = true;
    try {
      final Map<String, dynamic> fullBody = {
        'id': product.id,
        'name': updates['name'] ?? product.name,
        'category': product.category,
        'brand': product.brand,
        'model': product.model,
        'weight': updates['weight'] ?? product.weight,
        'yuan': updates['yuan'] ?? product.yuan,
        'currency': updates['currency'] ?? product.currency,
        'sea': updates['sea'] ?? product.sea,
        'air': updates['air'] ?? product.air,
        'shipmenttax': updates['shipmenttax'] ?? product.shipmentTax,
        'shipmenttaxair': updates['shipmenttaxair'] ?? product.shipmentTaxAir,
        'agent': product.agent,
        'wholesale': product.wholesale,
        'shipmentno': product.shipmentNo,
        'shipmentdate':
            product.shipmentDate != null
                ? DateFormat('yyyy-MM-dd').format(product.shipmentDate!)
                : null,
        // Send existing stock to preserve it during update
        'stock_qty': product.stockQty,
        'avg_purchase_price': product.avgPurchasePrice,
        'sea_stock_qty': product.seaStockQty,
        'air_stock_qty': product.airStockQty,
        'local_qty': product.localQty,
      };

      await productController.updateProduct(product.id, fullBody);

      final item = ShipmentItem(
        productId: product.id,
        productName: fullBody['name'],
        productModel: product.model,
        productBrand: product.brand,
        seaQty: seaQty,
        airQty: airQty,
        cartonNo: cartonNo,
        seaPriceSnapshot: (fullBody['sea'] as num).toDouble(),
        airPriceSnapshot: (fullBody['air'] as num).toDouble(),
      );

      currentManifestItems.add(item);
      Get.back();
      Get.snackbar("Success", "Product Updated & Added to Manifest");
    } catch (e) {
      Get.snackbar("Error", "Update Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void removeFromManifest(int index) => currentManifestItems.removeAt(index);

  // --- 2. SAVE MANIFEST ---
  Future<void> saveShipmentToFirestore() async {
    if (currentManifestItems.isEmpty) {
      Get.snackbar("Error", "No items to ship");
      return;
    }
    isLoading.value = true;
    try {
      final newShipment = ShipmentModel(
        shipmentName:
            shipmentNameCtrl.text.isEmpty
                ? "Shipment ${DateFormat('MM/dd').format(shipmentDateInput.value)}"
                : shipmentNameCtrl.text,
        createdDate: shipmentDateInput.value,
        totalCartons: int.tryParse(totalCartonCtrl.text) ?? 0,
        totalWeight: double.tryParse(totalWeightCtrl.text) ?? 0.0,
        totalAmount: currentManifestTotalCost,
        items: currentManifestItems.toList(),
        isReceived: false,
      );

      await _firestore.collection('shipments').add(newShipment.toMap());

      currentManifestItems.clear();
      shipmentNameCtrl.clear();
      totalCartonCtrl.text = '0';
      totalWeightCtrl.text = '0';
      searchCtrl.clear();
      Get.back();
      Get.snackbar("Success", "Shipment Created Successfully");
    } catch (e) {
      Get.snackbar("Error", "Save failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- 3. RECEIVE SHIPMENT (WITH MODERN LOADING) ---
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate,
  ) async {
    // 1. Show Modern Loading Dialog
    _showLoadingDialog(shipment.items.length);

    try {
      // 2. Execute Tasks (Parallel Processing)
      List<Future> tasks = [];
      for (var item in shipment.items) {
        tasks.add(_processReceiveItem(item, arrivalDate));
      }
      await Future.wait(tasks);

      // 3. Update Firestore Status
      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
      });

      // 4. Close Loading & Refresh
      if (Get.isDialogOpen ?? false) Get.back(); // Close loading

      productController.fetchProducts(); // Refresh UI

      Get.snackbar(
        "Complete",
        "Received ${shipment.items.length} items successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(); // Close loading on error
      Get.snackbar(
        "Error",
        "Receive Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // HELPER: MODERN LOADING DIALOG
  void _showLoadingDialog(int count) {
    Get.dialog(
      PopScope(
        canPop: false, // Prevent back button closing
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                    backgroundColor: Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Processing Stock Entry",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Updating $count items & prices...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false, // Prevent tapping outside
    );
  }

  // --- ITEM PROCESSOR (ORDER FLIPPED: Date -> Stock) ---
  Future<void> _processReceiveItem(
    ShipmentItem item,
    DateTime arrivalDate,
  ) async {
    // A. Get Snapshot
    Product? localP = productController.allProducts.firstWhereOrNull(
      (p) => p.id == item.productId,
    );

    if (localP != null) {
      // B. Update Date (Preserving Old Stock)
      final Map<String, dynamic> dateUpdateBody = {
        'id': localP.id,
        'name': localP.name,
        'category': localP.category,
        'brand': localP.brand,
        'model': localP.model,
        'weight': localP.weight,
        'yuan': localP.yuan,
        'currency': localP.currency,
        'sea': localP.sea,
        'air': localP.air,
        'shipmenttax': localP.shipmentTax,
        'shipmenttaxair': localP.shipmentTaxAir,
        'agent': localP.agent,
        'wholesale': localP.wholesale,
        'shipmentno': localP.shipmentNo,

        // UPDATE: Date
        'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),

        // SAFETY: Send OLD Stock so we don't zero it
        'stock_qty': localP.stockQty,
        'avg_purchase_price': localP.avgPurchasePrice,
        'sea_stock_qty': localP.seaStockQty,
        'air_stock_qty': localP.airStockQty,
        'local_qty': localP.localQty,
      };

      await productController.updateProduct(localP.id, dateUpdateBody);
    }

    // C. Add Stock (Server adds this to existing)
    await productController.addMixedStock(
      productId: item.productId,
      seaQty: item.seaQty,
      airQty: item.airQty,
      localQty: 0,
    );
  }

  // --- PDF GENERATION ---
  Future<void> generatePdf(ShipmentModel shipment) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final tableData =
        shipment.items
            .map(
              (e) => [
                e.productName,
                "${e.productModel}\n${e.cartonNo}",
                "${e.seaQty}",
                "${e.airQty}",
                e.totalItemCost.toStringAsFixed(0),
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "SHIPMENT MANIFEST",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text("Name: ${shipment.shipmentName}"),
                    pw.Text(
                      "Departed: ${DateFormat('yyyy-MM-dd').format(shipment.createdDate)}",
                    ),
                    if (shipment.arrivalDate != null)
                      pw.Text(
                        "Arrived: ${DateFormat('yyyy-MM-dd').format(shipment.arrivalDate!)}",
                      ),
                    pw.Text(
                      "Total Value: ${shipment.totalAmount.toStringAsFixed(0)}",
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headers: ['Item', 'Model/Ctn', 'Sea', 'Air', 'Cost'],
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}
