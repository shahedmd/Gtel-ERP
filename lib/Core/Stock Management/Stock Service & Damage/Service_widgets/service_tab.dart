import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Service/service_constatnts.dart';
import '../service_controller.dart';
import 'return_stock_dialog.dart';
import 'pagination_footer.dart';

// ─── Shared date formatter (singleton, format once) ───────────────────────────
final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
String formatServiceDate(String? raw) {
  if (raw == null) return 'N/A';
  try {
    return _dateFmt.format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return raw;
  }
}

/// One tab's worth of content (active service OR damage history).
///
/// Uses [AutomaticKeepAliveClientMixin] so the list isn't rebuilt when
/// switching tabs after the first render.
class ServiceTabContent extends StatefulWidget {
  const ServiceTabContent({
    super.key,
    required this.tab,
    required this.ctrl,
    required this.isMobile,
  });

  final ServiceTab       tab;
  final ServiceController ctrl;
  final bool             isMobile;

  @override
  State<ServiceTabContent> createState() => _ServiceTabContentState();
}

class _ServiceTabContentState extends State<ServiceTabContent>
    with AutomaticKeepAliveClientMixin {
  // Each tab manages its own scroll controllers to avoid cross-tab interference.
  final _vScroll = ScrollController();
  final _hScroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _vScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by mixin

    return Obx(() {
      // Re-run whenever serviceLogs, pagination, or loading state changes.
      final _ = widget.ctrl.prodCtrl.serviceLogs.length; // reactive dependency
      final isLoading = widget.ctrl.isLoading;
      final fullList  = widget.tab == ServiceTab.active
          ? widget.ctrl.activeServices
          : widget.ctrl.damageLogs;

      if (isLoading && fullList.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 3));
      }

      if (fullList.isEmpty) {
        return _EmptyState(tab: widget.tab);
      }

      final page       = widget.ctrl.currentPage(widget.tab);
      final total      = widget.ctrl.totalCount(widget.tab);
      final pages      = widget.ctrl.totalPages(widget.tab);
      final pageSlice  = widget.ctrl.paginatedList(widget.tab);
      final startIndex = (page - 1) * AppLayout.pageSize;
      final endIndex   = (startIndex + pageSlice.length);

      return Column(
        children: [
          _SummaryHeader(tab: widget.tab, ctrl: widget.ctrl),
          Expanded(
            child: _TableCard(
              items:     pageSlice,
              tab:       widget.tab,
              isMobile:  widget.isMobile,
              ctrl:      widget.ctrl,
              hScroll:   _hScroll,
              vScroll:   _vScroll,
            ),
          ),
          PaginationFooter(
            total:      total,
            startIndex: startIndex,
            endIndex:   endIndex,
            totalPages: pages,
            current:    page,
            isMobile:   widget.isMobile,
            onNext:     () => widget.ctrl.nextPage(widget.tab),
            onPrev:     () => widget.ctrl.prevPage(widget.tab),
          ),
        ],
      );
    });
  }
}

// ─── Summary header ───────────────────────────────────────────────────────────
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.tab, required this.ctrl});
  final ServiceTab       tab;
  final ServiceController ctrl;

  @override
  Widget build(BuildContext context) {
    if (tab == ServiceTab.active) {
      return _Banner(
        color: Colors.orange,
        icon: Icons.build,
        text: 'Items currently pending repair: ${ctrl.activePendingQty}',
      );
    } else {
      return _Banner(
        color: Colors.red,
        icon: Icons.warning_amber,
        text: 'Total Loss Value: ৳${ctrl.totalDamageLoss.toStringAsFixed(2)}',
      );
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final MaterialColor color;
  final IconData      icon;
  final String        text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: color.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color.shade800),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

// ─── Card wrapper ─────────────────────────────────────────────────────────────
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.items,
    required this.tab,
    required this.isMobile,
    required this.ctrl,
    required this.hScroll,
    required this.vScroll,
  });

  final List<Map<String, dynamic>> items;
  final ServiceTab                 tab;
  final bool                       isMobile;
  final ServiceController          ctrl;
  final ScrollController           hScroll;
  final ScrollController           vScroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isMobile
            ? _MobileList(items: items, tab: tab, ctrl: ctrl)
            : _DesktopTable(
                items:   items,
                tab:     tab,
                ctrl:    ctrl,
                hScroll: hScroll,
                vScroll: vScroll,
              ),
      ),
    );
  }
}

// ─── Desktop scrollable table ──────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.items,
    required this.tab,
    required this.ctrl,
    required this.hScroll,
    required this.vScroll,
  });

  final List<Map<String, dynamic>> items;
  final ServiceTab                 tab;
  final ServiceController          ctrl;
  final ScrollController           hScroll;
  final ScrollController           vScroll;

  static const _activeColumns  = ['DATE', 'MODEL', 'QTY', 'UNIT VALUE', 'STATUS', 'ACTION'];
  static const _damageColumns  = ['DATE', 'MODEL', 'QTY', 'UNIT COST',  'TOTAL LOSS'];
  static const _activeWidths   = [180.0, 200.0, 80.0, 120.0, 120.0, 150.0];
  static const _damageWidths   = [180.0, 200.0, 80.0, 120.0, 150.0];

  @override
  Widget build(BuildContext context) {
    final columns = tab == ServiceTab.active ? _activeColumns : _damageColumns;
    final widths  = tab == ServiceTab.active ? _activeWidths  : _damageWidths;
    final minW    = widths.fold(0.0, (a, b) => a + b);

    return ScrollConfiguration(
      behavior: const TableScrollBehavior(),
      child: Scrollbar(
        controller: vScroll,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: vScroll,
          child: Scrollbar(
            controller: hScroll,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: hScroll,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ─────────────────────────────────────
                    _HeaderRow(columns: columns, widths: widths),
                    // ── Data rows ──────────────────────────────────────
                    ...List.generate(items.length, (i) {
                      final item = items[i];
                      return _DataRow(
                        item:   item,
                        tab:    tab,
                        ctrl:   ctrl,
                        widths: widths,
                        isEven: i.isEven,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.widths});
  final List<String> columns;
  final List<double> widths;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.headerBg,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < columns.length; i++)
              SizedBox(
                width: widths[i],
                child: Text(
                  columns[i],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateGrey,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.item,
    required this.tab,
    required this.ctrl,
    required this.widths,
    required this.isEven,
  });

  final Map<String, dynamic> item;
  final ServiceTab            tab;
  final ServiceController     ctrl;
  final List<double>          widths;
  final bool                  isEven;

  @override
  Widget build(BuildContext context) {
    final qty      = int.tryParse(item['qty'].toString()) ?? 0;
    final cost     = double.tryParse(item['return_cost'].toString()) ?? 0.0;
    final dateStr  = formatServiceDate(item['created_at']?.toString());

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: tab == ServiceTab.active
          ? _ActiveRow(item: item, qty: qty, cost: cost, date: dateStr, ctrl: ctrl, widths: widths)
          : _DamageRow(item: item, qty: qty, cost: cost, date: dateStr, widths: widths),
    );
  }
}

// ─── Active row ───────────────────────────────────────────────────────────────
class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.item, required this.qty, required this.cost,
    required this.date, required this.ctrl, required this.widths,
  });

  final Map<String, dynamic> item;
  final int qty; final double cost; final String date;
  final ServiceController ctrl;
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    final isActive = item['status'] == 'active';
    return Row(children: [
      _cell(Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textDark)), widths[0]),
      _cell(Text(item['model'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), widths[1]),
      _cell(Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), widths[2]),
      _cell(Text('৳${cost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)), widths[3]),
      _cell(StatusBadge(label: isActive ? 'Pending' : 'Returned', color: isActive ? Colors.orange : Colors.green), widths[4]),
      _cell(
        isActive
            ? ElevatedButton.icon(
                onPressed: () => _showReturnDialog(context),
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Return'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              )
            : const Text('-', style: TextStyle(color: Colors.grey)),
        widths[5],
      ),
    ]);
  }

  void _showReturnDialog(BuildContext context) {
    Get.dialog(ReturnStockDialog(
      logId:     item['id'] as int,
      modelName: item['model']?.toString() ?? '',
      maxQty:    qty,
      onConfirm: ctrl.returnStock,
    ));
  }
}

// ─── Damage row ───────────────────────────────────────────────────────────────
class _DamageRow extends StatelessWidget {
  const _DamageRow({
    required this.item, required this.qty, required this.cost,
    required this.date, required this.widths,
  });

  final Map<String, dynamic> item;
  final int qty; final double cost; final String date;
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    final totalLoss = qty * cost;
    return Row(children: [
      _cell(Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textDark)), widths[0]),
      _cell(Text(item['model'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), widths[1]),
      _cell(Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), widths[2]),
      _cell(Text('৳${cost.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark)), widths[3]),
      _cell(Text('৳${totalLoss.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), widths[4]),
    ]);
  }
}

Widget _cell(Widget child, double width) => SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );

// ─── Mobile list ──────────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  const _MobileList({required this.items, required this.tab, required this.ctrl});
  final List<Map<String, dynamic>> items;
  final ServiceTab                 tab;
  final ServiceController          ctrl;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item    = items[i];
        final qty     = int.tryParse(item['qty'].toString()) ?? 0;
        final cost    = double.tryParse(item['return_cost'].toString()) ?? 0.0;
        final dateStr = formatServiceDate(item['created_at']?.toString());

        return tab == ServiceTab.active
            ? _ActiveCard(item: item, qty: qty, cost: cost, date: dateStr, ctrl: ctrl)
            : _DamageCard(item: item, qty: qty, cost: cost, date: dateStr);
      },
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.item, required this.qty, required this.cost,
    required this.date, required this.ctrl,
  });

  final Map<String, dynamic> item;
  final int qty; final double cost; final String date;
  final ServiceController ctrl;

  @override
  Widget build(BuildContext context) {
    final isActive = item['status'] == 'active';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: [
        // header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item['model'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkSlate)),
              StatusBadge(
                label: isActive ? 'Pending' : 'Returned',
                color: isActive ? Colors.orange : Colors.green,
              ),
            ],
          ),
        ),
        // body
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatColumn(label: 'Quantity',   value: '$qty',                  valueColor: null),
                _StatColumn(label: 'Unit Value', value: '৳${cost.toStringAsFixed(2)}', valueColor: Colors.teal),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Get.dialog(ReturnStockDialog(
                    logId:     item['id'] as int,
                    modelName: item['model']?.toString() ?? '',
                    maxQty:    qty,
                    onConfirm: ctrl.returnStock,
                  )),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Return Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _DamageCard extends StatelessWidget {
  const _DamageCard({required this.item, required this.qty, required this.cost, required this.date});
  final Map<String, dynamic> item;
  final int qty; final double cost; final String date;

  @override
  Widget build(BuildContext context) {
    final totalLoss = qty * cost;
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['model'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkSlate)),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('-$qty', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('৳${totalLoss.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
      ]),
    );
  }
}

// ─── Shared micro-widgets ──────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});
  final String        label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.shade200),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color.shade800,
          ),
        ),
      );
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, this.valueColor});
  final String  label;
  final String  value;
  final Color?  valueColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
        ],
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});
  final ServiceTab tab;

  @override
  Widget build(BuildContext context) {
    final isActive = tab == ServiceTab.active;
    final color    = isActive ? Colors.green : Colors.blue;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
          child: Icon(
            isActive ? Icons.check_circle_outline : Icons.sentiment_satisfied_alt,
            size: 48,
            color: color.shade400,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isActive ? 'All Clear' : 'No Damage',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkSlate),
        ),
        const SizedBox(height: 8),
        Text(
          isActive ? 'No products currently in service.' : 'Great! No damaged items recorded.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      ]),
    );
  }
}