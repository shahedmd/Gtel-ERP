// lib/Core/Stock Management/widgets/shortlist_table.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import '../../Core Utils/activity_logger.dart';
import '../../Permission/permission_button.dart';
import '../stock_shorlist_and_china_order.dart';

class ShortlistTable extends StatelessWidget {
  final bool isMobile;
  final ProductController ctrl;
  final ShipmentController shipCtrl;
  final OrderCartController cartCtrl;

  const ShortlistTable({
    super.key,
    required this.isMobile,
    required this.ctrl,
    required this.shipCtrl,
    required this.cartCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isShortListLoading.value && ctrl.shortListProducts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (ctrl.shortListProducts.isEmpty) {
        return const _EmptyState();
      }

      return isMobile
          ? _MobileList(
            products: ctrl.shortListProducts,
            shipCtrl: shipCtrl,
            cartCtrl: cartCtrl,
          )
          : _DesktopTable(
            products: ctrl.shortListProducts,
            shipCtrl: shipCtrl,
            cartCtrl: cartCtrl,
          );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Table
// ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List<Product> products;
  final ShipmentController shipCtrl;
  final OrderCartController cartCtrl;

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  _DesktopTable({
    required this.products,
    required this.shipCtrl,
    required this.cartCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _vScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vScroll,
            child: Scrollbar(
              controller: _hScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Center(
                    child: SizedBox(
                      width: 1050,
                      child: Column(
                        children: [
                          // Header
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: const Row(
                              children: [
                                _HeaderCell('STATUS', 100),
                                _HeaderCell('MODEL', 120),
                                _HeaderCell('PRODUCT NAME', 200),
                                _HeaderCell('PRICE (AIR/SEA)', 120),
                                _HeaderCell('STOCK', 80),
                                _HeaderCell('ON WAY', 80),
                                _HeaderCell('ALERT', 80),
                                _HeaderCell('ORDER QTY', 90),
                                _HeaderCell('ACTION', 80),
                              ],
                            ),
                          ),
                          // Rows
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            itemBuilder:
                                (context, i) => _DesktopRow(
                                  product: products[i],
                                  shipCtrl: shipCtrl,
                                  cartCtrl: cartCtrl,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Row — per product
// ─────────────────────────────────────────────────────────────
class _DesktopRow extends StatefulWidget {
  final Product product;
  final ShipmentController shipCtrl;
  final OrderCartController cartCtrl;

  const _DesktopRow({
    required this.product,
    required this.shipCtrl,
    required this.cartCtrl,
  });

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final onWay = widget.shipCtrl.getOnWayQty(p.id);
    final isCritical = p.stockQty <= 0;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 100, child: _StatusBadge(isCritical: isCritical)),
          SizedBox(
            width: 120,
            child: Text(
              p.model,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flight_takeoff,
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '৳${p.air.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_boat,
                      size: 12,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '৳${p.sea.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${p.stockQty}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCritical ? Colors.red : Colors.black,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: onWay > 0 ? _OnWayBadge(qty: onWay) : const Text('-'),
          ),
          SizedBox(width: 80, child: Text('${p.alertQty}')),
          SizedBox(
            width: 90,
            child: SizedBox(
              width: 70,
              height: 35,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),

          // Add to cart — canCreate permission লাগবে
          SizedBox(
            width: 80,
            child: PermissionButton(
              route: Routes.stock,
              type: PermissionType.canCreate,
              showDisabled: true,
              child: IconButton(
                icon: const Icon(
                  Icons.add_shopping_cart,
                  color: Color(0xFF2563EB),
                ),
                onPressed: () => _addToCart(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product p) {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty > 0) {
      widget.cartCtrl.addToCart(p, qty);
      ActivityLogger.log(
        action: 'ADD_TO_ORDER_CART',
        module: 'Stock',
        details: '${p.model} | Qty: $qty added to PO cart',
      );
      Get.snackbar(
        'Added',
        '${p.model} added to PO',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      _qtyCtrl.text = '1';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Mobile List
// ─────────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final List<Product> products;
  final ShipmentController shipCtrl;
  final OrderCartController cartCtrl;

  const _MobileList({
    required this.products,
    required this.shipCtrl,
    required this.cartCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:
          (context, i) => _MobileCard(product: products[i], cartCtrl: cartCtrl),
    );
  }
}

class _MobileCard extends StatefulWidget {
  final Product product;
  final OrderCartController cartCtrl;

  const _MobileCard({required this.product, required this.cartCtrl});

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isCritical = p.stockQty <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                _StatusBadge(isCritical: isCritical),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Stock',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '${p.stockQty}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Air: ৳${p.air.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Sea: ৳${p.sea.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Add to cart — permission check
                PermissionButton(
                  route: Routes.stock,
                  type: PermissionType.canCreate,
                  showDisabled: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Order Qty',
                            labelStyle: TextStyle(fontSize: 10),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                        onPressed: () => _addToCart(p),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product p) {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty > 0) {
      widget.cartCtrl.addToCart(p, qty);
      ActivityLogger.log(
        action: 'ADD_TO_ORDER_CART',
        module: 'Stock',
        details: '${p.model} | Qty: $qty added to PO cart',
      );
      Get.snackbar(
        'Added',
        'Added to PO',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      _qtyCtrl.text = '1';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isCritical;

  const _StatusBadge({required this.isCritical});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCritical ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Text(
        isCritical ? 'CRITICAL' : 'LOW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isCritical ? Colors.red : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _OnWayBadge extends StatelessWidget {
  final int qty;

  const _OnWayBadge({required this.qty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        '$qty',
        style: TextStyle(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
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
              Icons.check_circle_outline,
              size: 60,
              color: Color(0xFF10B981),
            ),
            SizedBox(height: 16),
            Text(
              'Healthy Inventory!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No products require restocking at this moment.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}