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

// =========================================================
// 1. HELPER CLASSES FOR AGGREGATION (NEW)
// =========================================================
class IncomingDetail {
  final String shipmentName;
  final DateTime date;
  final int qty;

  IncomingDetail({
    required this.shipmentName,
    required this.date,
    required this.qty,
  });
}

class AggregatedOnWayProduct {
  final int productId;
  final String model;
  final String name;
  final List<IncomingDetail> incomingDetails;

  AggregatedOnWayProduct({
    required this.productId,
    required this.model,
    required this.name,
    required this.incomingDetails,
  });

  // Calculate total across all shipments for this product
  int get totalQty => incomingDetails.fold(0, (sumv, item) => sumv + item.qty);
}

// =========================================================
// 2. MAIN CONTROLLER
// =========================================================

class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VendorController vendorController = Get.put(VendorController());

  // --- STATE ---
  final RxList<ShipmentModel> shipments = <ShipmentModel>[].obs;

  // NEW: LIST FOR THE UI (Product Centric)
  final RxList<AggregatedOnWayProduct> aggregatedList =
      <AggregatedOnWayProduct>[].obs;

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

  String formatMoney(double amount) =>
      "BDT ${_currencyFormatter.format(amount)}";

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

  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

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

  void onSearchChanged(String val) => productController.search(val);

  // ==========================================
  // FIRESTORE LISTENER & AGGREGATION LOGIC
  // ==========================================
  void bindFirestoreStream() {
    _shipmentSubscription = _firestore
        .collection('shipments')
        .orderBy('createdDate', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (event) {
            // 1. Parse Shipments (Existing logic)
            final loadedShipments =
                event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
            shipments.value = loadedShipments;

            // 2. Calculate On Way Totals (Existing logic for Shortlist)
            _calculateOnWayTotals(loadedShipments);

            // 3. NEW: AGGREGATE DATA (For OnGoingShipmentsPage)
            _aggregateOnWayData(loadedShipments);
          },
          onError: (e) {
            print("Firestore Error: $e");
          },
        );
  }

  // Existing helper for ShortlistPage badges
  void _calculateOnWayTotals(List<ShipmentModel> list) {
    final Map<int, int> tempMap = {};
    for (var shipment in list) {
      if (!shipment.isReceived) {
        for (var item in shipment.items) {
          int totalQty = item.seaQty + item.airQty;
          if (tempMap.containsKey(item.productId)) {
            tempMap[item.productId] = tempMap[item.productId]! + totalQty;
          } else {
            tempMap[item.productId] = totalQty;
          }
        }
      }
    }
    onWayStockMap.assignAll(tempMap);
  }

  // NEW: Aggregation Logic (Product Centric)
  void _aggregateOnWayData(List<ShipmentModel> allShipments) {
    Map<int, AggregatedOnWayProduct> tempMap = {};

    for (var shipment in allShipments) {
      if (shipment.isReceived) continue; // Skip received shipments

      for (var item in shipment.items) {
        int qty = item.seaQty + item.airQty;
        if (qty <= 0) continue;

        // Create a detail object for this specific shipment
        final detail = IncomingDetail(
          shipmentName: shipment.shipmentName,
          date: shipment.createdDate,
          qty: qty,
        );

        // If product already exists in map, add detail to it
        if (tempMap.containsKey(item.productId)) {
          tempMap[item.productId]!.incomingDetails.add(detail);
        } else {
          // New product found
          tempMap[item.productId] = AggregatedOnWayProduct(
            productId: item.productId,
            model: item.productModel,
            name: item.productName,
            incomingDetails: [detail],
          );
        }
      }
    }

    // Sort details inside each product by date (oldest shipment first)
    for (var p in tempMap.values) {
      p.incomingDetails.sort((a, b) => a.date.compareTo(b.date));
    }

    // Update UI list
    aggregatedList.assignAll(tempMap.values.toList());
  }

  int getOnWayQty(int productId) {
    return onWayStockMap[productId] ?? 0;
  }

  // ==========================================
  // 1. ADD TO MANIFEST (AND UPDATE PRODUCT MASTER)
  // ==========================================
  Future<void> addToManifestAndVerify({
    required Product product,
    required Map<String, dynamic> updates,
    required int seaQty,
    required int airQty,
    required String cartonNo,
  }) async {
    isLoading.value = true;
    try {
      // Helper: Prefer new value from 'updates', fallback to 'product'
      dynamic val(String key, dynamic current) => updates[key] ?? current;

      final Map<String, dynamic> serverBody = {
        'name': val('name', product.name),
        'category': product.category,
        'brand': product.brand,
        'model': product.model,
        'weight': (val('weight', product.weight) as num).toDouble(),
        'yuan': (val('yuan', product.yuan) as num).toDouble(),
        'currency': (val('currency', product.currency) as num).toDouble(),
        'sea': (val('sea', product.sea) as num).toDouble(),
        'air': (val('air', product.air) as num).toDouble(),
        'agent': (val('agent', product.agent) as num).toDouble(),
        'wholesale': (val('wholesale', product.wholesale) as num).toDouble(),
        'shipmenttax':
            (val('shipmenttax', product.shipmentTax) as num).toDouble(),
        'shipmenttaxair':
            (val('shipmenttaxair', product.shipmentTaxAir) as num).toDouble(),
        'shipmentno': int.tryParse(product.shipmentNo.toString()) ?? 0,
        'shipmentdate': product.shipmentDate?.toIso8601String(),
        'stock_qty': product.stockQty,
        'avg_purchase_price': product.avgPurchasePrice,
        'sea_stock_qty': product.seaStockQty,
        'air_stock_qty': product.airStockQty,
        'local_qty': product.localQty,
        'alert_qty': product.alertQty,
      };

      await productController.updateProduct(product.id, serverBody);

      final item = ShipmentItem(
        productId: product.id,
        productName: serverBody['name'],
        productModel: product.model,
        productBrand: product.brand,
        productCategory: product.category,
        unitWeightSnapshot: (serverBody['weight'] as num).toDouble(),
        seaQty: seaQty,
        airQty: airQty,
        cartonNo: cartonNo,
        seaPriceSnapshot: (serverBody['sea'] as num).toDouble(),
        airPriceSnapshot: (serverBody['air'] as num).toDouble(),
      );

      currentManifestItems.add(item);
      Get.back();
      Get.snackbar("Success", "Product Details Updated & Added to Manifest");
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update product: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void removeFromManifest(int index) => currentManifestItems.removeAt(index);

  // ==========================================
  // 2. SAVE MANIFEST TO FIRESTORE
  // ==========================================
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
      Get.snackbar("Success", "Shipment Manifest Created");
    } catch (e) {
      Get.snackbar("Error", "Save failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 3. RECEIVE SHIPMENT (BULK STOCK ADD)
  // ==========================================
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate, {
    String? selectedVendorId,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Authentication Error: Please login.";
      if (shipment.docId == null || shipment.docId!.isEmpty) {
        throw "Invalid Shipment ID.";
      }

      List<Map<String, dynamic>> bulkItems =
          shipment.items.map((item) {
            return {
              'id': item.productId,
              'sea_qty': item.seaQty,
              'air_qty': item.airQty,
              'local_qty': 0,
              'local_price': 0.0,
              'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),
            };
          }).toList();

      bool success = await productController.bulkAddStockMixed(bulkItems);

      if (!success) {
        throw "Server failed to process bulk stock update.";
      }

      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorId': selectedVendorId,
      });

      String vendorMsg = "";
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        try {
          await vendorController.addAutomatedShipmentCredit(
            vendorId: selectedVendorId,
            amount: shipment.totalAmount,
            shipmentName: shipment.shipmentName,
            date: arrivalDate,
          );
          vendorMsg = " & Vendor Credited";
        } catch (e) {
          Get.snackbar(
            "Warning",
            "Stock added, but Vendor Credit failed: $e",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }

      Get.snackbar(
        "Success",
        "Stock Received$vendorMsg",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.defaultDialog(
        title: "Error",
        middleText: e.toString(),
        textConfirm: "OK",
        confirmTextColor: Colors.white,
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // 4. PDF GENERATION (SINGLE MANIFEST - OLD)
  // ==========================================
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

  // ==========================================
  // 5. NEW PDF: AGGREGATED PRODUCT REPORT
  // ==========================================
  Future<void> generateAggregatedOnWayPdf() async {
    if (aggregatedList.isEmpty) {
      Get.snackbar(
        "Info",
        "No on-way shipments found to export.",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "INCOMING INVENTORY REPORT",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Model
                1: const pw.FlexColumnWidth(1), // Total Qty
                2: const pw.FlexColumnWidth(4), // Shipment Details
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("Model / Product", isBold: true),
                    _pdfCell(
                      "Total On Way",
                      isBold: true,
                      align: pw.TextAlign.center,
                    ),
                    _pdfCell(
                      "Shipment Breakdown (Ref | Date | Qty)",
                      isBold: true,
                    ),
                  ],
                ),
                // Data
                ...aggregatedList.map((product) {
                  // Format breakdown: "Ship1 (Oct 20) : 50pcs"
                  String details = product.incomingDetails
                      .map(
                        (d) =>
                            "${d.shipmentName} | ${DateFormat('MMM dd').format(d.date)} | ${d.qty} pcs",
                      )
                      .join("\n");

                  return pw.TableRow(
                    children: [
                      _pdfCell("${product.model}\n${product.name}"),
                      _pdfCell(
                        "${product.totalQty}",
                        align: pw.TextAlign.center,
                        isBold: true,
                      ),
                      _pdfCell(details),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name:
          'Incoming_Inventory_Summary_${DateFormat('MM-dd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
