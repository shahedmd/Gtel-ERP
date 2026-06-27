import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'stockcontroller.dart';
import 'stockproductmodel.dart';

const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF2563EB);
const Color bgGrey = Color(0xFFF8FAFC);
const Color textDark = Color(0xFF334155);

class TableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

// ==========================================
// 1. LOCAL CONTROLLER (For Pagination & Search)
// ==========================================
class ServicePageController extends GetxController {
  final ProductController prodCtrl = Get.find<ProductController>();

  final int itemsPerPage = 15;
  final RxInt activePage = 1.obs;
  final RxInt damagePage = 1.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prodCtrl.fetchServiceLogs();
    });
  }

  // Getters for filtered lists
  List<Map<String, dynamic>> get activeServices =>
      prodCtrl.serviceLogs.where((e) => e['type'] == 'service').toList();

  List<Map<String, dynamic>> get damageLogs =>
      prodCtrl.serviceLogs.where((e) => e['type'] == 'damage').toList();

  void nextActivePage(int totalPages) {
    if (activePage.value < totalPages) activePage.value++;
  }

  void prevActivePage() {
    if (activePage.value > 1) activePage.value--;
  }

  void nextDamagePage(int totalPages) {
    if (damagePage.value < totalPages) damagePage.value++;
  }

  void prevDamagePage() {
    if (damagePage.value > 1) damagePage.value--;
  }
}

// ==========================================
// 2. MAIN UI PAGE
// ==========================================
class ServicePage extends StatelessWidget {
  ServicePage({super.key});

  final ServicePageController ctrl = Get.put(ServicePageController());
  final ScrollController _hScroll1 = ScrollController();
  final ScrollController _vScroll1 = ScrollController();
  final ScrollController _hScroll2 = ScrollController();
  final ScrollController _vScroll2 = ScrollController();

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgGrey,
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.handyman, color: darkSlate, size: isMobile ? 22 : 26),
              const SizedBox(width: 10),
              Text(
                "Service & Damage Log",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: darkSlate,
                  fontSize: isMobile ? 18 : 22,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: darkSlate),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.print, color: activeAccent),
              tooltip: "Download Report",
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected:
                  (value) => ServicePdfGenerator.generateAndDownloadPdf(
                    value,
                    ctrl.prodCtrl.serviceLogs,
                  ),
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: 'service',
                      child: Row(
                        children: [
                          Icon(Icons.build, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            "Print Service Report",
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'damage',
                      child: Row(
                        children: [
                          Icon(Icons.broken_image, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "Print Damage Report",
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => ctrl.prodCtrl.fetchServiceLogs(),
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              tooltip: "Refresh Logs",
            ),
            const SizedBox(width: 16),
          ],
          bottom: const TabBar(
            labelColor: activeAccent,
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: activeAccent,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(
                icon: Icon(Icons.build_circle_outlined),
                text: "Active Service",
              ),
              Tab(
                icon: Icon(Icons.broken_image_outlined),
                text: "Damage History",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent(isMobile, true), // Active Service
            _buildTabContent(isMobile, false), // Damage History
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB CONTENT ROUTER
  // ==========================================
  Widget _buildTabContent(bool isMobile, bool isActiveService) {
    return Obx(() {
      final isLoading = ctrl.prodCtrl.isActionLoading.value;
      final list = isActiveService ? ctrl.activeServices : ctrl.damageLogs;

      if (isLoading && list.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 3));
      }

      if (list.isEmpty) {
        return _buildEmptyState(
          isActiveService
              ? Icons.check_circle_outline
              : Icons.sentiment_satisfied_alt,
          isActiveService ? "All Clear" : "No Damage",
          isActiveService
              ? "No products currently in service."
              : "Great! No damaged items recorded.",
          isActiveService ? Colors.green : Colors.blue,
        );
      }

      // Pagination setup
      final currentPage =
          isActiveService ? ctrl.activePage.value : ctrl.damagePage.value;
      final totalItems = list.length;
      final totalPages = (totalItems / ctrl.itemsPerPage).ceil();
      final startIndex = (currentPage - 1) * ctrl.itemsPerPage;
      final endIndex =
          (startIndex + ctrl.itemsPerPage > totalItems)
              ? totalItems
              : startIndex + ctrl.itemsPerPage;
      final paginatedList = list.sublist(startIndex, endIndex);

      return Column(
        children: [
          _buildSummaryHeader(isActiveService, list),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 12 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  isMobile
                      ? _buildMobileList(paginatedList, isActiveService)
                      : _buildDesktopTable(paginatedList, isActiveService),
            ),
          ),
          _buildPaginationFooter(
            totalItems,
            startIndex,
            endIndex,
            totalPages,
            currentPage,
            isMobile,
            isActiveService,
          ),
        ],
      );
    });
  }

  // ==========================================
  // HEADER & SUMMARIES
  // ==========================================
  Widget _buildSummaryHeader(
    bool isActiveService,
    List<Map<String, dynamic>> list,
  ) {
    if (isActiveService) {
      final totalQty = list.fold<int>(
        0,
        (sum, item) =>
            item['status'] == 'active'
                ? sum + (int.tryParse(item['qty'].toString()) ?? 0)
                : sum,
      );
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.orange.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 18, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text(
              "Items currently pending repair: $totalQty",
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      final totalLoss = list.fold<double>(
        0.0,
        (sum, item) =>
            sum +
            ((int.tryParse(item['qty'].toString()) ?? 0) *
                (double.tryParse(item['return_cost'].toString()) ?? 0.0)),
      );
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.red.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 18, color: Colors.red.shade800),
            const SizedBox(width: 8),
            Text(
              "Total Loss Value: ৳${totalLoss.toStringAsFixed(2)}",
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ==========================================
  // DESKTOP TABLE
  // ==========================================
  Widget _buildDesktopTable(
    List<Map<String, dynamic>> list,
    bool isActiveService,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
        final hScroll = isActiveService ? _hScroll1 : _hScroll2;
        final vScroll = isActiveService ? _vScroll1 : _vScroll2;

        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Scrollbar(
            controller: vScroll,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: vScroll,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: hScroll,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          child: Row(
                            children:
                                isActiveService
                                    ? [
                                      _headerCell("DATE", 180),
                                      _headerCell("MODEL", 200),
                                      _headerCell("QTY", 80),
                                      _headerCell("UNIT VALUE", 120),
                                      _headerCell("STATUS", 120),
                                      _headerCell("ACTION", 150),
                                    ]
                                    : [
                                      _headerCell("DATE", 180),
                                      _headerCell("MODEL", 200),
                                      _headerCell("QTY", 80),
                                      _headerCell("UNIT COST", 120),
                                      _headerCell("TOTAL LOSS", 150),
                                    ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final qty =
                                int.tryParse(item['qty'].toString()) ?? 0;
                            final cost =
                                double.tryParse(
                                  item['return_cost'].toString(),
                                ) ??
                                0.0;
                            final dateStr = _formatDate(item['created_at']);

                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                              child:
                                  isActiveService
                                      ? _buildActiveServiceDesktopRow(
                                        item,
                                        qty,
                                        cost,
                                        dateStr,
                                      )
                                      : _buildDamageDesktopRow(
                                        item,
                                        qty,
                                        cost,
                                        dateStr,
                                      ),
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
      },
    );
  }

  Widget _buildActiveServiceDesktopRow(
    Map<String, dynamic> item,
    int qty,
    double cost,
    String dateStr,
  ) {
    final bool isActive = item['status'] == 'active';
    return Row(
      children: [
        _dataCell(
          Text(dateStr, style: const TextStyle(fontSize: 12, color: textDark)),
          180,
        ),
        _dataCell(
          Text(
            item['model'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          200,
        ),
        _dataCell(
          Text(
            "$qty",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          80,
        ),
        _dataCell(
          Text(
            "৳${cost.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
          120,
        ),
        _dataCell(
          _buildStatusBadge(
            isActive ? "Pending" : "Returned",
            isActive ? Colors.orange : Colors.green,
          ),
          120,
        ),
        _dataCell(
          isActive
              ? ElevatedButton.icon(
                onPressed:
                    () => Get.dialog(
                      _ReturnStockDialog(
                        id: item['id'],
                        modelName: item['model'],
                        maxQty: qty,
                        controller: ctrl.prodCtrl,
                      ),
                    ),
                icon: const Icon(Icons.undo, size: 16),
                label: const Text("Return"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              )
              : const Text("-", style: TextStyle(color: Colors.grey)),
          150,
        ),
      ],
    );
  }

  Widget _buildDamageDesktopRow(
    Map<String, dynamic> item,
    int qty,
    double cost,
    String dateStr,
  ) {
    final totalLoss = qty * cost;
    return Row(
      children: [
        _dataCell(
          Text(dateStr, style: const TextStyle(fontSize: 12, color: textDark)),
          180,
        ),
        _dataCell(
          Text(
            item['model'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          200,
        ),
        _dataCell(
          Text(
            "$qty",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          80,
        ),
        _dataCell(
          Text(
            "৳${cost.toStringAsFixed(2)}",
            style: const TextStyle(color: textDark),
          ),
          120,
        ),
        _dataCell(
          Text(
            "৳${totalLoss.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          150,
        ),
      ],
    );
  }

  Widget _headerCell(String text, double width) => SizedBox(
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
  Widget _dataCell(Widget child, double width) => SizedBox(
    width: width,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  // ==========================================
  // MOBILE CARDS
  // ==========================================
  Widget _buildMobileList(
    List<Map<String, dynamic>> list,
    bool isActiveService,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        final qty = int.tryParse(item['qty'].toString()) ?? 0;
        final cost = double.tryParse(item['return_cost'].toString()) ?? 0.0;
        final dateStr = _formatDate(item['created_at']);

        if (isActiveService) {
          final bool isActive = item['status'] == 'active';
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['model'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: darkSlate,
                        ),
                      ),
                      _buildStatusBadge(
                        isActive ? "Pending" : "Returned",
                        isActive ? Colors.orange : Colors.green,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Quantity",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "$qty",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "Unit Value",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "৳${cost.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Get.dialog(
                                  _ReturnStockDialog(
                                    id: item['id'],
                                    modelName: item['model'],
                                    maxQty: qty,
                                    controller: ctrl.prodCtrl,
                                  ),
                                ),
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text("Return Stock"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          final totalLoss = qty * cost;
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['model'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: darkSlate,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "-$qty",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "৳${totalLoss.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================
  Widget _buildStatusBadge(String status, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color.shade800,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(
    int totalItems,
    int start,
    int end,
    int totalPages,
    int current,
    bool isMobile,
    bool isActive,
  ) {
    if (totalItems == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isMobile)
            Text(
              "Showing ${start + 1} to $end of $totalItems",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed:
                    current > 1
                        ? (isActive ? ctrl.prevActivePage : ctrl.prevDamagePage)
                        : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  "Page $current of $totalPages",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    current < totalPages
                        ? () =>
                            (isActive
                                ? ctrl.nextActivePage(totalPages)
                                : ctrl.nextDamagePage(totalPages))
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String sub,
    MaterialColor color,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkSlate,
            ),
          ),
          const SizedBox(height: 8),
          Text(sub, style: const TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _ReturnStockDialog extends StatefulWidget {
  final int id;
  final String modelName;
  final int maxQty;
  final ProductController controller;

  const _ReturnStockDialog({
    required this.id,
    required this.modelName,
    required this.maxQty,
    required this.controller,
  });

  @override
  State<_ReturnStockDialog> createState() => _ReturnStockDialogState();
}

class _ReturnStockDialogState extends State<_ReturnStockDialog> {
  late TextEditingController qtyController;
  late TextEditingController locationController;
  int? selectedWarehouseId;

  @override
  void initState() {
    super.initState();
    qtyController = TextEditingController(text: widget.maxQty.toString());
    locationController = TextEditingController();
    final warehouses = widget.controller.activeWarehouses;
    if (warehouses.isNotEmpty) {
      selectedWarehouseId = warehouses.first.id;
    }
  }

  @override
  void dispose() {
    qtyController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.controller.activeWarehouses;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "Return to Stock",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Return ${widget.modelName} from Service?",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "Max available: ${widget.maxQty}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Quantity
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: "Quantity",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          // Warehouse selector
          if (warehouses.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: selectedWarehouseId,
                  hint: const Text(
                    'Select Warehouse',
                    style: TextStyle(fontSize: 13),
                  ),
                  items:
                      warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.store_outlined,
                                    size: 15,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    w.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => selectedWarehouseId = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Location (optional)
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: "Location (optional)",
              hintText: "e.g. Aisle 3, Shelf 2",
              prefixIcon: Icon(Icons.location_on, size: 18, color: Colors.teal),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final int enteredQty = int.tryParse(qtyController.text) ?? 0;
            if (enteredQty <= 0) {
              Get.snackbar(
                "Error",
                "Quantity must be at least 1",
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
              return;
            }
            if (enteredQty > widget.maxQty) {
              Get.snackbar(
                "Error",
                "Cannot return more than ${widget.maxQty}",
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
              return;
            }
            Get.back();
            widget.controller.returnFromService(
              widget.id,
              enteredQty,
              warehouseId: selectedWarehouseId,
              location:
                  locationController.text.trim().isNotEmpty
                      ? locationController.text.trim()
                      : null,
            );
          },
          child: const Text("Confirm Return"),
        ),
      ],
    );
  }
}

class ServicePdfGenerator {
  static Future<void> generateAndDownloadPdf(
    String reportType,
    List<Map<String, dynamic>> rawData,
  ) async {
    final pdf = pw.Document();

    final isDamage = reportType == 'damage';
    final title = isDamage ? "DAMAGE HISTORY REPORT" : "ACTIVE SERVICE LOG";
    final dataList = rawData.where((e) => e['type'] == reportType).toList();

    if (dataList.isEmpty) {
      Get.snackbar(
        "No Data",
        "There is no data to generate a report for.",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    int totalQty = 0;
    double totalValue = 0.0;

    for (var item in dataList) {
      int q = int.tryParse(item['qty'].toString()) ?? 0;
      double c = double.tryParse(item['return_cost'].toString()) ?? 0.0;
      totalQty += q;
      if (isDamage) totalValue += (q * c);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  "Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers:
                  isDamage
                      ? [
                        'No.',
                        'Date',
                        'Model',
                        'Qty',
                        'Unit Cost',
                        'Total Loss',
                      ]
                      : ['No.', 'Date', 'Model', 'Qty', 'Status'],
              data: List<List<String>>.generate(dataList.length, (index) {
                final item = dataList[index];
                final qty = int.tryParse(item['qty'].toString()) ?? 0;
                final cost =
                    double.tryParse(item['return_cost'].toString()) ?? 0.0;

                String dateStr = "N/A";
                if (item['created_at'] != null) {
                  dateStr = DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(DateTime.parse(item['created_at']).toLocal());
                }

                if (isDamage) {
                  return [
                    (index + 1).toString(),
                    dateStr,
                    item['model'] ?? '-',
                    qty.toString(),
                    "Tk ${cost.toStringAsFixed(2)}",
                    "Tk ${(qty * cost).toStringAsFixed(2)}",
                  ];
                } else {
                  return [
                    (index + 1).toString(),
                    dateStr,
                    item['model'] ?? '-',
                    qty.toString(),
                    item['status'] == 'active' ? 'Pending' : 'Returned',
                  ];
                }
              }),
            ),
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Total Items: $totalQty",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (isDamage) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Total Loss Value: Tk ${totalValue.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Prepared By",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Authorized Signature",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}

// Keep the old PdfService here if you need it for the Shortlist page
class PdfService {
  static Future<void> generateShortlistPdf(List<Product> products) async {
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      doc.addPage(
        pw.MultiPage(
          maxPages: 200,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (context) => _buildHeader(),
          footer: (context) => _buildFooter(context),
          build:
              (context) => [
                _buildSummary(products),
                pw.SizedBox(height: 15),
                _buildProductTable(products),
              ],
        ),
      );

      final String filename =
          'Reorder_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: filename);
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'INVENTORY REORDER REPORT',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildSummary(List<Product> products) {
    int critical = 0;
    for (var p in products) {
      if (p.stockQty == 0) critical++;
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text("Total Items", style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                "${products.length}",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                "Critical (0 Stock)",
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                "$critical",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductTable(List<Product> products) {
    final data =
        products.map((p) {
          final shortage = p.alertQty - p.stockQty;
          return [
            p.model,
            (p.name.length > 30 ? '${p.name.substring(0, 30)}...' : p.name)
                .replaceAll('\n', ' '),
            p.stockQty.toString(),
            p.alertQty.toString(),
            '+$shortage',
            p.stockQty == 0 ? 'CRITICAL' : 'LOW',
          ];
        }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Model', 'Name', 'Stock', 'Alert', 'Shortage', 'Status'],
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 18,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }
}
