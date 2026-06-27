// ignore_for_file: deprecated_member_use, empty_catches

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';

// --- Theme Colors ---
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


class OrderHistoryController extends GetxController {
  final int pageSize = 15;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;

  final RxList<DocumentSnapshot> orders = <DocumentSnapshot>[].obs;
  final RxList<DocumentSnapshot> pageStartDocs = <DocumentSnapshot>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchFirstPage();
  }

  Future<void> fetchFirstPage() async {
    isLoading.value = true;
    try {
      var snap =
          await FirebaseFirestore.instance
              .collection('order_history')
              .orderBy('date', descending: true)
              .limit(pageSize)
              .get();
      orders.assignAll(snap.docs);
      if (orders.isNotEmpty) {
        pageStartDocs.clear();
        pageStartDocs.add(orders.first);
      }
      hasMore.value = orders.length == pageSize;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
    isLoading.value = false;
  }

  Future<void> fetchNextPage() async {
    if (orders.isEmpty || !hasMore.value) return;
    isLoading.value = true;
    try {
      var snap =
          await FirebaseFirestore.instance
              .collection('order_history')
              .orderBy('date', descending: true)
              .startAfterDocument(orders.last)
              .limit(pageSize)
              .get();

      if (snap.docs.isNotEmpty) {
        orders.assignAll(snap.docs);
        pageStartDocs.add(orders.first);
        hasMore.value = orders.length == pageSize;
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load next page",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
    isLoading.value = false;
  }

  Future<void> fetchPrevPage() async {
    if (pageStartDocs.length > 1) {
      isLoading.value = true;
      try {
        pageStartDocs.removeLast();
        var targetDoc = pageStartDocs.last;

        var snap =
            await FirebaseFirestore.instance
                .collection('order_history')
                .orderBy('date', descending: true)
                .startAtDocument(targetDoc)
                .limit(pageSize)
                .get();

        orders.assignAll(snap.docs);
        hasMore.value = true;
      } catch (e) {}
      isLoading.value = false;
    }
  }

  Future<void> refreshCurrentPage() async {
    if (pageStartDocs.isEmpty) return fetchFirstPage();
    isLoading.value = true;
    try {
      var targetDoc = pageStartDocs.last;
      var snap =
          await FirebaseFirestore.instance
              .collection('order_history')
              .orderBy('date', descending: true)
              .startAtDocument(targetDoc)
              .limit(pageSize)
              .get();
      orders.assignAll(snap.docs);
      hasMore.value = orders.length == pageSize;
    } catch (e) {}
    isLoading.value = false;
  }
}

// ==========================================
// 2. MAIN UI PAGE (Stateless + Obx)
// ==========================================
class OrderHistoryPage extends StatelessWidget {
  OrderHistoryPage({super.key});

  final OrderHistoryController ctrl = Get.put(OrderHistoryController());
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.history_edu, color: darkSlate, size: isMobile ? 22 : 26),
            const SizedBox(width: 10),
            Text(
              "Purchase Order History",
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Obx(
                      () =>
                          ctrl.isLoading.value
                              ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                              : ctrl.orders.isEmpty
                              ? _buildEmptyState()
                              : (isMobile
                                  ? _buildMobileCards()
                                  : _buildDesktopTable(context)),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildPaginationFooter(isMobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Order Records",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: darkSlate,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: ctrl.refreshCurrentPage,
            tooltip: "Refresh",
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 950 ? constraints.maxWidth : 950.0;

        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
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
                            children: [
                              _headerCell("S/N", 60),
                              _headerCell("DATE", 160),
                              _headerCell("COMPANY NAME", 250),
                              _headerCell("VIA", 80),
                              _headerCell("ITEMS", 80),
                              _headerCell("STATUS", 120),
                              _headerCell("ACTION", 80),
                            ],
                          ),
                        ),
                        Obx(
                          () => ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ctrl.orders.length,
                            itemBuilder: (context, index) {
                              final doc = ctrl.orders[index];
                              final data = doc.data() as Map<String, dynamic>;

                              String dateStr = "N/A";
                              if (data['date'] != null) {
                                DateTime dt =
                                    (data['date'] as Timestamp).toDate();
                                dateStr = DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(dt);
                              }

                              final int serial =
                                  ((ctrl.pageStartDocs.length - 1) *
                                      ctrl.pageSize) +
                                  index +
                                  1;
                              final status = data['status'] ?? 'Pending';

                              return Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 20,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _dataCell(
                                      Text(
                                        "$serial",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textDark,
                                        ),
                                      ),
                                      60,
                                    ),
                                    _dataCell(
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      160,
                                    ),
                                    _dataCell(
                                      Text(
                                        data['company_name'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: darkSlate,
                                          fontSize: 14,
                                        ),
                                      ),
                                      250,
                                    ),
                                    _dataCell(
                                      Text(
                                        data['delivery_method'] ?? 'N/A',
                                        style: const TextStyle(color: textDark),
                                      ),
                                      80,
                                    ),
                                    _dataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "${data['total_items'] ?? 0}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: activeAccent,
                                          ),
                                        ),
                                      ),
                                      80,
                                    ),
                                    _dataCell(_buildStatusBadge(status), 120),
                                    _dataCell(
                                      _buildActionMenu(context, doc.id, status),
                                      80,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

  Widget _headerCell(String text, double width) {
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

  Widget _dataCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _buildMobileCards() {
    return Obx(
      () => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final doc = ctrl.orders[index];
          final data = doc.data() as Map<String, dynamic>;

          String dateStr = "N/A";
          if (data['date'] != null) {
            dateStr = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format((data['date'] as Timestamp).toDate());
          }
          final status = data['status'] ?? 'Pending';

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Expanded(
                        child: Text(
                          data['company_name'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: darkSlate,
                          ),
                        ),
                      ),
                      _buildActionMenu(context, doc.id, status),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Delivery Via",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                data['delivery_method'] ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "Total Items",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${data['total_items'] ?? 0} Models",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: activeAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color border = const Color(0xFFFDE68A);
    Color text = const Color(0xFFD97706);

    if (status == 'On the way') {
      bg = const Color(0xFFDBEAFE);
      border = const Color(0xFFBFDBFE);
      text = activeAccent;
    } else if (status == 'Complete') {
      bg = const Color(0xFFD1FAE5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      color: Colors.white,
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile)
              Text(
                "Page ${ctrl.pageStartDocs.isEmpty ? 1 : ctrl.pageStartDocs.length}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      ctrl.pageStartDocs.length > 1 && !ctrl.isLoading.value
                          ? ctrl.fetchPrevPage
                          : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text("Prev"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: darkSlate,
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      ctrl.hasMore.value && !ctrl.isLoading.value
                          ? ctrl.fetchNextPage
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: darkSlate,
                    elevation: 0,
                  ),
                  child: const Row(
                    children: [
                      Text("Next"),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.black12),
            SizedBox(height: 16),
            Text(
              "No order history found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    String docId,
    String currentStatus,
  ) {
    return PopupMenuButton<String>(
      tooltip: "Actions",
      icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'view') {
          _showOrderDetails(
            context,
            docId,
          ).then((_) => ctrl.refreshCurrentPage());
        }
        if (value == 'status') _changeOrderStatusDialog(docId, currentStatus);
        if (value == 'delete') _deleteFullOrderDialog(docId);
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, color: activeAccent, size: 20),
                  SizedBox(width: 10),
                  Text('View / Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'status',
              child: Row(
                children: [
                  Icon(Icons.sync_alt, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Text('Change Status'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Delete Order', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  // ==========================================
  // DIALOGS (Refactored to Obx & Local State)
  // ==========================================
  void _changeOrderStatusDialog(String docId, String currentStatus) {
    RxString selectedStatus =
        currentStatus.obs; // GetX reactive state replaces StatefulBuilder

    Get.dialog(
      AlertDialog(
        title: const Text("Update Order Status"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Obx(
          () => DropdownButtonFormField<String>(
            value: selectedStatus.value,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items:
                ['Pending', 'On the way', 'Complete']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (val) {
              if (val != null) selectedStatus.value = val;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              ctrl.isLoading.value = true;
              await FirebaseFirestore.instance
                  .collection('order_history')
                  .doc(docId)
                  .update({'status': selectedStatus.value});
              await ctrl.refreshCurrentPage();
              Get.snackbar(
                "Success",
                "Status changed to ${selectedStatus.value}",
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _deleteFullOrderDialog(String docId) {
    Get.defaultDialog(
      title: "Delete Entire Order?",
      middleText: "This action cannot be undone. Are you sure?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: darkSlate,
      onConfirm: () async {
        Get.back();
        ctrl.isLoading.value = true;
        await FirebaseFirestore.instance
            .collection('order_history')
            .doc(docId)
            .delete();
        await ctrl.refreshCurrentPage();
        Get.snackbar(
          "Deleted",
          "Purchase order deleted.",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      },
    );
  }

  Future<void> _showOrderDetails(BuildContext context, String docId) async {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 800,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final List items = data['items'] ?? [];
              final status = data['status'] ?? 'Pending';
              final company = data['company_name'] ?? 'N/A';
              final delivery = data['delivery_method'] ?? 'N/A';

              String dateStr = "";
              if (data['date'] != null) {
                dateStr = DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format((data['date'] as Timestamp).toDate());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Order Details",
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1),

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
                                "Supplier: $company",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Date: $dateStr\nVia: $delivery | Status: $status",
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobile)
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    () => Get.dialog(
                                      _AddProductToOrderDialog(
                                        docId: docId,
                                        currentItems: items,
                                      ),
                                    ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Add Item"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed:
                                    items.isEmpty
                                        ? null
                                        : () =>
                                            HistoryPdfGenerator.generateHistoryPdf(
                                              items,
                                              data,
                                              dateStr,
                                            ),
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text("Reprint PO"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: activeAccent,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  if (isMobile) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Get.dialog(
                                  _AddProductToOrderDialog(
                                    docId: docId,
                                    currentItems: items,
                                  ),
                                ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                items.isEmpty
                                    ? null
                                    : () =>
                                        HistoryPdfGenerator.generateHistoryPdf(
                                          items,
                                          data,
                                          dateStr,
                                        ),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text("Reprint"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    "Ordered Items",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child:
                        items.isEmpty
                            ? const Center(
                              child: Text(
                                "No items left in this order.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder:
                                    (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      item['model'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item['name'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_square,
                                            color: Colors.blueGrey,
                                            size: 20,
                                          ),
                                          onPressed:
                                              () => Get.dialog(
                                                _EditItemQtyDialog(
                                                  docId: docId,
                                                  currentItems: items,
                                                  index: index,
                                                  currentQty: item['order_qty'],
                                                ),
                                              ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Text(
                                            "${item['order_qty']}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed:
                                              () => _deleteItemFromList(
                                                docId,
                                                items,
                                                index,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _deleteItemFromList(String docId, List currentItems, int index) {
    Get.defaultDialog(
      title: "Remove Item?",
      middleText: "Remove this product from the order?",
      textConfirm: "Remove",
      textCancel: "Cancel",
      buttonColor: Colors.red,
      confirmTextColor: Colors.white,
      onConfirm: () async {
        currentItems.removeAt(index);
        if (currentItems.isEmpty) {
          await FirebaseFirestore.instance
              .collection('order_history')
              .doc(docId)
              .delete();
          Get.back();
          Get.back(); // Close both dialogs
        } else {
          await FirebaseFirestore.instance
              .collection('order_history')
              .doc(docId)
              .update({
                'items': currentItems,
                'total_items': currentItems.length,
              });
          Get.back();
        }
      },
    );
  }
}

// ==========================================
// Stateful Dialog (Required to safely dispose TextEditingController)
// ==========================================
class _EditItemQtyDialog extends StatefulWidget {
  final String docId;
  final List currentItems;
  final int index;
  final int currentQty;

  const _EditItemQtyDialog({
    required this.docId,
    required this.currentItems,
    required this.index,
    required this.currentQty,
  });

  @override
  State<_EditItemQtyDialog> createState() => _EditItemQtyDialogState();
}

class _EditItemQtyDialogState extends State<_EditItemQtyDialog> {
  late TextEditingController qtyCtrl;

  @override
  void initState() {
    super.initState();
    qtyCtrl = TextEditingController(text: widget.currentQty.toString());
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "Edit Quantity",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: TextField(
        controller: qtyCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            int newQty = int.tryParse(qtyCtrl.text) ?? 0;
            if (newQty > 0) {
              widget.currentItems[widget.index]['order_qty'] = newQty;
              await FirebaseFirestore.instance
                  .collection('order_history')
                  .doc(widget.docId)
                  .update({'items': widget.currentItems});
              Get.back();
            }
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

// ==========================================
// Stateless Dialog with Local Rx State
// ==========================================
class _AddProductToOrderDialog extends StatelessWidget {
  final String docId;
  final List currentItems;

  _AddProductToOrderDialog({required this.docId, required this.currentItems});

  final ProductController prodCtrl = Get.find<ProductController>();
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;

  void _performSearch(String val) async {
    if (val.length < 2) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }
    isSearching.value = true;
    var results = await prodCtrl.searchProductsForDropdown(val);
    searchResults.assignAll(results);
    isSearching.value = false;
  }

  void _promptQtyAndAdd(Map<String, dynamic> selectedProduct) {
    TextEditingController qtyCtrl = TextEditingController(text: "1");
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Add ${selectedProduct['model']}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Order Quantity",
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              int qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty > 0) {
                int existingIndex = currentItems.indexWhere(
                  (item) => item['product_id'] == selectedProduct['id'],
                );
                if (existingIndex != -1) {
                  currentItems[existingIndex]['order_qty'] += qty;
                } else {
                  currentItems.add({
                    'product_id': selectedProduct['id'],
                    'model': selectedProduct['model'],
                    'name': selectedProduct['name'],
                    'order_qty': qty,
                  });
                }
                await FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .update({
                      'items': currentItems,
                      'total_items': currentItems.length,
                    });
                Get.back();
                Get.back();
                Get.snackbar(
                  "Added",
                  "${selectedProduct['model']} added to order.",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text("Add to Order"),
          ),
        ],
      ),
    ).then(
      (_) => qtyCtrl.dispose(),
    ); // Clean up immediately after dialog closes
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Search & Add Product",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: "Type Model or Name to search...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: _performSearch,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(
                () =>
                    isSearching.value
                        ? const Center(child: CircularProgressIndicator())
                        : searchResults.isEmpty
                        ? const Center(
                          child: Text(
                            "No results. Type to search.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.separated(
                          itemCount: searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final productMap = searchResults[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                productMap['model'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                productMap['name'],
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: activeAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () => _promptQtyAndAdd(productMap),
                                child: const Text("Select"),
                              ),
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ENTERPRISE PDF GENERATOR
// ==========================================
class HistoryPdfGenerator {
  static Future<void> generateHistoryPdf(
    List<dynamic> items,
    Map<String, dynamic> orderData,
    String orderDate,
  ) async {
    final pdf = pw.Document();

    final company = orderData['company_name'] ?? 'N/A';
    final delivery = orderData['delivery_method'] ?? 'N/A';
    final status = orderData['status'] ?? 'Pending';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "PURCHASE ORDER",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  "Date: $orderDate",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Info Block
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Supplier: $company",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Delivery Method: $delivery",
                        style: const pw.TextStyle(
                          color: PdfColors.grey800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Status: ${status.toUpperCase()}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color:
                          status == 'Complete'
                              ? PdfColors.green800
                              : PdfColors.orange800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Professional Data Table
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
              headers: ['No.', 'Model', 'Product Name', 'Order Qty'],
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(5),
                3: const pw.FlexColumnWidth(2),
              },
              data: List<List<String>>.generate(items.length, (index) {
                return [
                  (index + 1).toString(),
                  items[index]['model'] ?? '-',
                  items[index]['name'] ?? '-',
                  items[index]['order_qty'].toString(),
                ];
              }),
            ),
            pw.SizedBox(height: 15),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Text(
                    "Total Ordered Items: ${items.length}",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
              ],
            ),

            // Signature
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
      name: 'Reprint_Order_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}