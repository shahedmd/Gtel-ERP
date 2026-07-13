import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/cmodel.dart';
import 'package:intl/intl.dart';
import 'conditioncontroller.dart'; // Ensure the path matches your controller file

class ConditionSalesPage extends StatefulWidget {
  const ConditionSalesPage({super.key});

  @override
  State<ConditionSalesPage> createState() => _ConditionSalesPageState();
}

class _ConditionSalesPageState extends State<ConditionSalesPage> {
  // Theme Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color alertRed = Color(0xFFDC2626);

  // Mobile breakpoint
  static const double mobileBreakpoint = 700;

  late final ConditionSalesController ctrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(ConditionSalesController());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!ctrl.isLoading.value &&
        !ctrl.isMoreLoading.value &&
        ctrl.hasMore.value &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      ctrl.loadConditionSales(loadMore: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < mobileBreakpoint;
            return SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, ctrl, isMobile),
                  _buildStatsTicker(ctrl),
                  const SizedBox(height: 10),
                  _buildFilters(context, ctrl, isMobile),
                  const SizedBox(height: 10),
                  _buildDataList(ctrl, context, isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==============================================================================
  // 1. HEADER
  // ==============================================================================
  Widget _buildHeader(
    BuildContext context,
    ConditionSalesController ctrl,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child:
          isMobile
              ? _headerMobile(context, ctrl)
              : _headerDesktop(context, ctrl),
    );
  }

  Widget _titleBlock({double iconSize = 24, double titleSize = 20}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activeAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            size: iconSize,
            color: activeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Condition Sales & Courier Ledger",
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
                maxLines: 2,
              ),
              const Text(
                "Track shipments, collect due, and manage condition sales",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _downloadPdfButton(
    BuildContext context,
    ConditionSalesController ctrl, {
    bool fullWidth = false,
  }) {
    final button = OutlinedButton.icon(
      onPressed: () => _showCourierPickerDialog(context, ctrl),
      icon: const Icon(
        Icons.picture_as_pdf_outlined,
        size: 18,
        color: alertRed,
      ),
      label: const Text(
        "Download Pending PDF",
        style: TextStyle(
          color: alertRed,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: alertRed),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _headerDesktop(BuildContext context, ConditionSalesController ctrl) {
    return Row(
      children: [
        Expanded(child: _titleBlock()),
        const SizedBox(width: 16),
        _downloadPdfButton(context, ctrl),
        const SizedBox(width: 16),
        Obx(
          () => _headerCard(
            "TOTAL COURIER DUE",
            "৳ ${ctrl.totalPendingAmount.value.toStringAsFixed(0)}",
            alertRed,
          ),
        ),
      ],
    );
  }

  Widget _headerMobile(BuildContext context, ConditionSalesController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleBlock(iconSize: 20, titleSize: 16),
        const SizedBox(height: 14),
        Obx(
          () => _headerCard(
            "TOTAL COURIER DUE",
            "৳ ${ctrl.totalPendingAmount.value.toStringAsFixed(0)}",
            alertRed,
            fullWidth: true,
          ),
        ),
        const SizedBox(height: 10),
        _downloadPdfButton(context, ctrl, fullWidth: true),
      ],
    );
  }

  Widget _headerCard(
    String title,
    String value,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment:
            fullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // 2. STATS TICKER
  // ==============================================================================
  Widget _buildStatsTicker(ConditionSalesController ctrl) {
    return Obx(() {
      if (ctrl.courierBalances.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children:
              ctrl.courierBalances.entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "৳${e.value.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: darkSlate,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    });
  }

  // ==============================================================================
  // 3. FILTERS & SEARCH
  // ==============================================================================
  Widget _buildFilters(
    BuildContext context,
    ConditionSalesController ctrl,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter chips - always horizontally scrollable so it never overflows
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(ctrl, "Today"),
                const SizedBox(width: 8),
                _filterChip(ctrl, "This Month"),
                const SizedBox(width: 8),
                _filterChip(ctrl, "Last Month"),
                const SizedBox(width: 8),
                _filterChip(ctrl, "This Year"),
                const SizedBox(width: 8),
                _filterChip(ctrl, "All Time"),
                const SizedBox(width: 8),
                _customDateChip(context, ctrl),
                const SizedBox(width: 8),
                _courierDropdown(ctrl),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          // Search Bar - always full width, stacked below chips
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (v) => ctrl.searchQuery.value = v,
              decoration: const InputDecoration(
                hintText: "Search Name, Challan, Invoice...",
                hintStyle: TextStyle(fontSize: 13),
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 20, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _courierDropdown(ConditionSalesController ctrl) {
    return Obx(() {
      List<String> couriers = ["All", ...ctrl.courierBalances.keys];
      if (!couriers.contains(ctrl.selectedCourierFilter.value)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.selectedCourierFilter.value = "All";
        });
      }

      return Container(
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:
                couriers.contains(ctrl.selectedCourierFilter.value)
                    ? ctrl.selectedCourierFilter.value
                    : "All",
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down, color: textMuted),
            items:
                couriers.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(
                      c == "All" ? "All Couriers" : c,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (val) {
              if (val != null) {
                ctrl.selectedCourierFilter.value = val;
              }
            },
          ),
        ),
      );
    });
  }

  Widget _filterChip(ConditionSalesController ctrl, String label) {
    return Obx(() {
      bool isSelected = ctrl.selectedFilter.value == label;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) {
          ctrl.customDateRange.value = null;
          ctrl.selectedFilter.value = label;
        },
        selectedColor: activeAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : darkSlate,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
      );
    });
  }

  Widget _customDateChip(BuildContext context, ConditionSalesController ctrl) {
    return Obx(() {
      bool isCustom = ctrl.selectedFilter.value == "Custom";
      String label = "Custom Date";
      if (isCustom && ctrl.customDateRange.value != null) {
        label =
            "${DateFormat('dd/MM/yy').format(ctrl.customDateRange.value!.start)} - ${DateFormat('dd/MM/yy').format(ctrl.customDateRange.value!.end)}";
      }

      return ActionChip(
        label: Text(label),
        onPressed: () async {
          DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2022),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  primaryColor: activeAccent,
                  colorScheme: const ColorScheme.light(primary: activeAccent),
                  buttonTheme: const ButtonThemeData(
                    textTheme: ButtonTextTheme.primary,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            ctrl.customDateRange.value = picked;
            ctrl.selectedFilter.value = "Custom";
          }
        },
        backgroundColor: isCustom ? activeAccent : Colors.white,
        labelStyle: TextStyle(
          color: isCustom ? Colors.white : darkSlate,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isCustom ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
      );
    });
  }

  // ==============================================================================
  // 4. DATA LIST (table on desktop, cards on mobile) - no inner scroll, page scrolls
  // ==============================================================================
  Widget _buildDataList(
    ConditionSalesController ctrl,
    BuildContext context,
    bool isMobile,
  ) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.allOrders.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (ctrl.filteredOrders.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "No condition sales records found for this period",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
        decoration: BoxDecoration(
          color: isMobile ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isMobile ? null : Border.all(color: Colors.grey.shade200),
          boxShadow:
              isMobile
                  ? null
                  : [BoxShadow(color: Colors.grey.shade100, blurRadius: 10)],
        ),
        child:
            isMobile
                ? _mobileCardsList(ctrl, context)
                : _desktopTable(ctrl, context),
      );
    });
  }

  Widget _desktopTable(ConditionSalesController ctrl, BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: darkSlate,
            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  "DATE & INVOICE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "CUSTOMER",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "LOGISTICS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "TOTAL AMOUNT",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "COURIER DUE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "ACTION",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Body - built as a plain Column since the OUTER SingleChildScrollView handles scrolling
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              ctrl.filteredOrders.length + (ctrl.isMoreLoading.value ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5),
          itemBuilder: (context, index) {
            if (index == ctrl.filteredOrders.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final order = ctrl.filteredOrders[index];
            return _orderRowDesktop(order, context, ctrl);
          },
        ),
      ],
    );
  }

  Widget _mobileCardsList(ConditionSalesController ctrl, BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount:
          ctrl.filteredOrders.length + (ctrl.isMoreLoading.value ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == ctrl.filteredOrders.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final order = ctrl.filteredOrders[index];
        return _orderCardMobile(order, context, ctrl);
      },
    );
  }

  Widget _orderRowDesktop(
    ConditionOrderModel order,
    BuildContext context,
    ConditionSalesController ctrl,
  ) {
    bool isPaid = order.courierDue <= 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  order.invoiceId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                    fontSize: 13,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yy, hh:mm a').format(order.date),
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SelectableText(
                  order.customerPhone,
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.courierName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Challan: ${order.challanNo}",
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showEditChallanDialog(context, ctrl, order),
                      child: const Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "৳${order.grandTotal.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isPaid ? "CLEARED" : "৳${order.courierDue.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid ? successGreen : alertRed,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _confirmDeleteDialog(context, ctrl, order),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: alertRed,
                  ),
                  tooltip: "Delete Condition Sale",
                ),
                IconButton(
                  onPressed: () => ctrl.printInvoice(order),
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 20,
                    color: darkSlate,
                  ),
                  tooltip: "Download/Print Invoice",
                ),
                const SizedBox(width: 8),
                if (isPaid)
                  const Icon(Icons.check_circle, color: successGreen, size: 22)
                else
                  ElevatedButton(
                    onPressed: () => _showPaymentDialog(context, ctrl, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      "Collect",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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

  // Mobile card - all the same data, stacked vertically instead of in columns
  Widget _orderCardMobile(
    ConditionOrderModel order,
    BuildContext context,
    ConditionSalesController ctrl,
  ) {
    bool isPaid = order.courierDue <= 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice + date + delete/print icons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      order.invoiceId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yy, hh:mm a').format(order.date),
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ctrl.printInvoice(order),
                icon: const Icon(
                  Icons.print_outlined,
                  size: 20,
                  color: darkSlate,
                ),
                tooltip: "Download/Print Invoice",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _confirmDeleteDialog(context, ctrl, order),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: alertRed,
                ),
                tooltip: "Delete Condition Sale",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 20),
          // Customer
          Text(
            order.customerName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          SelectableText(
            order.customerPhone,
            style: const TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 10),
          // Courier + challan
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.courierName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Challan: ${order.challanNo}",
                    style: const TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showEditChallanDialog(context, ctrl, order),
                    child: const Icon(Icons.edit, size: 13, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount + Due
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOTAL AMOUNT",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      "৳${order.grandTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "COURIER DUE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      isPaid
                          ? "CLEARED"
                          : "৳${order.courierDue.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isPaid ? successGreen : alertRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action
          SizedBox(
            width: double.infinity,
            child:
                isPaid
                    ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: successGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: successGreen,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Payment Cleared",
                            style: TextStyle(
                              color: successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ElevatedButton(
                      onPressed: () => _showPaymentDialog(context, ctrl, order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Collect Payment",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // DIALOGS (widths now adapt to screen size)
  // ==============================================================================

  double _dialogWidth(BuildContext context, double maxWidth) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth < maxWidth + 32 ? screenWidth * 0.92 : maxWidth;
  }

  void _showCourierPickerDialog(
    BuildContext context,
    ConditionSalesController ctrl,
  ) {
    List<String> couriers = ctrl.courierBalances.keys.toList();

    if (couriers.isEmpty) {
      Get.snackbar("No Couriers", "No couriers with pending dues found.");
      return;
    }

    String? selectedCourier;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Container(
              width: _dialogWidth(context, 350),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Courier",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Choose the courier to generate the pending sales PDF for.",
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourier,
                    items:
                        couriers
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => selectedCourier = v),
                    decoration: const InputDecoration(
                      labelText: "Courier",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed:
                          selectedCourier == null
                              ? null
                              : () {
                                Get.back();
                                ctrl.downloadPendingConditionSalesReport(
                                  selectedCourier!,
                                );
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "GENERATE PDF",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDeleteDialog(
    BuildContext context,
    ConditionSalesController ctrl,
    ConditionOrderModel order,
  ) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: _dialogWidth(context, 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: alertRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: alertRed,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Delete Condition Sale?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Invoice: ${order.invoiceId}\nAre you sure you want to delete this sale? The products will be restored to the SEA stock automatically.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: darkSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ctrl.deleteConditionSale(order);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditChallanDialog(
    BuildContext context,
    ConditionSalesController ctrl,
    ConditionOrderModel order,
  ) {
    final cController = TextEditingController(text: order.challanNo);
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: _dialogWidth(context, 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Challan Number",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: cController,
                decoration: const InputDecoration(
                  labelText: "New Challan No",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                  ),
                  onPressed: () {
                    ctrl.updateChallanNumber(
                      order.invoiceId,
                      order.customerPhone,
                      cController.text,
                    );
                  },
                  child: const Text(
                    "Update",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    ConditionSalesController ctrl,
    ConditionOrderModel order,
  ) {
    final amountC = TextEditingController(
      text: order.courierDue.toStringAsFixed(0),
    );
    final refC = TextEditingController();
    String method = "Cash";

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setState) {
            String refLabel = "Reference Note";
            String refHint = "Optional";
            if (method == "Bank") {
              refLabel = "Bank Name & Account No.";
              refHint = "Required (e.g., BRAC 1029...)";
            } else if (method == "Bkash") {
              refLabel = "Bkash Number";
              refHint = "Required (e.g., 017...)";
            } else if (method == "Nagad") {
              refLabel = "Nagad Number";
              refHint = "Required (e.g., 017...)";
            }

            return SingleChildScrollView(
              child: Container(
                width: _dialogWidth(context, 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Receive from ${order.courierName}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Invoice: ${order.invoiceId}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Due: ৳${order.courierDue.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: alertRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: amountC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Received Amount",
                        prefixText: "৳ ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      items:
                          ["Cash", "Bank", "Bkash", "Nagad"]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            method = v;
                            refC.clear();
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Payment Method",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: refC,
                      decoration: InputDecoration(
                        labelText: refLabel,
                        hintText: refHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Obx(
                        () => ElevatedButton(
                          onPressed:
                              ctrl.isLoading.value
                                  ? null
                                  : () {
                                    double amt =
                                        double.tryParse(amountC.text) ?? 0;
                                    if (amt <= 0) {
                                      Get.snackbar(
                                        "Error",
                                        "Please enter a valid amount",
                                      );
                                      return;
                                    }
                                    if (method != "Cash" &&
                                        refC.text.trim().isEmpty) {
                                      Get.snackbar(
                                        "Error",
                                        "$refLabel is required for $method payments",
                                      );
                                      return;
                                    }
                                    ctrl.receiveConditionPayment(
                                      order: order,
                                      receivedAmount: amt,
                                      method: method,
                                      refNumber: refC.text.trim(),
                                    );
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successGreen,
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              ctrl.isLoading.value
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    "CONFIRM COLLECTION",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
