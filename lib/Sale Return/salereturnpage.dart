// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart'; // Ensure you add this package: shimmer: ^3.0.0
import 'salereturnController.dart'; // Ensure this path is correct

class SaleReturnPage extends StatelessWidget {
  final controller = Get.put(SaleReturnController());

  // === NEW: Local State for Internal Item Filtering ===
  final RxString _internalItemSearchQuery = ''.obs;

  SaleReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50 background (lighter)
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 1. SEARCH SECTION (Invoice Search)
          _buildSearchSection(),

          // 2. MAIN CONTENT (Order Details & Item Selection)
          Expanded(
            child: Obx(() {
              // Loading State
              if (controller.isLoading.value) {
                return _buildShimmerLoading();
              }

              // Empty State
              if (controller.orderData.value == null) {
                return _buildEmptyState();
              }

              // Data Loaded - Pass context to build the content
              return _buildMainContent(context);
            }),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ========================================================================
  // APPBAR WIDGET
  // ========================================================================

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        "Edit Invoice & Return",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Color(0xFF0F172A),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  // ========================================================================
  // MAIN CONTENT WIDGET (With Internal Search added)
  // ========================================================================

  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        120,
      ), // Extra bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerInfoCard(controller.orderData.value!),
          const SizedBox(height: 24),

          // Header for Items & Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "INVOICE ITEMS",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddProductSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add Item"),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF3B82F6,
                  ).withOpacity(0.1), // Blue-500 light
                  foregroundColor: const Color(0xFF2563EB), // Blue-600
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ============================================================
          // NEW: INTERNAL ITEM SEARCH BAR
          // ============================================================
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged:
                  (value) =>
                      _internalItemSearchQuery.value = value.toLowerCase(),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Find item in invoice (by name or model)...",
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                prefixIcon: Icon(
                  Icons.filter_list_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          // ============================================================

          // Interactive List of Items (With filtering applied)
          Obx(() {
            // 1. First, get the items (excluding purely deleted ones)
            final allVisibleItems =
                controller.modifiedItems
                    .asMap()
                    .entries
                    .where((entry) => (entry.value['qty'] as int) > 0)
                    .toList();

            // 2. Apply filtering based on internal search query
            final query = _internalItemSearchQuery.value;
            final filteredEntries =
                query.isEmpty
                    ? allVisibleItems
                    : allVisibleItems.where((entry) {
                      final name = entry.value['name'].toString().toLowerCase();
                      final model =
                          entry.value['model'].toString().toLowerCase();
                      return name.contains(query) || model.contains(query);
                    }).toList();

            // 3. Render the list
            if (filteredEntries.isEmpty && query.isNotEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "No matching items found in this invoice.",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEntries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final originalIndex = filteredEntries[idx].key;
                final item = filteredEntries[idx].value;
                return _buildEditableItemCard(originalIndex, item);
              },
            );
          }),
        ],
      ),
    );
  }

  // ========================================================================
  // INVOICE SEARCH SECTION (Top of page)
  // ========================================================================

  Widget _buildSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Slate-100
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: controller.searchController,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Enter Full ID or Last 4 Digits...",
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (val) {
                  _internalItemSearchQuery.value =
                      ''; // Reset item filter on new search
                  controller.smartSearch(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _internalItemSearchQuery.value =
                    ''; // Reset item filter on new search
                controller.smartSearch(controller.searchController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B), // Slate-800
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: const Text(
                "Find",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SHIMMER LOADING WIDGET
  // ========================================================================

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 100,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ), // Search bar shimmer
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (index) => Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // EMPTY STATE WIDGET
  // ========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Find an Invoice",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the full ID or the last few digits to\nmodify items or process a return.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SUB-WIDGETS (Optimized UI Elements)
  // ========================================================================

  Widget _buildCustomerInfoCard(Map<String, dynamic> data) {
    bool isCondition = data['isCondition'] == true;
    String courierName = data['courierName'] ?? "";
    double originalTotal =
        double.tryParse(data['grandTotal'].toString()) ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['customerName'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['customerPhone'] ?? "",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCondition)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF), // Purple-50
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE9D5FF),
                    ), // Purple-200
                  ),
                  child: Text(
                    courierName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E22CE),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Invoice ID",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    data['invoiceId'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Original Total",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "৳${originalTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItemCard(int index, Map<String, dynamic> item) {
    int qty = item['qty'];
    double price = item['saleRate'];
    double subtotal = item['subtotal'];
    String pid = item['productId'].toString();
    String currentDest = controller.returnDestinations[pid] ?? 'Local';

    Color qtyColor =
        qty > 0 ? const Color(0xFF0F172A) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (item['model'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      item['model'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildItemStat("Rate", "৳${price.toStringAsFixed(0)}"),
                    const SizedBox(width: 12),
                    _buildItemStat(
                      "Subtotal",
                      "৳${subtotal.toStringAsFixed(0)}",
                      isBold: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildReturnToDropdown(pid, currentDest),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQtyBtn(
                      Icons.remove,
                      () => controller.decreaseQty(index),
                      const Color(0xFF64748B),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        "$qty",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: qtyColor,
                        ),
                      ),
                    ),
                    _buildQtyBtn(
                      Icons.add,
                      () => controller.increaseQty(index),
                      const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => controller.removeProduct(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemStat(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildReturnToDropdown(String pid, String currentDest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Return to: ",
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentDest,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
              items:
                  ['Local', 'Sea', 'Air']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
              onChanged: (val) {
                if (val != null) {
                  controller.setDestination(pid, val);
                  controller.returnDestinations.refresh();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // BOTTOM BAR WIDGET
  // ========================================================================

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      if (controller.orderData.value == null) return const SizedBox.shrink();

      double originalTotal =
          double.tryParse(
            controller.orderData.value!['grandTotal'].toString(),
          ) ??
          0.0;
      double newTotal = controller.currentModifiedTotal;
      double delta = newTotal - originalTotal;

      bool isRefund = delta < 0;

      String deltaText = delta.abs().toStringAsFixed(0);
      Color deltaColor =
          isRefund ? const Color(0xFFDC2626) : const Color(0xFFCA8A04);

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "New Total",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "৳ ${newTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (delta != 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: deltaColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${isRefund ? 'Refund' : 'Extra Due'}: ৳$deltaText",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: deltaColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      () => _confirmUpdateDialog(
                        context,
                        originalTotal,
                        newTotal,
                        delta,
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Update",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ========================================================================
  // CONFIRMATION DIALOG & HELPERS (modernized)
  // ========================================================================

  void _confirmUpdateDialog(
    BuildContext context,
    double oldTotal,
    double newTotal,
    double delta,
  ) {
    String dominantMethod = 'Cash';
    if (controller.orderData.value != null) {
      var pd = controller.orderData.value!['paymentDetails'] ?? {};
      double c = double.tryParse(pd['cash']?.toString() ?? '0') ?? 0;
      double b = double.tryParse(pd['bkash']?.toString() ?? '0') ?? 0;
      double n = double.tryParse(pd['nagad']?.toString() ?? '0') ?? 0;
      double bk = double.tryParse(pd['bank']?.toString() ?? '0') ?? 0;

      if (b > c && b >= n && b >= bk)
        {dominantMethod = 'Bkash';}
      else if (n > c && n >= b && n >= bk)
        {dominantMethod = 'Nagad';}
      else if (bk > c && bk >= b && bk >= n)
        {dominantMethod = 'Bank';}
    }

    double extraPaid = delta > 0 ? delta : 0.0;
    String selectedMethod = dominantMethod;
    final extraPaidCtrl = TextEditingController(
      text: extraPaid.toStringAsFixed(0),
    );

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            delta < 0
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        delta < 0
                            ? Icons.assignment_return_rounded
                            : Icons.edit_attributes,
                        size: 24,
                        color:
                            delta < 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Confirm Update",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        "Original:",
                        "৳${oldTotal.toStringAsFixed(0)}",
                        const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        "New Total:",
                        "৳${newTotal.toStringAsFixed(0)}",
                        const Color(0xFF0F172A),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (delta > 0)
                  _buildExtraDueForm(
                    delta,
                    extraPaidCtrl,
                    selectedMethod,
                    (val) => selectedMethod = val!,
                  )
                else if (delta < 0)
                  _buildRefundInfo(delta.abs()),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                        controller.processEditInvoice(
                          extraCollectedAmount:
                              delta > 0
                                  ? (double.tryParse(extraPaidCtrl.text) ?? 0.0)
                                  : 0.0,
                          extraCollectedMethod: selectedMethod,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text("Confirm"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color textColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildExtraDueForm(
    double delta,
    TextEditingController ctrl,
    String method,
    Function(String?) onMethodChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFEF08A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Extra Bill:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA16207),
                ),
              ),
              Text(
                "৳${delta.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFFA16207),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSimpleInput(
                  ctrl,
                  "Amount Paying",
                  isNumeric: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: method,
                  isDense: true,
                  decoration: _buildModernInputDecoration("Via"),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                  items:
                      ['Cash', 'Bkash', 'Nagad', 'Bank']
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                  onChanged: onMethodChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "*If customer isn't paying now, set amount to 0 (It will be added as Due).",
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundInfo(double refundAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You will refund ৳${refundAmount.toStringAsFixed(0)} and restore stock for returned items.",
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildModernInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _buildSimpleInput(
    TextEditingController ctrl,
    String label, {
    bool isNumeric = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: _buildModernInputDecoration(label),
    );
  }

  // ========================================================================
  // ADD PRODUCT SHEET & SHEET COMPONENTS
  // ========================================================================

  void _showAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddProductBottomSheet(),
    );
  }
}

class _AddProductBottomSheet extends StatefulWidget {
  const _AddProductBottomSheet();

  @override
  State<_AddProductBottomSheet> createState() => _AddProductBottomSheetState();
}

class _AddProductBottomSheetState extends State<_AddProductBottomSheet> {
  final SaleReturnController controller = Get.find<SaleReturnController>();

  bool _isCreatingNew = false;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: "0.0");
  final _qtyCtrl = TextEditingController(text: "1");

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await controller.searchStockProducts(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _promptQtyAndAdd(Map<String, dynamic> product) {
    final qtyC = TextEditingController(text: "1");
    final rateC = TextEditingController(
      text: product['wholesale']?.toString() ?? "0",
    );

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add ${product['name']}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  decoration: _buildSheetInputDecoration("Quantity"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rateC,
                  keyboardType: TextInputType.number,
                  decoration: _buildSheetInputDecoration("Selling Rate (৳)"),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        controller.addNewProductToInvoice(
                          product,
                          int.tryParse(qtyC.text) ?? 1,
                          double.tryParse(rateC.text) ?? 0.0,
                          double.tryParse(
                                product['avg_purchase_price']?.toString() ??
                                    "0",
                              ) ??
                              0.0,
                        );
                        Get.back(); // Close Dialog
                        Get.back(); // Close BottomSheet
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildSheetInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildToggleButton(
                  "Search Existing",
                  !_isCreatingNew,
                  Icons.search_rounded,
                  () => setState(() => _isCreatingNew = false),
                ),
                const SizedBox(width: 8),
                _buildToggleButton(
                  "Create New",
                  _isCreatingNew,
                  Icons.add_rounded,
                  () => setState(() => _isCreatingNew = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isCreatingNew ? _buildCreateNewForm() : _buildSearchList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    bool isSelected,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: "Search by Name or Model...",
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_isSearching)
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_searchResults.isEmpty && _searchCtrl.text.isNotEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "No products found.",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                var p = _searchResults[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  title: Text(
                    p['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    "${p['model'] ?? 'No Model'}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  onTap: () => _promptQtyAndAdd(p),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCreateNewForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: _buildSheetInputDecoration("Product Name"),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idCtrl,
                  decoration: _buildSheetInputDecoration("Barcode (Optional)"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _modelCtrl,
                  decoration: _buildSheetInputDecoration("Model"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildSheetInputDecoration("Sale Rate (৳)"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildSheetInputDecoration("Cost Rate (৳)"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildSheetInputDecoration("Qty"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_nameCtrl.text.isEmpty || _rateCtrl.text.isEmpty) {
                  Get.snackbar("Error", "Name and Sale Rate are required.");
                  return;
                }
                Get.back();
                controller.createAndAddNewProductToInvoice(
                  name: _nameCtrl.text,
                  model: _modelCtrl.text.trim(),
                  qty: int.tryParse(_qtyCtrl.text) ?? 1,
                  saleRate: double.tryParse(_rateCtrl.text) ?? 0.0,
                  costRate: double.tryParse(_costCtrl.text) ?? 0.0,
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              label: const Text(
                "Create & Add",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
