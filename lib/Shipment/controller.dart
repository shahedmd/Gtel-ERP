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
  int get totalQty => incomingDetails.fold(0, (sumv, item) => sumv + item.qty);
}

// --- MODEL FOR MISSING ITEMS ---
class OnHoldItem {
  final String docId;
  final String shipmentName;
  final String carrier;
  final DateTime purchaseDate;
  final int productId;
  final String productName;
  final String productModel;
  final int missingQty;

  OnHoldItem({
    required this.docId,
    required this.shipmentName,
    required this.carrier,
    required this.purchaseDate,
    required this.productId,
    required this.productName,
    required this.productModel,
    required this.missingQty,
  });

  factory OnHoldItem.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OnHoldItem(
      docId: doc.id,
      shipmentName: data['shipmentName'] ?? '',
      carrier: data['carrier'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      productId: data['productId'] ?? 0,
      productName: data['productName'] ?? '',
      productModel: data['productModel'] ?? '',
      missingQty: data['missingQty'] ?? 0,
    );
  }
}

class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VendorController vendorController = Get.put(VendorController());

  // --- STATE ---
  final RxList<ShipmentModel> allShipments = <ShipmentModel>[].obs;
  final RxList<ShipmentModel> filteredShipments = <ShipmentModel>[].obs;
  final RxList<AggregatedOnWayProduct> aggregatedList =
      <AggregatedOnWayProduct>[].obs;

  // NEW: ON HOLD LIST & FILTERED LIST
  final RxList<OnHoldItem> onHoldItems = <OnHoldItem>[].obs;
  final RxList<OnHoldItem> filteredOnHoldItems =
      <OnHoldItem>[].obs; // Added for sorting

  // --- CONFIG ---
  final List<String> carrierList = [
    "SAJ Express",
    "SF Express",
    "DHL",
    "FedEx",
    "Cosco Shipping",
    "Local Cargo",
    "Other",
  ];
  final RxString filterCarrier = ''.obs;
  final RxString filterVendor = ''.obs;
  final RxString filterOnHoldCarrier = ''.obs; // Added filter for On Hold

  // --- MANIFEST INPUTS ---
  final RxList<ShipmentItem> currentManifestItems = <ShipmentItem>[].obs;
  final Rx<DateTime> purchaseDateInput = DateTime.now().obs;
  final Rxn<String> selectedVendorId = Rxn<String>();
  final Rxn<String> selectedVendorName = Rxn<String>();
  final Rxn<String> selectedCarrier = Rxn<String>();

  final TextEditingController totalCartonCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController totalWeightCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController shipmentNameCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController globalExchangeRateCtrl = TextEditingController(
    text: '0.0',
  );

  final RxBool isLoading = false.obs;
  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

  StreamSubscription? _shipmentSubscription;
  StreamSubscription? _onHoldSubscription;

  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  String formatMoney(double amount) =>
      "BDT ${_currencyFormatter.format(amount)}";

  // --- GETTERS ---
  double get totalOnWayValue => allShipments
      .where((s) => !s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.totalAmount);
  double get totalCompletedValue => allShipments
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
    bindOnHoldStream();
    ever(filterCarrier, (_) => _applyFilters());
    ever(filterVendor, (_) => _applyFilters());
    ever(
      filterOnHoldCarrier,
      (_) => _applyOnHoldFilters(),
    ); // Listener for On Hold Sort
  }

  @override
  void onClose() {
    _shipmentSubscription?.cancel();
    _onHoldSubscription?.cancel();
    totalCartonCtrl.dispose();
    totalWeightCtrl.dispose();
    shipmentNameCtrl.dispose();
    searchCtrl.dispose();
    globalExchangeRateCtrl.dispose();
    super.onClose();
  }

  void onSearchChanged(String val) => productController.search(val);

  // --- FIRESTORE LISTENERS ---
  void bindFirestoreStream() {
    _shipmentSubscription = _firestore
        .collection('shipments')
        .orderBy('purchaseDate', descending: true)
        .limit(100)
        .snapshots()
        .listen((event) {
          final loaded =
              event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
          allShipments.value = loaded;
          _applyFilters();
          _calculateOnWayTotals(loaded);
          _aggregateOnWayData(loaded);
        }, onError: (e) => print("Firestore Error: $e"));
  }

  void bindOnHoldStream() {
    _onHoldSubscription = _firestore
        .collection('on_hold_items')
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .listen((event) {
          onHoldItems.value =
              event.docs.map((e) => OnHoldItem.fromSnapshot(e)).toList();
          _applyOnHoldFilters(); // Apply filter initially
        });
  }

  void _applyFilters() {
    List<ShipmentModel> temp = List.from(allShipments);
    if (filterCarrier.value.isNotEmpty) {
      temp = temp.where((s) => s.carrier == filterCarrier.value).toList();
    }
    if (filterVendor.value.isNotEmpty) {
      temp = temp.where((s) => s.vendorId == filterVendor.value).toList();
    }
    filteredShipments.value = temp;
  }

  // NEW: Filter logic for On Hold Items
  void _applyOnHoldFilters() {
    if (filterOnHoldCarrier.value.isEmpty) {
      filteredOnHoldItems.assignAll(onHoldItems);
    } else {
      filteredOnHoldItems.assignAll(
        onHoldItems.where((i) => i.carrier == filterOnHoldCarrier.value),
      );
    }
  }

  void _calculateOnWayTotals(List<ShipmentModel> list) {
    final Map<int, int> tempMap = {};
    for (var shipment in list) {
      if (!shipment.isReceived) {
        for (var item in shipment.items) {
          int totalQty = item.seaQty + item.airQty;
          tempMap[item.productId] = (tempMap[item.productId] ?? 0) + totalQty;
        }
      }
    }
    onWayStockMap.assignAll(tempMap);
  }

  void _aggregateOnWayData(List<ShipmentModel> list) {
    Map<int, AggregatedOnWayProduct> tempMap = {};
    for (var shipment in list) {
      if (shipment.isReceived) continue;
      for (var item in shipment.items) {
        int qty = item.seaQty + item.airQty;
        if (qty <= 0) continue;
        final detail = IncomingDetail(
          shipmentName: shipment.shipmentName,
          date: shipment.purchaseDate,
          qty: qty,
        );
        if (tempMap.containsKey(item.productId)) {
          tempMap[item.productId]!.incomingDetails.add(detail);
        } else {
          tempMap[item.productId] = AggregatedOnWayProduct(
            productId: item.productId,
            model: item.productModel,
            name: item.productName,
            incomingDetails: [detail],
          );
        }
      }
    }
    for (var p in tempMap.values) {
      p.incomingDetails.sort((a, b) => a.date.compareTo(b.date));
    }
    aggregatedList.assignAll(tempMap.values.toList());
  }

  int getOnWayQty(int productId) => onWayStockMap[productId] ?? 0;

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
        'sea_stock_qty': product.seaStockQty,
        'air_stock_qty': product.airStockQty,
        'local_qty': product.localQty,
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
        receivedSeaQty: seaQty,
        receivedAirQty: airQty,
        cartonNo: cartonNo,
        seaPriceSnapshot: (serverBody['sea'] as num).toDouble(),
        airPriceSnapshot: (serverBody['air'] as num).toDouble(),
      );

      currentManifestItems.add(item);
      Get.back();
      Get.snackbar("Success", "Added to Manifest");
    } catch (e) {
      Get.snackbar(
        "Error",
        "Update failed: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void removeFromManifest(int index) => currentManifestItems.removeAt(index);

  Future<void> saveShipmentToFirestore() async {
    if (currentManifestItems.isEmpty) {
      Get.snackbar("Error", "No items to ship");
      return;
    }
    if (selectedVendorId.value == null || selectedCarrier.value == null) {
      Get.snackbar("Error", "Please select Vendor and Carrier");
      return;
    }
    isLoading.value = true;
    try {
      final newShipment = ShipmentModel(
        shipmentName:
            shipmentNameCtrl.text.isEmpty
                ? "Shipment ${DateFormat('MM/dd').format(purchaseDateInput.value)}"
                : shipmentNameCtrl.text,
        purchaseDate: purchaseDateInput.value,
        vendorId: selectedVendorId.value,
        vendorName: selectedVendorName.value ?? 'Unknown',
        carrier: selectedCarrier.value!,
        exchangeRate: double.tryParse(globalExchangeRateCtrl.text) ?? 0.0,
        totalCartons: int.tryParse(totalCartonCtrl.text) ?? 0,
        totalWeight: double.tryParse(totalWeightCtrl.text) ?? 0.0,
        totalAmount: currentManifestTotalCost,
        items: currentManifestItems.toList(),
        isReceived: false,
      );

      await _firestore.collection('shipments').add(newShipment.toMap());

      // Credit Vendor
      await vendorController.addAutomatedShipmentCredit(
        vendorId: newShipment.vendorId!,
        amount: newShipment.totalAmount,
        shipmentName: newShipment.shipmentName,
        date: newShipment.purchaseDate,
      );

      _resetForm();
      Get.back();
      Get.snackbar("Success", "Manifest Created & Vendor Credited");
    } catch (e) {
      Get.snackbar("Error", "Save failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _resetForm() {
    currentManifestItems.clear();
    shipmentNameCtrl.clear();
    totalCartonCtrl.text = '0';
    totalWeightCtrl.text = '0';
    globalExchangeRateCtrl.text = '0.0';
    selectedVendorId.value = null;
    selectedVendorName.value = null;
    selectedCarrier.value = null;
    searchCtrl.clear();
  }

  // --- UPDATE DETAILS (Add/Edit Items) ---
  Future<void> updateShipmentDetails(
    ShipmentModel shipment,
    List<ShipmentItem> updatedItems,
    String report,
  ) async {
    if (shipment.docId == null) return;
    isLoading.value = true;
    try {
      // NOTE: We do NOT update 'totalAmount'. Vendor bill is locked to original order.
      await _firestore.collection('shipments').doc(shipment.docId).update({
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'carrierReport': report,
      });
      Get.snackbar("Success", "Shipment Details Updated");
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- RECEIVE SHIPMENT (UPDATED LOGIC: IGNORE MISSING + FINANCIAL CALC) ---
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate,
  ) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Authentication Error";

      // 1. ADD RECEIVED STOCK
      List<Map<String, dynamic>> bulkItems =
          shipment.items.map((item) {
            return {
              'id': item.productId,
              'sea_qty': item.receivedSeaQty,
              'air_qty': item.receivedAirQty,
              'local_qty': 0,
              'local_price': 0.0,
              'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),
            };
          }).toList();

      bool success = await productController.bulkAddStockMixed(bulkItems);
      if (!success) throw "Stock update failed";

      // 2. CHECK FOR MISSING ITEMS (LOSS) -> ADD TO ON HOLD
      WriteBatch batch = _firestore.batch();
      bool hasLoss = false;

      for (var item in shipment.items) {
        int ordered = item.seaQty + item.airQty;
        int received = item.receivedSeaQty + item.receivedAirQty;
        int missing = ordered - received;

        // UPDATED: Only send to On Hold if missing > 0 AND ignoreMissing is false
        if (missing > 0 && !item.ignoreMissing) {
          hasLoss = true;
          DocumentReference ref = _firestore.collection('on_hold_items').doc();
          batch.set(ref, {
            'shipmentName': shipment.shipmentName,
            'carrier': shipment.carrier,
            'purchaseDate': Timestamp.fromDate(shipment.purchaseDate),
            'productId': item.productId,
            'productName': item.productName,
            'productModel': item.productModel,
            'missingQty': missing,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (hasLoss) await batch.commit();

      // 3. CALCULATE FINANCIAL DIFFERENCE (Current Received Value vs Original Bill)
      double totalReceivedValue = shipment.items.fold(
        0.0,
        (sum, item) => sum + item.receivedItemValue,
      );
      double originalBill = shipment.totalAmount;
      double diff = originalBill - totalReceivedValue;

      // If diff is positive, it means we received LESS value than we billed.
      // This amount is saved as a "Loss Note" but does NOT deduct from vendor balance automatically.
      double vendorLoss = (diff > 0) ? diff : 0.0;

      // 4. CLOSE SHIPMENT
      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorLossAmount': vendorLoss, // Save the note amount
      });

      Get.back();
      Get.snackbar(
        "Success",
        "Stock Received. ${hasLoss ? 'Missing items moved to On Hold.' : ''} ${vendorLoss > 0 ? 'Shortage Note: ${formatMoney(vendorLoss)}' : ''}",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.defaultDialog(title: "Error", middleText: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // --- RESOLVE ON HOLD ITEM ---
  Future<void> resolveOnHoldItem(OnHoldItem item) async {
    isLoading.value = true;
    try {
      // 1. Add to stock
      List<Map<String, dynamic>> singleItem = [
        {
          'id': item.productId,
          'sea_qty': 0,
          'air_qty': item.missingQty, // Default to Air for recovery
          'local_qty': 0,
          'local_price': 0.0,
          'shipmentdate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        },
      ];

      bool success = await productController.bulkAddStockMixed(singleItem);
      if (!success) throw "Stock update failed";

      // 2. Remove from On Hold list
      await _firestore.collection('on_hold_items').doc(item.docId).delete();

      Get.snackbar(
        "Success",
        "Item recovered and added to stock.",
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to resolve: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- UPDATED PROFESSIONAL PDF GENERATION ---
  Future<void> generatePdf(ShipmentModel shipment) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Prepare Table Data
    final tableHeaders = [
      'Carton',
      'Model',
      'Name',
      'Qty (Ord)',
      'Qty (Recv)',
      'Cost/Unit',
      'Total',
    ];

    final tableData =
        shipment.items.map((e) {
          // Determine cost used (Snapshot)
          double cost =
              (e.seaPriceSnapshot > 0)
                  ? e.seaPriceSnapshot
                  : e.airPriceSnapshot;
          return [
            e.cartonNo,
            e.productModel,
            e.productName,
            "${e.seaQty + e.airQty}",
            "${e.receivedSeaQty + e.receivedAirQty}",
            formatMoney(cost),
            formatMoney(e.totalItemCost),
          ];
        }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build:
            (context) => [
              // 1. HEADER SECTION
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 1, color: PdfColors.grey),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "SHIPMENT MANIFEST",
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text("ID: ${shipment.shipmentName}"),
                        pw.Text(
                          "Date: ${DateFormat('yyyy-MM-dd').format(shipment.purchaseDate)}",
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Vendor: ${shipment.vendorName}",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text("Carrier: ${shipment.carrier}"),
                        pw.Text(
                          "Cartons: ${shipment.totalCartons} | Weight: ${shipment.totalWeight}kg",
                        ),
                        if (shipment.isReceived)
                          pw.Text(
                            "Status: RECEIVED",
                            style: pw.TextStyle(
                              color: PdfColors.green,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. REPORT SECTION (If exists)
              if (shipment.carrierReport != null &&
                  shipment.carrierReport!.isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "NOTE / REPORT:",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange900,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        shipment.carrierReport!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),

              // 3. PRODUCT TABLE
              pw.Table.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center, // Carton
                  3: pw.Alignment.center, // Qty Ord
                  4: pw.Alignment.center, // Qty Recv
                  5: pw.Alignment.centerRight, // Cost
                  6: pw.Alignment.centerRight, // Total
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(1.2),
                  6: const pw.FlexColumnWidth(1.2),
                },
              ),

              pw.SizedBox(height: 10),

              // 4. TOTALS
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Total Value (Billable): ${formatMoney(shipment.totalAmount)}",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (shipment.vendorLossAmount > 0)
                      pw.Text(
                        "Shortage Note: ${formatMoney(shipment.vendorLossAmount)}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.red,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Manifest_${shipment.shipmentName}.pdf',
    );
  }

  Future<void> generateAggregatedOnWayPdf() async {
    if (aggregatedList.isEmpty) {
      Get.snackbar("Info", "No data.");
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
              child: pw.Text(
                "INCOMING INVENTORY",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Model",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Qty",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Breakdown",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...aggregatedList.map((product) {
                  String details = product.incomingDetails
                      .map((d) => "${d.shipmentName} | ${d.qty} pcs")
                      .join("\n");
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("${product.model}\n${product.name}"),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("${product.totalQty}"),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(details),
                      ),
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
      name: 'Incoming_Report.pdf',
    );
  }
}