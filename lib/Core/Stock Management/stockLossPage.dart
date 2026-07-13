import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'stockcontroller.dart';

// ─── Constants (mirrors product_screen.dart palette) ───────────────────────

const _kBlue = Color(0xFF2563EB);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kRed = Color(0xFFDC2626);
const _kRedSoft = Color(0xFFFEF2F2);
const _kGreen = Color(0xFF16A34A);
const _kGreenSoft = Color(0xFFF0FDF4);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF8FAFC);
const _kSurface = Colors.white;
const _kTextPrimary = Color(0xFF1E293B);
const _kTextSecondary = Color(0xFF64748B);
const _kTableHeader = Color(0xFFF1F5F9);
const _kGrey = Color(0xFF9CA3AF);
const _kGreySoft = Color(0xFFF3F4F6);
const _kPurple = Color(0xFF7C3AED);
const _kPurpleSoft = Color(0xFFF5F3FF);

class StockLossPage extends StatefulWidget {
  const StockLossPage({super.key});

  @override
  State<StockLossPage> createState() => _StockLossPageState();
}

class _StockLossPageState extends State<StockLossPage>
    with SingleTickerProviderStateMixin {
  final ProductController controller = Get.find<ProductController>();
  late final TabController _tabController;
  final RxBool _isExporting = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    controller.lossLimit.value = 30;
    controller.fetchLossLogs(page: 1);
    controller.fetchLossSummary();
  }

  Future<void> _handleExport() async {
    if (_isExporting.value) return;
    _isExporting.value = true;
    try {
      if (_tabController.index == 0) {
        await exportLossHistoryPdf(controller);
      } else {
        await exportLossSummaryPdf(controller);
      }
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        e.toString(),
        backgroundColor: _kRed,
        colorText: Colors.white,
      );
    } finally {
      _isExporting.value = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 850;

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(
              Icons.report_gmailerrorred_outlined,
              color: _kPurple,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Stock Loss',
              style: TextStyle(
                fontSize: mobile ? 18 : 21,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip:
                  _tabController.index == 0
                      ? 'Download History as PDF'
                      : 'Download Summary as PDF',
              onPressed: _isExporting.value ? null : _handleExport,
              icon:
                  _isExporting.value
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: _kPurple,
                      ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kPurple,
          unselectedLabelColor: _kTextSecondary,
          indicatorColor: _kPurple,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [Tab(text: 'History'), Tab(text: 'Summary')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryTab(mobile: mobile, controller: controller),
          _SummaryTab(mobile: mobile, controller: controller),
        ],
      ),
    );
  }
}

// ─── History Tab ─────────────────────────────────────────────────────────────

// ─── Compact table column widths ────────────────────────────────────────────

class _LCol {
  static const double date = 82;
  static const double product = 210;
  static const double warehouse = 120;
  static const double reason = 100;
  static const double qty = 50;
  static const double unitCost = 85;
  static const double totalLoss = 95;
  static const double status = 85;
  static const double action = 56;
  static const double rowPadding = 14;

  static double get contentWidth =>
      date +
      product +
      warehouse +
      reason +
      qty +
      unitCost +
      totalLoss +
      status +
      action;

  static double get tableMinWidth => contentWidth + (rowPadding * 2);
}

class _HistoryTab extends StatefulWidget {
  final bool mobile;
  final ProductController controller;

  const _HistoryTab({required this.mobile, required this.controller});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final ScrollController _hScroll = ScrollController();

  bool get mobile => widget.mobile;
  ProductController get controller => widget.controller;

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _summaryStrip(),
        _filterBar(context),
        const Divider(height: 1, color: _kBorder),
        Expanded(child: _table(context)),
        const Divider(height: 1, color: _kBorder),
        _pagination(),
      ],
    );
  }

  Widget _summaryStrip() {
    return Obx(
      () => Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 12, mobile ? 10 : 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _statCard(
                'Lost Units',
                controller.lossTotalQty.value.toString(),
                Icons.inventory_2_outlined,
                _kRed,
                _kRedSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Lost Value',
                '৳${controller.formatCurrency(controller.lossTotalValue.value)}',
                Icons.monetization_on_outlined,
                _kPurple,
                _kPurpleSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color fg,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 10, mobile ? 10 : 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: controller.searchLoss,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by model, name or brand...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: _kTextSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: _kTextSecondary,
                      size: 20,
                    ),
                    fillColor: _kSurface,
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _pickDateRange(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: _kTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Obx(
                () => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: controller.includeReturnedLoss.value,
                      activeColor: _kPurple,
                      onChanged: (_) => controller.toggleIncludeReturnedLoss(),
                    ),
                    const Text(
                      'Show returned entries',
                      style: TextStyle(fontSize: 12, color: _kTextSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Obx(() {
                final from = controller.lossFromDate.value;
                final to = controller.lossToDate.value;
                if (from == null && to == null) return const SizedBox.shrink();
                final label =
                    '${from != null ? DateFormat('dd MMM').format(from) : '...'}'
                    ' – '
                    '${to != null ? DateFormat('dd MMM').format(to) : '...'}';
                return GestureDetector(
                  onTap: () => controller.setLossDateRange(null, null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _kBlueSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 11, color: _kBlue),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 12, color: _kBlue),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          controller.lossFromDate.value != null &&
                  controller.lossToDate.value != null
              ? DateTimeRange(
                start: controller.lossFromDate.value!,
                end: controller.lossToDate.value!,
              )
              : null,
    );
    if (picked != null) {
      controller.setLossDateRange(picked.start, picked.end);
    }
  }

  Widget _table(BuildContext context) {
    return Obx(() {
      if (controller.isLossLoading.value && controller.lossLogs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.lossLogs.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: _kTextSecondary,
              ),
              SizedBox(height: 12),
              Text(
                'No loss entries found',
                style: TextStyle(color: _kTextSecondary, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _LCol.tableMinWidth,
            child: Column(
              children: [
                _tableHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.lossLogs.length,
                    itemBuilder:
                        (_, i) => _tableRow(context, controller.lossLogs[i], i),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _tableHeader() {
    return Container(
      color: _kTableHeader,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: _LCol.rowPadding,
      ),
      child: Row(
        children: [
          _hCell('DATE', _LCol.date),
          _hCell('PRODUCT', _LCol.product),
          _hCell('WAREHOUSE', _LCol.warehouse),
          _hCell('REASON', _LCol.reason),
          _hCell('QTY', _LCol.qty),
          _hCell('UNIT COST', _LCol.unitCost),
          _hCell('TOTAL LOSS', _LCol.totalLoss),
          _hCell('STATUS', _LCol.status),
          _hCell('', _LCol.action),
        ],
      ),
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
          fontSize: 10.5,
          color: _kTextSecondary,
          letterSpacing: 0.4,
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

  Widget _tableRow(BuildContext context, StockLossLog log, int index) {
    final returned = log.isReturned;
    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? _kSurface : const Color(0xFFFAFAFC),
        border: const Border(bottom: BorderSide(color: _kBorder, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: _LCol.rowPadding,
      ),
      child: Row(
        children: [
          _dCell(
            Text(
              log.createdAt != null
                  ? DateFormat('dd MMM yy').format(log.createdAt!)
                  : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kTextSecondary),
            ),
            _LCol.date,
          ),
          _dCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        log.model.isNotEmpty ? log.model : log.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: _kTextPrimary,
                        ),
                      ),
                      Text(
                        log.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log.note.isNotEmpty)
                  Tooltip(
                    message: log.note,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        size: 13,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            _LCol.product,
          ),
          _dCell(
            Text(
              log.warehouseName.isNotEmpty ? log.warehouseName : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kTextSecondary),
            ),
            _LCol.warehouse,
          ),
          _dCell(
            Text(
              log.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kTextPrimary),
            ),
            _LCol.reason,
          ),
          _dCell(
            Text(
              log.qty.toString(),
              maxLines: 1,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: _kTextPrimary,
              ),
            ),
            _LCol.qty,
          ),
          _dCell(
            Text(
              '৳${log.unitCost.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kTextSecondary),
            ),
            _LCol.unitCost,
          ),
          _dCell(
            Text(
              '৳${log.totalLossValue.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: returned ? _kTextSecondary : _kRed,
              ),
            ),
            _LCol.totalLoss,
          ),
          _dCell(
            _pill(
              returned ? 'RETURNED' : 'ACTIVE',
              returned ? _kGreen : _kPurple,
              returned ? _kGreenSoft : _kPurpleSoft,
            ),
            _LCol.status,
          ),
          _dCell(
            returned
                ? const Icon(Icons.check, size: 16, color: _kGrey)
                : InkWell(
                  onTap: () => _showReturnDialog(context, log),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.undo, size: 17, color: _kGreen),
                  ),
                ),
            _LCol.action,
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 9.5),
      ),
    );
  }

  Widget _pagination() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: 10),
      child: Obx(() {
        final total = controller.lossTotal.value;
        final current = controller.lossPage.value;
        final size = controller.lossLimit.value;
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
              current > 1 ? controller.prevLossPage : null,
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
              current < totalPages ? controller.nextLossPage : null,
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

  // ─── Return / Reverse Dialog ────────────────────────────────────────────

  void _showReturnDialog(BuildContext context, StockLossLog log) {
    final qtyC = TextEditingController(text: log.qty.toString());
    final locationC = TextEditingController();
    final RxInt warehouseId = RxInt(log.warehouseId ?? 0);
    final RxString error = RxString('');

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.undo, color: _kGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reverse Loss: ${log.model.isNotEmpty ? log.model : log.productName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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
              Text(
                'Recorded loss: ${log.qty} units (৳${log.totalLossValue.toStringAsFixed(0)})',
                style: const TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyC,
                keyboardType: TextInputType.number,
                onChanged: (_) => error.value = '',
                decoration: InputDecoration(
                  labelText: 'Quantity to restore',
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
              const SizedBox(height: 12),
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
                        'Restore to original warehouse',
                        style: TextStyle(fontSize: 13),
                      ),
                      items:
                          controller.activeWarehouses
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(
                                    w.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) warehouseId.value = v;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationC,
                decoration: InputDecoration(
                  labelText: 'Location (optional)',
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
                    error.value.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
              ),
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
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
                      : const Icon(Icons.undo, size: 16),
              label: const Text('Restore Stock'),
              onPressed:
                  controller.isActionLoading.value
                      ? null
                      : () async {
                        final qty = int.tryParse(qtyC.text) ?? 0;
                        if (qty <= 0 || qty > log.qty) {
                          error.value =
                              'Enter a value between 1 and ${log.qty}.';
                          return;
                        }
                        final success = await controller.returnFromLoss(
                          log,
                          qty: qty,
                          warehouseId:
                              warehouseId.value == 0 ? null : warehouseId.value,
                          location:
                              locationC.text.trim().isNotEmpty
                                  ? locationC.text.trim()
                                  : null,
                        );
                        if (success) Get.back();
                      },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Tab ─────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final bool mobile;
  final ProductController controller;

  const _SummaryTab({required this.mobile, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLossSummaryLoading.value &&
          controller.lossSummary.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final summary = controller.lossSummary;
      if (summary.isEmpty) {
        return const Center(
          child: Text(
            'No summary data available',
            style: TextStyle(color: _kTextSecondary),
          ),
        );
      }

      final overall = Map<String, dynamic>.from(summary['overall'] ?? {});
      final byProduct = List<Map<String, dynamic>>.from(
        (summary['by_product'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      final byReason = List<Map<String, dynamic>>.from(
        (summary['by_reason'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      final byMonth = List<Map<String, dynamic>>.from(
        (summary['by_month'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );

      return RefreshIndicator(
        onRefresh: () => controller.fetchLossSummary(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(mobile ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _overallCard(
                      'Total Units Lost',
                      '${overall['total_qty'] ?? 0}',
                      Icons.inventory_2_outlined,
                      _kRed,
                      _kRedSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overallCard(
                      'Total Loss Value',
                      '৳${controller.formatCurrency(safeDouble(overall['total_value']))}',
                      Icons.monetization_on_outlined,
                      _kPurple,
                      _kPurpleSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overallCard(
                      'Products Affected',
                      '${overall['distinct_products'] ?? 0}',
                      Icons.category_outlined,
                      _kBlue,
                      _kBlueSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('By Reason'),
              const SizedBox(height: 8),
              _reasonList(byReason),
              const SizedBox(height: 20),
              _sectionTitle('By Month'),
              const SizedBox(height: 8),
              _monthList(byMonth),
              const SizedBox(height: 20),
              _sectionTitle('Top Products by Loss Value'),
              const SizedBox(height: 8),
              _productList(byProduct),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: _kTextPrimary,
      ),
    );
  }

  Widget _overallCard(
    String label,
    String value,
    IconData icon,
    Color fg,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _kTextSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _emptyMini();
    final maxVal = items
        .map((e) => safeDouble(e['total_value']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children:
            items.map((e) {
              final val = safeDouble(e['total_value']);
              final frac = maxVal > 0 ? (val / maxVal).clamp(0.02, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${e['reason']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${e['total_qty']} pcs · ৳${val.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: _kGreySoft,
                        valueColor: const AlwaysStoppedAnimation(_kPurple),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _monthList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _emptyMini();
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == items.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border:
                      isLast
                          ? null
                          : const Border(
                            bottom: BorderSide(color: _kBorder, width: 0.6),
                          ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: _kTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${e['month']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${e['total_qty']} pcs',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '৳${safeDouble(e['total_value']).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRed,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _productList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _emptyMini();
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == items.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border:
                      isLast
                          ? null
                          : const Border(
                            bottom: BorderSide(color: _kBorder, width: 0.6),
                          ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e['model'] ?? e['product_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${e['product_name']}${(e['brand'] ?? '').toString().isNotEmpty ? ' · ${e['brand']}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${safeDouble(e['total_value']).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kRed,
                          ),
                        ),
                        Text(
                          '${e['total_qty']} pcs',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _emptyMini() => Container(
    padding: const EdgeInsets.all(20),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kBorder),
    ),
    child: const Text(
      'No data yet',
      style: TextStyle(color: _kTextSecondary, fontSize: 12),
    ),
  );
}

// ─── PDF Export ──────────────────────────────────────────────────────────────
//
// Two reports are supported:
//   • History  -> full itemised list of loss entries (respects the current
//                 search / date-range / include-returned filters, but is not
//                 limited to the current page — it re-fetches everything
//                 matching those filters with `all=true`).
//   • Summary  -> the aggregate report (overall totals, by reason, by month,
//                 by product) currently loaded in the Summary tab.
//
// Both use `Printing.layoutPdf`, which opens the native share/print/save
// sheet on every platform (including "Save as PDF" in the browser on web),
// so no extra storage permissions are needed.

Future<List<StockLossLog>> _fetchAllLossLogsForExport(
  ProductController controller,
) async {
  final uri = Uri.parse('${ProductController.baseUrl}/stock/loss').replace(
    queryParameters: {
      'all': 'true',
      'search': controller.lossSearchText.value.trim(),
      'include_returned': controller.includeReturnedLoss.value.toString(),
      if (controller.lossFromDate.value != null)
        'from_date': controller.lossFromDate.value!.toIso8601String(),
      if (controller.lossToDate.value != null)
        'to_date': controller.lossToDate.value!.toIso8601String(),
    },
  );

  final res = await http.get(uri).timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw Exception('Server error (${res.statusCode}) while fetching logs');
  }

  final decoded = jsonDecode(res.body);
  final list = (decoded['logs'] as List? ?? []);
  return list
      .map((e) => StockLossLog.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<void> exportLossHistoryPdf(ProductController controller) async {
  final logs = await _fetchAllLossLogsForExport(controller);

  if (logs.isEmpty) {
    Get.snackbar(
      'Nothing to Export',
      'No loss entries match the current filters.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }

  final totalQty = logs.fold<int>(0, (a, b) => a + b.qty);
  final totalValue = logs.fold<double>(0, (a, b) => a + b.totalLossValue);
  final activeCount = logs.where((l) => !l.isReturned).length;

  final doc = pw.Document();
  final dateFmt = DateFormat('dd MMM yyyy');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) {
        if (ctx.pageNumber != 1) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Stock Loss Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
          ],
        );
      },
      footer:
          (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
      build:
          (ctx) => [
            pw.Row(
              children: [
                _pdfStatBox('Entries', logs.length.toString()),
                pw.SizedBox(width: 10),
                _pdfStatBox('Active Losses', activeCount.toString()),
                pw.SizedBox(width: 10),
                _pdfStatBox('Units Lost', totalQty.toString()),
                pw.SizedBox(width: 10),
                _pdfStatBox(
                  'Value Lost',
                  currencyFmt.format(totalValue),
                  highlight: true,
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF7C3AED),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 22,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.6),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(1.6),
                5: pw.FlexColumnWidth(1.8),
                6: pw.FlexColumnWidth(1.4),
              },
              headers: const [
                'Date',
                'Model',
                'Reason',
                'Qty',
                'Unit Cost',
                'Total Loss',
                'Status',
              ],
              data:
                  logs.map((l) {
                    return [
                      l.createdAt != null ? dateFmt.format(l.createdAt!) : '—',
                      l.model.isNotEmpty ? l.model : l.productName,
                      l.reason,
                      l.qty.toString(),
                      currencyFmt.format(l.unitCost),
                      currencyFmt.format(l.totalLossValue),
                      l.isReturned ? 'Returned' : 'Active',
                    ];
                  }).toList(),
            ),
          ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name:
        'stock_loss_history_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
  );
}

Future<void> exportLossSummaryPdf(ProductController controller) async {
  final summary = controller.lossSummary;
  if (summary.isEmpty) {
    Get.snackbar(
      'Nothing to Export',
      'Summary data has not loaded yet.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }

  final overall = Map<String, dynamic>.from(summary['overall'] ?? {});
  final byProduct = List<Map<String, dynamic>>.from(
    (summary['by_product'] as List? ?? []).map(
      (e) => Map<String, dynamic>.from(e),
    ),
  );
  final byReason = List<Map<String, dynamic>>.from(
    (summary['by_reason'] as List? ?? []).map(
      (e) => Map<String, dynamic>.from(e),
    ),
  );
  final byMonth = List<Map<String, dynamic>>.from(
    (summary['by_month'] as List? ?? []).map(
      (e) => Map<String, dynamic>.from(e),
    ),
  );

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) {
        if (ctx.pageNumber != 1) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Stock Loss Summary',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
          ],
        );
      },
      footer:
          (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
      build:
          (ctx) => [
            pw.Row(
              children: [
                _pdfStatBox('Units Lost', '${overall['total_qty'] ?? 0}'),
                pw.SizedBox(width: 10),
                _pdfStatBox(
                  'Value Lost',
                  currencyFmt.format(safeDouble(overall['total_value'])),
                  highlight: true,
                ),
                pw.SizedBox(width: 10),
                _pdfStatBox(
                  'Products Affected',
                  '${overall['distinct_products'] ?? 0}',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('By Reason'),
            pw.SizedBox(height: 6),
            _pdfSimpleTable(
              headers: const ['Reason', 'Qty', 'Total Value'],
              rows:
                  byReason
                      .map(
                        (e) => [
                          '${e['reason']}',
                          '${e['total_qty']}',
                          currencyFmt.format(safeDouble(e['total_value'])),
                        ],
                      )
                      .toList(),
            ),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('By Month'),
            pw.SizedBox(height: 6),
            _pdfSimpleTable(
              headers: const ['Month', 'Qty', 'Total Value'],
              rows:
                  byMonth
                      .map(
                        (e) => [
                          '${e['month']}',
                          '${e['total_qty']}',
                          currencyFmt.format(safeDouble(e['total_value'])),
                        ],
                      )
                      .toList(),
            ),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('Top Products by Loss Value'),
            pw.SizedBox(height: 6),
            _pdfSimpleTable(
              headers: const ['Product', 'Qty', 'Total Value'],
              rows:
                  byProduct
                      .map(
                        (e) => [
                          '${e['model'] ?? e['product_name']}',
                          '${e['total_qty']}',
                          currencyFmt.format(safeDouble(e['total_value'])),
                        ],
                      )
                      .toList(),
            ),
          ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name:
        'stock_loss_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
  );
}

final NumberFormat currencyFmt = NumberFormat('#,##0', 'en_US');

pw.Widget _pdfStatBox(String label, String value, {bool highlight = false}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color:
            highlight
                ? const PdfColor.fromInt(0xFFF5F3FF)
                : const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color:
                  highlight
                      ? const PdfColor.fromInt(0xFF7C3AED)
                      : const PdfColor.fromInt(0xFF1E293B),
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _pdfSectionTitle(String title) {
  return pw.Text(
    title,
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
  );
}

pw.Widget _pdfSimpleTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  if (rows.isEmpty) {
    return pw.Text(
      'No data',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    );
  }
  return pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFF2563EB),
    ),
    cellStyle: const pw.TextStyle(fontSize: 8.5),
    cellHeight: 20,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
    headers: headers,
    data: rows,
  );
}
