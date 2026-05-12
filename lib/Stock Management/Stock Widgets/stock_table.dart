import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../Menubar and Navigation/app_pages.dart';
import '../../../Permission/permission_button.dart';
import '../../../Permission/permission_controller.dart';
import '../../../Shipment/controller.dart';
import '../../Core/Core Utils/activity_logger.dart';
import '../stock_controller.dart';
import '../stock_helper_dialogs.dart';
import '../stock_model.dart';

class StockScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class StockTable extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;
  final ShipmentController shipmentController;
  final ScrollController verticalScroll;
  final ScrollController horizontalScroll;

  const StockTable({
    super.key,
    required this.isMobile,
    required this.controller,
    required this.shipmentController,
    required this.verticalScroll,
    required this.horizontalScroll,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
      }

      if (controller.allProducts.isEmpty) {
        return const _EmptyState();
      }

      return ScrollConfiguration(
        behavior: StockScrollBehavior(),
        child: Scrollbar(
          controller: verticalScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: verticalScroll,
            child: Scrollbar(
              controller: horizontalScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1660,
                  child: Column(
                    children: [
                      const _TableHeader(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.allProducts.length,
                        itemBuilder: (context, index) {
                          final product = controller.allProducts[index];
                          final onWay = shipmentController.getOnWayQty(
                            product.id,
                          );

                          return _ProductRow(
                            product: product,
                            onWay: onWay,
                            controller: controller,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          _HeaderCell('MODEL', 180),
          _HeaderCell('PRODUCT', 150),
          _HeaderCell('STATUS', 80),
          _HeaderCell('TOTAL', 74),
          _HeaderCell('WAREHOUSE', 250),
          _HeaderCell('ON WAY', 76),
          _HeaderCell('SEA/AIR/LOCAL', 120),
          _HeaderCell('SHIP DATE', 100),
          _HeaderCell('AVG COST', 100),
          _HeaderCell('AGENT', 90),
          _HeaderCell('WHOLESALE', 100),
          _HeaderCell('PROFIT', 100),
          _HeaderCell('ACTIONS', 170),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: Color(0xFF64748B),
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final int onWay;
  final ProductController controller;

  const _ProductRow({
    required this.product,
    required this.onWay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _DataCell(
            Text(
              p.model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            180,
          ),
          _DataCell(_ProductNameCell(product: p), 150),
          _DataCell(_StockBadge(stock: p.stockQty, alert: p.alertQty), 80),
          _DataCell(_TotalStockCell(product: p), 74),
          _DataCell(
            _WarehouseCell(product: p, controller: controller),
            250,
          ),
          _DataCell(
            onWay > 0
                ? _MiniBadge(text: onWay.toString(), color: Colors.blue)
                : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
            76,
          ),
          _DataCell(
            Text(
              '${p.seaStockQty} / ${p.airStockQty} / ${p.localQty}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            120,
          ),
          _DataCell(
            Text(
              p.shipmentDate != null
                  ? DateFormat('yyyy-MM-dd').format(p.shipmentDate!)
                  : '-',
              style: const TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            100,
          ),
          _DataCell(_MoneyText(value: p.avgPurchasePrice), 100),
          _DataCell(_MoneyText(value: p.agent), 90),
          _DataCell(_MoneyText(value: p.wholesale), 100),
          _DataCell(_ProfitCell(product: p), 100),
          _DataCell(_ActionButtons(product: p, controller: controller), 170),
        ],
      ),
    );
  }
}

class _ProductNameCell extends StatelessWidget {
  final Product product;

  const _ProductNameCell({required this.product});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: product.name,
      child: Text(
        product.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TotalStockCell extends StatelessWidget {
  final Product product;

  const _TotalStockCell({required this.product});

  @override
  Widget build(BuildContext context) {
    final low = product.stockQty <= product.alertQty;

    return Text(
      product.stockQty.toString(),
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 14,
        color: low ? const Color(0xFFDC2626) : const Color(0xFF111827),
      ),
    );
  }
}

class _WarehouseCell extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _WarehouseCell({
    required this.product,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final stocks = product.warehouseStocks.where((e) => e.qty > 0).toList();

    if (stocks.isEmpty) {
      return Text(
        'No warehouse stock',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      );
    }

    final first = stocks.first;
    final extra = stocks.length - 1;

    return InkWell(
      onTap: () => Get.dialog(
        _WarehouseBreakdownDialog(product: product, controller: controller),
      ),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warehouse_rounded,
              size: 15,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${first.warehouseName}: ${first.qty}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            if (extra > 0)
              Text(
                '+$extra',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseBreakdownDialog extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _WarehouseBreakdownDialog({
    required this.product,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final rows = product.warehouseStocks.where((e) => e.qty > 0).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: Column(
          children: [
            _DialogHeader(
              title: '${product.model} warehouse stock',
              icon: Icons.warehouse_rounded,
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No warehouse breakdown available.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = rows[index];

                        return _WarehouseBreakdownTile(
                          product: product,
                          stock: item,
                          controller: controller,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseBreakdownTile extends StatelessWidget {
  final Product product;
  final ProductWarehouseStock stock;
  final ProductController controller;

  const _WarehouseBreakdownTile({
    required this.product,
    required this.stock,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.warehouseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stock.location.isEmpty ? 'No location set' : stock.location,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _MiniBadge(text: '${stock.qty} pcs', color: Colors.green),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Edit location',
            onPressed: () => _showEditLocationDialog(context),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context) {
    final locationCtrl = TextEditingController(text: stock.location);

    Get.dialog(
      AlertDialog(
        title: const Text('Update Warehouse Location'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: locationCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'Example: Rack A-3, Box 12',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              await controller.updateProductWarehouseLocation(
                productId: product.id,
                warehouseId: stock.warehouseId,
                location: locationCtrl.text.trim(),
              );

              await ActivityLogger.stockUpdated(
                '${product.model} location updated | Warehouse: ${stock.warehouseName}',
              );

              Get.back();
              Get.back();
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MoneyText extends StatelessWidget {
  final double value;

  const _MoneyText({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tk ${value.toStringAsFixed(1)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF047857),
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final Widget child;
  final double width;

  const _DataCell(this.child, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _ActionButtons({
    required this.product,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canCreate,
          showDisabled: true,
          child: IconButton(
            tooltip: 'Receive stock',
            onPressed: () => _showAddStockDialog(context, product),
            icon: const Icon(
              Icons.add_shopping_cart_rounded,
              color: Colors.teal,
              size: 20,
            ),
          ),
        ),
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canEdit,
          showDisabled: true,
          child: IconButton(
            tooltip: 'Edit product',
            onPressed: () async {
              showEditProductDialog(product, controller);
              await ActivityLogger.stockUpdated(
                'Editing: ${product.model} | ${product.name}',
              );
            },
            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
          ),
        ),
        _MoreOptionsButton(product: product, controller: controller),
      ],
    );
  }

  void _showAddStockDialog(BuildContext context, Product product) {
    final seaQtyC = TextEditingController(text: '0');
    final airQtyC = TextEditingController(text: '0');
    final localQtyC = TextEditingController(text: '0');
    final localPriceC = TextEditingController(text: '0');
    final locationC = TextEditingController();
    final selectedDate = Rx<DateTime?>(null);
    final predictedAvg = product.avgPurchasePrice.obs;
    final selectedWarehouseId = RxnInt();

    final activeWarehouses = controller.activeWarehouses;

    if (activeWarehouses.isNotEmpty) {
      selectedWarehouseId.value = _parseInt(activeWarehouses.first['id']);
    }

    void calcPrediction() {
      final sea = int.tryParse(seaQtyC.text) ?? 0;
      final air = int.tryParse(airQtyC.text) ?? 0;
      final local = int.tryParse(localQtyC.text) ?? 0;
      final localPrice = double.tryParse(localPriceC.text) ?? 0.0;

      final oldValue = product.stockQty * product.avgPurchasePrice;
      final seaCost =
          (product.yuan * product.currency) + (product.weight * product.shipmentTax);
      final airCost =
          (product.yuan * product.currency) + (product.weight * product.shipmentTaxAir);
      final newBatch = (sea * seaCost) + (air * airCost) + (local * localPrice);
      final totalQty = product.stockQty + sea + air + local;

      if (totalQty > 0) {
        predictedAvg.value = (oldValue + newBatch) / totalQty;
      } else {
        predictedAvg.value = product.avgPurchasePrice;
      }
    }

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
          child: Column(
            children: [
              _DialogHeader(
                title: 'Receive Stock: ${product.model}',
                icon: Icons.add_shopping_cart_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => _InfoStrip(
                          text:
                              'Predicted avg cost: Tk ${predictedAvg.value.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel('Stock type'),
                      Row(
                        children: [
                          Expanded(
                            child: _QtyField(
                              label: 'Sea Qty',
                              controller: seaQtyC,
                              icon: Icons.waves_rounded,
                              onChanged: calcPrediction,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QtyField(
                              label: 'Air Qty',
                              controller: airQtyC,
                              icon: Icons.flight_rounded,
                              onChanged: calcPrediction,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _QtyField(
                              label: 'Local Qty',
                              controller: localQtyC,
                              icon: Icons.store_rounded,
                              onChanged: calcPrediction,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QtyField(
                              label: 'Local Price',
                              controller: localPriceC,
                              icon: Icons.payments_rounded,
                              onChanged: calcPrediction,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('Warehouse'),
                      Obx(
                        () => DropdownButtonFormField<int>(
                          value: selectedWarehouseId.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select warehouse',
                            prefixIcon: Icon(Icons.warehouse_rounded),
                          ),
                          items: activeWarehouses.map((warehouse) {
                            final id = _parseInt(warehouse['id']);
                            final name =
                                warehouse['name']?.toString() ?? 'Warehouse $id';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => selectedWarehouseId.value = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationC,
                        decoration: const InputDecoration(
                          labelText: 'Product location inside warehouse',
                          hintText: 'Example: Rack A-3, Box 12',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('Shipment'),
                      Obx(
                        () => InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: Get.context!,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );

                            if (picked != null) selectedDate.value = picked;
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Shipment date optional',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              selectedDate.value == null
                                  ? 'Select date'
                                  : DateFormat('dd MMM yyyy')
                                      .format(selectedDate.value!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: Get.back, child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    Obx(() {
                      return FilledButton.icon(
                        onPressed: controller.isActionLoading.value
                            ? null
                            : () async {
                                final sea = int.tryParse(seaQtyC.text) ?? 0;
                                final air = int.tryParse(airQtyC.text) ?? 0;
                                final local = int.tryParse(localQtyC.text) ?? 0;
                                final price =
                                    double.tryParse(localPriceC.text) ?? 0.0;

                                if (sea <= 0 && air <= 0 && local <= 0) {
                                  Get.snackbar(
                                    'Stock',
                                    'Enter at least one quantity',
                                    backgroundColor: Colors.orange,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }

                                await controller.addMixedStock(
                                  productId: product.id,
                                  seaQty: sea,
                                  airQty: air,
                                  localQty: local,
                                  localUnitPrice: price,
                                  shipmentDate: selectedDate.value,
                                  warehouseId: selectedWarehouseId.value,
                                  warehouseLocation: locationC.text.trim(),
                                );

                                await ActivityLogger.stockUpdated(
                                  '${product.model} | Sea: $sea, Air: $air, Local: $local',
                                );

                                Get.back();
                              },
                        icon: controller.isActionLoading.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                        label: const Text('Confirm Receive'),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreOptionsButton extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _MoreOptionsButton({
    required this.product,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey[700]),
      onSelected: (value) => _handleAction(context, value),
      itemBuilder: (_) => [
        if (_hasEditPermission())
          const PopupMenuItem(
            value: 'transfer',
            child: _MenuAction(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer Warehouse',
              color: Color(0xFF2563EB),
            ),
          ),
        if (_hasEditPermission())
          const PopupMenuItem(
            value: 'service',
            child: _MenuAction(
              icon: Icons.handyman_rounded,
              label: 'Send to Service',
            ),
          ),
        if (_hasEditPermission())
          const PopupMenuItem(
            value: 'damage',
            child: _MenuAction(
              icon: Icons.broken_image_rounded,
              label: 'Mark as Damage',
              color: Colors.orange,
            ),
          ),
        if (_hasDeletePermission())
          const PopupMenuItem(
            value: 'delete',
            child: _MenuAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Product',
              color: Colors.redAccent,
            ),
          ),
      ],
    );
  }

  bool _hasEditPermission() {
    try {
      return Get.find<PermissionController>().canEdit(Routes.stock);
    } catch (_) {
      return true;
    }
  }

  bool _hasDeletePermission() {
    try {
      return Get.find<PermissionController>().canDelete(Routes.stock);
    } catch (_) {
      return true;
    }
  }

  void _handleAction(BuildContext context, String value) {
    if (value == 'transfer') {
      _showTransferDialog(context);
      return;
    }

    if (value == 'service') {
      _showQtyDialog(context, 'Service', Colors.orange, (qty, warehouseId) async {
        await controller.addToService(
          productId: product.id,
          model: product.model,
          qty: qty,
          type: 'service',
          currentAvgPrice: product.avgPurchasePrice,
          warehouseId: warehouseId,
        );

        await ActivityLogger.log(
          action: 'SERVICE_STOCK',
          module: 'Stock',
          details: '${product.model} to Service | Qty: $qty',
        );
      });
      return;
    }

    if (value == 'damage') {
      _showQtyDialog(context, 'Damage', Colors.redAccent, (qty, warehouseId) async {
        await controller.addToService(
          productId: product.id,
          model: product.model,
          qty: qty,
          type: 'damage',
          currentAvgPrice: product.avgPurchasePrice,
          warehouseId: warehouseId,
        );

        await ActivityLogger.log(
          action: 'DAMAGE_STOCK',
          module: 'Stock',
          details: '${product.model} to Damage | Qty: $qty',
        );
      });
      return;
    }

    if (value == 'delete') {
      showDeleteConfirmDialog(product.id, controller);
      ActivityLogger.stockDeleted('${product.model} | ${product.name}');
    }
  }

  void _showQtyDialog(
    BuildContext context,
    String title,
    Color color,
    Future<void> Function(int qty, int? warehouseId) onConfirm,
  ) {
    final qtyCtrl = TextEditingController();
    final selectedWarehouseId = RxnInt();

    final availableSources =
        product.warehouseStocks.where((item) => item.qty > 0).toList();

    if (availableSources.isNotEmpty) {
      selectedWarehouseId.value = availableSources.first.warehouseId;
    }

    Get.dialog(
      AlertDialog(
        title: Text('$title Item'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${product.model} | Stock: ${product.stockQty}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => DropdownButtonFormField<int>(
                  value: selectedWarehouseId.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Deduct from warehouse',
                    prefixIcon: Icon(Icons.warehouse_rounded),
                  ),
                  items: availableSources.map((item) {
                    return DropdownMenuItem<int>(
                      value: item.warehouseId,
                      child: Text(
                        '${item.warehouseName} (${item.qty} pcs)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => selectedWarehouseId.value = value,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              final warehouseId = selectedWarehouseId.value;
              final source = availableSources.firstWhereOrNull(
                (item) => item.warehouseId == warehouseId,
              );

              if (warehouseId == null || source == null) {
                Get.snackbar(
                  'Error',
                  'Please select a warehouse',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              if (qty <= 0 || qty > source.qty) {
                Get.snackbar(
                  'Error',
                  'Invalid quantity',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              await onConfirm(qty, warehouseId);
              Get.back();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final qtyCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final availableSources =
        product.warehouseStocks.where((item) => item.qty > 0).toList();
    final activeWarehouses = controller.activeWarehouses;

    final fromWarehouseId = RxnInt();
    final toWarehouseId = RxnInt();

    if (availableSources.isNotEmpty) {
      fromWarehouseId.value = availableSources.first.warehouseId;
    }

    final firstDestination = activeWarehouses.firstWhereOrNull((warehouse) {
      final id = _parseInt(warehouse['id']);
      return id != fromWarehouseId.value;
    });

    if (firstDestination != null) {
      toWarehouseId.value = _parseInt(firstDestination['id']);
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Transfer Warehouse Stock'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${product.model} | ${product.name}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Obx(
                () => DropdownButtonFormField<int>(
                  value: fromWarehouseId.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'From warehouse',
                    prefixIcon: Icon(Icons.output_rounded),
                  ),
                  items: availableSources.map((item) {
                    return DropdownMenuItem<int>(
                      value: item.warehouseId,
                      child: Text(
                        '${item.warehouseName} (${item.qty} pcs)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => fromWarehouseId.value = value,
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => DropdownButtonFormField<int>(
                  value: toWarehouseId.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'To warehouse',
                    prefixIcon: Icon(Icons.input_rounded),
                  ),
                  items: activeWarehouses.map((warehouse) {
                    final id = _parseInt(warehouse['id']);
                    final name = warehouse['name']?.toString() ?? 'Warehouse $id';

                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) => toWarehouseId.value = value,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Transfer quantity',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Destination location',
                  hintText: 'Example: Rack B-2',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              final fromId = fromWarehouseId.value;
              final toId = toWarehouseId.value;
              final qty = int.tryParse(qtyCtrl.text) ?? 0;

              if (fromId == null || toId == null) {
                Get.snackbar(
                  'Error',
                  'Please select both warehouses',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              if (fromId == toId) {
                Get.snackbar(
                  'Error',
                  'Source and destination cannot be same',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              final source = availableSources.firstWhereOrNull(
                (item) => item.warehouseId == fromId,
              );

              if (source == null || qty <= 0 || qty > source.qty) {
                Get.snackbar(
                  'Error',
                  'Invalid transfer quantity',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              await controller.transferWarehouseStock(
                productId: product.id,
                fromWarehouseId: fromId,
                toWarehouseId: toId,
                qty: qty,
                toLocation: locationCtrl.text.trim(),
              );

              await ActivityLogger.log(
                action: 'TRANSFER_WAREHOUSE_STOCK',
                module: 'Stock',
                details:
                    '${product.model} | Qty: $qty | From: $fromId | To: $toId',
              );

              Get.back();
            },
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Transfer'),
          ),
        ],
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuAction({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF475569),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _QtyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final VoidCallback onChanged;

  const _QtyField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2563EB),
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final String text;

  const _InfoStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2563EB),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _DialogHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ProfitCell extends StatelessWidget {
  final Product product;

  const _ProfitCell({required this.product});

  @override
  Widget build(BuildContext context) {
    final agentProfit = product.agent - product.avgPurchasePrice;
    final wholesaleProfit = product.wholesale - product.avgPurchasePrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfitLine(label: 'A', value: agentProfit),
        const SizedBox(height: 2),
        _ProfitLine(label: 'W', value: wholesaleProfit),
      ],
    );
  }
}

class _ProfitLine extends StatelessWidget {
  final String label;
  final double value;

  const _ProfitLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final loss = value < 0;

    return Text(
      '$label ${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)}',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        color: loss ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final MaterialColor color;

  const _MiniBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade800,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  final int alert;

  const _StockBadge({
    required this.stock,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final low = stock <= alert;

    return _MiniBadge(
      text: low ? 'LOW' : 'OK',
      color: low ? Colors.red : Colors.green,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 58,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'No products found',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
