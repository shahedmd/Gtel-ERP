import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../Shipment/controller.dart';
import 'ongoining_shipment_page.dart';
import 'stockshorlistandchinaorder.dart';
import 'stockdamange_servicepage.dart';
import 'stockcontroller.dart';
import 'helperdialogs.dart';
import 'stockproductmodel.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kBlue = Color(0xFF2563EB);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kRed = Color(0xFFDC2626);
const _kRedSoft = Color(0xFFFEF2F2);
const _kGreen = Color(0xFF16A34A);
const _kGreenSoft = Color(0xFFF0FDF4);
const _kAmber = Color(0xFFD97706);
const _kAmberSoft = Color(0xFFFFFBEB);
const _kTeal = Color(0xFF0D9488);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF8FAFC);
const _kSurface = Colors.white;
const _kTextPrimary = Color(0xFF1E293B);
const _kTextSecondary = Color(0xFF64748B);
const _kTableHeader = Color(0xFFF1F5F9);
const _kGrey = Color(0xFF9CA3AF);
const _kGreySoft = Color(0xFFF3F4F6);

// ─── Column widths — NAME removed, WAREHOUSE wider ──────────────────────────

class _Col {
  static const double model = 230;
  static const double warehouse = 200; // wider to show location
  static const double status = 75;
  static const double profit = 110;
  static const double stock = 75;
  static const double onWay = 70;
  static const double shipDate = 90;
  static const double seaAir = 95;
  static const double avgCost = 100;
  static const double agent = 95;
  static const double wholesale = 100;
  static const double actions = 110;

  static const double rowPadding = 16;

  static double get contentWidth =>
      model +
      warehouse +
      status +
      profit +
      stock +
      onWay +
      shipDate +
      seaAir +
      avgCost +
      agent +
      wholesale +
      actions;

  static double get tableMinWidth => contentWidth + (rowPadding * 2);
}

// ─── Scroll behavior ─────────────────────────────────────────────────────────

class _MultiScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

// ─── Helper: qty in a specific warehouse ────────────────────────────────────

int _qtyInWarehouse(Product p, int warehouseId) {
  for (final s in p.warehouseStocks) {
    final id = int.tryParse(s['warehouse_id']?.toString() ?? '');
    if (id == warehouseId) {
      return int.tryParse(s['qty']?.toString() ?? '0') ?? 0;
    }
  }
  return 0;
}

// ─── ProductScreen ────────────────────────────────────────────────────────────

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductController controller = Get.put(ProductController());
  final ShipmentController shipmentController = Get.put(ShipmentController());
  final TextEditingController _currencyInput = TextEditingController();
  final ScrollController _hScroll = ScrollController();
  final ScrollController _mainScroll = ScrollController();

  @override
  void dispose() {
    _currencyInput.dispose();
    _hScroll.dispose();
    _mainScroll.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 850;

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar(mobile),
      // ── Full page vertical scroll ──────────────────────────────────────────
      body: ScrollConfiguration(
        behavior: _MultiScrollBehavior(),
        child: SingleChildScrollView(
          controller: _mainScroll,
          child: Column(
            children: [
              _statsSection(context, mobile),
              _warehouseBar(mobile),
              _tableCard(mobile),
              const SizedBox(height: 80), // space for FAB
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProductDialog(controller),
        backgroundColor: _kBlue,
        elevation: 3,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Product',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: mobile ? 13 : 14,
          ),
        ),
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar(bool mobile) {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _kTextPrimary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Inventory',
            style: TextStyle(
              fontSize: mobile ? 18 : 21,
              fontWeight: FontWeight.w800,
              color: _kTextPrimary,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _kBorder, height: 1),
      ),
      actions: mobile ? _mobileActions() : _desktopActions(),
    );
  }

  List<Widget> _mobileActions() => [
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: _kTextPrimary),
      onSelected: _handleAppBarAction,
      itemBuilder: (_) => _appBarMenuItems(),
    ),
  ];

  List<Widget> _desktopActions() => [
    _appBarBtn(
      'Shipments',
      Icons.local_shipping_outlined,
      Colors.orange,
      () => Get.to(() => OnGoingShipmentsPage()),
    ),
    _appBarBtn(
      'Service',
      Icons.handyman_outlined,
      Colors.orange,
      () => Get.to(() => ServicePage()),
    ),
    const SizedBox(width: 4),
    _appBarBtn(
      'Alerts',
      Icons.warning_amber_rounded,
      _kRed,
      () => Get.to(() => ShortlistPage()),
      bg: _kRedSoft,
    ),
    const SizedBox(width: 4),
    IconButton(
      icon: const Icon(Icons.refresh, color: _kTextSecondary),
      tooltip: 'Refresh',
      onPressed: controller.fetchProducts,
    ),
    const SizedBox(width: 12),
  ];

  Widget _appBarBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Color? bg,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  void _handleAppBarAction(String value) {
    switch (value) {
      case 'shipments':
        Get.to(() => OnGoingShipmentsPage());
        break;
      case 'service':
        Get.to(() => ServicePage());
        break;
      case 'alerts':
        Get.to(() => ShortlistPage());
        break;
      case 'refresh':
        controller.fetchProducts();
        break;
    }
  }

  List<PopupMenuEntry<String>> _appBarMenuItems() => [
    _menuItem('shipments', 'Shipments', Icons.local_shipping, Colors.orange),
    _menuItem('service', 'Service Center', Icons.handyman, Colors.orange),
    _menuItem('alerts', 'Low Stock', Icons.warning_amber, _kRed),
    _menuItem('refresh', 'Refresh Data', Icons.refresh, _kBlue),
  ];

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Stats ──────────────────────────────────────────────────────────────────

  Widget _statsSection(BuildContext context, bool mobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 10 : 16,
        mobile ? 10 : 14,
        mobile ? 10 : 16,
        0,
      ),
      child:
          mobile
              ? Column(
                children: [
                  _valuationCard(mobile),
                  const SizedBox(height: 10),
                  _currencyCard(mobile),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 2, child: _valuationCard(mobile)),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: _currencyCard(mobile)),
                ],
              ),
    );
  }

  Widget _valuationCard(bool mobile) {
    return _card(
      child: Row(
        children: [
          _iconBox(Icons.monetization_on_outlined, _kBlue, _kBlueSoft, mobile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    controller.selectedWarehouse.value != null
                        ? 'Value — ${controller.selectedWarehouse.value!.name}'
                        : 'Total Warehouse Value',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 11 : 12,
                      color: _kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Obx(
                  () => Text(
                    '৳ ${controller.formattedTotalValuation}',
                    style: TextStyle(
                      fontSize: mobile ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: _kBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyCard(bool mobile) {
    final rateLine = Row(
      children: [
        _iconBox(Icons.currency_exchange, _kAmber, _kAmberSoft, mobile),
        SizedBox(width: mobile ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulk Currency Update (CNY)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: mobile ? 11 : 12,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Obx(
                () => Text(
                  '1 ¥ = ${controller.currentCurrency.value.toStringAsFixed(2)} ৳',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final rateField = SizedBox(
      height: 38,
      child: TextField(
        controller: _currencyInput,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'New rate',
          hintStyle: const TextStyle(fontSize: 12),
          fillColor: _kBg,
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _kBorder),
          ),
        ),
      ),
    );

    final applyBtn = SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: _handleCurrencyUpdate,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAmber,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          mobile ? 'Apply' : 'Apply to All',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 12 : 18,
        vertical: mobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
      ),
      child:
          mobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  rateLine,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: rateField),
                      const SizedBox(width: 8),
                      applyBtn,
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(child: rateLine),
                  const SizedBox(width: 14),
                  SizedBox(width: 110, child: rateField),
                  const SizedBox(width: 8),
                  applyBtn,
                ],
              ),
    );
  }

  // ─── Warehouse Bar ──────────────────────────────────────────────────────────

  Widget _warehouseBar(bool mobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 10, mobile ? 10 : 16, 0),
      child: Obx(() {
        if (controller.isWarehouseLoading.value &&
            controller.warehouses.isEmpty) {
          return const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              _warehouseChip(
                label: 'All',
                icon: Icons.warehouse_outlined,
                selected: controller.selectedWarehouse.value == null,
                inactive: false,
                onTap: controller.clearWarehouseFilter,
              ),
              Container(width: 1, height: 28, color: _kBorder),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: controller.warehouses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) {
                    final w = controller.warehouses[i];
                    final selected =
                        controller.selectedWarehouse.value?.id == w.id;
                    return _warehouseChip(
                      label: w.name,
                      icon: Icons.store_outlined,
                      selected: selected,
                      inactive: !w.isActive,
                      onTap: () => controller.selectWarehouse(w),
                    );
                  },
                ),
              ),
              Container(width: 1, height: 28, color: _kBorder),
              _warehouseManageBtn(mobile),
            ],
          ),
        );
      }),
    );
  }

  Widget _warehouseChip({
    required String label,
    required IconData icon,
    required bool selected,
    required bool inactive,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : (inactive ? _kGrey : _kTextSecondary);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color:
              selected ? _kBlue : (inactive ? _kGreySoft : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            if (inactive) ...[
              const SizedBox(width: 5),
              Text(
                '(Inactive)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warehouseManageBtn(bool mobile) {
    return GestureDetector(
      onTap: () => _showWarehouseManageDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: _kBlueSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 14, color: _kBlue),
            if (!mobile) ...[
              const SizedBox(width: 5),
              const Text(
                'Manage',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Table Card — no Expanded, full height ───────────────────────────────

  Widget _tableCard(bool mobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(mobile ? 10 : 16, 10, mobile ? 10 : 16, 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _toolbar(mobile),
          const Divider(height: 1, color: _kBorder),
          _table(mobile),
          const Divider(height: 1, color: _kBorder),
          _pagination(mobile),
        ],
      ),
    );
  }

  // ─── Toolbar ─────────────────────────────────────────────────────────────────

  Widget _toolbar(bool mobile) {
    return Padding(
      padding: EdgeInsets.all(mobile ? 10 : 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: controller.search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    mobile ? 'Search...' : 'Search by model, name or brand...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: _kTextSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: _kTextSecondary,
                  size: 20,
                ),
                fillColor: _kBg,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Obx(() {
            final active = controller.sortByLoss.value;
            return GestureDetector(
              onTap: controller.toggleSortByLoss,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 10 : 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active ? _kRedSoft : _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? _kRed : _kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? Icons.trending_down : Icons.sort,
                      size: 18,
                      color: active ? _kRed : _kTextSecondary,
                    ),
                    if (!mobile) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Loss First',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? _kRed : _kTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Table — shrinkWrap for full page scroll ──────────────────────────────

  Widget _table(bool mobile) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.allProducts.isEmpty) {
        return _emptyState();
      }

      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _Col.tableMinWidth,
            child: Column(
              children: [
                _tableHeader(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.allProducts.length,
                  itemBuilder: (context, i) {
                    final p = controller.allProducts[i];
                    return _tableRow(context, p, i);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─── Table Header — NAME removed ─────────────────────────────────────────

  Widget _tableHeader() {
    return Container(
      color: _kTableHeader,
      padding: const EdgeInsets.symmetric(
        vertical: 11,
        horizontal: _Col.rowPadding,
      ),
      child: Row(
        children: [
          _hCell('MODEL', _Col.model),
          _hCell('WAREHOUSE / LOCATION', _Col.warehouse),
          _hCell('STATUS', _Col.status),
          _hCell('PROFIT', _Col.profit),
          _hCell('STOCK', _Col.stock),
          _hCell('ON WAY', _Col.onWay),
          _hCell('SHIP DATE', _Col.shipDate),
          _hCell('SEA / AIR', _Col.seaAir),
          _hCell('AVG COST', _Col.avgCost),
          _hCell('AGENT', _Col.agent),
          _hCell('WHOLESALE', _Col.wholesale),
          _hCell('ACTIONS', _Col.actions),
        ],
      ),
    );
  }

  // ─── Table Row — NAME removed ─────────────────────────────────────────────

  Widget _tableRow(BuildContext context, Product p, int index) {
    final onWay = shipmentController.getOnWayQty(p.id);
    final isLow = p.stockQty <= p.alertQty;

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? _kSurface : const Color(0xFFFAFAFC),
        border: const Border(bottom: BorderSide(color: _kBorder, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 9,
        horizontal: _Col.rowPadding,
      ),
      child: Row(
        children: [
          _dCell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _kTextPrimary,
                  ),
                ),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _kTextSecondary),
                ),
              ],
            ),
            _Col.model,
          ),
          _dCell(_warehouseStockCell(p), _Col.warehouse),
          _dCell(_statusBadge(p.stockQty, p.alertQty), _Col.status),
          _dCell(_profitCell(p), _Col.profit),
          _dCell(
            Text(
              p.stockQty.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isLow ? _kRed : _kTextPrimary,
              ),
            ),
            _Col.stock,
          ),
          _dCell(
            onWay > 0
                ? _pill(onWay.toString(), _kBlue, _kBlueSoft)
                : const Text('—', style: TextStyle(color: _kTextSecondary)),
            _Col.onWay,
          ),
          _dCell(
            Text(
              p.shipmentDate != null
                  ? DateFormat('dd MMM yy').format(p.shipmentDate!)
                  : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF047857),
                fontWeight: FontWeight.w600,
              ),
            ),
            _Col.shipDate,
          ),
          _dCell(
            Text(
              '${p.seaStockQty} / ${p.airStockQty}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kTextSecondary),
            ),
            _Col.seaAir,
          ),
          _dCell(
            Text(
              '৳${p.avgPurchasePrice.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF047857),
                fontWeight: FontWeight.w700,
              ),
            ),
            _Col.avgCost,
          ),
          _dCell(
            Text(
              '৳${p.agent.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            _Col.agent,
          ),
          _dCell(
            Text(
              '৳${p.wholesale.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            _Col.wholesale,
          ),
          _dCell(_actions(context, p), _Col.actions),
        ],
      ),
    );
  }

  // ─── Warehouse Stock Cell — shows location ────────────────────────────────

  Widget _warehouseStockCell(Product p) {
    final items = p.warehouseStocks.where((s) => (s['qty'] ?? 0) > 0).toList();

    if (items.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(color: _kTextSecondary, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children:
          items.map<Widget>((s) {
            final location = s['location']?.toString().trim() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: _kBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${s['warehouse_name']}: ${s['qty']}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 10,
                            color: _kTeal,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              location,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _kTeal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _hCell(String label, double w) {
    return SizedBox(
      width: w,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: _kTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _dCell(Widget child, double w) {
    return SizedBox(
      width: w,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _statusBadge(int stock, int alert) {
    final low = stock <= alert;
    return _pill(
      low ? 'LOW' : 'OK',
      low ? _kRed : _kGreen,
      low ? _kRedSoft : _kGreenSoft,
    );
  }

  Widget _pill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _profitCell(Product p) {
    final a = p.agent - p.avgPurchasePrice;
    final w = p.wholesale - p.avgPurchasePrice;

    Widget line(String label, double v) {
      final loss = v < 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: _kTextSecondary),
          ),
          Flexible(
            child: Text(
              '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: loss ? _kRed : _kGreen,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [line('A', a), const SizedBox(height: 2), line('W', w)],
    );
  }

  // ─── Row Actions ────────────────────────────────────────────────────────────

  Widget _actions(BuildContext context, Product p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(
          Icons.add_shopping_cart,
          _kTeal,
          'Add Stock',
          () => _showAddStockDialog(context, p),
        ),
        _iconBtn(
          Icons.edit_outlined,
          _kBlue,
          'Edit',
          () => showEditProductDialog(p, controller),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
          onSelected: (val) => _handleRowAction(context, val, p),
          itemBuilder:
              (_) => [
                _menuItem(
                  'service',
                  'Send to Service',
                  Icons.handyman,
                  Colors.orange,
                ),
                _menuItem(
                  'damage',
                  'Mark as Damage',
                  Icons.broken_image,
                  _kRed,
                ),
                _menuItem(
                  'transfer',
                  'Transfer Stock',
                  Icons.swap_horiz,
                  _kBlue,
                ),
                _menuItem(
                  'set_location',
                  'Set Location',
                  Icons.location_on,
                  _kTeal,
                ),
                _menuItem(
                  'delete',
                  'Delete Product',
                  Icons.delete_outline,
                  Colors.grey,
                ),
              ],
        ),
      ],
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _handleRowAction(BuildContext context, String val, Product p) {
    switch (val) {
      case 'service':
        _showQtyDialog(
          context,
          'Service',
          p,
          (qty) => controller.addToService(
            productId: p.id,
            model: p.model,
            qty: qty,
            type: 'service',
            currentAvgPrice: p.avgPurchasePrice,
          ),
        );
        break;
      case 'damage':
        _showQtyDialog(
          context,
          'Damage',
          p,
          (qty) => controller.addToService(
            productId: p.id,
            model: p.model,
            qty: qty,
            type: 'damage',
            currentAvgPrice: p.avgPurchasePrice,
          ),
        );
        break;
      case 'transfer':
        _showTransferDialog(context, p);
        break;
      case 'set_location':
        _showSetLocationDialog(p);
        break;
      case 'delete':
        showDeleteConfirmDialog(p.id, controller);
        break;
    }
  }

  // ─── Pagination ─────────────────────────────────────────────────────────────

  Widget _pagination(bool mobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: 10),
      child: Obx(() {
        final total = controller.totalProducts.value;
        final current = controller.currentPage.value;
        final size = controller.pageSize.value;
        final totalPages = (total / size).ceil().clamp(1, 9999);
        final start = total == 0 ? 0 : (current - 1) * size + 1;
        final end = (current * size).clamp(0, total);

        return Row(
          children: [
            if (!mobile)
              Text(
                'Showing $start–$end of $total',
                style: const TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
            const Spacer(),
            _pageBtn(
              Icons.chevron_left,
              current > 1 ? controller.previousPage : null,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                '$current / $totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _pageBtn(
              Icons.chevron_right,
              current < totalPages ? controller.nextPage : null,
            ),
          ],
        );
      }),
    );
  }

  Widget _pageBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap != null ? _kSurface : _kBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? _kTextPrimary : _kTextSecondary,
        ),
      ),
    );
  }

  // ─── Shared helpers ─────────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color fg, Color bg, bool mobile) {
    return Container(
      padding: EdgeInsets.all(mobile ? 9 : 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: fg, size: mobile ? 22 : 26),
    );
  }

  Widget _emptyState() {
    return const SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: _kTextSecondary),
            SizedBox(height: 14),
            Text(
              'No products found',
              style: TextStyle(color: _kTextSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Stock Dialog ────────────────────────────────────────────────────────

  void _showAddStockDialog(BuildContext context, Product p) {
    final seaC = TextEditingController(text: '0');
    final airC = TextEditingController(text: '0');
    final localC = TextEditingController(text: '0');
    final priceC = TextEditingController(text: '0');
    final locationC = TextEditingController();
    final Rx<DateTime?> date = Rx<DateTime?>(null);
    final predictedAvg = p.avgPurchasePrice.obs;
    final RxInt selectedWarehouseId = RxInt(
      controller.activeWarehouses.firstOrNull?.id ?? 0,
    );

    void recalculate() {
      final s = int.tryParse(seaC.text) ?? 0;
      final a = int.tryParse(airC.text) ?? 0;
      final l = int.tryParse(localC.text) ?? 0;
      final lp = double.tryParse(priceC.text) ?? 0.0;
      final oldVal = p.stockQty * p.avgPurchasePrice;
      final seaCost = (p.yuan * p.currency) + (p.weight * p.shipmentTax);
      final airCost = (p.yuan * p.currency) + (p.weight * p.shipmentTaxAir);
      final incoming = (s * seaCost) + (a * airCost) + (l * lp);
      final totalQty = p.stockQty + s + a + l;
      if (totalQty > 0) predictedAvg.value = (oldVal + incoming) / totalQty;
    }

    Widget field(String label, TextEditingController ctrl, IconData icon) {
      return TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => recalculate(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: _kTextSecondary),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: _kTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Receive Stock: ${p.model}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _kBlueSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_graph, size: 16, color: _kBlue),
                        const SizedBox(width: 8),
                        Text(
                          'New Avg Cost: ৳${predictedAvg.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _kBlue,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.activeWarehouses.isNotEmpty) ...[
                  const Text(
                    'Destination Warehouse',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value:
                              selectedWarehouseId.value == 0
                                  ? null
                                  : selectedWarehouseId.value,
                          hint: const Text(
                            'Select warehouse',
                            style: TextStyle(fontSize: 13),
                          ),
                          items:
                              controller.activeWarehouses
                                  .map(
                                    (w) => DropdownMenuItem(
                                      value: w.id,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.store_outlined,
                                            size: 15,
                                            color: _kTextSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            w.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) selectedWarehouseId.value = v;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  'Shipment Stock',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: field('Sea Qty', seaC, Icons.waves)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field(
                        'Air Qty',
                        airC,
                        Icons.airplanemode_active_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Local Purchase',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: field('Qty', localC, Icons.inventory_2_outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field(
                        'Unit Price',
                        priceC,
                        Icons.price_change_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Warehouse Location (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: locationC,
                  decoration: InputDecoration(
                    hintText: 'e.g. Aisle 3, Shelf 2',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      size: 18,
                      color: _kTeal,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Obx(
                  () => GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: Get.context!,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) date.value = picked;
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Shipment Date (Optional)',
                        labelStyle: const TextStyle(fontSize: 13),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        date.value == null
                            ? 'Select date'
                            : DateFormat('dd MMM yyyy').format(date.value!),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text(
              'Confirm Receive',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              controller.addMixedStock(
                productId: p.id,
                seaQty: int.tryParse(seaC.text) ?? 0,
                airQty: int.tryParse(airC.text) ?? 0,
                localQty: int.tryParse(localC.text) ?? 0,
                localUnitPrice: double.tryParse(priceC.text) ?? 0.0,
                shipmentDate: date.value,
                warehouseId:
                    selectedWarehouseId.value == 0
                        ? null
                        : selectedWarehouseId.value,
                warehouseLocation:
                    locationC.text.trim().isNotEmpty
                        ? locationC.text.trim()
                        : null,
              );
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  // ─── Transfer Dialog ────────────────────────────────────────────────────────

  void _showTransferDialog(BuildContext context, Product p) {
    if (controller.warehouses.length < 2) {
      Get.snackbar(
        'Not Enough Warehouses',
        'You need at least 2 warehouses to transfer stock.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final qtyC = TextEditingController();
    final fromId = RxInt(controller.warehouses.first.id);
    final destinationCandidates =
        controller.activeWarehouses.where((w) => w.id != fromId.value).toList();
    final toId = RxInt(
      destinationCandidates.isNotEmpty
          ? destinationCandidates.first.id
          : (controller.activeWarehouses.isNotEmpty
              ? controller.activeWarehouses.first.id
              : controller.warehouses.last.id),
    );
    final RxString transferError = RxString('');

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: _kBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transfer: ${p.model}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kBlueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: _kBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Stock: ${p.stockQty} units',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'From Warehouse',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(
                () => _warehouseDropdown(
                  options: controller.warehouses,
                  value: fromId.value,
                  onChanged: (v) {
                    if (v != null) {
                      fromId.value = v;
                      transferError.value = '';
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              Obx(() {
                final avail = _qtyInWarehouse(p, fromId.value);
                return Text(
                  'Available here: $avail units',
                  style: const TextStyle(fontSize: 12, color: _kTextSecondary),
                );
              }),
              const SizedBox(height: 12),
              const Text(
                'To Warehouse',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(
                () => _warehouseDropdown(
                  options: controller.activeWarehouses,
                  value: toId.value,
                  onChanged: (v) {
                    if (v != null) toId.value = v;
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyC,
                keyboardType: TextInputType.number,
                onChanged: (_) => transferError.value = '',
                decoration: InputDecoration(
                  labelText: 'Transfer Quantity',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.numbers, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
              ),
              Obx(
                () =>
                    transferError.value.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            transferError.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          Obx(
            () => ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon:
                  controller.isTransferLoading.value
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.swap_horiz, size: 16),
              label: const Text(
                'Transfer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed:
                  controller.isTransferLoading.value
                      ? null
                      : () async {
                        final qty = int.tryParse(qtyC.text) ?? 0;
                        if (fromId.value == toId.value) {
                          transferError.value =
                              'Source and destination must be different.';
                          return;
                        }
                        if (qty <= 0) {
                          transferError.value =
                              'Enter a quantity greater than zero.';
                          return;
                        }
                        final avail = _qtyInWarehouse(p, fromId.value);
                        if (qty > avail) {
                          transferError.value =
                              'Only $avail units available in this warehouse.';
                          return;
                        }
                        final success = await controller.transferStock(
                          productId: p.id,
                          fromWarehouseId: fromId.value,
                          toWarehouseId: toId.value,
                          qty: qty,
                        );
                        if (success) Get.back();
                      },
            ),
          ),
        ],
      ),
    );
  }

  Widget _warehouseDropdown({
    required List<Warehouse> options,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    final hasValue = options.any((w) => w.id == value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: hasValue ? value : null,
          hint: const Text('Select warehouse', style: TextStyle(fontSize: 13)),
          items:
              options
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.store_outlined,
                            size: 15,
                            color: _kTextSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(w.name, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Quantity Dialog ────────────────────────────────────────────────────────

  void _showQtyDialog(
    BuildContext context,
    String action,
    Product p,
    Function(int) onConfirm,
  ) {
    final ctrl = TextEditingController();
    final isDamage = action == 'Damage';

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '$action: ${p.model}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Available stock: ${p.stockQty}',
              style: const TextStyle(color: _kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDamage ? _kRed : Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final qty = int.tryParse(ctrl.text) ?? 0;
              if (qty > 0 && qty <= p.stockQty) {
                onConfirm(qty);
                Get.back();
              } else {
                Get.snackbar(
                  'Invalid Quantity',
                  'Enter a value between 1 and ${p.stockQty}',
                  backgroundColor: _kRed,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Confirm $action'),
          ),
        ],
      ),
    );
  }

  // ─── Warehouse Manage Dialog ──────────────────────────────────────────────

  void _showWarehouseManageDialog() {
    if (controller.warehouseSummaries.isEmpty &&
        !controller.isWarehouseLoading.value) {
      controller.fetchWarehouseSummary();
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _kBorder)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warehouse_outlined,
                      color: _kBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Manage Warehouses',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _kTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Obx(() {
                  if (controller.isWarehouseLoading.value) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (controller.warehouseSummaries.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'No warehouse data available',
                            style: TextStyle(color: _kTextSecondary),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: controller.fetchWarehouseSummary,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children:
                        controller.warehouseSummaries.map((w) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: w.isActive ? _kBlueSoft : _kGreySoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.store_outlined,
                                    color: w.isActive ? _kBlue : _kGrey,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              w.name,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: _kTextPrimary,
                                              ),
                                            ),
                                          ),
                                          if (!w.isActive) ...[
                                            const SizedBox(width: 6),
                                            _pill(
                                              'INACTIVE',
                                              _kGrey,
                                              _kGreySoft,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${w.productCount} products · ${w.totalQty} units',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showEditWarehouseDialog(w),
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _kBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap:
                                          () => _confirmDeleteWarehouse(
                                            w.id,
                                            w.name,
                                          ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: _kRed,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: _addWarehouseInline(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteWarehouse(int id, String name) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Deactivate Warehouse?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to deactivate "$name"?\n'
          'It will no longer appear in active lists.\n'
          'Stock data will be preserved.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              controller.deleteWarehouse(id);
              Get.back();
              Get.back();
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Widget _addWarehouseInline() {
    final nameC = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: nameC,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'New warehouse name...',
              hintStyle: const TextStyle(fontSize: 13, color: _kTextSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed:
                controller.isActionLoading.value
                    ? null
                    : () async {
                      final name = nameC.text.trim();
                      if (name.isNotEmpty) {
                        await controller.createWarehouse(name);
                        nameC.clear();
                      }
                    },
            icon:
                controller.isActionLoading.value
                    ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.add, size: 16),
            label: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditWarehouseDialog(dynamic summary) {
    final nameC = TextEditingController(text: summary.name);
    final isActive = RxBool(summary.isActive);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Edit Warehouse',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: InputDecoration(
                labelText: 'Warehouse Name',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active', style: TextStyle(fontSize: 14)),
                value: isActive.value,
                activeColor: _kBlue,
                onChanged: (v) => isActive.value = v,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              await controller.updateWarehouse(
                summary.id,
                nameC.text.trim(),
                isActive: isActive.value,
              );
              Get.back();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // ─── Set Location Dialog — pre-fills existing location ───────────────────

  void _showSetLocationDialog(Product p) {
    if (controller.activeWarehouses.isEmpty) {
      Get.snackbar(
        'No Active Warehouses',
        'Please create at least one active warehouse first.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    // Pre-select warehouse that has stock
    final stockedWarehouseIds =
        p.warehouseStocks
            .where((s) => (s['qty'] ?? 0) > 0)
            .map((s) => int.tryParse(s['warehouse_id']?.toString() ?? '') ?? 0)
            .toList();

    final defaultId =
        stockedWarehouseIds.isNotEmpty
            ? stockedWarehouseIds.first
            : controller.activeWarehouses.firstOrNull?.id ?? 0;

    final warehouseId = RxInt(defaultId);

    // Pre-fill existing location for the default warehouse
    String existingLocation = '';
    if (defaultId > 0) {
      final existing = p.warehouseStocks.firstWhereOrNull(
        (s) => int.tryParse(s['warehouse_id']?.toString() ?? '') == defaultId,
      );
      existingLocation = existing?['location']?.toString().trim() ?? '';
    }

    final locationC = TextEditingController(text: existingLocation);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: _kTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Set Location: ${p.model}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warehouse dropdown
            Obx(
              () => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: warehouseId.value == 0 ? null : warehouseId.value,
                    hint: const Text(
                      'Select warehouse',
                      style: TextStyle(fontSize: 13),
                    ),
                    items:
                        controller.activeWarehouses.map((w) {
                          final wStock = p.warehouseStocks.firstWhereOrNull(
                            (s) =>
                                int.tryParse(
                                  s['warehouse_id']?.toString() ?? '',
                                ) ==
                                w.id,
                          );
                          final qty =
                              wStock != null ? safeInt(wStock['qty']) : 0;
                          return DropdownMenuItem(
                            value: w.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.store_outlined,
                                  size: 15,
                                  color: _kTextSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  w.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (qty > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kBlueSoft,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$qty pcs',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _kBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        warehouseId.value = v;
                        // Auto-fill location for selected warehouse
                        final wStock = p.warehouseStocks.firstWhereOrNull(
                          (s) =>
                              int.tryParse(
                                s['warehouse_id']?.toString() ?? '',
                              ) ==
                              v,
                        );
                        locationC.text =
                            wStock?['location']?.toString().trim() ?? '';
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: locationC,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Aisle 3, Shelf 2',
                prefixIcon: const Icon(
                  Icons.location_on,
                  size: 18,
                  color: _kTeal,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text(
              'Save Location',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              final loc = locationC.text.trim();
              if (loc.isEmpty) {
                Get.snackbar(
                  'Error',
                  'Please enter a location',
                  backgroundColor: _kRed,
                  colorText: Colors.white,
                );
                return;
              }
              controller.setProductWarehouseLocation(
                productId: p.id,
                warehouseId: warehouseId.value,
                location: loc,
              );
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  // ─── Currency Update ──────────────────────────────────────────────────────

  void _handleCurrencyUpdate() {
    final val = double.tryParse(_currencyInput.text);
    if (val != null && val > 0) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Confirm Bulk Revaluation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Update rate to ¥1 = ৳${val.toStringAsFixed(2)}?\n\n'
            'This will recalculate Avg Cost and Prices for ALL products.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAmber,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                controller.updateCurrencyAndRecalculate(val);
                _currencyInput.clear();
                Get.back();
              },
              child: const Text('Update All'),
            ),
          ],
        ),
      );
    } else {
      Get.snackbar(
        'Invalid Rate',
        'Please enter a valid currency rate.',
        backgroundColor: _kRed,
        colorText: Colors.white,
      );
    }
  }
}