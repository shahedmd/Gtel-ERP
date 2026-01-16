// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
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
  final VendorController vendorController = Get.put(VendorController());

  // --- STATE ---
  final RxList<ShipmentModel> shipments = <ShipmentModel>[].obs;
  final RxBool isLoading = false.obs;
  StreamSubscription? _shipmentSubscription;

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

  // --- FORMATTER HELPER (BDT Prefix, No K/M abbreviations) ---
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  /// Formats double to "BDT 1,200,500.00"
  String formatMoney(double amount) {
    return "BDT ${_currencyFormatter.format(amount)}";
  }

  // --- DASHBOARD TOTALS (Raw values for logic) ---
  double get totalOnWayValue => shipments
      .where((s) => !s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get totalCompletedValue => shipments
      .where((s) => s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get currentManifestTotalCost =>
      currentManifestItems.fold(0.0, (sumv, item) => sumv + item.totalItemCost);

  // --- DASHBOARD TOTALS (Formatted Strings for UI) ---
  String get totalOnWayDisplay => formatMoney(totalOnWayValue);
  String get totalCompletedDisplay => formatMoney(totalCompletedValue);
  String get currentManifestTotalDisplay =>
      formatMoney(currentManifestTotalCost);

  @override
  void onInit() {
    super.onInit();
    bindFirestoreStream();
  }

  @override
  void onClose() {
    _shipmentSubscription?.cancel(); // Prevent memory leaks
    totalCartonCtrl.dispose();
    totalWeightCtrl.dispose();
    shipmentNameCtrl.dispose();
    searchCtrl.dispose();
    super.onClose();
  }

  void bindFirestoreStream() {
    _shipmentSubscription = _firestore
        .collection('shipments')
        .orderBy('createdDate', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (event) {
            shipments.value =
                event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
          },
          onError: (e) {
          },
        );
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
      // Safe parsing helper to avoid crashes
      dynamic safeGet(String key, dynamic fallback) => updates[key] ?? fallback;

      final Map<String, dynamic> fullBody = {
        'id': product.id,
        'name': safeGet('name', product.name),
        'category': product.category,
        'brand': product.brand,
        'model': product.model,
        'weight': safeGet('weight', product.weight),
        'yuan': safeGet('yuan', product.yuan),
        'currency': safeGet('currency', product.currency),
        'sea': safeGet('sea', product.sea),
        'air': safeGet('air', product.air),
        'shipmenttax': safeGet('shipmenttax', product.shipmentTax),
        'shipmenttaxair': safeGet('shipmenttaxair', product.shipmentTaxAir),
        'agent': product.agent,
        'wholesale': product.wholesale,
        'shipmentno': product.shipmentNo,
        'shipmentdate':
            product.shipmentDate != null
                ? DateFormat('yyyy-MM-dd').format(product.shipmentDate!)
                : null,
        // Preserve existing stock
        'stock_qty': product.stockQty,
        'avg_purchase_price': product.avgPurchasePrice,
        'sea_stock_qty': product.seaStockQty,
        'air_stock_qty': product.airStockQty,
        'local_qty': product.localQty,
      };

      // 1. Update Product details on Server
      await productController.updateProduct(product.id, fullBody);

      // Inside ShipmentController -> addToManifestAndVerify

      final item = ShipmentItem(
        productId: product.id,
        productName: fullBody['name'],
        productModel: product.model,
        productBrand: product.brand,
        // NEW FIELDS
        productCategory: product.category,
        unitWeightSnapshot: (fullBody['weight'] as num).toDouble(),
        // END NEW FIELDS
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

      // Reset UI
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

  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate, {
    String? selectedVendorId, // OPTIONAL: If null, no credit entry is made
  }) async {
    // 1. Show Blocking Dialog
    _showLoadingDialog(shipment.items.length);

    try {
      // 2. Process Items (Parallel)
      List<Future> tasks = [];
      for (var item in shipment.items) {
        tasks.add(_processReceiveItem(item, arrivalDate));
      }

      // 3. Process Vendor Credit (Parallel or Sequential)
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        // Add task to create credit entry
        tasks.add(
          vendorController.addAutomatedShipmentCredit(
            vendorId: selectedVendorId,
            amount: shipment.totalAmount, // Total shipment value
            shipmentName: shipment.shipmentName,
            date: arrivalDate,
          ),
        );
      }

      // Execute all tasks (Stock Update + Vendor Credit)
      await Future.wait(tasks);

      // 4. Update Firestore Shipment Status
      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorId': selectedVendorId, // Optional: store who supplied it
      });

      // 5. Force Close Loading
      Get.back();

      // 6. Refresh Data
      await productController.fetchProducts();

      Get.snackbar(
        "Complete",
        "Stock Received & Vendor Credited",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.back(); // Close loading on error
      Get.snackbar(
        "Error",
        "Process Failed: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // HELPER: MODERN LOADING DIALOG
  void _showLoadingDialog(int count) {
    Get.dialog(
      PopScope(
        canPop: false,
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
                  "Updating $count items & recalculating prices...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // --- ITEM PROCESSOR ---
  Future<void> _processReceiveItem(
    ShipmentItem item,
    DateTime arrivalDate,
  ) async {
    // Find the product in local state
    Product? localP = productController.allProducts.firstWhereOrNull(
      (p) => p.id == item.productId,
    );

    // If product exists in DB
    if (localP != null) {
      // Step A: Update the Last Shipment Date
      // We must send the whole object back to prevent overwriting other fields with null
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

        // THE CHANGE: Update Date
        'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),

        // CRITICAL: Send current stock so updateProduct doesn't reset it to 0
        'stock_qty': localP.stockQty,
        'avg_purchase_price': localP.avgPurchasePrice,
        'sea_stock_qty': localP.seaStockQty,
        'air_stock_qty': localP.airStockQty,
        'local_qty': localP.localQty,
      };

      await productController.updateProduct(localP.id, dateUpdateBody);
    }

    // Step B: Add the incoming stock
    // This calls the server endpoint that handles weighted average cost calculation
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

    // Using standard fonts to ensure compatibility
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
                formatMoney(e.totalItemCost), // Used formatter here for PDF too
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
                    pw.SizedBox(height: 5),
                    pw.Text("Name: ${shipment.shipmentName}"),
                    pw.Text(
                      "Departed: ${DateFormat('yyyy-MM-dd').format(shipment.createdDate)}",
                    ),
                    if (shipment.arrivalDate != null)
                      pw.Text(
                        "Arrived: ${DateFormat('yyyy-MM-dd').format(shipment.arrivalDate!)}",
                      ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "Total Value: ${formatMoney(shipment.totalAmount)}", // Formatted
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(0.5),
                  3: const pw.FlexColumnWidth(0.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
              ),
            ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Manifest_${shipment.shipmentName}.pdf',
    );
  }
}
