// ignore_for_file: deprecated_member_use, avoid_print
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'shipmodel.dart';

// --- INTERNAL MODELS ---
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

// --- CONTROLLER ---

class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VendorController vendorController = Get.put(VendorController());

  // --- STATE ---
  final RxList<ShipmentModel> allShipments = <ShipmentModel>[].obs;
  final RxList<ShipmentModel> filteredShipments = <ShipmentModel>[].obs;

  // PAGINATION
  final RxInt shipmentPage = 1.obs;
  final RxInt shipmentPageSize = 20.obs;

  final RxList<AggregatedOnWayProduct> aggregatedList =
      <AggregatedOnWayProduct>[].obs;
  final RxList<OnHoldItem> onHoldItems = <OnHoldItem>[].obs;
  final RxList<OnHoldItem> filteredOnHoldItems = <OnHoldItem>[].obs;

  // CONFIG
  final List<String> carrierList = [
    "RH",
    "TRT",
    "GREEN",
    "DIAMOND",
    "RS",
    "Other",
  ];
  final RxString filterCarrier = ''.obs;
  final RxString filterVendor = ''.obs;
  final RxString filterOnHoldCarrier = ''.obs;

  // MANIFEST INPUTS
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

  // Carrier Cost
  final TextEditingController carrierCostPerCtnCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController totalCarrierCostDisplayCtrl =
      TextEditingController(text: '0');

  final TextEditingController shipmentNameCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController globalExchangeRateCtrl = TextEditingController(
    text: '0.0',
  );

  final RxBool isLoading = false.obs;
  final RxMap<int, int> onWayStockMap = <int, int>{}.obs;

  StreamSubscription? _shipmentSubscription;
  StreamSubscription? _onHoldSubscription;

  // --- CURRENCY FORMATTERS ---
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  String formatMoney(double amount) =>
      "BDT ${_currencyFormatter.format(amount)}";

  final NumberFormat _rmbFormatter = NumberFormat('#,##0.00', 'en_US');
  String formatRMB(double amount) => "¥ ${_rmbFormatter.format(amount)}";

  // --- GETTERS ---
  double get calculatedTotalWeight => currentManifestItems.fold(
    0.0,
    (sumv, item) =>
        sumv + (item.unitWeightSnapshot * (item.seaQty + item.airQty)),
  );
  double get totalOnWayValue => allShipments
      .where((s) => !s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.grandTotal);
  double get totalCompletedValue => allShipments
      .where((s) => s.isReceived)
      .fold(0.0, (sumv, item) => sumv + item.grandTotal);
  double get currentManifestProductCost =>
      currentManifestItems.fold(0.0, (sumv, item) => sumv + item.totalItemCost);

  double get liveTotalCarrierCost {
    int cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
    double costPerCtn = double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
    return cartons * costPerCtn;
  }

  double get liveGrandTotal =>
      currentManifestProductCost + liveTotalCarrierCost;

  // --- NEW RMB GETTERS ---
  double get currentManifestProductCostRMB {
    double rate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;
    return rate > 0 ? currentManifestProductCost / rate : 0.0;
  }

  double get liveTotalCarrierCostRMB {
    double rate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;
    return rate > 0 ? liveTotalCarrierCost / rate : 0.0;
  }

  double get liveGrandTotalRMB {
    double rate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;
    return rate > 0 ? liveGrandTotal / rate : 0.0;
  }

  String get totalOnWayDisplay => formatMoney(totalOnWayValue);
  String get totalCompletedDisplay => formatMoney(totalCompletedValue);
  String get currentManifestTotalDisplay => formatMoney(liveGrandTotal);

  List<ShipmentModel> get paginatedShipments {
    int start = (shipmentPage.value - 1) * shipmentPageSize.value;
    int end = start + shipmentPageSize.value;
    if (start >= filteredShipments.length) return [];
    if (end > filteredShipments.length) end = filteredShipments.length;
    return filteredShipments.sublist(start, end);
  }

  int get totalPages {
    if (filteredShipments.isEmpty) return 1;
    return (filteredShipments.length / shipmentPageSize.value).ceil();
  }

  @override
  void onInit() {
    super.onInit();
    bindFirestoreStream();
    bindOnHoldStream();

    totalCartonCtrl.addListener(_updateCarrierCost);
    carrierCostPerCtnCtrl.addListener(_updateCarrierCost);

    ever(filterCarrier, (_) {
      shipmentPage.value = 1;
      _applyFilters();
    });
    ever(filterVendor, (_) {
      shipmentPage.value = 1;
      _applyFilters();
    });
    ever(filterOnHoldCarrier, (_) => _applyOnHoldFilters());
  }

  void _updateCarrierCost() {
    int cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
    double costPerCtn = double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
    double total = cartons * costPerCtn;
    totalCarrierCostDisplayCtrl.text = total.toStringAsFixed(2);
    currentManifestItems.refresh();
  }

  @override
  void onClose() {
    _shipmentSubscription?.cancel();
    _onHoldSubscription?.cancel();
    totalCartonCtrl.dispose();
    totalWeightCtrl.dispose();
    carrierCostPerCtnCtrl.dispose();
    totalCarrierCostDisplayCtrl.dispose();
    shipmentNameCtrl.dispose();
    searchCtrl.dispose();
    globalExchangeRateCtrl.dispose();
    super.onClose();
  }

  void onSearchChanged(String val) => productController.search(val);
  void nextPage() {
    if (shipmentPage.value < totalPages) shipmentPage.value++;
  }

  void prevPage() {
    if (shipmentPage.value > 1) shipmentPage.value--;
  }

  // --- FIRESTORE LISTENERS ---
  void bindFirestoreStream() {
    _shipmentSubscription = _firestore
        .collection('shipments')
        .orderBy('purchaseDate', descending: true)
        .limit(500)
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
          _applyOnHoldFilters();
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
          tempMap[item.productId] =
              (tempMap[item.productId] ?? 0) + (item.seaQty + item.airQty);
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
    aggregatedList.assignAll(tempMap.values.toList());
  }

  int getOnWayQty(int productId) => onWayStockMap[productId] ?? 0;

  // --- ACTIONS ---
  Future<void> addToManifestAndVerify({
    required int? productId,
    required Map<String, dynamic> productData,
    required int seaQty,
    required int airQty,
    required String cartonNo,
  }) async {
    isLoading.value = true;
    try {
      int finalProductId = productId ?? 0;
      if (productId == null || productId == 0) {
        final createBody = {
          ...productData,
          'stock_qty': 0,
          'sea_stock_qty': 0,
          'air_stock_qty': 0,
          'local_qty': 0,
        };
        int? newId = await productController.createProductReturnId(createBody);
        if (newId != null && newId != 0) {
          finalProductId = newId;
        } else {
          throw "Product ID Missing";
        }
      } else {
        await productController.updateProduct(finalProductId, productData);
      }
      final item = ShipmentItem(
        productId: finalProductId,
        productName: productData['name'],
        productModel: productData['model'],
        productBrand: productData['brand'],
        productCategory: productData['category'],
        unitWeightSnapshot: (productData['weight'] as num).toDouble(),
        seaQty: seaQty,
        airQty: airQty,
        receivedSeaQty: seaQty,
        receivedAirQty: airQty,
        cartonNo: cartonNo,
        seaPriceSnapshot: (productData['sea'] as num).toDouble(),
        airPriceSnapshot: (productData['air'] as num).toDouble(),
      );
      currentManifestItems.add(item);
      totalWeightCtrl.text = calculatedTotalWeight.toStringAsFixed(2);
      Get.back();
      Get.snackbar(
        "Success",
        "Added to Manifest",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "$e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void removeFromManifest(int index) {
    currentManifestItems.removeAt(index);
    totalWeightCtrl.text = calculatedTotalWeight.toStringAsFixed(2);
  }

  Future<void> saveShipmentToFirestore() async {
    if (currentManifestItems.isEmpty) return;
    if (selectedVendorId.value == null || selectedCarrier.value == null) return;
    isLoading.value = true;
    try {
      double carrierCostPerCtn =
          double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
      int cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
      double totalCarrierFee = carrierCostPerCtn * cartons;
      double exchangeRate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;

      final newShipment = ShipmentModel(
        shipmentName:
            shipmentNameCtrl.text.isEmpty
                ? "Shipment ${DateFormat('MM/dd').format(purchaseDateInput.value)}"
                : shipmentNameCtrl.text,
        purchaseDate: purchaseDateInput.value,
        vendorId: selectedVendorId.value,
        vendorName: selectedVendorName.value ?? 'Unknown',
        carrier: selectedCarrier.value!,
        exchangeRate: exchangeRate,
        totalCartons: cartons,
        totalWeight: calculatedTotalWeight,
        carrierCostPerCarton: carrierCostPerCtn,
        totalCarrierFee: totalCarrierFee,
        totalAmount: currentManifestProductCost,
        items: currentManifestItems.toList(),
        isReceived: false,
      );

      final newShipmentMap = newShipment.toMap();

      // Ensure initial RMB values are injected directly into Firestore Map
      if (exchangeRate > 0) {
        newShipmentMap['totalAmountRMB'] =
            currentManifestProductCost / exchangeRate;
        newShipmentMap['totalCarrierFeeRMB'] = totalCarrierFee / exchangeRate;
        newShipmentMap['grandTotalRMB'] =
            (currentManifestProductCost + totalCarrierFee) / exchangeRate;
      }

      await _firestore.collection('shipments').add(newShipmentMap);
      await vendorController.addAutomatedShipmentCredit(
        vendorId: newShipment.vendorId!,
        amount: newShipment.totalAmount,
        shipmentName: newShipment.shipmentName,
        date: newShipment.purchaseDate,
      );

      _resetForm();
      Get.back();
      Get.snackbar("Success", "Manifest Created");
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  void _resetForm() {
    currentManifestItems.clear();
    shipmentNameCtrl.clear();
    totalCartonCtrl.text = '0';
    totalWeightCtrl.text = '0';
    carrierCostPerCtnCtrl.text = '0';
    totalCarrierCostDisplayCtrl.text = '0';
    globalExchangeRateCtrl.text = '0.0';
    selectedVendorId.value = null;
    selectedVendorName.value = null;
    selectedCarrier.value = null;
    searchCtrl.clear();
  }

  // --- NEW: EDIT & RECALCULATE MANIFEST ---
  Future<void> saveEditedManifest({
    required String docId,
    required List<ShipmentItem> newItems,
    required int newCartonCount,
    required double newCarrierRate,
    required String report,
  }) async {
    isLoading.value = true;
    try {
      // 1. Recalculate Totals based on Edited Items
      double newTotalProductCost = newItems.fold(
        0.0,
        (sumv, item) => sumv + item.totalItemCost,
      );
      double newTotalWeight = newItems.fold(
        0.0,
        (sumv, item) =>
            sumv + (item.unitWeightSnapshot * (item.seaQty + item.airQty)),
      );
      double newTotalCarrierFee = newCartonCount * newCarrierRate;
      double newGrandTotal = newTotalProductCost + newTotalCarrierFee;

      // Fetch the existing exchange rate to recalculate RMB
      double currentExchangeRate = 0.0;
      try {
        var doc = await _firestore.collection('shipments').doc(docId).get();
        if (doc.exists &&
            doc.data() != null &&
            doc.data()!.containsKey('exchangeRate')) {
          currentExchangeRate = (doc.data()!['exchangeRate'] ?? 0.0).toDouble();
        }
      } catch (e) {
        // Proceed safely if fetch fails
      }

      Map<String, dynamic> updateData = {
        'items': newItems.map((e) => e.toMap()).toList(),
        'totalCartons': newCartonCount,
        'carrierCostPerCarton': newCarrierRate,
        'totalCarrierFee': newTotalCarrierFee,
        'totalAmount': newTotalProductCost,
        'grandTotal': newGrandTotal, // Add grandTotal safely
        'totalWeight': newTotalWeight,
        'carrierReport': report,
      };

      // 2. Add RMB Calculation based on fetched Exchange Rate
      if (currentExchangeRate > 0) {
        updateData['totalAmountRMB'] =
            newTotalProductCost / currentExchangeRate;
        updateData['totalCarrierFeeRMB'] =
            newTotalCarrierFee / currentExchangeRate;
        updateData['grandTotalRMB'] = newGrandTotal / currentExchangeRate;
      }

      // 3. Update Firestore
      await _firestore.collection('shipments').doc(docId).update(updateData);

      Get.snackbar(
        "Success",
        "Manifest Updated & Recalculated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  // OLD Update method updated to ensure Yuan calculation is preserved
  Future<void> updateShipmentDetails(
    ShipmentModel shipment,
    List<ShipmentItem> updatedItems,
    String report,
  ) async {
    if (shipment.docId == null) return;
    isLoading.value = true;
    try {
      double newTotalProductCost = updatedItems.fold(
        0.0,
        (sumv, item) => sumv + item.totalItemCost,
      );

      Map<String, dynamic> updateMap = {
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'carrierReport': report,
        'totalAmount': newTotalProductCost,
      };

      if (shipment.exchangeRate > 0) {
        updateMap['totalAmountRMB'] =
            newTotalProductCost / shipment.exchangeRate;
        updateMap['grandTotalRMB'] =
            (newTotalProductCost + shipment.totalCarrierFee) /
            shipment.exchangeRate;
      }

      await _firestore
          .collection('shipments')
          .doc(shipment.docId)
          .update(updateMap);

      Get.snackbar(
        "Success",
        "Updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate,
  ) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      // 1. Stock
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
      await productController.bulkAddStockMixed(bulkItems);

      // 2. Loss
      WriteBatch batch = _firestore.batch();
      bool hasLoss = false;
      for (var item in shipment.items) {
        int missing =
            (item.seaQty + item.airQty) -
            (item.receivedSeaQty + item.receivedAirQty);
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

      // 3. Update Status
      double totalRecVal = shipment.items.fold(
        0.0,
        (sumv, i) => sumv + i.receivedItemValue,
      );
      double diff = shipment.totalAmount - totalRecVal;
      double diffRmb =
          shipment.exchangeRate > 0 ? diff / shipment.exchangeRate : 0.0;

      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorLossAmount': (diff > 0) ? diff : 0.0,
        'vendorLossAmountRMB': (diff > 0) ? diffRmb : 0.0,
      });
      Get.back();
      Get.snackbar(
        "Success",
        "Received",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.defaultDialog(title: "Error", middleText: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resolveOnHoldItem(OnHoldItem item) async {
    isLoading.value = true;
    try {
      await productController.addMixedStock(
        productId: item.productId,
        airQty: item.missingQty,
      );
      await _firestore.collection('on_hold_items').doc(item.docId).delete();
      Get.snackbar(
        "Success",
        "Resolved",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- UPDATED GENERATE PDF (With RMB Values) ---
  Future<void> generatePdf(ShipmentModel shipment) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // 1. Calculations for PDF
    double totalReceivedVal = shipment.items.fold(
      0.0,
      (sumv, e) => sumv + e.receivedItemValue,
    );

    // Total Weight of what was actually received
    double totalRecWeight = shipment.items.fold(0.0, (sumv, e) {
      int receivedQty = e.receivedSeaQty + e.receivedAirQty;
      return sumv + (receivedQty * e.unitWeightSnapshot);
    });

    // Differences
    double valDiff = shipment.totalAmount - totalReceivedVal;
    double weightDiff = shipment.totalWeight - totalRecWeight;

    // RMB Conversions for the PDF
    double exRate = shipment.exchangeRate;
    double productTotalRMB = exRate > 0 ? shipment.totalAmount / exRate : 0.0;
    double carrierTotalRMB =
        exRate > 0 ? shipment.totalCarrierFee / exRate : 0.0;
    double grandTotalRMB = exRate > 0 ? shipment.grandTotal / exRate : 0.0;
    double recValRMB = exRate > 0 ? totalReceivedVal / exRate : 0.0;
    double valDiffRMB = exRate > 0 ? valDiff / exRate : 0.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build:
            (context) => [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "SHIPMENT REPORT",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
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
                      pw.Text("Rate: ${shipment.exchangeRate} BDT/RMB"),
                      pw.Text(
                        shipment.isReceived
                            ? "Status: RECEIVED"
                            : "Status: ON WAY",
                        style: pw.TextStyle(
                          color:
                              shipment.isReceived
                                  ? PdfColors.green
                                  : PdfColors.orange,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // ITEMS TABLE
              pw.Table.fromTextArray(
                headers: [
                  'Ctn',
                  'Model',
                  'Name',
                  'Qty (Ord)',
                  'Qty (Rec)',
                  'Cost',
                  'Total',
                ],
                data:
                    shipment.items.map((e) {
                      double itemCost =
                          e.seaPriceSnapshot > 0
                              ? e.seaPriceSnapshot
                              : e.airPriceSnapshot;

                      String costStr = formatMoney(itemCost);
                      String totalStr = formatMoney(e.totalItemCost);

                      if (exRate > 0) {
                        costStr += "\n${formatRMB(itemCost / exRate)}";
                        totalStr += "\n${formatRMB(e.totalItemCost / exRate)}";
                      }

                      return [
                        e.cartonNo,
                        e.productModel,
                        e.productName,
                        "${e.seaQty + e.airQty}",
                        "${e.receivedSeaQty + e.receivedAirQty}",
                        costStr,
                        totalStr,
                      ];
                    }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(
                    1.8,
                  ), // Slightly widened for RMB addition
                },
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),

              // SUMMARY SECTION (WEIGHT & FINANCIALS)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LEFT: WEIGHT ANALYSIS
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "WEIGHT ANALYSIS",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Original:"),
                              pw.Text("${shipment.totalWeight} kg"),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Received:"),
                              pw.Text(
                                "${totalRecWeight.toStringAsFixed(2)} kg",
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                weightDiff > 0 ? "Loss:" : "Gain:",
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                "${weightDiff.abs().toStringAsFixed(2)} kg",
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color:
                                      weightDiff > 0.1
                                          ? PdfColors.red
                                          : (weightDiff < -0.1
                                              ? PdfColors.green
                                              : PdfColors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // RIGHT: FINANCIAL ANALYSIS
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Product Total: ${formatMoney(shipment.totalAmount)}${exRate > 0 ? '  |  ${formatRMB(productTotalRMB)}' : ''}",
                        ),
                        pw.Text(
                          "Carrier Fee: ${formatMoney(shipment.totalCarrierFee)}${exRate > 0 ? '  |  ${formatRMB(carrierTotalRMB)}' : ''}",
                        ),
                        pw.Text(
                          "GRAND TOTAL: ${formatMoney(shipment.grandTotal)}${exRate > 0 ? '  |  ${formatRMB(grandTotalRMB)}' : ''}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        pw.SizedBox(height: 10),

                        // Financial Discrepancy Display
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          color:
                              valDiff.abs() > 1
                                  ? (valDiff > 0
                                      ? PdfColors.red50
                                      : PdfColors.green50)
                                  : PdfColors.white,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                "Recv. Value: ${formatMoney(totalReceivedVal)}${exRate > 0 ? '  |  ${formatRMB(recValRMB)}' : ''}",
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              if (valDiff.abs() > 1)
                                pw.Text(
                                  valDiff > 0
                                      ? "SHORTAGE: ${formatMoney(valDiff)}${exRate > 0 ? '  |  ${formatRMB(valDiffRMB)}' : ''}"
                                      : "SURPLUS: ${formatMoney(valDiff.abs())}${exRate > 0 ? '  |  ${formatRMB(valDiffRMB.abs())}' : ''}",
                                  style: pw.TextStyle(
                                    color:
                                        valDiff > 0
                                            ? PdfColors.red
                                            : PdfColors.green,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (shipment.carrierReport != null &&
                  shipment.carrierReport!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 20),
                  child: pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "REPORT / NOTES:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange900,
                          ),
                        ),
                        pw.Text(shipment.carrierReport!),
                      ],
                    ),
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

  // --- RESTORED: AGGREGATED REPORT ---
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
        build:
            (context) => [
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
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
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
                  ...aggregatedList.map(
                    (product) => pw.TableRow(
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
                          child: pw.Text(
                            product.incomingDetails
                                .map((d) => "${d.shipmentName} | ${d.qty}")
                                .join("\n"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Incoming_Report.pdf',
    );
  }
}