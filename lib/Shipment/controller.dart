// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // This variable now controls the Spinner on the button
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

  // --- FORMATTER HELPER ---
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  String formatMoney(double amount) {
    return "BDT ${_currencyFormatter.format(amount)}";
  }

  // --- DASHBOARD TOTALS ---
  double get totalOnWayValue => shipments
      .where((s) => !s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get totalCompletedValue => shipments
      .where((s) => s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);

  double get currentManifestTotalCost =>
      currentManifestItems.fold(0.0, (sumv, item) => sumv + item.totalItemCost);

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
    _shipmentSubscription?.cancel();
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
        .listen((event) {
          shipments.value =
              event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
        }, onError: (e) {});
  }

  void onSearchChanged(String val) => productController.search(val);

  // --- ADD TO MANIFEST ---
  Future<void> addToManifestAndVerify({
    required Product product,
    required Map<String, dynamic> updates,
    required int seaQty,
    required int airQty,
    required String cartonNo,
  }) async {
    isLoading.value = true;
    try {
      // Helper to safely get new value or fallback to existing product value
      dynamic safeGet(String key, dynamic fallback) => updates[key] ?? fallback;

      final Map<String, dynamic> fullBody = {
        'id': product.id,
        'name': safeGet('name', product.name),
        'category':
            product
                .category, // Assuming category doesn't change here, or add safeGet if it does
        'brand': product.brand,
        'model': product.model,
        'weight': safeGet('weight', product.weight),
        'yuan': safeGet('yuan', product.yuan),
        'currency': safeGet('currency', product.currency),
        'sea': safeGet('sea', product.sea),
        'air': safeGet('air', product.air),
        'shipmenttax': safeGet('shipmenttax', product.shipmentTax),
        'shipmenttaxair': safeGet('shipmenttaxair', product.shipmentTaxAir),

        // --- UPDATED LINES START ---
        'agent': safeGet('agent', product.agent), // Now updates Agent Price
        'wholesale': safeGet(
          'wholesale',
          product.wholesale,
        ), // Now updates Wholesale Price

        // --- UPDATED LINES END ---
        'shipmentno': product.shipmentNo,
        'shipmentdate':
            product.shipmentDate != null
                ? DateFormat('yyyy-MM-dd').format(product.shipmentDate!)
                : null,
        // Preserve existing stock data
        'stock_qty': product.stockQty,
        'avg_purchase_price': product.avgPurchasePrice,
        'sea_stock_qty': product.seaStockQty,
        'air_stock_qty': product.airStockQty,
        'local_qty': product.localQty,
      };

      // 1. Update Product details on Server
      await productController.updateProduct(product.id, fullBody);

      // 2. Add to Local Manifest List
      final item = ShipmentItem(
        productId: product.id,
        productName: fullBody['name'],
        productModel: product.model,
        productBrand: product.brand,
        productCategory: product.category,
        unitWeightSnapshot: (fullBody['weight'] as num).toDouble(),
        seaQty: seaQty,
        airQty: airQty,
        cartonNo: cartonNo,
        // Use the updated prices for the manifest snapshot
        seaPriceSnapshot: (fullBody['sea'] as num).toDouble(),
        airPriceSnapshot: (fullBody['air'] as num).toDouble(),
      );

      currentManifestItems.add(item);
      Get.back(); // Close Dialog
      Get.snackbar("Success", "Product Updated & Added to Manifest");
    } catch (e) {
      Get.snackbar("Error", "Update Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void removeFromManifest(int index) => currentManifestItems.removeAt(index);

  // --- SAVE MANIFEST ---
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

  // --- RECEIVE SHIPMENT (No Dialog, using isLoading) ---
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate, {
    String? selectedVendorId,
  }) async {
    // 1. Start Loading - Controls the UI button spinner
    isLoading.value = true;

    // Optional: Notify user operation started
    Get.snackbar(
      "Processing",
      "Updating stocks...",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue[100],
      duration: const Duration(seconds: 1),
    );

    try {
      // --- AUTH CHECK ---
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw "AUTH ERROR: Not logged in. Check API Key Domain restrictions.";
      }

      if (shipment.docId == null || shipment.docId!.isEmpty) {
        throw "DATA ERROR: Shipment ID is missing.";
      }

      final String dateString = DateFormat('yyyy-MM-dd').format(arrivalDate);

      // --- API CALL ---
      List<Map<String, dynamic>> bulkItems =
          shipment.items.map((item) {
            return {
              'id': item.productId,
              'sea_qty': item.seaQty,
              'air_qty': item.airQty,
              'local_qty': 0,
              'local_price': 0.0,
              'shipmentdate': dateString,
            };
          }).toList();

      bool success = await productController.addBulkStockWithValuation(
        bulkItems,
      );
      if (!success) throw "Server rejected bulk update";

      // --- FIRESTORE UPDATE (Timestamp Fix Included) ---
      final Map<String, dynamic> updateData = {
        'isReceived': true,
        // CRITICAL: Convert DateTime to Timestamp for Web
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorId': selectedVendorId,
      };

      await _firestore
          .collection('shipments')
          .doc(shipment.docId)
          .update(updateData);

      // --- VENDOR CREDIT ---
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        try {
          await vendorController.addAutomatedShipmentCredit(
            vendorId: selectedVendorId,
            amount: shipment.totalAmount,
            shipmentName: shipment.shipmentName,
            date: arrivalDate,
          );
        } catch (e) {
          debugPrint("Vendor credit error: $e");
        }
      }

      Get.snackbar(
        "Success",
        "Shipment Received & Stock Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.defaultDialog(
        title: "Failed",
        middleText: "Error receiving shipment: $e",
        textConfirm: "OK",
        onConfirm: () => Get.back(),
      );
    } finally {
      // 2. Stop Loading - Button returns to normal (or hidden if received)
      isLoading.value = false;
      FocusManager.instance.primaryFocus?.unfocus();
    }
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
                formatMoney(e.totalItemCost),
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
                      "Total Value: ${formatMoney(shipment.totalAmount)}",
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
