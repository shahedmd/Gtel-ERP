import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import 'package:intl/intl.dart';
import '../../../Menubar and Navigation/app_pages.dart';
import '../../../Permission/permission_button.dart';
import '../../../Permission/permission_controller.dart';
import '../../../Shipment/controller.dart';
import '../../Core Utils/activity_logger.dart';
import '../stock_controller.dart';
import '../stock_helper_dialogs.dart';

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
        return const Center(child: CircularProgressIndicator());
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
                  width: 1300,
                  child: Column(
                    children: [
                      const _TableHeader(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.allProducts.length,
                        itemBuilder: (context, i) {
                          final p = controller.allProducts[i];
                          final onWay = shipmentController.getOnWayQty(p.id);
                          return _ProductRow(
                            product: p,
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

// ── Table Header ─────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: const Row(
        children: [
          _HeaderCell('MODEL', 120),
          _HeaderCell('NAME', 180),
          _HeaderCell('STATUS', 80),
          _HeaderCell('PROFIT', 100),
          _HeaderCell('STOCK', 80),
          _HeaderCell('ON WAY', 80),
          _HeaderCell('SHIP DATE', 80),
          _HeaderCell('SEA / AIR', 100),
          _HeaderCell('AVG COST', 100),
          _HeaderCell('AGENT', 100),
          _HeaderCell('WHOLESALE', 100),
          _HeaderCell('ACTIONS', 140),
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
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Product Row ──────────────────────────────────────────────
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          _DataCell(
            Text(
              p.model,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            120,
          ),
          _DataCell(
            Text(
              p.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
            ),
            180,
          ),
          _DataCell(_StockBadge(stock: p.stockQty, alert: p.alertQty), 80),
          _DataCell(_ProfitCell(product: p), 100),
          _DataCell(
            Text(
              p.stockQty.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: p.stockQty <= p.alertQty ? Colors.red : Colors.black,
              ),
            ),
            80,
          ),
          _DataCell(
            onWay > 0
                ? _Badge(text: onWay.toString(), color: Colors.blue)
                : const Text('-', style: TextStyle(color: Colors.grey)),
            80,
          ),
          _DataCell(
            Text(
              p.shipmentDate != null
                  ? DateFormat('yyyy-MM-dd').format(p.shipmentDate!)
                  : 'No date',
              style: const TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            80,
          ),
          _DataCell(
            Text(
              '${p.seaStockQty} / ${p.airStockQty}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            100,
          ),
          _DataCell(
            Text(
              '৳${p.avgPurchasePrice.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            100,
          ),
          _DataCell(
            Text(
              '৳${p.agent.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 13),
            ),
            100,
          ),
          _DataCell(
            Text(
              '৳${p.wholesale.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 13),
            ),
            100,
          ),
          _DataCell(_ActionButtons(product: p, controller: controller), 140),
        ],
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

// ── Action Buttons — PermissionButton দিয়ে wrap ──────────────
class _ActionButtons extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _ActionButtons({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = product;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canCreate,
          showDisabled: true,
          child: IconButton(
            icon: const Icon(
              Icons.add_shopping_cart,
              color: Colors.teal,
              size: 20,
            ),
            tooltip: 'Add Stock',
            onPressed: () => _showAddStockDialog(context, p),
          ),
        ),

        // Edit — canEdit permission লাগবে
        PermissionButton(
          route: Routes.stock,
          type: PermissionType.canEdit,
          showDisabled: true,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
            tooltip: 'Edit Product',
            onPressed: () async {
              showEditProductDialog(p, controller);
              await ActivityLogger.stockUpdated(
                'Editing: ${p.model} | ${p.name}',
              );
            },
          ),
        ),

        // More options — canEdit or canDelete লাগবে
        // PopupMenu নিজেই দেখাবে কিন্তু ভেতরে items permission অনুযায়ী
        _MoreOptionsButton(product: p, controller: controller),
      ],
    );
  }

  void _showAddStockDialog(BuildContext context, Product p) {
    final seaQtyC = TextEditingController(text: '0');
    final airQtyC = TextEditingController(text: '0');
    final localQtyC = TextEditingController(text: '0');
    final localPriceC = TextEditingController(text: '0');
    final selectedDate = Rx<DateTime?>(null);
    final predictedAvg = p.avgPurchasePrice.obs;

    void calcPrediction() {
      final s = int.tryParse(seaQtyC.text) ?? 0;
      final a = int.tryParse(airQtyC.text) ?? 0;
      final l = int.tryParse(localQtyC.text) ?? 0;
      final lp = double.tryParse(localPriceC.text) ?? 0.0;
      final oldValue = p.stockQty * p.avgPurchasePrice;
      final seaCost = (p.yuan * p.currency) + (p.weight * p.shipmentTax);
      final airCost = (p.yuan * p.currency) + (p.weight * p.shipmentTaxAir);
      final newBatch = (s * seaCost) + (a * airCost) + (l * lp);
      final totalQty = p.stockQty + s + a + l;
      if (totalQty > 0) {
        predictedAvg.value = (oldValue + newBatch) / totalQty;
      }
    }

    Widget inputField(String label, TextEditingController ctrl, IconData icon) {
      return TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => calcPrediction(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Receive Stock: ${p.model}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Obx(
                        () => Text(
                          'New Avg Cost: ৳${predictedAvg.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                inputField('Sea Qty', seaQtyC, Icons.waves),
                const SizedBox(height: 10),
                inputField('Air Qty', airQtyC, Icons.airplanemode_active),
                const Divider(height: 30),
                const Text(
                  'Local Purchase',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: inputField('Qty', localQtyC, Icons.inventory),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: inputField(
                        'Unit Price',
                        localPriceC,
                        Icons.price_change,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Obx(
                  () => InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: Get.context!,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) selectedDate.value = picked;
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Shipment Date (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        selectedDate.value == null
                            ? 'Select Date'
                            : DateFormat(
                              'dd MMM yyyy',
                            ).format(selectedDate.value!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final sea = int.tryParse(seaQtyC.text) ?? 0;
              final air = int.tryParse(airQtyC.text) ?? 0;
              final local = int.tryParse(localQtyC.text) ?? 0;
              final price = double.tryParse(localPriceC.text) ?? 0.0;
              await controller.addMixedStock(
                productId: p.id,
                seaQty: sea,
                airQty: air,
                localQty: local,
                localUnitPrice: price,
                shipmentDate: selectedDate.value,
              );
              await ActivityLogger.stockUpdated(
                '${p.model} | Sea: $sea, Air: $air, Local: $local',
              );
              Get.back();
            },
            child: const Text(
              'Confirm Receive',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── More Options — permission অনুযায়ী items দেখাবে ──────────
class _MoreOptionsButton extends StatelessWidget {
  final Product product;
  final ProductController controller;

  const _MoreOptionsButton({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = product;

    // canEdit বা canDelete যেকোনো একটা থাকলে button দেখাবে
    return PermissionButton(
      route: Routes.stock,
      type: PermissionType.canEdit,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
        onSelected: (val) => _handleAction(context, val, p),
        itemBuilder:
            (_) => [
              // Service — canEdit লাগবে
              const PopupMenuItem(
                value: 'service',
                child: ListTile(
                  leading: Icon(Icons.handyman, color: Colors.orange),
                  title: Text(
                    'Send to Service',
                    style: TextStyle(fontSize: 13),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              // Damage — canEdit লাগবে
              const PopupMenuItem(
                value: 'damage',
                child: ListTile(
                  leading: Icon(Icons.broken_image, color: Colors.red),
                  title: Text('Mark as Damage', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              // Delete — canDelete লাগবে — শুধু থাকবে যদি permission থাকে
              if (_hasDeletePermission())
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.redAccent),
                    title: Text(
                      'Delete Product',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
      ),
    );
  }

  // Delete permission check
  bool _hasDeletePermission() {
    try {
      final permCtrl = Get.find<PermissionController>();
      return permCtrl.canDelete(Routes.stock);
    } catch (_) {
      return false;
    }
  }

  void _handleAction(BuildContext ctx, String val, Product p) {
    if (val == 'service') {
      _showQtyDialog(ctx, 'Service', p, (qty) async {
        await controller.addToService(
          productId: p.id,
          model: p.model,
          qty: qty,
          type: 'service',
          currentAvgPrice: p.avgPurchasePrice,
        );
        await ActivityLogger.log(
          action: 'SERVICE_STOCK',
          module: 'Stock',
          details: '${p.model} → Service | Qty: $qty',
        );
      });
    } else if (val == 'damage') {
      _showQtyDialog(ctx, 'Damage', p, (qty) async {
        await controller.addToService(
          productId: p.id,
          model: p.model,
          qty: qty,
          type: 'damage',
          currentAvgPrice: p.avgPurchasePrice,
        );
        await ActivityLogger.log(
          action: 'DAMAGE_STOCK',
          module: 'Stock',
          details: '${p.model} → Damage | Qty: $qty',
        );
      });
    } else if (val == 'delete') {
      showDeleteConfirmDialog(p.id, controller);
      ActivityLogger.stockDeleted('${p.model} | ${p.name}');
    }
  }

  void _showQtyDialog(
    BuildContext ctx,
    String actionType,
    Product p,
    Function(int) onConfirm,
  ) {
    final qtyCtrl = TextEditingController();
    Get.defaultDialog(
      title: '$actionType Item',
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        children: [
          Text(
            '${p.model} (Stock: ${p.stockQty})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: actionType == 'Damage' ? Colors.red : Colors.orange,
      onConfirm: () {
        final qty = int.tryParse(qtyCtrl.text) ?? 0;
        if (qty > 0 && qty <= p.stockQty) {
          onConfirm(qty);
          Get.back();
        } else {
          Get.snackbar(
            'Error',
            'Invalid Quantity',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }
}

// ── Profit Cell ──────────────────────────────────────────────
class _ProfitCell extends StatelessWidget {
  final Product product;
  const _ProfitCell({required this.product});

  @override
  Widget build(BuildContext context) {
    final profitAgent = product.agent - product.avgPurchasePrice;
    final profitWholesale = product.wholesale - product.avgPurchasePrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProfitLine(label: 'A', profit: profitAgent),
        const SizedBox(height: 2),
        _ProfitLine(label: 'W', profit: profitWholesale),
      ],
    );
  }
}

class _ProfitLine extends StatelessWidget {
  final String label;
  final double profit;
  const _ProfitLine({required this.label, required this.profit});

  @override
  Widget build(BuildContext context) {
    final isLoss = profit < 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isLoss ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

// ── Badge ────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final MaterialColor color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  final int alert;
  const _StockBadge({required this.stock, required this.alert});

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: stock <= alert ? 'LOW' : 'OK',
      color: stock <= alert ? Colors.red : Colors.green,
    );
  }
}

// ── Empty State ──────────────────────────────────────────────
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
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
