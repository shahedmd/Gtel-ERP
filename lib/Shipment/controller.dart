// ignore_for_file: deprecated_member_use, avoid_print
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Stock Management/stock_controller.dart';
import 'shipmodel.dart';

// ─── Helper model for avg price snapshots ───────────────────────────────────
class _PriceSnapshot {
  final int qty;
  final double avg;
  const _PriceSnapshot({required this.qty, required this.avg});
}

// ─── Supporting models ───────────────────────────────────────────────────────
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
  int get totalQty => incomingDetails.fold(0, (s, item) => s + item.qty);
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

// ─── CONTROLLER ─────────────────────────────────────────────────────────────
class ShipmentController extends GetxController {
  final ProductController productController = Get.find<ProductController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VendorController vendorController = Get.put(VendorController());

  // ── STATE ──────────────────────────────────────────────────────────────────
  final RxList<ShipmentModel> allShipments = <ShipmentModel>[].obs;
  final RxList<ShipmentModel> filteredShipments = <ShipmentModel>[].obs;
  final RxList<AggregatedOnWayProduct> aggregatedList =
      <AggregatedOnWayProduct>[].obs;
  final RxList<OnHoldItem> onHoldItems = <OnHoldItem>[].obs;
  final RxList<OnHoldItem> filteredOnHoldItems = <OnHoldItem>[].obs;

  // PAGINATION
  final RxInt shipmentPage = 1.obs;
  final RxInt shipmentPageSize = 20.obs;

  // FILTERS
  final RxString filterCarrier = ''.obs;
  final RxString filterVendor = ''.obs;
  final RxString filterOnHoldCarrier = ''.obs;

  // MANIFEST LOCAL SEARCH
  final TextEditingController manifestSearchCtrl = TextEditingController();
  final RxString manifestSearchQuery = ''.obs;

  // CONFIG
  final List<String> carrierList = [
    "RH",
    "TRT",
    "GREEN",
    "DIAMOND",
    "RS",
    "Other",
  ];

  // MANIFEST INPUTS
  final RxList<ShipmentItem> currentManifestItems = <ShipmentItem>[].obs;
  final Rx<DateTime> purchaseDateInput = DateTime.now().obs;
  final Rxn<String> selectedVendorId = Rxn<String>();
  final Rxn<String> selectedVendorName = Rxn<String>();
  final Rxn<String> selectedCarrier = Rxn<String>();

  // TEXT CONTROLLERS
  final TextEditingController totalCartonCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController totalWeightCtrl = TextEditingController(
    text: '0',
  );
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

  // ── FORMATTERS ─────────────────────────────────────────────────────────────
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _rmbFormatter = NumberFormat('#,##0.00', 'en_US');

  String formatMoney(double amount) =>
      "BDT ${_currencyFormatter.format(amount)}";
  String formatRMB(double amount) => "¥ ${_rmbFormatter.format(amount)}";

  // ── COMPUTED GETTERS ───────────────────────────────────────────────────────
  int get currentManifestTotalQty =>
      currentManifestItems.fold(0, (s, i) => s + i.orderedQty);

  double get calculatedTotalWeight => currentManifestItems.fold(
    0.0,
    (s, i) => s + (i.unitWeightSnapshot * i.orderedQty),
  );

  double get currentManifestProductCost =>
      currentManifestItems.fold(0.0, (s, i) => s + i.totalItemCost);

  double get liveTotalCarrierCost {
    final cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
    final costPerCtn = double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
    return cartons * costPerCtn;
  }

  double get liveGrandTotal =>
      currentManifestProductCost + liveTotalCarrierCost;

  /// Carrier cost per unit across the ENTIRE current manifest.
  double get liveCarrierCostPerUnit {
    final qty = currentManifestTotalQty;
    return qty > 0 ? liveTotalCarrierCost / qty : 0;
  }

  // RMB equivalents
  double get _globalRate => double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;

  double get currentManifestProductCostRMB =>
      _globalRate > 0 ? currentManifestProductCost / _globalRate : 0.0;

  double get liveTotalCarrierCostRMB =>
      _globalRate > 0 ? liveTotalCarrierCost / _globalRate : 0.0;

  double get liveGrandTotalRMB =>
      _globalRate > 0 ? liveGrandTotal / _globalRate : 0.0;

  // Value displays
  double get totalOnWayValue => allShipments
      .where((s) => !s.isReceived)
      .fold(0.0, (s, item) => s + item.grandTotal);

  double get totalCompletedValue => allShipments
      .where((s) => s.isReceived)
      .fold(0.0, (s, item) => s + item.grandTotal);

  String get totalOnWayDisplay => formatMoney(totalOnWayValue);
  String get totalCompletedDisplay => formatMoney(totalCompletedValue);
  String get currentManifestTotalDisplay => formatMoney(liveGrandTotal);

  // Filtered manifest items
  List<ShipmentItem> get filteredManifestItems {
    if (manifestSearchQuery.value.isEmpty) return currentManifestItems;
    final q = manifestSearchQuery.value.toLowerCase();
    return currentManifestItems.where((item) {
      return item.productName.toLowerCase().contains(q) ||
          item.productModel.toLowerCase().contains(q) ||
          item.cartonNo.toLowerCase().contains(q);
    }).toList();
  }

  // Pagination
  List<ShipmentModel> get paginatedShipments {
    final start = (shipmentPage.value - 1) * shipmentPageSize.value;
    final end = (start + shipmentPageSize.value).clamp(
      0,
      filteredShipments.length,
    );
    if (start >= filteredShipments.length) return [];
    return filteredShipments.sublist(start, end);
  }

  int get totalPages =>
      filteredShipments.isEmpty
          ? 1
          : (filteredShipments.length / shipmentPageSize.value).ceil();

  // ── LIFECYCLE ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _bindFirestoreStream();
    _bindOnHoldStream();

    totalCartonCtrl.addListener(_updateCarrierCostDisplay);
    carrierCostPerCtnCtrl.addListener(_updateCarrierCostDisplay);

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
    manifestSearchCtrl.dispose();
    super.onClose();
  }

  void _updateCarrierCostDisplay() {
    final cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
    final costPerCtn = double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
    final total = cartons * costPerCtn;
    totalCarrierCostDisplayCtrl.text = total.toStringAsFixed(2);
    // Refresh manifest items to re-trigger carrier share calculations
    currentManifestItems.refresh();
  }

  // ── FIRESTORE STREAMS (Optimized) ─────────────────────────────────────────
  void _bindFirestoreStream() {
    _shipmentSubscription?.cancel();
    _shipmentSubscription = _firestore
        .collection('shipments')
        .orderBy('purchaseDate', descending: true)
        .limit(300) // Reduced from 500 for performance
        .snapshots()
        .listen((event) {
          final loaded =
              event.docs.map((e) => ShipmentModel.fromSnapshot(e)).toList();
          allShipments.value = loaded;
          _applyFilters();
          _calculateOnWayTotals(loaded);
          _aggregateOnWayData(loaded);
        }, onError: (e) => print("Shipment stream error: $e"));
  }

  void _bindOnHoldStream() {
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

  // Public alias for external refresh calls
  void bindFirestoreStream() => _bindFirestoreStream();
  void bindOnHoldStream() => _bindOnHoldStream();

  // ── FILTER HELPERS ─────────────────────────────────────────────────────────
  void _applyFilters() {
    var temp = List<ShipmentModel>.from(allShipments);
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
    final map = <int, int>{};
    for (final shipment in list) {
      if (shipment.isReceived) continue;
      for (final item in shipment.items) {
        map[item.productId] = (map[item.productId] ?? 0) + item.orderedQty;
      }
    }
    onWayStockMap.assignAll(map);
  }

  void _aggregateOnWayData(List<ShipmentModel> list) {
    final map = <int, AggregatedOnWayProduct>{};
    for (final shipment in list) {
      if (shipment.isReceived) continue;
      for (final item in shipment.items) {
        final qty = item.orderedQty;
        if (qty <= 0) continue;
        final detail = IncomingDetail(
          shipmentName: shipment.shipmentName,
          date: shipment.purchaseDate,
          qty: qty,
        );
        if (map.containsKey(item.productId)) {
          map[item.productId]!.incomingDetails.add(detail);
        } else {
          map[item.productId] = AggregatedOnWayProduct(
            productId: item.productId,
            model: item.productModel,
            name: item.productName,
            incomingDetails: [detail],
          );
        }
      }
    }
    aggregatedList.assignAll(map.values.toList());
  }

  // ── NAVIGATION HELPERS ────────────────────────────────────────────────────
  void onSearchChanged(String val) => productController.search(val);
  void nextPage() {
    if (shipmentPage.value < totalPages) shipmentPage.value++;
  }

  void prevPage() {
    if (shipmentPage.value > 1) shipmentPage.value--;
  }

  int getOnWayQty(int productId) => onWayStockMap[productId] ?? 0;

  // ── ACTIONS ───────────────────────────────────────────────────────────────

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
        final newId = await productController.createProductReturnId(createBody);
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
    currentManifestItems.refresh(); // triggers carrier share recalc in dialog
  }

  Future<void> saveShipmentToFirestore() async {
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
      final carrierCostPerCtn =
          double.tryParse(carrierCostPerCtnCtrl.text) ?? 0.0;
      final cartons = int.tryParse(totalCartonCtrl.text) ?? 0;
      final totalCarrierFee = carrierCostPerCtn * cartons;
      final exchangeRate = double.tryParse(globalExchangeRateCtrl.text) ?? 0.0;

      final shipmentName =
          shipmentNameCtrl.text.isEmpty
              ? "Shipment ${DateFormat('MM/dd').format(purchaseDateInput.value)}"
              : shipmentNameCtrl.text;

      final newShipment = ShipmentModel(
        shipmentName: shipmentName,
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

      final shipmentMap = newShipment.toMap();

      // Add RMB values
      if (exchangeRate > 0) {
        shipmentMap['totalAmountRMB'] =
            currentManifestProductCost / exchangeRate;
        shipmentMap['totalCarrierFeeRMB'] = totalCarrierFee / exchangeRate;
        shipmentMap['grandTotalRMB'] =
            (currentManifestProductCost + totalCarrierFee) / exchangeRate;
      }

      await _firestore.collection('shipments').add(shipmentMap);
      await vendorController.addAutomatedShipmentCredit(
        vendorId: newShipment.vendorId!,
        amount: newShipment.totalAmount,
        shipmentName: newShipment.shipmentName,
        date: newShipment.purchaseDate,
      );

      resetForm();
      Get.back();
      Get.snackbar(
        "Shipment Created",
        shipmentName,
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

  // ── EDIT MANIFEST ─────────────────────────────────────────────────────────
  Future<void> saveEditedManifest({
    required String docId,
    required List<ShipmentItem> newItems,
    required int newCartonCount,
    required double newCarrierRate,
    required String report,
  }) async {
    isLoading.value = true;
    try {
      final newTotalProductCost = newItems.fold(
        0.0,
        (s, i) => s + i.totalItemCost,
      );
      final newTotalWeight = newItems.fold(
        0.0,
        (s, i) => s + (i.unitWeightSnapshot * i.orderedQty),
      );
      final newTotalCarrierFee = newCartonCount * newCarrierRate;
      final newGrandTotal = newTotalProductCost + newTotalCarrierFee;

      // Fetch exchange rate to keep RMB values accurate
      double currentExchangeRate = 0.0;
      try {
        final doc = await _firestore.collection('shipments').doc(docId).get();
        if (doc.exists) {
          currentExchangeRate = (doc.data()?['exchangeRate'] ?? 0.0).toDouble();
        }
      } catch (_) {}

      final updateData = <String, dynamic>{
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
        "Updated",
        "Manifest recalculated successfully",
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
      final newTotalProductCost = updatedItems.fold(
        0.0,
        (s, i) => s + i.totalItemCost,
      );

      final updateMap = <String, dynamic>{
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
        "Saved",
        "Shipment details updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  // ── RECEIVE SHIPMENT ───────────────────────────────────────────────────────
  Future<void> receiveShipmentFast(
    ShipmentModel shipment,
    DateTime arrivalDate,
  ) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      // ── STEP 0: Snapshot current product data BEFORE stock changes ──────
      // This is critical for accurate weighted-average calculation.
      final priceSnapshots = <int, _PriceSnapshot>{};
      for (final item in shipment.items) {
        try {
          final p = productController.allProducts.firstWhere(
            (x) => x.id == item.productId,
          );
          priceSnapshots[item.productId] = _PriceSnapshot(
            qty: p.stockQty,
            // avgPurchasePrice is the `avg_purchase_price` field in Firestore.
            // Ensure your Product model maps this field correctly.
            avg: (p.avgPurchasePrice as num?)?.toDouble() ?? 0.0,
          );
        } catch (_) {
          // Product not found in local cache – skip (avg will use new cost)
        }
      }

      // ── STEP 1: Add stock to inventory ──────────────────────────────────
      final bulkItems =
          shipment.items
              .map(
                (item) => {
                  'id': item.productId,
                  'sea_qty': item.receivedSeaQty,
                  'air_qty': item.receivedAirQty,
                  'local_qty': 0,
                  'local_price': 0.0,
                  'shipmentdate': DateFormat('yyyy-MM-dd').format(arrivalDate),
                },
              )
              .toList();
      await productController.bulkAddStockMixed(bulkItems);

      // ── STEP 2: Update avg_purchase_price using WEIGHTED AVERAGE ─────────
      // Formula: new_avg = (oldQty * oldAvg + newQty * newCost) / (oldQty + newQty)
      // Cost includes carrier distribution per unit.
      await _updateAvgPurchasePrices(shipment, priceSnapshots);

      // ── STEP 3: Log on-hold (missing) items ─────────────────────────────
      final batch = _firestore.batch();
      bool hasLoss = false;
      for (final item in shipment.items) {
        final missing = item.lossQty;
        if (missing > 0 && !item.ignoreMissing) {
          hasLoss = true;
          final ref = _firestore.collection('on_hold_items').doc();
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

      // ── STEP 4: Mark shipment as received ────────────────────────────────
      final totalRecVal = shipment.items.fold(
        0.0,
        (s, i) => s + i.receivedItemValue,
      );
      final diff = shipment.totalAmount - totalRecVal;
      final diffRmb =
          shipment.exchangeRate > 0 ? diff / shipment.exchangeRate : 0.0;

      await _firestore.collection('shipments').doc(shipment.docId).update({
        'isReceived': true,
        'arrivalDate': Timestamp.fromDate(arrivalDate),
        'vendorLossAmount': diff > 0 ? diff : 0.0,
        'vendorLossAmountRMB': diff > 0 ? diffRmb : 0.0,
      });

      Get.back();
      Get.snackbar(
        "Received",
        "Shipment received & avg prices updated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.defaultDialog(title: "Error", middleText: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ── HELPER: Parse carton range string → number of cartons ────────────────
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
    // Single carton number like "3" → 1 carton
    return 1;
  }

  // ── PRIVATE: Weighted avg_purchase_price refinement at RECEIVE time ────────
  // The dialog already sets avg_purchase_price using ORDERED qty when the product
  // is added to the manifest. At receive time we REFINE it using ACTUAL received
  // qty, which corrects any discrepancy caused by missing/shorted items.
  //
  // Carrier cost is CARTON-BASED per item:
  //   item_carrier_cost = parseCartonCount(item.cartonNo) × carrierCostPerCarton
  //   carrier_per_unit  = item_carrier_cost / item.receivedQty
  // Weighted average:
  //   new_avg = (prevQty × prevAvg + newQty × newEffCost) / (prevQty + newQty)
  Future<void> _updateAvgPurchasePrices(
    ShipmentModel shipment,
    Map<int, _PriceSnapshot> snapshots,
  ) async {
    final futures = <Future<void>>[];

    for (final item in shipment.items) {
      final recvQty = item.receivedQty;
      if (recvQty <= 0) continue;

      // ── Carton-based carrier cost for THIS item ──────────────────────────
      final itemCartons = _parseCartonCount(item.cartonNo);
      final itemCarrierCost = itemCartons * shipment.carrierCostPerCarton;
      final carrierPerUnit = itemCarrierCost / recvQty;

      // ── Effective cost per unit (base price + carrier share) ─────────────
      final seaCost = item.seaPriceSnapshot + carrierPerUnit;
      final airCost = item.airPriceSnapshot + carrierPerUnit;

      final double newUnitCost;
      if (item.receivedSeaQty > 0 && item.receivedAirQty > 0) {
        // Mixed sea + air: weighted blend
        newUnitCost =
            (item.receivedSeaQty * seaCost + item.receivedAirQty * airCost) /
            recvQty;
      } else if (item.receivedSeaQty > 0) {
        newUnitCost = seaCost;
      } else {
        newUnitCost = airCost;
      }

      // ── Weighted average with EXISTING stock ─────────────────────────────
      final snap = snapshots[item.productId];
      final prevQty = snap?.qty ?? 0;
      final prevAvg = snap?.avg ?? 0.0;

      final double newAvg;
      if (prevQty > 0 && prevAvg > 0) {
        // Merge old stock avg with new cost
        newAvg =
            ((prevQty * prevAvg) + (recvQty * newUnitCost)) /
            (prevQty + recvQty);
      } else {
        // No existing stock (or avg was 0) → use new cost directly
        newAvg = newUnitCost;
      }

      // Only update the avg_purchase_price field — never touch other fields
      // Use direct Firestore update (not productController.updateProduct)
      // to guarantee only this single field is written, protecting all
      // other product fields from accidental overwrite.
      futures.add(
        _firestore
            .collection('products')
            .where('id', isEqualTo: item.productId)
            .limit(1)
            .get()
            .then((snap) {
              if (snap.docs.isNotEmpty) {
                return snap.docs.first.reference.update({
                  'avg_purchase_price': double.parse(newAvg.toStringAsFixed(4)),
                });
              }
            }),
      );
    }

    await Future.wait(futures, eagerError: false);
  }

  // ── ON-HOLD RESOLVE ───────────────────────────────────────────────────────
  Future<void> resolveOnHoldItem(OnHoldItem item) async {
    isLoading.value = true;
    try {
      await productController.addMixedStock(
        productId: item.productId,
        airQty: item.missingQty,
      );
      await _firestore.collection('on_hold_items').doc(item.docId).delete();
      Get.snackbar(
        "Resolved",
        "Item added to stock",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "$e");
    } finally {
      isLoading.value = false;
    }
  }

  // ── PDF GENERATION ────────────────────────────────────────────────────────
  Future<void> generatePdf(ShipmentModel shipment) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final totalReceivedVal = shipment.items.fold(
      0.0,
      (s, e) => s + e.receivedItemValue,
    );
    final totalRecWeight = shipment.items.fold(0.0, (s, e) {
      return s + (e.receivedQty * e.unitWeightSnapshot);
    });
    final valDiff = shipment.totalAmount - totalReceivedVal;
    final weightDiff = shipment.totalWeight - totalRecWeight;
    final exRate = shipment.exchangeRate;
    final carrierPerUnit = shipment.carrierCostPerOrderedUnit;

    double toRmb(double v) => exRate > 0 ? v / exRate : 0;

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
                        "Carrier/Unit: BDT ${carrierPerUnit.toStringAsFixed(2)}",
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

              // ITEMS TABLE
              pw.Table.fromTextArray(
                headers: [
                  'Ctn',
                  'Model',
                  'Name',
                  'Ord',
                  'Rec',
                  'Base Cost',
                  'Eff. Cost',
                  'Total',
                ],
                data:
                    shipment.items.map((e) {
                      final baseCost =
                          e.seaQty > 0
                              ? e.seaPriceSnapshot
                              : e.airPriceSnapshot;
                      final effCost = baseCost + carrierPerUnit;

                      String fmt(double v) =>
                          "BDT ${v.toStringAsFixed(2)}"
                          "${exRate > 0 ? '\n¥${toRmb(v).toStringAsFixed(2)}' : ''}";

                      return [
                        e.cartonNo,
                        e.productModel,
                        e.productName,
                        "${e.orderedQty}",
                        "${e.receivedQty}",
                        fmt(baseCost),
                        fmt(effCost),
                        fmt(e.totalItemCost),
                      ];
                    }).toList(),
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
                  1: const pw.FlexColumnWidth(1.4),
                  2: const pw.FlexColumnWidth(2.2),
                  3: const pw.FlexColumnWidth(0.7),
                  4: const pw.FlexColumnWidth(0.7),
                  5: const pw.FlexColumnWidth(1.4),
                  6: const pw.FlexColumnWidth(1.4),
                  7: const pw.FlexColumnWidth(1.5),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),

              // SUMMARY
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Weight
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
                          pw.SizedBox(height: 4),
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
                                          : PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Financial
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Product Total: ${formatMoney(shipment.totalAmount)}${exRate > 0 ? '  |  ${formatRMB(toRmb(shipment.totalAmount))}' : ''}",
                        ),
                        pw.Text(
                          "Carrier Fee: ${formatMoney(shipment.totalCarrierFee)}${exRate > 0 ? '  |  ${formatRMB(toRmb(shipment.totalCarrierFee))}' : ''}",
                        ),
                        pw.Text(
                          "GRAND TOTAL: ${formatMoney(shipment.grandTotal)}${exRate > 0 ? '  |  ${formatRMB(toRmb(shipment.grandTotal))}' : ''}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Received Value: ${formatMoney(totalReceivedVal)}${exRate > 0 ? '  |  ${formatRMB(toRmb(totalReceivedVal))}' : ''}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (valDiff.abs() > 1)
                          pw.Text(
                            valDiff > 0
                                ? "SHORTAGE: ${formatMoney(valDiff)}${exRate > 0 ? '  |  ${formatRMB(toRmb(valDiff))}' : ''}"
                                : "SURPLUS: ${formatMoney(valDiff.abs())}",
                            style: pw.TextStyle(
                              color:
                                  valDiff > 0 ? PdfColors.red : PdfColors.green,
                              fontWeight: pw.FontWeight.bold,
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
      onLayout: (f) => doc.save(),
      name: 'Manifest_${shipment.shipmentName}.pdf',
    );
  }

  Future<void> generateAggregatedOnWayPdf() async {
    if (aggregatedList.isEmpty) {
      Get.snackbar("Notice", "No on-way shipments to export.");
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
          final breakdown = product.incomingDetails
              .map(
                (d) =>
                    '${d.shipmentName} | ${DateFormat('MMM dd').format(d.date)} | ${d.qty} pcs',
              )
              .join('\n');
          return [
            product.model,
            product.name,
            product.totalQty.toString(),
            breakdown,
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
      onLayout: (f) async => pdf.save(),
      name: 'Incoming_${DateFormat('MMM_dd').format(DateTime.now())}.pdf',
    );
  }
}