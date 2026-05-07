import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import '../../../Menubar and Navigation/app_pages.dart';
import '../../../Permission/permission_button.dart';
import '../../Core Utils/activity_logger.dart';
import '../stock_controller.dart';
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
        return const _LoadingState();
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

  final ScrollController _hScroll = ScrollController();

  _DesktopTable({
    required this.products,
    required this.shipCtrl,
    required this.cartCtrl,
  });

  // Horizontal padding applied to EVERY row (header + data).
  // _tableWidth must include this so the Row is never wider than SizedBox.
  static const double _rowPaddingH = 16;

  // Column content widths
  static const double _colStatus = 110;
  static const double _colModel = 140;
  static const double _colName = 240;
  static const double _colPrice = 145;
  static const double _colStock = 95;
  static const double _colOnWay = 95;
  static const double _colAlert = 95;
  static const double _colQty = 110;
  static const double _colAction = 95;

  // SizedBox width = sum of all column widths + left + right padding.
  // The Row inside header/data rows gets exactly this minus the padding.
  static const double _tableWidth =
      _rowPaddingH * 2 +
      _colStatus +
      _colModel +
      _colName +
      _colPrice +
      _colStock +
      _colOnWay +
      _colAlert +
      _colQty +
      _colAction;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _hScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TableHeaderRow(),
              ...products.map(
                (p) => RepaintBoundary(
                  child: _DesktopRow(
                    product: p,
                    shipCtrl: shipCtrl,
                    cartCtrl: cartCtrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header Row
// ─────────────────────────────────────────────────────────────
class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: _DesktopTable._rowPaddingH, // same constant — no mismatch
      ),
      child: const Row(
        children: [
          _HeaderCell('STATUS', _DesktopTable._colStatus),
          _HeaderCell('MODEL', _DesktopTable._colModel),
          _HeaderCell('PRODUCT NAME', _DesktopTable._colName),
          _HeaderCell('PRICE (AIR/SEA)', _DesktopTable._colPrice),
          _HeaderCell('STOCK', _DesktopTable._colStock),
          _HeaderCell('ON WAY', _DesktopTable._colOnWay),
          _HeaderCell('ALERT', _DesktopTable._colAlert),
          _HeaderCell('ORDER QTY', _DesktopTable._colQty),
          _HeaderCell('ACTION', _DesktopTable._colAction),
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
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Row
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
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFF5F5) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: _DesktopTable._rowPaddingH, // same constant as header
      ),
      child: Row(
        children: [
          SizedBox(
            width: _DesktopTable._colStatus,
            child: _StatusBadge(isCritical: isCritical),
          ),
          SizedBox(
            width: _DesktopTable._colModel,
            child: Text(
              p.model,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          SizedBox(
            width: _DesktopTable._colName,
            child: Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          SizedBox(
            width: _DesktopTable._colPrice,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PriceRow(
                  icon: Icons.flight_takeoff,
                  color: const Color(0xFF2563EB),
                  label: '৳${p.air.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 4),
                _PriceRow(
                  icon: Icons.directions_boat,
                  color: const Color(0xFF0D9488),
                  label: '৳${p.sea.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          SizedBox(
            width: _DesktopTable._colStock,
            child: Text(
              '${p.stockQty}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color:
                    isCritical
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A),
              ),
            ),
          ),
          SizedBox(
            width: _DesktopTable._colOnWay,
            child:
                onWay > 0
                    ? _OnWayBadge(qty: onWay)
                    : const Text(
                      '—',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
          ),
          SizedBox(
            width: _DesktopTable._colAlert,
            child: Text(
              '${p.alertQty}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: _DesktopTable._colQty,
            child: SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _DesktopTable._colAction,
            child: PermissionButton(
              route: Routes.stock,
              type: PermissionType.canCreate,
              showDisabled: true,
              child: Tooltip(
                message: 'Add to PO',
                child: InkWell(
                  onTap: () => _addToCart(p),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                ),
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
        snackPosition: SnackPosition.BOTTOM,
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (int i = 0; i < products.length; i++) ...[
            if (i != 0) const SizedBox(height: 14),
            _MobileCard(product: products[i], cartCtrl: cartCtrl),
          ],
        ],
      ),
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
        border: Border.all(
          color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isCritical
                      ? const Color(0xFFFFF5F5)
                      : const Color(0xFFF8FAFC),
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
                    color: Color(0xFF0F172A),
                  ),
                ),
                _StatusBadge(isCritical: isCritical),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: 'Current Stock',
                        child: Text(
                          '${p.stockQty}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                isCritical
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InfoTile(
                        label: 'Alert At',
                        child: Text(
                          '${p.alertQty}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InfoTile(
                        label: 'Price',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PriceRow(
                              icon: Icons.flight_takeoff,
                              color: const Color(0xFF2563EB),
                              label: '৳${p.air.toStringAsFixed(0)}',
                            ),
                            const SizedBox(height: 2),
                            _PriceRow(
                              icon: Icons.directions_boat,
                              color: const Color(0xFF0D9488),
                              label: '৳${p.sea.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Order Qty',
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
        snackPosition: SnackPosition.BOTTOM,
      );
      _qtyCtrl.text = '1';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _PriceRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoTile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCritical;

  const _StatusBadge({required this.isCritical});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFDBA74),
        ),
      ),
      child: Text(
        isCritical ? 'CRITICAL' : 'LOW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '$qty',
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Center(
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
