import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Menubar%20and%20Navigation/app_pages.dart';
import 'package:gtel_erp/Permission/permission_button.dart';
import 'package:gtel_erp/Shipment/controller.dart';

import 'Stock Widgets/stock_appbar.dart';
import 'Stock Widgets/stock_stats.dart';
import 'Stock Widgets/stock_table.dart';
import 'stock_controller.dart';
import 'stock_helper_dialogs.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final ProductController controller;
  late final ShipmentController shipmentController;

  final TextEditingController _currencyInput = TextEditingController();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.find<ProductController>();
    shipmentController = Get.find<ShipmentController>();

    controller.refreshStockData();
  }

  @override
  void dispose() {
    _currencyInput.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: StockAppBar(isMobile: isMobile, controller: controller),
      floatingActionButton: PermissionButton(
        route: Routes.stock,
        type: PermissionType.canCreate,
        showDisabled: true,
        child: FloatingActionButton.extended(
          onPressed: () => showCreateProductDialog(controller),
          backgroundColor: const Color(0xFF2563EB),
          elevation: 2,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            isMobile ? 'Add' : 'Add Product',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          StockStatsSection(
            isMobile: isMobile,
            controller: controller,
            currencyInput: _currencyInput,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 8 : 16,
              0,
              isMobile ? 8 : 16,
              10,
            ),
            child: _StockToolbar(isMobile: isMobile, controller: controller),
          ),
          Expanded(
            child: _StockSurface(
              isMobile: isMobile,
              child: Column(
                children: [
                  Expanded(
                    child: StockTable(
                      isMobile: isMobile,
                      controller: controller,
                      shipmentController: shipmentController,
                      verticalScroll: _verticalScroll,
                      horizontalScroll: _horizontalScroll,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _PaginationSection(
                    isMobile: isMobile,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockSurface extends StatelessWidget {
  final bool isMobile;
  final Widget child;

  const _StockSurface({required this.isMobile, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isMobile ? 8 : 16, 0, isMobile ? 8 : 16, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _StockToolbar extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;

  const _StockToolbar({required this.isMobile, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _ToolbarShell(
      child: isMobile
          ? Column(
              children: [
                _SearchBox(controller: controller, isMobile: isMobile),
                const SizedBox(height: 10),
                _WarehouseFilter(controller: controller),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SortLossButton(
                        controller: controller,
                        isMobile: isMobile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ClearFiltersButton(controller: controller),
                    const SizedBox(width: 8),
                    _WarehouseSettingsButton(controller: controller),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _SearchBox(
                    controller: controller,
                    isMobile: isMobile,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 230,
                  child: _WarehouseFilter(controller: controller),
                ),
                const SizedBox(width: 10),
                _SortLossButton(controller: controller, isMobile: isMobile),
                const SizedBox(width: 10),
                _ClearFiltersButton(controller: controller),
                const SizedBox(width: 10),
                _WarehouseSettingsButton(controller: controller),
              ],
            ),
    );
  }
}

class _ToolbarShell extends StatelessWidget {
  final Widget child;

  const _ToolbarShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SearchBox extends StatelessWidget {
  final ProductController controller;
  final bool isMobile;

  const _SearchBox({required this.controller, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      onChanged: controller.search,
      decoration: InputDecoration(
        hintText:
            isMobile ? 'Search stock...' : 'Search by model, name or brand...',
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _WarehouseFilter extends StatelessWidget {
  final ProductController controller;

  const _WarehouseFilter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return DropdownButtonFormField<int?>(
        value: controller.selectedWarehouseId.value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Warehouse',
          prefixIcon: Icon(Icons.warehouse_rounded, size: 18),
          isDense: true,
          filled: true,
          fillColor: Color(0xFFF8FAFC),
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All Warehouses'),
          ),
          ...controller.activeWarehouses.map((warehouse) {
            final id = int.tryParse(warehouse['id'].toString()) ?? 0;
            final name = warehouse['name']?.toString() ?? 'Warehouse $id';

            return DropdownMenuItem<int?>(
              value: id,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: controller.selectWarehouseFilter,
      );
    });
  }
}

class _SortLossButton extends StatelessWidget {
  final ProductController controller;
  final bool isMobile;

  const _SortLossButton({required this.controller, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.sortByLoss.value;

      return SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: controller.toggleSortByLoss,
          icon: Icon(
            active ? Icons.trending_down_rounded : Icons.sort_rounded,
            size: 18,
            color: active ? const Color(0xFFDC2626) : const Color(0xFF475569),
          ),
          label: Text(
            isMobile ? 'Loss' : 'Loss First',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFFDC2626) : const Color(0xFF475569),
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: active ? const Color(0xFFFEF2F2) : Colors.white,
            side: BorderSide(
              color: active ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    });
  }
}

class _ClearFiltersButton extends StatelessWidget {
  final ProductController controller;

  const _ClearFiltersButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: controller.clearFilters,
        icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
        label: const Text(
          'Clear',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF475569),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _WarehouseSettingsButton extends StatelessWidget {
  final ProductController controller;

  const _WarehouseSettingsButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PermissionButton(
      route: Routes.stock,
      type: PermissionType.action,
      actionKey: 'stock.adjust',
      showDisabled: true,
      child: SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => Get.dialog(
            _WarehouseSettingsDialog(controller: controller),
          ),
          icon: const Icon(Icons.warehouse_rounded, size: 18),
          label: const Text(
            'Warehouses',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1D4ED8),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseSettingsDialog extends StatelessWidget {
  final ProductController controller;

  const _WarehouseSettingsDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Column(
          children: [
            _DialogHeader(
              title: 'Warehouse Settings',
              icon: Icons.warehouse_rounded,
              onClose: Get.back,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'New warehouse name',
                        prefixIcon: Icon(Icons.add_business_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(() {
                    return FilledButton.icon(
                      onPressed: controller.isActionLoading.value
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              await controller.createWarehouse(name);
                              nameCtrl.clear();
                            },
                      icon: controller.isActionLoading.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (controller.warehouses.isEmpty) {
                  return const Center(child: Text('No warehouses found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.warehouses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final warehouse = controller.warehouses[index];
                    return _WarehouseEditTile(
                      warehouse: warehouse,
                      controller: controller,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseEditTile extends StatefulWidget {
  final Map<String, dynamic> warehouse;
  final ProductController controller;

  const _WarehouseEditTile({required this.warehouse, required this.controller});

  @override
  State<_WarehouseEditTile> createState() => _WarehouseEditTileState();
}

class _WarehouseEditTileState extends State<_WarehouseEditTile> {
  late final TextEditingController _nameCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.warehouse['name']?.toString() ?? '',
    );
    _isActive = widget.warehouse['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(widget.warehouse['id'].toString()) ?? 0;
    final totalQty = widget.controller.warehouseTotalQty(id);
    final productCount = widget.controller.warehouseProductCount(id);
    final totalValue = widget.controller.warehouseTotalValue(id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse name',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              IconButton(
                tooltip: 'Save',
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  if (id <= 0 || name.isEmpty) return;
                  widget.controller.updateWarehouseName(
                    warehouseId: id,
                    name: name,
                    isActive: _isActive,
                  );
                },
                icon: const Icon(Icons.save_rounded, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _WarehouseMetric(
                label: 'Products',
                value: productCount.toString(),
                icon: Icons.category_rounded,
              ),
              const SizedBox(width: 8),
              _WarehouseMetric(
                label: 'Qty',
                value: totalQty.toString(),
                icon: Icons.inventory_2_rounded,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarehouseMetric(
                  label: 'Value',
                  value: widget.controller.formatMoney(totalValue),
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarehouseMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WarehouseMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationSection extends StatelessWidget {
  final bool isMobile;
  final ProductController controller;

  const _PaginationSection({required this.isMobile, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.totalProducts.value;
      final current = controller.currentPage.value;
      final size = controller.pageSize.value;
      final totalPages = controller.totalPages;
      final start = total == 0 ? 0 : ((current - 1) * size) + 1;
      final end = (current * size) > total ? total : current * size;

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: 10,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                isMobile
                    ? '$total products'
                    : 'Showing $start-$end of $total products',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: current > 1 ? controller.previousPage : null,
                ),
                Container(
                  width: isMobile ? 86 : 116,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$current / $totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: current < totalPages ? controller.nextPage : null,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.title,
    required this.icon,
    required this.onClose,
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}