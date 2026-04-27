// ignore_for_file: deprecated_member_use, avoid_print
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import '../Core/Stock Management/stock_controller.dart';
import 'shipmodel.dart';

/// Shows the shipment entry dialog for adding/editing a product in the manifest.
///
/// The dialog now shows:
///   • Base sea/air cost (calculated from yuan × rate + weight × tax)
///   • Carrier share per unit (based on total manifest carrier cost ÷ total units)
///   • Effective sea/air landing cost (base + carrier share) — what the product
///     actually costs you including shipping, for setting agent/wholesale prices
void showShipmentEntryDialog(
  Product? p,
  ShipmentController shipCtrl,
  ProductController prodCtrl,
  double globalRate, {
  Function(ShipmentItem)? onSubmit,
}) {
  final isNewProduct = p == null;

  // ── CONTROLLERS ────────────────────────────────────────────────────────────
  final nameC = TextEditingController(text: p?.name ?? '');
  final categoryC = TextEditingController(
    text: p?.category ?? 'Mobile Accessories',
  );
  final brandC = TextEditingController(text: p?.brand ?? '');
  final modelC = TextEditingController(text: p?.model ?? '');

  final double effectiveRate =
      globalRate > 0 ? globalRate : (p?.currency ?? 18.20);
  final weightC = TextEditingController(text: (p?.weight ?? 0.0).toString());
  final yuanC = TextEditingController(text: (p?.yuan ?? 0.0).toString());
  final currencyC = TextEditingController(text: effectiveRate.toString());
  final seaTaxC = TextEditingController(
    text: (p?.shipmentTax ?? 550.0).toString(),
  );
  final airTaxC = TextEditingController(
    text: (p?.shipmentTaxAir ?? 1200.0).toString(),
  );

  // Base prices (calculated, read-only)
  final double initSea =
      isNewProduct
          ? 0.0
          : (p.yuan * effectiveRate) + (p.weight * p.shipmentTax);
  final double initAir =
      isNewProduct
          ? 0.0
          : (p.yuan * effectiveRate) + (p.weight * p.shipmentTaxAir);
  final seaPriceC = TextEditingController(text: initSea.toStringAsFixed(2));
  final airPriceC = TextEditingController(text: initAir.toStringAsFixed(2));

  // Effective prices including carrier share (read-only display)
  final effSeaC = TextEditingController(text: initSea.toStringAsFixed(2));
  final effAirC = TextEditingController(text: initAir.toStringAsFixed(2));
  final carrierShareC = TextEditingController(text: '0.00');

  // Avg purchase price tracking
  final existingAvg =
      isNewProduct ? 0.0 : ((p.avgPurchasePrice as num?)?.toDouble() ?? 0.0);
  final existingStock = isNewProduct ? 0 : (p.stockQty);
  final newAvgC = TextEditingController(
    text: existingAvg > 0 ? existingAvg.toStringAsFixed(2) : '0.00',
  );

  // Sales & manifest
  final agentC = TextEditingController(text: (p?.agent ?? 0).toString());
  final wholesaleC = TextEditingController(
    text: (p?.wholesale ?? 0).toString(),
  );
  final alertQtyC = TextEditingController(text: (p?.alertQty ?? 5).toString());
  final addSeaQtyC = TextEditingController(text: '0');
  final addAirQtyC = TextEditingController(text: '0');
  final cartonNoC = TextEditingController();

  // Stock reference
  final oldSeaStock = p?.seaStockQty ?? 0;
  final oldAirStock = p?.airStockQty ?? 0;
  final oldLocalStock = p?.localQty ?? 0;
  final onWayQty = isNewProduct ? 0 : shipCtrl.getOnWayQty(p.id);

  // Carrier cost for THIS item = parseCartonCount(cartonNo) x cost_per_carton
  // Carrier per unit = item_carrier_cost / this_item_qty
  // Example: cost/carton=50, cartonNo="1-3" (3 cartons), qty=10
  //   item carrier = 150tk  =>  per unit = 15tk/unit
  int parseCartonCount(String cartonNo) {
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

  void recalculateAll() {
    final yuan = double.tryParse(yuanC.text) ?? 0.0;
    final weight = double.tryParse(weightC.text) ?? 0.0;
    final curr = double.tryParse(currencyC.text) ?? 0.0;
    final sTax = double.tryParse(seaTaxC.text) ?? 0.0;
    final aTax = double.tryParse(airTaxC.text) ?? 0.0;

    final baseSea = (yuan * curr) + (weight * sTax);
    final baseAir = (yuan * curr) + (weight * aTax);
    seaPriceC.text = baseSea.toStringAsFixed(2);
    airPriceC.text = baseAir.toStringAsFixed(2);

    // Carton-based carrier share for THIS item only
    final thisSeaQty = int.tryParse(addSeaQtyC.text) ?? 0;
    final thisAirQty = int.tryParse(addAirQtyC.text) ?? 0;
    final thisQty = thisSeaQty + thisAirQty;
    final costPerCarton =
        double.tryParse(shipCtrl.carrierCostPerCtnCtrl.text) ?? 0.0;
    final itemCartons = parseCartonCount(cartonNoC.text);
    final itemCarrierCost = itemCartons * costPerCarton;
    final share = thisQty > 0 ? itemCarrierCost / thisQty : 0.0;

    final effSea = baseSea + share;
    final effAir = baseAir + share;

    carrierShareC.text = share.toStringAsFixed(2);
    effSeaC.text = effSea.toStringAsFixed(2);
    effAirC.text = effAir.toStringAsFixed(2);

    // ── Live weighted avg_purchase_price calculation ──────────────────────
    // Formula: (existingStock x existingAvg + newQty x effectiveCost)
    //          / (existingStock + newQty)
    // effectiveCost = blended effective cost based on sea/air qty split
    if (!isNewProduct) {
      double newEffCost;
      if (thisSeaQty > 0 && thisAirQty > 0) {
        newEffCost = (thisSeaQty * effSea + thisAirQty * effAir) / thisQty;
      } else if (thisSeaQty > 0) {
        newEffCost = effSea;
      } else if (thisAirQty > 0) {
        newEffCost = effAir;
      } else {
        newEffCost = effSea > 0 ? effSea : effAir;
      }

      double projectedAvg;
      if (existingStock > 0 && existingAvg > 0 && thisQty > 0) {
        projectedAvg =
            ((existingStock * existingAvg) + (thisQty * newEffCost)) /
            (existingStock + thisQty);
      } else if (thisQty > 0) {
        projectedAvg = newEffCost;
      } else {
        projectedAvg = existingAvg;
      }

      newAvgC.text = projectedAvg.toStringAsFixed(2);
    }
  }

  // Bind all listeners -- cartonNoC included so share updates as user types
  for (final ctrl in [
    yuanC,
    weightC,
    currencyC,
    seaTaxC,
    airTaxC,
    addSeaQtyC,
    addAirQtyC,
    cartonNoC,
  ]) {
    ctrl.addListener(recalculateAll);
  }

  // Initial calculation
  recalculateAll();

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 880),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── HEADER ────────────────────────────────────────────────────
            _DialogHeader(
              isNewProduct: isNewProduct,
              productModel: p?.model ?? '',
              onWayQty: onWayQty,
            ),

            // ── BODY ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Identity
                    _sectionLabel("IDENTITY"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(
                            modelC,
                            "Model No.",
                            autoFocus: isNewProduct,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(nameC, "Product Name")),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(brandC, "Brand")),
                        const SizedBox(width: 12),
                        Expanded(child: _erpInput(categoryC, "Category")),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 2: Costing Parameters
                    _sectionLabel("COSTING PARAMETERS"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(yuanC, "Yuan (¥)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(currencyC, "Rate", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(weightC, "Weight (KG)", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(seaTaxC, "Sea Tax", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(airTaxC, "Air Tax", isNum: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 3: Landing Costs + Carrier Share + Effective Costs
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Base landing costs
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("BASE LANDING COST"),
                              Row(
                                children: [
                                  Expanded(
                                    child: _erpReadOnly(
                                      seaPriceC,
                                      "Sea Cost",
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _erpReadOnly(
                                      airPriceC,
                                      "Air Cost",
                                      Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Carrier share indicator
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("CARRIER SHARE"),
                              _erpReadOnly(
                                carrierShareC,
                                "Per Unit",
                                Colors.purple,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Effective (all-in) costs
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("EFFECTIVE COST (BASE + CARRIER)"),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _erpReadOnly(
                                        effSeaC,
                                        "Eff. Sea",
                                        Colors.green[700]!,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _erpReadOnly(
                                        effAirC,
                                        "Eff. Air",
                                        Colors.green[800]!,
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
                    const SizedBox(height: 4),
                    // Info text about carrier share — reactive via ValueListenableBuilder
                    // on carrierShareC (updated by recalculateAll) so no Obx needed here.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: carrierShareC,
                      builder: (_, val, __) {
                        final share = double.tryParse(val.text) ?? 0.0;
                        final costPerCarton =
                            double.tryParse(
                              shipCtrl.carrierCostPerCtnCtrl.text,
                            ) ??
                            0.0;
                        if (share <= 0 || costPerCarton <= 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: Colors.purple[400],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "BDT ${costPerCarton.toStringAsFixed(2)}/carton  •  "
                                  "BDT ${share.toStringAsFixed(2)}/unit carrier share",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple[400],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ROW 4: Sales Prices
                    _sectionLabel("SALES PRICES"),
                    Row(
                      children: [
                        Expanded(
                          child: _erpInput(agentC, "Agent Price", isNum: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(
                            wholesaleC,
                            "Wholesale Price",
                            isNum: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _erpInput(alertQtyC, "Alert Qty", isNum: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ROW 5: Manifest Entry
                    _sectionLabel("MANIFEST ENTRY"),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _erpInput(
                              addSeaQtyC,
                              "Sea Qty",
                              isNum: true,
                              bgColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _erpInput(
                              addAirQtyC,
                              "Air Qty",
                              isNum: true,
                              bgColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _erpInput(
                              cartonNoC,
                              "Carton No",
                              bgColor: Colors.white,
                              hint: "e.g. 1-3",
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!isNewProduct) ...[
                      const SizedBox(height: 12),

                      // ── AVG PRICE PANEL ──────────────────────────────────
                      // Shows current avg price and live projected new avg
                      // after this shipment is added.
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: newAvgC,
                        builder: (_, val, __) {
                          final projected = double.tryParse(val.text) ?? 0.0;
                          final hasChange =
                              (projected - existingAvg).abs() > 0.01;
                          final isIncrease = projected > existingAvg;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.analytics_outlined,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 10),
                                // Current avg
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "CURRENT AVG PRICE",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      existingAvg > 0
                                          ? "BDT ${existingAvg.toStringAsFixed(2)}"
                                          : "Not set",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Arrow
                                Icon(
                                  Icons.arrow_forward,
                                  color:
                                      hasChange
                                          ? (isIncrease
                                              ? Colors.redAccent
                                              : Colors.greenAccent)
                                          : Colors.white38,
                                  size: 18,
                                ),
                                const SizedBox(width: 16),
                                // New projected avg
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "NEW AVG PRICE",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      projected > 0
                                          ? "BDT ${projected.toStringAsFixed(2)}"
                                          : "—",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            hasChange
                                                ? (isIncrease
                                                    ? Colors.redAccent[100]!
                                                    : Colors.greenAccent[200]!)
                                                : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Change indicator
                                if (hasChange)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isIncrease
                                              ? Colors.red.withOpacity(0.25)
                                              : Colors.green.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${isIncrease ? '▲' : '▼'} "
                                      "${(projected - existingAvg).abs().toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isIncrease
                                                ? Colors.redAccent[100]!
                                                : Colors.greenAccent[200]!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // ── STOCK INFO ROW ───────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "STOCK:  SEA: $oldSeaStock  |  AIR: $oldAirStock  "
                              "|  LOCAL: $oldLocalStock  |  ON WAY: $onWayQty  "
                              "|  TOTAL: ${oldSeaStock + oldAirStock + oldLocalStock}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── FOOTER ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                color: Colors.grey[50],
              ),
              child: Obx(() {
                final loading = shipCtrl.isLoading.value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: loading ? null : () => Get.back(),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: loading ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          loading
                              ? null
                              : () async {
                                if (modelC.text.isEmpty || nameC.text.isEmpty) {
                                  Get.snackbar(
                                    "Required",
                                    "Model and Name are required",
                                    backgroundColor: Colors.redAccent,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }

                                final sCost =
                                    double.tryParse(seaPriceC.text) ?? 0.0;
                                final aCost =
                                    double.tryParse(airPriceC.text) ?? 0.0;
                                final sQty = int.tryParse(addSeaQtyC.text) ?? 0;
                                final aQty = int.tryParse(addAirQtyC.text) ?? 0;

                                final data = <String, dynamic>{
                                  'name': nameC.text,
                                  'category': categoryC.text,
                                  'brand': brandC.text,
                                  'model': modelC.text,
                                  'yuan': double.tryParse(yuanC.text) ?? 0.0,
                                  'weight':
                                      double.tryParse(weightC.text) ?? 0.0,
                                  'currency':
                                      double.tryParse(currencyC.text) ?? 0.0,
                                  'shipmenttax':
                                      double.tryParse(seaTaxC.text) ?? 0.0,
                                  'shipmenttaxair':
                                      double.tryParse(airTaxC.text) ?? 0.0,
                                  'sea': sCost,
                                  'air': aCost,
                                  // avg_purchase_price for existing products is preserved
                                  // below. It is recalculated at RECEIVE time only.
                                  'agent': double.tryParse(agentC.text) ?? 0.0,
                                  'wholesale':
                                      double.tryParse(wholesaleC.text) ?? 0.0,
                                  'alert_qty':
                                      int.tryParse(alertQtyC.text) ?? 5,
                                };

                                if (!isNewProduct) {
                                  // Preserve stock quantities
                                  data['stock_qty'] = p.stockQty;
                                  data['sea_stock_qty'] = p.seaStockQty;
                                  data['air_stock_qty'] = p.airStockQty;
                                  data['local_qty'] = p.localQty;

                                  // Save the live-calculated new avg price immediately.
                                  // This is the weighted average of existing stock + new
                                  // shipment qty at the effective cost (base + carrier share).
                                  // Formula: (existingStock x existingAvg + newQty x effCost)
                                  //          / (existingStock + newQty)
                                  final computedAvg =
                                      double.tryParse(newAvgC.text) ?? 0.0;
                                  if (computedAvg > 0) {
                                    data['avg_purchase_price'] = computedAvg;
                                  }
                                } else {
                                  data['stock_qty'] = 0;
                                  data['sea_stock_qty'] = 0;
                                  data['air_stock_qty'] = 0;
                                  data['local_qty'] = 0;
                                  // For new products, avg price = effective sea cost
                                  final effSea =
                                      double.tryParse(effSeaC.text) ?? 0.0;
                                  final effAir =
                                      double.tryParse(effAirC.text) ?? 0.0;
                                  final initAvg = effSea > 0 ? effSea : effAir;
                                  if (initAvg > 0) {
                                    data['avg_purchase_price'] = initAvg;
                                  }
                                }

                                if (onSubmit != null) {
                                  // Edit mode: synchronous local update
                                  final newItem = ShipmentItem(
                                    productId: isNewProduct ? 0 : p.id,
                                    productName: nameC.text,
                                    productModel: modelC.text,
                                    productBrand: brandC.text,
                                    productCategory: categoryC.text,
                                    unitWeightSnapshot:
                                        double.tryParse(weightC.text) ?? 0,
                                    seaQty: 0,
                                    airQty: 0,
                                    receivedSeaQty: sQty,
                                    receivedAirQty: aQty,
                                    cartonNo: cartonNoC.text,
                                    seaPriceSnapshot: sCost,
                                    airPriceSnapshot: aCost,
                                    ignoreMissing: true,
                                  );
                                  onSubmit(newItem);
                                  Get.back();
                                } else {
                                  // Add new: async via controller
                                  await shipCtrl.addToManifestAndVerify(
                                    productId: isNewProduct ? null : p.id,
                                    productData: data,
                                    seaQty: sQty,
                                    airQty: aQty,
                                    cartonNo: cartonNoC.text,
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isNewProduct
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF1E293B),
                        disabledBackgroundColor: Colors.grey[400],
                        minimumSize: const Size(160, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon:
                          loading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Icon(
                                isNewProduct ? Icons.add_circle : Icons.check,
                                size: 18,
                              ),
                      label: Text(
                        loading
                            ? "Processing..."
                            : (isNewProduct ? "CREATE & ADD" : "UPDATE & ADD"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// ── HEADER WIDGET ────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final bool isNewProduct;
  final String productModel;
  final int onWayQty;
  const _DialogHeader({
    required this.isNewProduct,
    required this.productModel,
    required this.onWayQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isNewProduct ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            isNewProduct ? Icons.add_circle_outline : Icons.edit_outlined,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            isNewProduct
                ? "NEW PRODUCT ENTRY"
                : "EDIT: ${productModel.toUpperCase()}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          if (!isNewProduct && onWayQty > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sailing, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "$onWayQty on way",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── REUSABLE INPUT WIDGETS ────────────────────────────────────────────────────
Widget _sectionLabel(String title) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Colors.grey,
      letterSpacing: 0.5,
    ),
  ),
);

Widget _erpInput(
  TextEditingController ctrl,
  String label, {
  bool isNum = false,
  bool autoFocus = false,
  Color? bgColor,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 36,
        child: TextField(
          controller: ctrl,
          autofocus: autoFocus,
          keyboardType:
              isNum
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            filled: true,
            fillColor: bgColor ?? Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _erpReadOnly(TextEditingController ctrl, String label, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: TextField(
          controller: ctrl,
          readOnly: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
    ],
  );
}