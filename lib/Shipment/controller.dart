// ignore_for_file: deprecated_member_use, avoid_print
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:intl/intl.dart';
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

  // --- MANIFEST LOCAL SEARCH ---
  final TextEditingController manifestSearchCtrl = TextEditingController();
  final RxString manifestSearchQuery = ''.obs;

  // Getter for filtered manifest items
  List<ShipmentItem> get filteredManifestItems {
    if (manifestSearchQuery.value.isEmpty) return currentManifestItems;
    final q = manifestSearchQuery.value.toLowerCase();
    return currentManifestItems.where((item) {
      return item.productName.toLowerCase().contains(q) ||
          item.productModel.toLowerCase().contains(q) ||
          item.cartonNo.toLowerCase().contains(q);
    }).toList();
  }

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
  final TextEditingController customCarrierCtrl = TextEditingController();
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

  // ── NEW: total ordered qty across the manifest + carrier cost / unit ─────
  int get currentManifestTotalQty =>
      currentManifestItems.fold(0, (s, i) => s + (i.seaQty + i.airQty));

  double get liveCarrierCostPerUnit {
    final qty = currentManifestTotalQty;
    return qty > 0 ? liveTotalCarrierCost / qty : 0.0;
  }

  // --- RMB GETTERS ---
  double get _globalRate => double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;

  double get currentManifestProductCostRMB =>
      _globalRate > 0 ? currentManifestProductCost / _globalRate : 0.0;

  double get liveTotalCarrierCostRMB =>
      _globalRate > 0 ? liveTotalCarrierCost / _globalRate : 0.0;

  double get liveGrandTotalRMB =>
      _globalRate > 0 ? liveGrandTotal / _globalRate : 0.0;

  String get totalOnWayDisplay => formatMoney(totalOnWayValue);
  String get totalCompletedDisplay => formatMoney(totalCompletedValue);
  String get currentManifestTotalDisplay => formatMoney(liveGrandTotal);

  List<ShipmentModel> get paginatedShipments {
    int start = (shipmentPage.value - 1) * shipmentPageSize.value;
    int end = (start + shipmentPageSize.value).clamp(
      0,
      filteredShipments.length,
    );
    if (start >= filteredShipments.length) return [];
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
    customCarrierCtrl.dispose();
    searchCtrl.dispose();
    globalExchangeRateCtrl.dispose();
    manifestSearchCtrl.dispose();
    super.onClose();
  }

  void onSearchChanged(String val) => productController.search(val);
  void nextPage() {
    if (shipmentPage.value < totalPages) shipmentPage.value++;
  }

  void prevPage() {
    if (shipmentPage.value > 1) shipmentPage.value--;
  }

  void bindFirestoreStream() {
    _shipmentSubscription?.cancel();
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
    _onHoldSubscription?.cancel();
    _onHoldSubscription = _firestore
        .collection('on_hold_items')
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .listen((event) {
          onHoldItems.value =
              event.docs.map((e) => OnHoldItem.fromSnapshot(e)).toList();
          _applyOnHoldFilters();
        }, onError: (e) => print("OnHold stream error: $e"));
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

        final int? newId = await productController.createProductReturnId(
          createBody,
        );
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
      Get.until((route) => route.settings.name != 'shipment-entry-dialog');

      Get.snackbar(
        "Added",
        "${item.productModel} added to manifest",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
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
    // NEW: forces any open dialog showing per-item carrier share to recalc.
    currentManifestItems.refresh();
  }

  Future<void> saveShipmentToFirestore() async {
    // NEW: explicit feedback instead of silently doing nothing.
    if (currentManifestItems.isEmpty) {
      Get.snackbar("Warning", "Add at least one item to the manifest.");
      return;
    }
    if (selectedVendorId.value == null || selectedCarrier.value == null) {
      Get.snackbar("Warning", "Select a vendor and carrier.");
      return;
    }
    isLoading.value = true;
    try {
      double carrierCostPerCtn =
          double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
      int cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
      double totalCarrierFee = carrierCostPerCtn * cartons;
      double exchangeRate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;

      final shipmentName =
          shipmentNameCtrl.text.isEmpty
              ? "Shipment ${DateFormat('MM/dd').format(purchaseDateInput.value)}"
              : shipmentNameCtrl.text;

      final newShipment = ShipmentModel(
        shipmentName: shipmentName,
        purchaseDate: purchaseDateInput.value,
        vendorId: selectedVendorId.value,
        vendorName: selectedVendorName.value ?? 'Unknown',
        carrier:
            selectedCarrier.value == 'Other'
                ? (customCarrierCtrl.text.trim().isEmpty
                    ? 'Other'
                    : customCarrierCtrl.text.trim())
                : selectedCarrier.value!,
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

      resetForm();
      Get.back();
      Get.snackbar(
        "Success",
        "Manifest Created: $shipmentName",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  void resetForm() {
    currentManifestItems.clear();
    shipmentNameCtrl.clear();
    customCarrierCtrl.clear();
    totalCartonCtrl.text = '0';
    totalWeightCtrl.text = '0';
    carrierCostPerCtnCtrl.text = '0';
    totalCarrierCostDisplayCtrl.text = '0';
    globalExchangeRateCtrl.text = '0.0';
    selectedVendorId.value = null;
    selectedVendorName.value = null;
    selectedCarrier.value = null;
    manifestSearchCtrl.clear();
    manifestSearchQuery.value = '';
    searchCtrl.clear();
  }

  // --- EDIT & RECALCULATE MANIFEST ---
  Future<void> saveEditedManifest({
    required String docId,
    required List<ShipmentItem> newItems,
    required int newCartonCount,
    required double newCarrierRate,
    required String report,
  }) async {
    isLoading.value = true;
    try {
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
        'grandTotal': newGrandTotal,
        'totalWeight': newTotalWeight,
        'carrierReport': report,
      };

      if (currentExchangeRate > 0) {
        updateData['totalAmountRMB'] =
            newTotalProductCost / currentExchangeRate;
        updateData['totalCarrierFeeRMB'] =
            newTotalCarrierFee / currentExchangeRate;
        updateData['grandTotalRMB'] = newGrandTotal / currentExchangeRate;
      }

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

  // --- RECEIVE SHIPMENT (warehouse-aware + weighted avg price refinement) ---
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate, {
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      List<Map<String, dynamic>> bulkItems =
          shipment.items.map((item) {
            return {
              'id': item.productId,
              'sea_qty': item.receivedSeaQty,
              'air_qty': item.receivedAirQty,
              'local_qty': 0,
              'local_price': 0.0,
              'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),
              if (warehouseId != null) 'warehouse_id': warehouseId,
              if (warehouseLocation != null && warehouseLocation.isNotEmpty)
                'warehouse_location': warehouseLocation,
            };
          }).toList();
      await productController.bulkAddStockMixed(bulkItems);

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
            if (warehouseId != null) 'warehouseId': warehouseId,
          });
        }
      }
      if (hasLoss) await batch.commit();

      // STEP 4: Update Status — PRESERVED, warehouse info still stored.
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
        if (warehouseId != null) 'receivedWarehouseId': warehouseId,
        if (warehouseLocation != null && warehouseLocation.isNotEmpty)
          'receivedWarehouseLocation': warehouseLocation,
      });

      // Refresh local product cache ONCE so the UI reflects the new
      // avg_purchase_price values (bulkAddStockMixed already refreshed
      // stock qty earlier in step 1, but avg price wasn't known yet then).
      await productController.fetchProducts();

      Get.back();
      Get.snackbar(
        "Success",
        "Received & average prices updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.defaultDialog(title: "Error", middleText: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ── NEW HELPER: Parse carton range string → number of cartons ────────────
  // Handles formats: "1-1" → 1, "1-3" → 3, "2-5" → 4, "3" → 1, "" → 1
  int _parseCartonCount(String cartonNo) {
    final trimmed = cartonNo.trim();
    if (trimmed.isEmpty) return 1;
    final parts = trimmed.split('-');
    if (parts.length == 2) {
      final start = int.tryParse(parts[0].trim()) ?? 1;
      final end = int.tryParse(parts[1].trim()) ?? 1;
      return (end - start + 1).clamp(1, 9999);
    }
    return 1;
  }

  Future<void> resolveOnHoldItem(
    OnHoldItem item, {
    required int releaseQty,
    int? warehouseId,
    String? warehouseLocation,
  }) async {
    final qty = releaseQty.clamp(1, item.missingQty);
    final isFullRelease = qty >= item.missingQty;

    isLoading.value = true;
    try {
      await productController.addMixedStock(
        productId: item.productId,
        airQty: qty,
        warehouseId: warehouseId,
        warehouseLocation: warehouseLocation,
      );

      if (isFullRelease) {
        await _firestore.collection('on_hold_items').doc(item.docId).delete();
      } else {
        await _firestore.collection('on_hold_items').doc(item.docId).update({
          'missingQty': item.missingQty - qty,
        });
      }

      Get.snackbar(
        "Success",
        isFullRelease
            ? "Fully Released to Stock"
            : "Partially Released ($qty pcs). ${item.missingQty - qty} still on hold.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- GENERATE PDF (With RMB Values + NEW Eff. Cost column) ---
  Future<void> generatePdf(ShipmentModel shipment) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    double totalReceivedVal = shipment.items.fold(
      0.0,
      (sumv, e) => sumv + e.receivedItemValue,
    );

    double totalRecWeight = shipment.items.fold(0.0, (sumv, e) {
      int receivedQty = e.receivedSeaQty + e.receivedAirQty;
      return sumv + (receivedQty * e.unitWeightSnapshot);
    });

    double valDiff = shipment.totalAmount - totalReceivedVal;
    double weightDiff = shipment.totalWeight - totalRecWeight;

    double exRate = shipment.exchangeRate;
    double productTotalRMB = exRate > 0 ? shipment.totalAmount / exRate : 0.0;
    double carrierTotalRMB =
        exRate > 0 ? shipment.totalCarrierFee / exRate : 0.0;
    double grandTotalRMB = exRate > 0 ? shipment.grandTotal / exRate : 0.0;
    double recValRMB = exRate > 0 ? totalReceivedVal / exRate : 0.0;
    double valDiffRMB = exRate > 0 ? valDiff / exRate : 0.0;

    int totalOrderedQty = shipment.items.fold(
      0,
      (s, e) => s + (e.seaQty + e.airQty),
    );
    double carrierPerUnitAvg =
        totalOrderedQty > 0 ? shipment.totalCarrierFee / totalOrderedQty : 0.0;

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
                        "Carrier/Unit (avg): ${formatMoney(carrierPerUnitAvg)}",
                      ),
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

              // ITEMS TABLE (NEW: added "Eff. Cost" column)
              pw.Table.fromTextArray(
                headers: [
                  'Ctn',
                  'Model',
                  'Name',
                  'Qty (Ord)',
                  'Qty (Rec)',
                  'Base Cost',
                  'Eff. Cost',
                  'Total',
                ],
                data: () {
                  // ── Step 1: Unique carton cost ও qty map বানাও ──
                  final Map<String, double> pdfCartonCostMap = {};
                  final Map<String, int> pdfCartonQtyMap = {};

                  for (final it in shipment.items) {
                    final k = it.cartonNo.trim();
                    if (k.isEmpty) continue;
                    if (!pdfCartonCostMap.containsKey(k)) {
                      pdfCartonCostMap[k] =
                          _parseCartonCount(k) * shipment.carrierCostPerCarton;
                    }
                    pdfCartonQtyMap[k] =
                        (pdfCartonQtyMap[k] ?? 0) +
                        (it.receivedSeaQty + it.receivedAirQty);
                  }

                  // ── Step 2: প্রতিটা item-এর row বানাও ──
                  return shipment.items.map((e) {
                    double baseCost =
                        e.seaPriceSnapshot > 0
                            ? e.seaPriceSnapshot
                            : e.airPriceSnapshot;

                    int itemRecvQty = e.receivedSeaQty + e.receivedAirQty;

                    final pdfKey = e.cartonNo.trim();
                    double itemCarrierShare = 0.0;
                    if (pdfKey.isNotEmpty && itemRecvQty > 0) {
                      final cCost = pdfCartonCostMap[pdfKey] ?? 0.0;
                      final cQty = pdfCartonQtyMap[pdfKey] ?? 1;
                      itemCarrierShare = cCost / cQty;
                    }

                    double effCost = baseCost + itemCarrierShare;

                    String baseStr = formatMoney(baseCost);
                    String effStr = formatMoney(effCost);
                    String totalStr = formatMoney(e.totalItemCost);

                    if (exRate > 0) {
                      baseStr += "\n${formatRMB(baseCost / exRate)}";
                      effStr += "\n${formatRMB(effCost / exRate)}";
                      totalStr += "\n${formatRMB(e.totalItemCost / exRate)}";
                    }

                    return [
                      e.cartonNo,
                      e.productModel,
                      e.productName,
                      "${e.seaQty + e.airQty}",
                      "${e.receivedSeaQty + e.receivedAirQty}",
                      baseStr,
                      effStr,
                      totalStr,
                    ];
                  }).toList();
                }(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.7),
                  1: const pw.FlexColumnWidth(1.3),
                  2: const pw.FlexColumnWidth(2.0),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(1.3),
                  6: const pw.FlexColumnWidth(1.3),
                  7: const pw.FlexColumnWidth(1.5),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),

              // SUMMARY SECTION (WEIGHT & FINANCIALS) — unchanged
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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

  Future<void> generateAggregatedOnWayPdf() async {
    if (aggregatedList.isEmpty) {
      Get.snackbar("Notice", "No shipments to download.");
      return;
    }

    final pdf = pw.Document();

    final headers = [
      'Model',
      'Product Name',
      'Total Qty',
      'Shipment Breakdown',
    ];

    final data =
        aggregatedList.map((product) {
          final breakdownStr = product.incomingDetails
              .map((d) {
                final dateStr = DateFormat('MMM dd').format(d.date);
                return '${d.shipmentName} | $dateStr | ${d.qty} pcs';
              })
              .join('\n');

          return [
            product.model,
            product.name,
            product.totalQty.toString(),
            breakdownStr,
          ];
        }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Incoming Shipments Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(3.5),
                },
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Incoming_Shipments_Report_${DateFormat('MMM_dd').format(DateTime.now())}.pdf',
    );
  }
}
